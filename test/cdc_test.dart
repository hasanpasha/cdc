
import 'package:cdc/cdc.dart';
import 'package:test/test.dart';


// TODO: add more test
// TODO: add tests for parsing and tacky_ir and generated asm
void main() {
  test('lexer', () {
    expect("+-*/() 1234 main int void ++ , --<<>>|&^<><=>====!=!+=-=*=/=%=&=|=^=<<=>>=if else?goto:do while for break continue switch default case".lex().map((tok) => tok.kind), <TokenKind>[
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
      .comma,
      .hyphenHyphen,
      .lessLess,
      .greaterGreater,
      .or,
      .and,
      .xor,
      .less,
      .greater,
      .lessEqual,
      .greaterEqual,
      .equalEqual,
      .equal,
      .bangEqual,
      .bang,
      .plusEqual,
      .hyphenEqual,
      .starEqual,
      .forwardSlashEqual,
      .percentEqual,
      .andEqual,
      .orEqual,
      .xorEqual,
      .lessLessEqual,
      .greaterGreaterEqual,
      .if$,
      .else$,
      .questionMark,
      .goto,
      .colon,
      .do$,
      .while$,
      .for$,
      .break$,
      .continue$,
      .switch$,
      .default$,
      .case$,
      .eoi,
    ]);
  });
}
