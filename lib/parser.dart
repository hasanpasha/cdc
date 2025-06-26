
import 'package:cdc/ast.dart';
import 'package:cdc/token.dart';

enum Precedence {
  none,
  term,
  factor,
  unary,
  primary;

  bool operator <=(Precedence other) {
    return index <= other.index;
  }

  Precedence operator +(int offset) {
    return Precedence.values.firstWhere((precedence) => precedence.index == index+offset);
  }
}

class PrecedenceRule {
  final Expr Function()? _prefixFn;
  final Expr Function(Expr lhs)? _infixFn;
  final Precedence precedence;

  static PrecedenceRule get none => PrecedenceRule(prefixFn: null, infixFn: null, precedence: Precedence.none);

  PrecedenceRule({Expr Function()? prefixFn, Expr Function(Expr)? infixFn, Precedence? precedence}) : 
    _infixFn = infixFn, 
    _prefixFn = prefixFn, 
    precedence = precedence ?? Precedence.none;

  Expr prefix() => _prefixFn!();
  Expr infix(Expr lhs) => _infixFn!(lhs);
}


class Parser {
  final List<Token> tokens;
  int _currentIdx = 0;

  static ProgramAST parse(List<Token> tokens) {
    final parser = Parser(tokens);
    return parser.parseProgram();
  }

  Parser(this.tokens);

  ProgramAST parseProgram() {
    final FunctionAST function = _function();
    _consume(TokenKind.eoi, "Expect end of input.");
    
    return ProgramAST(function: function);
  }
  
  FunctionAST _function() {
    _consume(TokenKind.int, "Expect `int` at start of function.");
    final name = _consume(TokenKind.identifier, "Expect identifier name for function definition.");
    _consume(TokenKind.leftParen, "Expect a '(' at start of parameters list.");
    _consume(TokenKind.void_, "Expect `void` as argument.");
    _consume(TokenKind.rightParen, "Expect ')' closing parameters list.");
    _consume(TokenKind.leftBraces, "Expect '{' opening a function body.");
    final Stmt body = statement();
    _consume(TokenKind.rightBraces, "Expect '}' closing a function body.");

    return FunctionAST(name: name, body: body);
  }
  
  Stmt statement() {
    return _returnStmt();
  }
  
  ReturnStmt _returnStmt() {
    final keyword = _consume(TokenKind.return_, "Expect a `return` keyword.");
    final expr = expression();
    _consume(TokenKind.semicolon, "Expect a ';' at the end of return statement.");
    return ReturnStmt(keyword, expr);
  }

  Map<TokenKind, PrecedenceRule> get _rules => {
    TokenKind.leftParen: PrecedenceRule(prefixFn: _group),
    TokenKind.plus: PrecedenceRule(infixFn: _binary, precedence: Precedence.term),
    TokenKind.hyphen: PrecedenceRule(prefixFn: _unary, infixFn: _binary, precedence: Precedence.term),
    TokenKind.asterisk: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.forwardSlash: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.percent: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.tilde: PrecedenceRule(prefixFn: _unary, precedence: Precedence.unary),
    TokenKind.constant: PrecedenceRule(prefixFn: _constant),
  };
  
  
  
  PrecedenceRule _peekPrecedenceRule() => _rules[_peek().kind] ?? PrecedenceRule.none;

  Expr _parsePrecedence(Precedence precedence) {
    final PrecedenceRule rule = _peekPrecedenceRule();
    var lhs = rule.prefix();

    while (!_isAtEnd && precedence <= _peekPrecedenceRule().precedence) {
      final nextRule = _peekPrecedenceRule();
      lhs = nextRule.infix(lhs);
    }

    return lhs;
  }

  Expr expression() {
    return _parsePrecedence(Precedence.term);
  }
  
  BinaryExpr _binary(Expr lhs) {
    final operator = _consumeOneOf([TokenKind.plus, TokenKind.hyphen, TokenKind.asterisk, TokenKind.forwardSlash, TokenKind.percent]);
    final rhs = _parsePrecedence(_rules[operator.kind]!.precedence + 1);
  
    return BinaryExpr(operator, lhs, rhs);
  }

  UnaryExpr _unary() {
    final operator = _consumeOneOf([TokenKind.hyphen, TokenKind.tilde]);
    final operand = _parsePrecedence(Precedence.unary);

    return UnaryExpr(operator, operand);
  }

  Expr _group() {
    _consume(TokenKind.leftParen, "Expect '(' before group expr.");
    final expr = expression();
    _consume(TokenKind.rightParen, "Expect ')' after group expr.");
    return expr;
  }
  
  ConstantExpr _constant() {
    final constant = _consume(TokenKind.constant, "Expect a constant.");
    return ConstantExpr(constant.lexeme);
  }
  
  Token _consume(TokenKind kind, String msg) {
    final Token next = _peek();
    if (next.kind != kind) {
      throw Exception("${next.location}: unexpected token kind `${next.kind}`, $msg");
    }

    return _advance();
  }
  
  Token _consumeOneOf(List<TokenKind> list) {
    final next = _peek();
    return list.contains(next.kind) 
      ? _advance()
      : throw Exception("${next.location}: unexpected token kind `${next.kind}`, expected one of `$list`");
  }
  
  bool get _isAtEnd => _currentIdx == tokens.length;
  Token _peek() => tokens[_currentIdx];
  Token _advance() => tokens[_currentIdx++];
}