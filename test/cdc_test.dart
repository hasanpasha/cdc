
import 'package:cdc/cdc.dart';
import 'package:test/test.dart';


// TODO: add more test
// TODO: add tests for parsing and tacky_ir and generated asm
void main() {
  test('lexer', () {
    expect("+-*/() 1234 main int void ++--<<>>|&^<?:>".lex().map((tok) => tok.kind), <TokenKind>[
      .plus,
      .hyphen,
      .asterisk,
      .forwardSlash,
      .leftParen,
      .rightParen,
      .constant,
      .identifier,
      .int,
      .void$,
      .plusPlus,
      .hyphenHyphen,
      .lessLess,
      .greaterGreater,
      .or,
      .and,
      .xor,
      .less,
      .questionMark,
      .colon,
      .greater,
      .eoi,
    ]);
  });
}
