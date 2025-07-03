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
  var _verbose = false;

  bool get onlyLex => _onlyLex;
  var _onlyLex = false;

  bool get onlyParse => _onlyParse;
  var _onlyParse = false;

  bool get onlyGenTacky => _onlyGenTacky;
  var _onlyGenTacky = false;

  bool get onlyGenASM => _onlyGenASM;
  var _onlyGenASM = false;

  Future parse(List<String> args) async {
    final optDefStr = """
    |v,verbose|?,h,help|l,lex|p,parse|t,tacky|c,codegen|
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

    if (result.isSet("tacky")) {
      _onlyGenTacky = true;
    }

    if (result.isSet("codegen")) {
      _onlyGenASM = true;
    }
  }

  Never usage([String? error]) => throw Exception("""
${Options.appName} ${Options.appVersion} (c) 2025 Hasan Pasha

USAGE:

${Options.appName} [OPTIONS]

-?, -h, -[-]help                - this help screen
-v, -[-]verbose                 - detailed log

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
    _logger.out(programAst.prettyTree());
    exit(0);
  }

  final programIr = TackyIRGenerator.generate(programAst);
  if (o.isVerbose) {
    _logger.verbose(programIr.toString());
  }
  if (o.onlyGenTacky) {
    _logger.out(programIr.toString());
    exit(0);
  }

  
  final programAsm = programIr.generateAsm(.x86_64);
  if (o.isVerbose) { 
    _logger.verbose(programAsm.toString());
  }
  if (o.onlyGenASM) {
    _logger.out(programAsm.toString());
    exit(0);
  }

  final asmOutPath = o.inputFile.replaceExtension('.s');
  await File(asmOutPath.path).writeAsString(programAsm.emit(), flush: true);

  final binPath = o.inputFile.replaceExtension('');
  if ((exitCode = await command(gccPath, [asmOutPath.path, '-o', binPath.path])) != 0) {
    _logger.error("failed compiling file $asmOutPath: $exitCode");
    exit(exitCode);
  }
  // TODO: add option to only output asm file
  // await File(asmOutPath.path).delete();
}

// TODO: refactor
extension on Uri {
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

Future<int> command(Uri binUri, List<String> args, {bool verbose = false}) async {
  final binPath = binUri.hasAbsolutePath ? binUri.path : "./${binUri.path}";

  print("\$ $binPath ${args.join(' ')}");
  final result = await Process.run(binPath, args);
  
  if (verbose) {
    stdout.write(result.stdout.toString());
  }
  
  if (result.exitCode != 0) {
    print("abnormal exit ${result.exitCode}: ${result.stderr}");
  }
  
  return result.exitCode;
}