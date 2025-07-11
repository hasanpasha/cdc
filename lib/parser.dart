import 'package:cdc/ast.dart';
import 'package:cdc/token.dart';

enum Precedence {
  none,
  assignment, // = += -= *= /= %= <<= >>= &= |= ^=
  ternaryCond, // ?:
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
  unaryPostfix, // ++ -- () []
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

class Environment {
  final Map<String, String> symbols = {};
  final Environment? enclosing;

  Environment([this.enclosing]);
  
  bool isDefined(String identifier) {
    if (isDefinedInCurScope(identifier)) return true;
    return enclosing?.isDefined(identifier) ?? false;
  }

  bool isDefinedInCurScope(String identifier) => symbols.containsKey(identifier);
  
  String get(String identifier) {
    if (!isDefined(identifier)) {
      throw Exception("`$identifier` has not been defined.");
    }
    return symbols[identifier] ?? enclosing!.get(identifier);
  }
  
  void define(String identifier, String uniqueName) {
    if (symbols.containsKey(identifier)) {
      throw Exception("`$identifier` is already defined in the current scope.");
    }
    symbols[identifier] = uniqueName;
  }
}


class Parser {
  final List<Token> tokens;
  int _currentIdx = 0;

  Environment environment = Environment();
  int _varCount = 0;
  final List<(Location, String)> issues = [];

  static ProgramAst parse(List<Token> tokens, { bool constantFold = false }) {
    final parser = Parser(tokens);

    var program = parser.parseProgram();

    if (parser.issues.isNotEmpty) {
      throw MultiIssues(parser.issues);
    }
    
    // if (constantFold) {
    //   program = ConstantFolder.transform(program);
    // }

    return program;
  }

  Parser(this.tokens);

  ProgramAst parseProgram() {
    final FunctionAst function = _function();
    _consume(.eoi, "Expect end of input.");
    
    return ProgramAst(function);
  }
  
  FunctionAst _function() {
    _consume(.int, "Expect `int` at start of function.");
    final name = _consume(.identifier, "Expect identifier name for function definition.");
    _consume(.leftParen, "Expect a '(' at start of parameters list.");
    _consume(.void$, "Expect `void` as argument.");
    _consume(.rightParen, "Expect ')' closing parameters list.");
    Block body = _block();

    return FunctionAst(name, body);
  }

  Block _block() {
    final blockToken = _consume(.leftBraces, "Expect '{' opening a function body.");
    
    bool hadError = false;
    final List<BlockItem> body = [];
    environment = Environment(environment);
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
    environment = environment.enclosing!;
    if (hadError) {
      throw SyntaxError(blockToken, "error while parsing a block.");
    }
    
    _consume(.rightBraces, "Expect '}' closing a block.");
    
    return Block(body);
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

    late final String uniqueName;
    if (environment.isDefinedInCurScope(name.lexeme)) {
      issues.add((name.location, "Duplicate variable declaration."));
      uniqueName = environment.get(name.lexeme);
    } else {
      uniqueName = _makeTemp(name.lexeme);
      environment.define(name.lexeme, uniqueName);
    }
    
    Expr? init;
    if (_peek().kind == .equal) {
      _consume(.equal, "Expect '=' before initializer.");
      init = expression();
    }
    _consume(.semicolon, "Expect a ';' at the end of a variable declaration.");
    return VariableDecl(name.copyWith(lexeme: uniqueName), init);
  }

  Stmt statement() {
    return switch (_peek().kind) {
      .semicolon => _nullStmt(),
      .return$ => _returnStmt(),
      .if$ => _ifStmt(),
      .goto => _gotoStmt(),
      .identifier => _labeledStmtOrExprStmt(),
      .leftBraces => _compoundStmt(),
      .break$ => _breakStmt(),
      .continue$ => _continueStmt(),
      .while$ => _whileStmt(),
      .do$ => _doWhileStmt(),
      .for$ => _forStmt(),
      .switch$ => _switchStmt(),
      .case$ => _caseStmt(),
      .default$ => _defaultStmt(),
      _ => _expressionStmt(),
    };
  }


