import 'dart:async';
import 'dart:io';

import 'package:cdc/cdc.dart';

final gccPath = Uri.file('/usr/bin/gcc');

mixin Deletable {
  Uri get path;
  
  Future<void> delete() async => await File(path.path).delete();
}

extension BatchDelete on List<Deletable> {
  Future<void> delete() async {
    for (var file in this) {
      await file.delete();
    }
  }
}

class CFile {
  final Uri path;

  const CFile(this.path); 

  Future<TranslationUnitFile> expand([Uri? output, Map<String, String>? defines]) async {
    
    final outputPath = output ?? path.replaceExtension('.cc');

    final result = await command(Uri.file('/usr/bin/gcc'), ['-E', '-P', path.path, '-o', outputPath.path]);
    if (result != 0) {
      print("failed expanding $path");
      exit(result);
    }

    return TranslationUnitFile(outputPath);
  }
}

class TranslationUnitFile with Deletable {
  @override
  final Uri path;

  const TranslationUnitFile(this.path);

  Future<List<Token>> lex() async {
    final source = await File(path.path).readAsString();
    return Lexer.lex(source);
  }

  Future<ProgramAst> parse() async {
    final tokens = await lex();
    return Parser.parse(tokens);
  }

  Future<ProgramAst> validate() async {
    final program = await parse();
    
    return analyze(program);
  }

  Future<ProgramTir> irgen() async {
    final analyzedProgram = await validate();
    return TackyIRGenerator.generate(analyzedProgram);
  }

  Future<ProgramASM> codegen(Arch arch) async {
    final ir = await irgen();

    final AsmGenerator generator = switch (arch) {
      .x86_64 => X8664Generator(),
      .aarch64 => AArch64Generator(),
    };

    return generator.generate(ir);
  }

  Future<AssemblyFile> emitAsmFile(Arch arch, [Uri? output]) async {
    final asm = await codegen(arch);
    final code = asm.emit();

    final outputPath = output ?? path.replaceExtension('.s');
    await File(outputPath.path).writeAsString(code);
  
    return switch (arch) {
      .x86_64 => X8664AssemblyFile(outputPath),
      .aarch64 => AArch64AssemblyFile(outputPath),
    };
  }
}

abstract class AssemblyFile with Deletable {
  @override
  final Uri path;

  const AssemblyFile(this.path);

  Future<ObjectFile> compile([Uri? output]);
}

class X8664AssemblyFile extends AssemblyFile {
  X8664AssemblyFile(super.path);
  
  @override
  Future<ObjectFile> compile([Uri? output]) async {
    final outputPath = output ?? path.replaceExtension('.o');
    
    final result = await command(Uri.file('/usr/bin/x86_64-linux-gnu-as'), ['-c', path.path, '-o', outputPath.path]);
    if (result != 0) {
      print("failed compiling $path");
      exit(result);
    }

    return X8664ObjectFile(outputPath);
  }
}


class AArch64AssemblyFile extends AssemblyFile {
  AArch64AssemblyFile(super.path);
  
  @override
  Future<ObjectFile> compile([Uri? output]) async {
    final outputPath = output ?? path.replaceExtension('.o');
    
    final result = await command(Uri.file('/usr/bin/aarch64-linux-gnu-as'), ['-c', path.path, '-o', outputPath.path]);
    if (result != 0) {
      print("failed compiling $path");
      exit(result);
    }

    return AArch64ObjectFile(outputPath);
  }
}

abstract class ObjectFile with Deletable {
  @override
  final Uri path;

  ObjectFile(this.path);
  
  Linker createLinker({bool shared = false, bool freestanding = false, Uri? linkerScript});
}

class X8664ObjectFile extends ObjectFile {
  X8664ObjectFile(super.path);
  
  @override
  Linker createLinker({bool shared = false, bool freestanding = false, Uri? linkerScript}) => 
    X8664Linker(objects: [this], shared: shared, freestanding: freestanding);
}

class AArch64ObjectFile extends ObjectFile {
  AArch64ObjectFile(super.path);

  @override
  Linker createLinker({bool shared = false, bool freestanding = false, Uri? linkerScript}) => 
    AArch64Linker(objects: [this], shared: shared, freestanding: freestanding);
}

abstract class Linker {
  final List<ObjectFile> objects;
  final Uri? linkerScript;
  final bool shared;
  final bool freestanding;
  final String? entry;

  const Linker({required this.objects, this.entry, this.linkerScript, required this.shared, required this.freestanding});

  static Linker of(List<ObjectFile> objects, {bool shared = false, bool freestanding = false, Uri? linkerScript}) {
    if (objects.isEmpty) throw Exception("Can't create a linker for a list of empty objects.");
    
    final linker = objects.first.createLinker(shared: shared, freestanding: freestanding, linkerScript: linkerScript);
    objects.sublist(1).forEach((object) => linker.addObject(object));
    return linker;
  } 

  void addObject(ObjectFile object);

  Future<ElfFile> link({Uri? output});
}

class X8664Linker implements Linker {
  @override
  final List<ObjectFile> objects;
  @override
  final Uri? linkerScript;
  @override
  final bool shared;
  @override
  final bool freestanding;
  @override
  final String? entry;

  const X8664Linker({required this.objects, this.entry, this.linkerScript, this.shared = false, this.freestanding = false});

  @override
  Future<ElfFile> link({Uri? output}) async {
    final outputPath = output?.path ?? 'a.out';
    final linker = Uri.file(freestanding ? '/opt/cross/bin/x86_64-elf-gcc' : '/usr/bin/x86_64-linux-gnu-gcc');

    final args = [
      ...objects.map((e) => e.path.path),
      '-o',
      outputPath,
      if (linkerScript != null) ...[
        '-X',
        linkerScript!.path,
      ],
      if (shared) '-shared',
    ];


    final result = await command(linker, args);
    if (result != 0) {
      print("failed linking $outputPath");
      exit(result);
    }

    return ElfFile(Uri.file(outputPath));
  }
  
  @override
  void addObject(ObjectFile object) {
    if (object is! X8664ObjectFile) throw Exception("object file should be of same arch.");
    objects.add(object);
  }
}

class AArch64Linker implements Linker {
  @override
  final List<ObjectFile> objects;
  @override
  final Uri? linkerScript;
  @override
  final bool shared;
  @override
  final bool freestanding;
  @override
  final String? entry;

  const AArch64Linker({required this.objects, this.entry, this.linkerScript, this.shared = false, this.freestanding = false});


  @override
  Future<ElfFile> link({Uri? output}) async {
    final outputPath = output?.path ?? 'a.out';
    final linker = Uri.file(freestanding ? '/opt/cross/bin/aarch64-elf-gcc' : '/usr/bin/aarch64-linux-gnu-gcc-14');

    final args = [
      ...objects.map((e) => e.path.path),
      '-o',
      outputPath,
      if (linkerScript != null) ...[
        '-X',
        linkerScript!.path,
      ],
      if (shared) '-shared',
    ];


    final result = await command(linker, args);
    if (result != 0) {
      print("failed linking $outputPath");
      exit(result);
    }

    return ElfFile(Uri.file(outputPath));
  }

  @override
  void addObject(ObjectFile object) {
    if (object is! AArch64ObjectFile) throw Exception("object file should be of same arch.");
    objects.add(object);
  }
}

class ElfFile with Deletable {
  @override
  final Uri path;

  ElfFile(this.path);
}

