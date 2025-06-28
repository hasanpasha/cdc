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
    return values.firstWhere((precedence) => precedence.index == index+offset);
  }

  Precedence operator -(int offset) {
    return values.firstWhere((precedence) => precedence.index == index-offset);
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

  static PrecedenceRule get none => PrecedenceRule(prefixFn: null, infixFn: null, precedence: .none);

  PrecedenceRule({Expr Function()? prefixFn, Expr Function(Expr)? infixFn, Precedence? precedence, Associativity? associativity}) : 
    _infixFn = infixFn, 
    _prefixFn = prefixFn, 
    precedence = precedence ?? .none,
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
    _consume(.eoi, "Expect end of input.");
    
    return ProgramAST(function: function);
  }
  
  FunctionAST _function() {
    _consume(.int, "Expect `int` at start of function.");
    final name = _consume(.identifier, "Expect identifier name for function definition.");
    _consume(.leftParen, "Expect a '(' at start of parameters list.");
    _consume(.void$, "Expect `void` as argument.");
    _consume(.rightParen, "Expect ')' closing parameters list.");
    _consume(.leftBraces, "Expect '{' opening a function body.");
    final Stmt body = statement();
    _consume(.rightBraces, "Expect '}' closing a function body.");

    return FunctionAST(name: name, body: body);
  }
  
  Stmt statement() {
    return _returnStmt();
  }
  
  ReturnStmt _returnStmt() {
    final keyword = _consume(.return$, "Expect a `return` keyword.");
    final expr = expression();
    _consume(.semicolon, "Expect a ';' at the end of return statement.");
    return ReturnStmt(keyword, expr);
  }

  
  Map<TokenKind, PrecedenceRule> get _rules => {
    // dart format off
    .plus: PrecedenceRule(infixFn: _binary, precedence: .term),
    .hyphen: PrecedenceRule(prefixFn: _unary, infixFn: _binary, precedence: .term),
    .asterisk: PrecedenceRule(infixFn: _binary, precedence: .factor),
    .forwardSlash: PrecedenceRule(infixFn: _binary, precedence: .factor),
    .percent: PrecedenceRule(infixFn: _binary, precedence: .factor),
    .tilde: PrecedenceRule(prefixFn: _unary, precedence: .unary),
    .leftParen: PrecedenceRule(prefixFn: _group, precedence: .primary),
    .lessLess: PrecedenceRule(infixFn: _binary, precedence: .shift),
    .greaterGreater: PrecedenceRule(infixFn: _binary, precedence: .shift),
    .and: PrecedenceRule(infixFn: _binary,precedence: .band),
    .xor: PrecedenceRule(infixFn: _binary, precedence: .bxor),
    .or: PrecedenceRule(infixFn: _binary, precedence: .bor),
    .constant: PrecedenceRule(prefixFn: _constant, precedence: .primary),
    // dart format on
  };
  
  PrecedenceRule _peekPrecedenceRule() => _rules[_peek().kind] ?? .none;

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
    return _parsePrecedence(.bor);
  }
  
  BinaryExpr _binary(Expr lhs) {
    final operator = _consumeOneOf([
      .plus,
      .hyphen,
      .asterisk,
      .forwardSlash,
      .percent,
      .and,
      .or,
      .xor,
      .lessLess,
      .greaterGreater,
    ]);
    
    final nextRule = _rules[operator.kind]!;
    final rhs = _parsePrecedence((nextRule.associativity == .left) ? nextRule.precedence + 1 : nextRule.precedence);
  
    return BinaryExpr(operator, lhs, rhs);
  }

  UnaryExpr _unary() {
    final operator = _consumeOneOf([.hyphen, .tilde]);
    final operand = _parsePrecedence(.unary);

    return UnaryExpr(operator, operand);
  }

  Expr _group() {
    _consume(.leftParen, "Expect '(' before group expr.");
    final expr = expression();
    _consume(.rightParen, "Expect ')' after group expr.");
    return expr;
  }
  
  ConstantExpr _constant() {
    final constant = _consume(.constant, "Expect a constant.");
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
        .plus => left+right,
        .hyphen => left-right,
        .asterisk => left*right,
        .forwardSlash => left/right,
        .percent => left%right,
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
        .hyphen => -right,
        .tilde => ~right,
        _ => throw Exception("unexpected operator: ${unaryExpr.operator.kind.name}"),
      };
      return ConstantExpr("$result");
    }

    return UnaryExpr(unaryExpr.operator, operand);
  }
}