  NullStmt _nullStmt() {
    _consume(.semicolon, "Expect ';' in a null statement.");
    return NullStmt();
  }

  ExpressionStmt _expressionStmt() {
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

  IfStmt _ifStmt() {
    _consume(.if$, "Expect an `if` keyword.");
    _consume(.leftParen, "Expect a '(' before `if` condition expr.");
    final cond = expression();
    _consume(.rightParen, "Expect a ')' closing `if` condition expr.");
    final thenStmt = statement();
    Stmt? elseStmt;
    if (_match(.else$)) {
      elseStmt = statement();
    } 

    return IfStmt(cond, thenStmt, elseStmt);
  } 

  GotoStmt _gotoStmt() {
    _consume(.goto, "Expect a `goto` keyword.");
    final label = _consume(.identifier, "Expect a goto destination label.");
    _consume(.semicolon, "Expect a ';' after goto label.");
    return GotoStmt(label);
  }

  Stmt _labeledStmtOrExprStmt() {
    final label = _consume(.identifier, "Expect an identifier.");
    if (_match(.colon)) {
      return LabeledStmtStmt(label, statement());
    }

    _retract();
    return _expressionStmt();
  }

  CompoundStmt _compoundStmt() => 
    CompoundStmt(_block());

  BreakStmt _breakStmt() {
    final token = _consume(.break$, "Expect a 'break' keyword.");
    _consume(.semicolon, "Expect a ';' closing `break` stmt.");
    return BreakStmt(token, "");
  }

  ContinueStmt _continueStmt() {
    final token = _consume(.continue$, "Expect a 'continue' keyword.");
    _consume(.semicolon, "Expect a ';' closing `constinue` stmt.");
    return ContinueStmt(token, "");
  }

  WhileStmt _whileStmt() {
    _consume(.while$, "Expect a 'while' keyword");
    _consume(.leftParen, "Expect a '(' before while condition expression.");
    final cond = expression();
    _consume(.rightParen, "Expect a ')' after while condition expression.");
    final body = statement();

    return WhileStmt(cond, body, "");
  }

  DoWhileStmt _doWhileStmt() {
    _consume(.do$, "Expect a 'do' keyword");
    final body = statement();
    _consume(.while$, "Expect a 'while' keyword after 'do' body and before while condition.");
    _consume(.leftParen, "Expect a '(' before while condition expression.");
    final cond = expression();
    _consume(.rightParen, "Expect a ')' after while condition expression.");
    _consume(.semicolon, "Expect a ';' closing a do-while statement.");

    return DoWhileStmt(body, cond, "");
  }

  ForStmt _forStmt() {
    _consume(.for$, "Expect a 'for' keyword.");
    _consume(.leftParen, "Expect a '(' before `for` header.");
    
    environment = Environment(environment);
    final  forInit = _forInit();
    final cond = _optExpr(.semicolon);
    final post = _optExpr(.rightParen);
    final body = statement();
    environment = environment.enclosing!;

    return ForStmt(forInit, cond, post, body, "");
  }

  Expr? _optExpr(TokenKind optIndicator) {
    if (_peek().kind == optIndicator) {
      _advance();
      return null;
    }
    final expr = expression();
    _consume(optIndicator, "Expect a '${optIndicator.name}' after expr.");
    return expr;
  }

  ForInit _forInit() {
    if (_match(.semicolon)) {
      return InitExpForInit(null);
    } else if (_peek().kind == .int) {
      return InitDeclForInit(declaration());
    } else {
      final init = InitExpForInit(expression());
      _consume(.semicolon, "Expect a ';' after `InitExp`.");
      return init;
    }
  }

  SwitchStmt _switchStmt() {
    _consume(.switch$, "Expect a 'switch' keyword.");
    _consume(.leftParen, "Expect a '(' before switch expr.");
    final expr = expression();
    _consume(.rightParen, "Expect a ')' after switch expr.");
    final body = statement();

    return SwitchStmt(expr, body, [], null, "");
  }

  CaseStmt _caseStmt() {
    final token = _consume(.case$, "Expect a 'case' keyword.");
    final constExpr = _constant();
    _consume(.colon, "Expect a ':' after case expr.");
    Stmt? stmt; 
    if (!<TokenKind>[.case$, .default$, .rightBraces].contains(_peek().kind)) {
      stmt = statement();
    }

    return CaseStmt(constExpr, stmt, token, "");
  }

  DefaultStmt _defaultStmt() {
    final token = _consume(.default$, "Expect a 'default' keyword.");
    _consume(.colon, "Expect a ':' after case expr.");
    Stmt? stmt; 
    if (!<TokenKind>[.case$, .default$, .rightBraces].contains(_peek().kind)) {
      stmt = statement();
    }

    return DefaultStmt(stmt, token, "");
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
    .plusEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .hyphenEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .starEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .forwardSlashEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .percentEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .andEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .orEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .xorEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .lessLessEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .greaterGreaterEqual: PrecedenceRule(infixFn: _assignment, precedence: .assignment),
    .plusPlus: PrecedenceRule(prefixFn: _unary, infixFn: _unaryPostfix, precedence: .unary),
    .hyphenHyphen: PrecedenceRule(prefixFn: _unary, infixFn: _unaryPostfix, precedence: .unary),
    .questionMark: PrecedenceRule(infixFn: _conditional, precedence: .ternaryCond),
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

  bool _isLvalue(Expr expr) => expr is VarExpr;

  PrefixUnaryExpr _unary() {
    final operator = _consumeOneOf([.hyphen, .tilde, .bang, .plusPlus, .hyphenHyphen]);
    final operand = _parsePrecedence(.unary);

    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(operator.kind)) {
      if (!_isLvalue(operand)) {
        issues.add((operator.location, "expression must be a modifiable lvalue!"));
      }
    }

    return PrefixUnaryExpr(operator, operand);
  }

  Expr _unaryPostfix(Expr left) {
    final operator = _consumeOneOf([.plusPlus, .hyphenHyphen]);
    
    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(operator.kind)) {
      if (!_isLvalue(left)) {
        issues.add((operator.location, "expression must be a modifiable lvalue!"));
      }
    }

    return PostfixUnaryExpr(operator, left);
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

    if (!environment.isDefined(identifier.lexeme)) {
      issues.add((identifier.location, "undeclared variable '${identifier.lexeme}'"));
    }

    return VarExpr(identifier.copyWith(lexeme: environment.get(identifier.lexeme)));
  }

