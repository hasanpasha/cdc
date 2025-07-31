import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:parse_args/parse_args.dart';
// TODO: replace with a better logger
import 'package:thin_logger/thin_logger.dart';

import 'package:cdc/cdc.dart';

final _logger = Logger();

class Options {
  static const appName = "cdc";
  static const appVersion = "0.0.1";

  late final Set<Uri> inputFiles;

  late final bool isVerbose;
  late final bool onlyLex;
  late final bool onlyParse;
  late final bool onlyValidate;
  late final bool onlyGenTacky;
  late final bool onlyGenASM;

  late final bool compileOnly;
  late final bool shared;
  late final Uri? output;
  late final Arch target;

  late final bool compileAndAssemble;

  Future parse(List<String> args) async {
    final optDefStr = """
    |verbose|?,h,help|lex|parse|validate|tacky|codegen
    |s,compile_only|shared|o,output:|t,target:
    |c,compile_assemble|
    ::
    """;

    final result = parseArgs(optDefStr, args, validate: true);

    if (result.isSet("help")) {
      usage();
    }

    if (result.getStrValues('').isEmpty) {
      usage("no input.");
    } 
    
    inputFiles = result.getStrValues('').map((str) => Uri.file(str)).toSet();

    isVerbose = result.isSet('verbose');
    if (isVerbose) {
      _logger.level = Logger.levelVerbose;
    }

    onlyLex = result.isSet("lex");
    onlyParse = result.isSet("parse");
    onlyValidate = result.isSet("validate");
    onlyGenTacky = result.isSet("tacky");
    onlyGenASM = result.isSet("codegen");
    
    compileOnly = result.isSet("compile_only");
    shared = result.isSet("shared");

    final outputValue = result.getStrValue("output");
    output = (outputValue != null) ?  Uri.file(outputValue) : null;

    final targetValue = result.getStrValue("target");
    try {
      target = (targetValue == null) ? .x86_64 : Arch.values.firstWhere((arch) => arch.name == targetValue);
    } catch (_) {
      usage("Unknown target arch: $targetValue");
    }

    compileAndAssemble = result.isSet("compile_assemble");
  }

  Never usage([String? error]) => throw Exception("""
${Options.appName} ${Options.appVersion} (c) 2025 Hasan Pasha

USAGE:

${Options.appName} [OPTIONS]

-?, -h, -[-]help            - this help screen
-[-]verbose                 - detailed log
-[-]lex                     - only Lex
-[-]parse                   - only parse
-[-]validate                - only validate
-[-]tacky                   - only generate tacky
-[-]codegen                 - only generate asm without outputing file
-s, -[-]compile_only        - preserve the generated assembly file
-[-]shared                  - create a shared object 
-t, -[-]target              - compiler target architecture
                              supported: ${Arch.values.map((arch) => arch.name).join(", ")}
-c, -[-]compile_assemble    - only generate object file
${(error == null) || error.isEmpty ? '' : "\n*** ERROR: $error"}
""");
}

Future main(List<String> arguments) async {
  var o = Options();
  try {
    await o.parse(arguments);
  } on Exception catch (e) {
    _logger.error(e.toString());
    exit(1);
  }

  final inputs = o.inputFiles.map((input) => CFile(input));
  final cFiles = await Future.wait(inputs.map((input) async => await input.expand()));


  if (o.onlyLex) {
    for (final cfile in cFiles) {
      final token = await cfile.lex();
      for (var token in token) {
        _logger.out("${token.location}: ${token.kind.name} ${token.lexeme}");
      }
    }

    await cFiles.delete();
    exit(0);
  }

  if (o.onlyParse) {
    for (final cfile in cFiles) {
      final ast = await cfile.parse();
      _logger.out(prettifier(ast, lines: true));
    }
    
    await cFiles.delete();
    exit(0);
  }

  if (o.onlyValidate) {
    for (final cfile in cFiles) {
      final ast = await cfile.validate();
      _logger.out(prettifier(ast, lines: true));
    }
    
    await cFiles.delete();
    exit(0);
  }

  if (o.onlyGenTacky) {
    for (final cfile in cFiles) {
      final ir = await cfile.irgen();
      _logger.out(ir.accept(TackyIrInspector()));
    }
    
    await cFiles.delete();
    exit(0);
  }

  final Arch arch = o.target;

  if (o.onlyGenASM) {
    for (final cfile in cFiles) {
      final asm = await cfile.codegen(arch);
      _logger.out(asm.toString());
    }
    
    await cFiles.delete();
    exit(0);
  }

  final asmFiles = await Future.wait(cFiles.map((cfile) => cfile.emitAsmFile(arch)));
  await cFiles.delete();
  
  if (o.compileOnly) {
    exit(0);
  }

  final objectFiles = await Future.wait(asmFiles.map((asmFile) => asmFile.compile()));
  await asmFiles.delete();
  if (o.compileAndAssemble) {
    exit(0);
  }

  final linker = Linker.of(objectFiles, shared: o.shared);

  final outputPath = o.output ?? o.inputFiles.first.replaceExtension('');
  final _ = await linker.link(output: outputPath);
  await objectFiles.delete();
}