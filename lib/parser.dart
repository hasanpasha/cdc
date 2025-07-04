import 'package:cdc/ast.dart';
import 'package:cdc/token.dart';

enum Precedence {
  none,
  assignment, // = += -= *= /= %= <<= >>= &= |= ^=
  lor,    // logical or
  land,   // logical and
  bor,    // bitwise or
  bxor,   // bitwise exclusive or
  band,   // bitwise and 
  cmpEquality,       // == !=
  cmpLessGreater, // < <= > >=
  shift,  // bitwise left and right shift
  term,   // +-
  factor, // */%
  unary,  // - + ~ !
  primary; // '1'  'i' 'name' 'main'

  bool operator <=(Precedence other) {
    return index <= other.index;
  }

  Precedence operator +(int offset) {
    return values.firstWhere((precedence) => precedence.index == index+offset);
  }
}

class PrecedenceRule {
  final Expr Function()? _prefixFn;
  final Expr Function(Expr lhs)? _infixFn;
  final Precedence precedence;

  static PrecedenceRule get none => PrecedenceRule(prefixFn: null, infixFn: null, precedence: .none);

  PrecedenceRule({Expr Function()? prefixFn, Expr Function(Expr)? infixFn, Precedence? precedence}) : 
    _infixFn = infixFn, 
    _prefixFn = prefixFn, 
    precedence = precedence ?? .none;

  Expr prefix() => _prefixFn!();
  Expr infix(Expr lhs) => _infixFn!(lhs);
}


class SyntaxError implements Exception {
  final Token token;
  final String message;

  const SyntaxError(this.token, this.message);

  @override
  String toString() => "${token.location}: ${token.lexeme}, $message.";
}

class LexerError extends SyntaxError {
  final List<ErrorToken> errors;

  LexerError(this.errors): super(errors.first, "lexer error");
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
    
    bool hadError = false;
    final List<BlockItem> body = [];
    while (!_isAtEnd && _peek().kind != .rightBraces) {
      try {
        body.add(blockItem());
      } on LexerError catch (e) {
        hadError = true;
        for (var error in e.errors) {
          print("${error.location}: lexer error, ${error.message}");
        }
        _synchronize();
      } on SyntaxError catch (e) {
        hadError = true;
        print(e);
        _synchronize();
      }
    }
    if (hadError) {
      throw SyntaxError(name, "error while parsing function body.");
    }

    _consume(.rightBraces, "Expect '}' closing a function body.");

    return FunctionAST(name: name, body: body);
  }

  BlockItem blockItem() {
    if (_peek().kind == .int) return DeclBlockItem(declaration());
    return StmtBlockItem(statement());
  }
  
  Decl declaration() {
    return _variableDecl();
  }

  Decl _variableDecl() {
    _consume(.int, "Expect a variable type.");
    Token name = _consume(.identifier, "Expect a variable identifier.");
    Expr? init;
    if (_peek().kind == .equal) {
      _consume(.equal, "Expect '=' before initializer.");
      init = expression();
    }
    _consume(.semicolon, "Expect a ';' at the end of a variable declaration.");
    return VariableDecl(name, init);
  }

  Stmt statement() {
    if (_peek().kind == .semicolon) return _nullStmt();
    if (_peek().kind == .return$) return _returnStmt();
    return _expressionStmt();
  }

  Stmt _nullStmt() {
    _consume(.semicolon, "Expect ';' in a null statement.");
    return NullStmt();
  }

  Stmt _expressionStmt() {
    final expr = expression();
    _consume(.semicolon, "Expect ';' at the end of an expression statement.");
    return ExpressionStmt(expr);
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
    .and: PrecedenceRule(infixFn: _binary, precedence: .band),
    .xor: PrecedenceRule(infixFn: _binary, precedence: .bxor),
    .or: PrecedenceRule(infixFn: _binary, precedence: .bor),
    .constant: PrecedenceRule(prefixFn: _constant, precedence: .primary),
    .identifier: PrecedenceRule(prefixFn: _var, precedence: .primary),
    .bang: PrecedenceRule(prefixFn: _unary, precedence: .unary),
    .less: PrecedenceRule(infixFn: _binary, precedence: .cmpLessGreater),
    .lessEqual: PrecedenceRule(infixFn: _binary, precedence: .cmpLessGreater),
    .greater: PrecedenceRule(infixFn: _binary, precedence: .cmpLessGreater),
    .greaterEqual: PrecedenceRule(infixFn: _binary, precedence: .cmpLessGreater),
    .equalEqual: PrecedenceRule(infixFn: _binary, precedence: .cmpEquality),
    .bangEqual: PrecedenceRule(infixFn: _binary, precedence: .cmpEquality),
    .andAnd : PrecedenceRule(infixFn: _binary, precedence: .land),
    .orOr : PrecedenceRule(infixFn: _binary, precedence: .lor),
    .equal: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    // dart format on
  };
  
  PrecedenceRule _peekPrecedenceRule() => _rules[_peek().kind] ?? .none;

  Expr _parsePrecedence(Precedence precedence) {
    final PrecedenceRule rule = _peekPrecedenceRule();
    
    Expr lhs;
    try {
      lhs = rule.prefix();
    } on SyntaxError {
      rethrow;
    } catch (e) {
      throw SyntaxError(_peek(), "operator doesn't have a prefix parsing method.");
    }

    while (!_isAtEnd && precedence <= _peekPrecedenceRule().precedence) {
      final nextRule = _peekPrecedenceRule();
      
      try {
        lhs = nextRule.infix(lhs);
      } on SyntaxError {
        rethrow;
      } catch (e) {
        throw SyntaxError(_peek(), "operator doesn't have an infix parsing method.");
      }
    }

    return lhs;
  }

  Expr expression() {
    return _parsePrecedence(.assignment);
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
      .less,
      .lessEqual,
      .greater,
      .greaterEqual,
      .equalEqual,
      .bangEqual,
      .andAnd,
      .orOr,
    ]);
    
    final nextRule = _rules[operator.kind]!;
    final rhs = _parsePrecedence(nextRule.precedence + 1);
  
    return BinaryExpr(operator, lhs, rhs);
  }

  UnaryExpr _unary() {
    final operator = _consumeOneOf([.hyphen, .tilde, .bang]);
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
    return ConstantExpr(constant);
  }

  VarExpr _var() {
    final identifier = _consume(.identifier, "Expect an identifier.");
    return VarExpr(identifier);
  }

  Expr _assignment(Expr left) {
    final operator = _consumeOneOf([
      .equal,
    ]);
    
    final nextRule = _rules[operator.kind]!;
    final right = _parsePrecedence(nextRule.precedence);
  
    return AssignmentExpr(left, right);
  }
  
  Token _consume(TokenKind kind, String msg) {
    final Token next = _peek();
    if (next.kind != kind) {
      throw SyntaxError(next, msg);
    }
    
    return _advance();
  }
  
  Token _consumeOneOf(List<TokenKind> list) {
    final next = _peek();
    return list.contains(next.kind) 
      ? _advance()
      : throw SyntaxError(next, "should be one of [${list.join(", ")}]");
  }
  
  bool get _isAtEnd => _currentIdx == tokens.length;
  
  Token _peek() {
    Token next = tokens[_currentIdx];

    final List<ErrorToken> errors = [];
    while (!_isAtEnd && next.kind == .error) {
      errors.add(next as ErrorToken);
      _currentIdx++;
      next = tokens[_currentIdx];
    }

    if (errors.isNotEmpty) {
      throw LexerError(errors);
    }

    return next;
  }
  
  Token _advance() {
    Token next = _peek();
    _currentIdx++;
    return next;
  }
  
  void _synchronize() {
    while (!_isAtEnd) {
      if (_peek().kind == .semicolon) {
        _advance();
        return;
      }

      switch (_peek().kind) {
        case .int || .return$:
          return;
        default:
          // print(_peek());
          break;
      }

      _advance();
    }
  }
  
}