  Expr _assignment(Expr left) {
    if (!_isLvalue(left)) {
      issues.add((ExprLocationExtractor.extract(left), "Invalid lvalue!"));
    }
    
    final operator = _consumeOneOf([
      .equal,
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
    ]);

    final nextRule = _rules[operator.kind]!;
    final right = _parsePrecedence(nextRule.precedence);
  
    return AssignmentExpr(operator, left, right);
  }

  Expr _conditional(Expr cond) {
    _consume(.questionMark, "Expect '?' before ternary conditional lhs expr.");
    final lhs = expression();
    _consume(.colon, "Expect ':' after ternary conditional lhs expr.");
    final rhs = _parsePrecedence(.ternaryCond);
    return ConditionalExpr(cond, lhs, rhs);
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

  void _retract() {
    _currentIdx--;
  }
  
  bool _match(TokenKind kind) {
    if (_peek().kind == kind) {
      _advance();
      return true;
    }
    return false;
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
  
  String _makeTemp(String lexeme) => "r.$lexeme.${_varCount++}";
  
}

// class ConstantFolder implements StmtVisitor<Stmt>, ExprVisitor<Expr>, DeclVisitor<Decl>, BlockItemVisitor<BlockItem> {
//   static ProgramAst transform(ProgramAst program) => ConstantFolder().visitProgram(program);
  
//   ProgramAst visitProgram(ProgramAst program) => ProgramAst(function: visitFunction(program.function));
  
//   visitFunction(FunctionAst function) => FunctionAst(
//     name: function.name, 
//     body: function.body.map((item) => item.accept(this)).toList()
//   );
  
//   @override
//   Expr visitBinaryExpr(BinaryExpr binaryExpr) {
//     final lhs = binaryExpr.lhs.accept(this);
//     final rhs = binaryExpr.rhs.accept(this);

//     if (lhs is ConstantExpr && rhs is ConstantExpr) {
//       final left = int.parse(lhs.value.lexeme);
//       final right = int.parse(rhs.value.lexeme);
//       final result = switch (binaryExpr.operator.kind) {
//         .plus => left+right,
//         .hyphen => left-right,
//         .asterisk => left*right,
//         .forwardSlash => left/right,
//         .percent => left%right,
//         _ => throw Exception("unexpected operator: ${binaryExpr.operator.kind.name}"),
//       };
//       return ConstantExpr(Token(.constant, result.toInt().toString(), lhs.value.location));
//     }

//     return BinaryExpr(binaryExpr.operator, lhs, rhs);
//   }
  
//   @override
//   Expr visitConstantExpr(ConstantExpr constantExpr) => constantExpr;
  
//   @override
//   Stmt visitReturnStmt(ReturnStmt returnStmt) => ReturnStmt(returnStmt.keyword, returnStmt.expr.accept(this));
  
//   @override
//   Expr visitUnaryExpr(UnaryExpr unaryExpr) {
//     final operand = unaryExpr.operand.accept(this);

//     if (operand is ConstantExpr) {
//       final right = int.parse(operand.value.lexeme);
//       final result = switch (unaryExpr.operator.kind) {
//         .hyphen => -right,
//         .tilde => ~right,
//         _ => throw Exception("unexpected operator: ${unaryExpr.operator.kind.name}"),
//       };
//       return ConstantExpr(Token(.constant, result.toString(), operand.value.location));
//     }

//     return UnaryExpr(unaryExpr.operator, operand);
//   }
  
//   @override
//   Expr visitAssignmentExpr(AssignmentExpr assignmentExpr) => 
//     AssignmentExpr(assignmentExpr.lhs.accept(this), assignmentExpr.rhs.accept(this));
  
//   @override
//   Expr visitVarExpr(VarExpr varExpr) => varExpr;
  
//   @override
//   Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => 
//     ExpressionStmt(expressionStmt.expr.accept(this));
  
//   @override
//   Stmt visitNullStmt(NullStmt nullStmt) => nullStmt;
  
//   @override
//   BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => DeclBlockItem(declBlockItem.decl.accept(this));
  
//   @override
//   BlockItem visitStmtBlockItem(StmtBlockItem stmtBlockItem) => StmtBlockItem(stmtBlockItem.stmt.accept(this));
  
//   @override
//   Decl visitVariableDecl(VariableDecl variableDecl) => VariableDecl(variableDecl.name, variableDecl.init?.accept(this));
// }

class MultiIssues implements Exception {
  final List<(Location, String)> issues;
  final String? message;

  MultiIssues(this.issues, [this.message]);

  @override
  String toString() => 
"""Encountered ${issues.length} issues:
${issues.map((pair) => "${pair.$1}: ${pair.$2}").join("\n")}${message != null ? "\n$message" : '' }""";
}

class ExprLocationExtractor implements ExprVisitor<Location> {
  static Location extract(Expr expr) => expr.accept(ExprLocationExtractor());
  
  @override
  Location visitAssignmentExpr(AssignmentExpr assignmentExpr) =>
    assignmentExpr.lhs.accept(this);

  @override
  Location visitBinaryExpr(BinaryExpr binaryExpr) => binaryExpr.operator.location;

  @override
  Location visitConstantExpr(ConstantExpr constantExpr) => constantExpr.value.location;

  @override
  Location visitVarExpr(VarExpr varExpr) => varExpr.identifier.location;
  
  @override
  Location visitPostfixUnaryExpr(PostfixUnaryExpr postfixUnaryExpr) =>  postfixUnaryExpr.operator.location;
  
  @override
  Location visitPrefixUnaryExpr(PrefixUnaryExpr prefixUnaryExpr) => prefixUnaryExpr.operator.location;
  
  @override
  Location visitConditionalExpr(ConditionalExpr conditionalExpr) => conditionalExpr.cond.accept(this);
}