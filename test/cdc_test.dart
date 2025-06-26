
import 'package:cdc/cdc.dart';
import 'package:test/test.dart';

void main() {
  test('lexer', () {
    expect("+-*/() 1234 main int void".lex().map((tok) => tok.kind), <TokenKind>[
      TokenKind.plus,
      TokenKind.hyphen,
      TokenKind.asterisk,
      TokenKind.forwardSlash,
      TokenKind.leftParen,
      TokenKind.rightParen,
      TokenKind.constant,
      TokenKind.identifier,
      TokenKind.int,
      TokenKind.void$,
      TokenKind.eoi,
    ]);
  });
}
