import 'package:cdc/ast.dart';
import 'package:cdc/token.dart';

enum Precedence {
  none,
  bor,
  bxor,
  band,
  shift,
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

  Precedence operator -(int offset) {
    return Precedence.values.firstWhere((precedence) => precedence.index == index-offset);
  }
}

enum Associativity {
  left,
  right,
}

class PrecedenceRule {
  final Expr Function()? _prefixFn;
  final Expr Function(Expr lhs)? _infixFn;
  final Precedence precedence;
  final Associativity associativity;

  static PrecedenceRule get none => PrecedenceRule(prefixFn: null, infixFn: null, precedence: Precedence.none);

  PrecedenceRule({Expr Function()? prefixFn, Expr Function(Expr)? infixFn, Precedence? precedence, Associativity? associativity}) : 
    _infixFn = infixFn, 
    _prefixFn = prefixFn, 
    precedence = precedence ?? Precedence.none,
    associativity = associativity ?? Associativity.left;
    

  Expr prefix() => _prefixFn!();
  Expr infix(Expr lhs) => _infixFn!(lhs);
}


class Parser {
  final List<Token> tokens;
  int _currentIdx = 0;

  static ProgramAST parse(List<Token> tokens, { bool constantFold = false }) {
    final parser = Parser(tokens);

    var program = parser.parseProgram();
    
    if (constantFold) {
      program = ConstantFolder.transform(program);
    }

    return program;
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
    _consume(TokenKind.void$, "Expect `void` as argument.");
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
    final keyword = _consume(TokenKind.return$, "Expect a `return` keyword.");
    final expr = expression();
    _consume(TokenKind.semicolon, "Expect a ';' at the end of return statement.");
    return ReturnStmt(keyword, expr);
  }

  
  Map<TokenKind, PrecedenceRule> get _rules => {
    // dart format off
    TokenKind.plus: PrecedenceRule(infixFn: _binary, precedence: Precedence.term),
    TokenKind.hyphen: PrecedenceRule(prefixFn: _unary, infixFn: _binary, precedence: Precedence.term),
    TokenKind.asterisk: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.forwardSlash: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.percent: PrecedenceRule(infixFn: _binary, precedence: Precedence.factor),
    TokenKind.tilde: PrecedenceRule(prefixFn: _unary, precedence: Precedence.unary),
    TokenKind.leftParen: PrecedenceRule(prefixFn: _group, precedence: Precedence.primary),
    TokenKind.lessLess: PrecedenceRule(infixFn: _binary, precedence: Precedence.shift),
    TokenKind.greaterGreater: PrecedenceRule(infixFn: _binary, precedence: Precedence.shift),
    TokenKind.and: PrecedenceRule(infixFn: _binary,precedence: Precedence.band),
    TokenKind.xor: PrecedenceRule(infixFn: _binary, precedence: Precedence.bxor),
    TokenKind.or: PrecedenceRule(infixFn: _binary, precedence: Precedence.bor),
    TokenKind.constant: PrecedenceRule(prefixFn: _constant, precedence: Precedence.primary),
    // dart format on
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
    return _parsePrecedence(Precedence.bor);
  }
  
  BinaryExpr _binary(Expr lhs) {
    final operator = _consumeOneOf([
      TokenKind.plus,
      TokenKind.hyphen,
      TokenKind.asterisk,
      TokenKind.forwardSlash,
      TokenKind.percent,
      TokenKind.and,
      TokenKind.or,
      TokenKind.xor,
      TokenKind.lessLess,
      TokenKind.greaterGreater,
    ]);
    
    final nextRule = _rules[operator.kind]!;
    final rhs = _parsePrecedence((nextRule.associativity == Associativity.left) ? nextRule.precedence + 1 : nextRule.precedence);
  
    return BinaryExpr(operator, lhs, rhs);
  }

  UnaryExpr _unary() {
    final operator = _consumeOneOf([TokenKind.hyphen, TokenKind.tilde]);

    final nextRule = _rules[operator.kind]!;
    final operand = _parsePrecedence(nextRule.precedence);

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

class ConstantFolder implements StmtVisitor<Stmt>, ExprVisitor<Expr> {
  static ProgramAST transform(ProgramAST program) => ConstantFolder().visitProgram(program);
  
  ProgramAST visitProgram(ProgramAST program) => ProgramAST(function: visitFunction(program.function));
  
  visitFunction(FunctionAST function) => FunctionAST(name: function.name, body: function.body.accept(this));
  
  @override
  Expr visitBinaryExpr(BinaryExpr binaryExpr) {
    final lhs = binaryExpr.lhs.accept(this);
    final rhs = binaryExpr.rhs.accept(this);

    if (lhs is ConstantExpr && rhs is ConstantExpr) {
      final left = int.parse(lhs.value);
      final right = int.parse(rhs.value);
      final result = switch (binaryExpr.operator.kind) {
        TokenKind.plus => left+right,
        TokenKind.hyphen => left-right,
        TokenKind.asterisk => left*right,
        TokenKind.forwardSlash => left/right,
        TokenKind.percent => left%right,
        _ => throw Exception("unexpected operator: ${binaryExpr.operator.kind.name}"),
      };
      return ConstantExpr("${result.toInt()}");
    }

    return BinaryExpr(binaryExpr.operator, lhs, rhs);
  }
  
  @override
  Expr visitConstantExpr(ConstantExpr constantExpr) => constantExpr;
  
  @override
  Stmt visitReturnStmt(ReturnStmt returnStmt) => ReturnStmt(returnStmt.keyword, returnStmt.expr.accept(this));
  
  @override
  Expr visitUnaryExpr(UnaryExpr unaryExpr) {
    final operand = unaryExpr.operand.accept(this);

    if (operand is ConstantExpr) {
      final right = int.parse(operand.value);
      final result = switch (unaryExpr.operator.kind) {
        TokenKind.hyphen => -right,
        TokenKind.tilde => ~right,
        _ => throw Exception("unexpected operator: ${unaryExpr.operator.kind.name}"),
      };
      return ConstantExpr("$result");
    }

    return UnaryExpr(unaryExpr.operator, operand);
  }
}