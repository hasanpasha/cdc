import 'dart:async';
import 'dart:io';

import 'package:cdc/lexer.dart';
import 'package:cdc/parser.dart';
import 'package:cdc/token.dart';
import 'package:file/local.dart';
import 'package:parse_args/parse_args.dart';
import 'package:thin_logger/thin_logger.dart';


final _fs = LocalFileSystem();

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

  bool get isGenTacky => _onlyGenTacky;
  var _onlyGenTacky = false;

  bool get isGenASM => _onlyGenASM;
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
  }

  final tokens = await o.inputFile.readAsTokens();

  final program = Parser.parse(tokens);
  
  _logger.verbose(program.toString());
}

extension on Uri {
  Future<String> read() async => await File(path).readAsString();
  Future<List<Token>> readAsTokens() async => Tokens(await read(), path).toList();
}
