
import 'dart:io';

import 'package:cdc/cdc.dart';

enum Arch { x86_64, aarch64 }

extension AsmGenerate on ProgramIR {
  ProgramASM generateAsm(Arch arch) {
    final AsmGenerator generator = switch (arch) {
      .x86_64 => X8664Generator(),
      .aarch64 => AArch64Generator(),
    };

    return generator.generate(this);
  }
}

extension UriUtils on Uri {
  Future<String> read() async => await File(path).readAsString();
  Future<List<Token>> readAsTokens() async => Lexer(await read(), path).toList();

  String baseFilename() {
    return pathSegments.last;
  }

  String baseFilenameWithoutExtension() {
    final parts = baseFilename().split('.');
    if (parts.length == 1) return parts.first;
    parts.removeLast();
    return parts.join();
  }

  Uri replaceExtension(String newExtension) {
    final newFilenamem = "${baseFilenameWithoutExtension()}$newExtension";
    final pathSegms = pathSegments.toList();
    pathSegms.removeLast();
    pathSegms.add(newFilenamem);
    final newPath = replace(pathSegments: pathSegms);
    return newPath;
  }
}