class ConstantFolder implements StmtVisitor<Stmt>, ExprVisitor<Expr>, DeclVisitor<Decl>, BlockItemVisitor<BlockItem> {
  static ProgramAST transform(ProgramAST program) => ConstantFolder().visitProgram(program);
  
  ProgramAST visitProgram(ProgramAST program) => ProgramAST(function: visitFunction(program.function));
  
  visitFunction(FunctionAST function) => FunctionAST(
    name: function.name, 
    body: function.body.map((item) => item.accept(this)).toList()
  );
  
  @override
  Expr visitBinaryExpr(BinaryExpr binaryExpr) {
    final lhs = binaryExpr.lhs.accept(this);
    final rhs = binaryExpr.rhs.accept(this);

    if (lhs is ConstantExpr && rhs is ConstantExpr) {
      final left = int.parse(lhs.value.lexeme);
      final right = int.parse(rhs.value.lexeme);
      final result = switch (binaryExpr.operator.kind) {
        .plus => left+right,
        .hyphen => left-right,
        .asterisk => left*right,
        .forwardSlash => left/right,
        .percent => left%right,
        _ => throw Exception("unexpected operator: ${binaryExpr.operator.kind.name}"),
      };
      return ConstantExpr(Token(.constant, result.toInt().toString(), lhs.value.location));
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
      final right = int.parse(operand.value.lexeme);
      final result = switch (unaryExpr.operator.kind) {
        .hyphen => -right,
        .tilde => ~right,
        _ => throw Exception("unexpected operator: ${unaryExpr.operator.kind.name}"),
      };
      return ConstantExpr(Token(.constant, result.toString(), operand.value.location));
    }

    return UnaryExpr(unaryExpr.operator, operand);
  }
  
  @override
  Expr visitAssignmentExpr(AssignmentExpr assignmentExpr) => 
    AssignmentExpr(assignmentExpr.lhs.accept(this), assignmentExpr.rhs.accept(this));
  
  @override
  Expr visitVarExpr(VarExpr varExpr) => varExpr;
  
  @override
  Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => 
    ExpressionStmt(expressionStmt.expr.accept(this));
  
  @override
  Stmt visitNullStmt(NullStmt nullStmt) => nullStmt;
  
  @override
  BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => DeclBlockItem(declBlockItem.decl.accept(this));
  
  @override
  BlockItem visitStmtBlockItem(StmtBlockItem stmtBlockItem) => StmtBlockItem(stmtBlockItem.stmt.accept(this));
  
  @override
  Decl visitVariableDecl(VariableDecl variableDecl) => VariableDecl(variableDecl.name, variableDecl.init?.accept(this));
}