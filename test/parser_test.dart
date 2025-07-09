import 'package:cdc/cdc.dart';
import 'package:test/test.dart';

ProgramAst parse(String code) => Parser.parse(code.lex());

Token _dumpToken(TokenKind kind, String lexeme) {
  return Token(kind, lexeme, Location(1, 1));
}

void main() {
  group('chapter_1', () {
    group('invalid parse', () {
      test('end before expr', () {
        expect(() => parse("""
        int main(void) {
          return
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('extra junk', () {
        expect(() => parse("""
        int main(void)
        {
            return 2;
        }
        // A single identifier outside of a declaration isn't a valid top-level construct
        foo
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('invalid function name', () {
        expect(() => parse("""
        /* A function name must be an identifier, not a constant */
        int 3 (void) {
            return 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('keyword wrong case', () {
        expect(() => parse("""
        int main(void) {
            RETURN 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('missing type', () {
        expect(() => parse("""
        // note: in older versions of C this would be valid
        // and return type would default to 'int'
        // GCC/Clang will compile it (with a warning)
        // for backwards compatibility
        main(void) {
            return 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('misspelled keyword', () {
        expect(() => parse("""
        int main(void) {
            returns 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });
      
      test('no semicolon', () {
        expect(() => parse("""
        int main (void) {
            return 0
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('not expression', () {
        expect(() => parse("""
        int main(void) {
            return int;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('space in keyword', () {
        expect(() => parse("""
        int main(void){
            retur n 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('switched parens', () {
        expect(() => parse("""
        int main )( {
            return 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('unclosed brace', () {
        expect(() => parse("""
        int main(void) {
          return 0;

        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });

      test('unclosed paren', () {
        expect(() => parse("""
        int main(void {
          return 0;
        }
        """), throwsA(TypeMatcher<SyntaxError>())
        );
      });
    });
    group('valid', () {


      test('return 0', () {
        expect(parse("""
        int main(void) {
            return 0;
        }
        """), ProgramAst(FunctionAst(_dumpToken(.identifier, 'main'), Block([
          StmtBlockItem(ReturnStmt(_dumpToken(.return$, 'return'), ConstantExpr(_dumpToken(.constant, '0'))))
        ]))));
      });

      test('return 2', () {
        expect(parse("""
        int main(void) {
            return 2;
        }
        """), ProgramAst(FunctionAst(_dumpToken(.identifier, 'main'), Block([
          StmtBlockItem(ReturnStmt(_dumpToken(.return$, 'return'), ConstantExpr(_dumpToken(.constant, '2'))))
        ]))));
      });

    });
  });

  group('chapter 2', () {
    group('invalid parse', () {
      test('extra paren', () {
        expect(() => parse("""
        int main(void)
        {
            return (3));
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('missing const', () {
        expect(() => parse("""
        int main(void) {
            return ~;
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('missing semicolon', () {
        expect(() => parse("""
        int main(void) {
            return -5
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('nested missing const', () {
        expect(() => parse("""
        int main(void)
        {
            return -~;
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('parenthesize operand', () {
        expect(() => parse("""
        int main(void) {
            return (-)3;
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('unclosed paren', () {
        expect(() => parse("""
        int main(void)
        {
            return (1;
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

      test('wrong order', () {
        expect(() => parse("""
        int main(void) {
            return 4-;
        }
        """), throwsA(TypeMatcher<SyntaxError>()));
      });

    });
    group('valid', () {

      test('bitwise int min', () {
        expect(parse("""
        int main(void) {
            // take the bitwise complement of the smallest int we can construct right now
            // (minimum representable int is actually -2147483648, but we can't
            // construct it b/c the constant 2147483648 is out of bounds)
            return ~-2147483647;
        }
        """), ProgramAst(FunctionAst(_dumpToken(.identifier, 'main'), Block([
          StmtBlockItem(ReturnStmt(_dumpToken(.return$, 'return'), PrefixUnaryExpr(_dumpToken(.tilde, '~'), 
            PrefixUnaryExpr(_dumpToken(.hyphen, '-'), ConstantExpr(_dumpToken(.constant, '2147483647'))))))
        ]))));
      });

    });
  });
}
