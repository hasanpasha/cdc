import 'package:cdc/cdc.dart';
import 'package:test/test.dart';

// void main() {
//   test('lexer', () {
//     expect("+-*/() 1234 main int void ++--<<>>|&^<><=>====!=!+=-=*=/=%=&=|=^=<<=>>=1221e".lex().map((tok) => tok.kind), <TokenKind>[
//       .plus,
//       .hyphen,
//       .asterisk,
//       .forwardSlash,
//       .leftParen,
//       .rightParen,
//       .constant,
//       .identifier,
//       .int,
//       .void$,
//       .plusPlus,
//       .hyphenHyphen,
//       .lessLess,
//       .greaterGreater,
//       .or,
//       .and,
//       .xor,
//       .less,
//       .greater,
//       .lessEqual,
//       .greaterEqual,
//       .equalEqual,
//       .equal,
//       .bangEqual,
//       .bang,
//       .plusEqual,
//       .hyphenEqual,
//       .starEqual,
//       .forwardSlashEqual,
//       .percentEqual,
//       .andEqual,
//       .orEqual,
//       .xorEqual,
//       .lessLessEqual,
//       .greaterGreaterEqual,
//       .error,
//       .eoi,
//     ]);
//   });
// }

final loc = Location(1, 1);

void main() {
  group('chapter_1', () {
    group('lex', () {
      group('invalid', () {
        test('at sign', () => expect("0@1".lex().kinds(), <TokenKind>[.constant, .error, .constant, .eoi]));
        test("backslash", () => expect("\\".lex().kinds(), <TokenKind>[.error, .eoi]));
        test("backtick", () => expect("`".lex().kinds(), <TokenKind>[.error, .eoi]));
        test("invalid identifier", () => expect("1foo".lex(), <Token>[ErrorToken(loc, '1foo', ''), Token(.eoi, '', loc)]));
        test("invalid identifier 2", () => expect("@b".lex().kinds(), <TokenKind>[.error, .identifier, .eoi]));
      });

      group('valid', () {
        test("invalid identifier 2", () => expect("""
        int main(void) {
            // test case w/ multi-digit constant
            return 100;
        }
        """.lex().kinds(), <TokenKind>[.int, .identifier, .leftParen, .void$, .rightParen, .leftBraces,
         .return$, .constant, .semicolon, .rightBraces, .eoi,]));
        
        test("multilines", () {
          final tokens = """
            int
            main
            (
            void
            )
            {
            return
            0
            ;
            }
          """.lex();
          expect(tokens.kinds(), <TokenKind>[.int, .identifier, .leftParen, .void$, .rightParen, .leftBraces,
          .return$, .constant, .semicolon, .rightBraces, .eoi,]);
          expect(tokens[1].lexeme, 'main');
          expect(tokens[7].lexeme, '0');
        });

        test("no newlines", () {
          final tokens = "int main(void){return 0;}".lex();
          expect(tokens.kinds(), <TokenKind>[.int, .identifier, .leftParen, .void$, .rightParen, .leftBraces,
          .return$, .constant, .semicolon, .rightBraces, .eoi,]);
          expect(tokens[1].lexeme, 'main');
          expect(tokens[7].lexeme, '0');
        });

        test("spaces", () {
          final tokens = "   int   main    (  void)  {   return  0 ; }".lex();
          expect(tokens.kinds(), <TokenKind>[.int, .identifier, .leftParen, .void$, .rightParen, .leftBraces,
          .return$, .constant, .semicolon, .rightBraces, .eoi,]);
          expect(tokens[1].lexeme, 'main');
          expect(tokens[7].lexeme, '0');
        });

        test("tabs", () {
          final tokens = "int	main	(	void)	{	return	0	;	}".lex();
          expect(tokens.kinds(), <TokenKind>[.int, .identifier, .leftParen, .void$, .rightParen, .leftBraces,
          .return$, .constant, .semicolon, .rightBraces, .eoi,]);
          expect(tokens[1].lexeme, 'main');
          expect(tokens[7].lexeme, '0');
        });
      
      });
    });
  });
}

extension on List<Token> {
  List<TokenKind> kinds() => map((token) => token.kind).toList();
}