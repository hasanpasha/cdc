import 'dart:async';
import 'dart:io';

import 'package:parse_args/parse_args.dart';
// TODO: replace with a better logger
import 'package:thin_logger/thin_logger.dart';

import 'package:cdc/cdc.dart';

final _logger = Logger();

class Options {
  static const appName = "cdc";
  static const appVersion = "0.0.1";

  late final Uri inputFile;

  late final bool isVerbose;
  late final bool onlyLex;
  late final bool onlyParse;
  late final bool onlyValidate;
  late final bool onlyGenTacky;
  late final bool onlyGenASM;

  late final bool compileOnly;
  late final bool compileAndAssemble;

  Future parse(List<String> args) async {
    final optDefStr = """
    |verbose|?,h,help|lex|parse|validate|tacky|codegen
    |s,compile_only|c,compile_assemble|
    :
    """;

    final result = parseArgs(optDefStr, args, validate: true);

    if (result.isSet("help")) {
      usage();
    }

    if (result.getStrValue('') == null) {
      usage("no input.");
    } 
    
    inputFile = Uri.file(result.getStrValue('')!);

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

  final input = CFile(o.inputFile);
  final cfile = await input.expand();

  if (o.onlyLex) {
    final token = await cfile.lex();
    for (var token in token) {
      _logger.out("${token.location}: ${token.kind.name} ${token.lexeme}");
    }
    await cfile.delete();
    exit(0);
  }

  if (o.onlyParse) {
    final ast = await cfile.parse();
    _logger.out(ast.accept(ASTPrettier()));
    await cfile.delete();
    exit(0);
  }

  if (o.onlyValidate) {
    final ast = await cfile.validate();
    _logger.out(ast.accept(ASTPrettier()));
    await cfile.delete();
    exit(0);
  }

  if (o.onlyGenTacky) {
    final ir = await cfile.irgen();
    _logger.out(ir.accept(TackyIrInspector()));
    await cfile.delete();
    exit(0);
  }

  final Arch arch = .x86_64;

  if (o.onlyGenASM) {
    final asm = await cfile.codegen(arch);
    _logger.out(asm.toString());
    await cfile.delete();
    exit(0);
  }

  final asmFile = await cfile.emitAsmFile(arch);
  await cfile.delete();
  if (o.compileOnly) {
    exit(0);
  }

  final objectFile = await asmFile.compile();
  await asmFile.delete();
  if (o.compileAndAssemble) {
    exit(0);
  }

  final linker = objectFile.createLinker();
  final _ = await linker.link(output: o.inputFile.replaceExtension(''));
  await objectFile.delete();
}