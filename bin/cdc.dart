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

  Uri get inputFile => _inputFile;
  Uri _inputFile = Uri();

  bool get isVerbose => _verbose;
  bool _verbose = false;

  bool get onlyLex => _onlyLex;
  bool _onlyLex = false;

  bool get onlyParse => _onlyParse;
  bool _onlyParse = false;

  bool get onlyValidate => _onlyValidtae;
  bool _onlyValidtae = false;

  bool get onlyGenTacky => _onlyGenTacky;
  bool _onlyGenTacky = false;

  bool get onlyGenASM => _onlyGenASM;
  bool _onlyGenASM = false;
  
  bool get preserveAsm => _preserveAsm;
  bool _preserveAsm = false;

  Future parse(List<String> args) async {
    final optDefStr = """
    |verbose|?,h,help|l,lex|p,parse|v,validate|t,tacky|c,codegen|preserve_asm|
    :
    """;

    final result = parseArgs(optDefStr, args, validate: true);

    if (result.isSet("help")) {
      usage();
    }

    if (result.getStrValue('') != null) {
      _inputFile = Uri.file(result.getStrValue('')!);
    } else {
      usage("no input.");
    }

    if (result.isSet('verbose')) {
      _verbose = true;
      _logger.level = Logger.levelVerbose;
    }

    if (result.isSet("lex")) {
      _onlyLex = true;
    }

    if (result.isSet("parse")) {
      _onlyParse = true;
    }

    if (result.isSet("validate")) {
      _onlyValidtae = true;
    }

    if (result.isSet("tacky")) {
      _onlyGenTacky = true;
    }

    if (result.isSet("codegen")) {
      _onlyGenASM = true;
    }

    if (result.isSet("preserve_asm")) {
      _preserveAsm = true;
    }
  }

  Never usage([String? error]) => throw Exception("""
${Options.appName} ${Options.appVersion} (c) 2025 Hasan Pasha

USAGE:

${Options.appName} [OPTIONS]

-?, -h, -[-]help                - this help screen
-[-]verbose                     - detailed log
-l, -[-]lex                     - only Lex
-p, -[-]parse                   - only parse
-v, -[-]validate                - only validate
-t, -[-]tacky                   - only generate tacky
-c, -[-]codegen                 - only generate asm without outputing file
-[-]preserve_asm                - preserve the generated assembly file

${(error == null) || error.isEmpty ? '' : "*** ERROR: $error"}
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

  final gccPath = Uri.file('/usr/bin/gcc');
  int exitCode = 0;

  final expandedFile = o.inputFile.replaceExtension('.cc');
  if ((exitCode = await command(gccPath, ['-E', '-P', o.inputFile.path, '-o', expandedFile.path])) != 0) {
    _logger.error("failed expanding .c file: $exitCode");
    exit(exitCode);
  }

  final tokens = await expandedFile.readAsTokens();
  await File(expandedFile.path).delete();
  if (o.isVerbose) {
    _logger.verbose(tokens.toString());
  }

  if (o.onlyLex) {
    for (var token in tokens) {
      _logger.out(token.toString());
    }
    exit(0);
  }

  final programAst = Parser.parse(tokens, constantFold: false);
  if (o.isVerbose) {
    _logger.verbose(programAst.toString());
  }
  if (o.onlyParse) {
    _logger.out(programAst.accept(ASTPrettier()));
    exit(0);
  }

  final analyzedProgramAst = analyze(programAst);

  if (o.onlyValidate) {
    _logger.out(analyzedProgramAst.accept(ASTPrettier()));
    exit(0);
  }

  final programIr = TackyIRGenerator.generate(analyzedProgramAst);
  if (o.isVerbose) {
    _logger.verbose(programIr.toString());
  }
  if (o.onlyGenTacky) {
    _logger.out(programIr.accept(TackyIrInspector()));
    _logger.out(programIr.toString());
    exit(0);
  }

  final programAsm = programIr.generateAsm(.aarch64);
  if (o.isVerbose) { 
    _logger.verbose(programAsm.toString());
  }
  if (o.onlyGenASM) {
    _logger.out(programAsm.toString());
    _logger.out(programAsm.toString());
    exit(0);
  }

  await programAsm.compile(o._inputFile.replaceExtension(''), preserveAsmFile: true);
}