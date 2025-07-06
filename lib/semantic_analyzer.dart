
import 'package:cdc/ast.dart';
import 'package:cdc/token.dart';

ProgramAST analyze(ProgramAST programAst) {
  ProgramAST newProgram;
  
  newProgram = VariableResolution.transform(programAst);

  return programAst;
}

class VariableResolution implements BlockItemVisitor<BlockItem>, StmtVisitor<Stmt>, DeclVisitor<Decl>, ExprVisitor<Expr> {
  final Map<String, String> _variables = {};
  int _counter = 0;
  final List<(Location, String)> _issues = [];

  static ProgramAST transform(ProgramAST programAst) {
    final variableResoluer = VariableResolution();

    final (issues, newProgram) = variableResoluer.visitProgram(programAst);
  
    if (issues.isNotEmpty) {
      throw MultiErrors(issues);
    }

    return newProgram;
  }
  
  (List<(Location, String)>, ProgramAST) visitProgram(ProgramAST programAst) => 
    (_issues, ProgramAST(function: visitFunction(programAst.function)));
  
  FunctionAST visitFunction(FunctionAST function) => 
    FunctionAST(
      name: function.name, 
      body: function.body.map((e) => e.accept(this)).toList()
    );
  
  @override
  Expr visitAssignmentExpr(AssignmentExpr assignmentExpr) {
    if (assignmentExpr.lhs is! VarExpr) {
      _issues.add((ExprLocationExtractor.extract(assignmentExpr), "Invalid lvalue!"));
    }

    return AssignmentExpr(assignmentExpr.lhs.accept(this), assignmentExpr.rhs.accept(this));
  }
  
  @override
  Expr visitBinaryExpr(BinaryExpr binaryExpr) => 
    BinaryExpr(binaryExpr.operator, binaryExpr.lhs.accept(this), binaryExpr.rhs.accept(this));
  
  @override
  Expr visitConstantExpr(ConstantExpr constantExpr) => constantExpr;
  
  @override
  BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => 
    DeclBlockItem(declBlockItem.decl.accept(this));
  
  @override
  Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => 
    ExpressionStmt(expressionStmt.expr.accept(this));
  
  @override
  Stmt visitNullStmt(NullStmt nullStmt) => nullStmt;
  
  @override
  Stmt visitReturnStmt(ReturnStmt returnStmt) => 
    ReturnStmt(returnStmt.keyword, returnStmt.expr.accept(this));
  
  @override
  BlockItem visitStmtBlockItem(StmtBlockItem stmtBlockItem) =>
    StmtBlockItem(stmtBlockItem.stmt.accept(this));
  
  @override
  Expr visitUnaryExpr(UnaryExpr unaryExpr) =>
    UnaryExpr(unaryExpr.operator, unaryExpr.operand.accept(this));
  
  @override
  Expr visitVarExpr(VarExpr varExpr) {
    if (!_variables.containsKey(varExpr.identifier.lexeme)) {
      _issues.add((varExpr.identifier.location, "undeclared variable '${varExpr.identifier.lexeme}'"));
      return varExpr;
    }

    return VarExpr(varExpr.identifier.copyWith(lexeme: _variables[varExpr.identifier.lexeme]));
  }
  
  @override
  Decl visitVariableDecl(VariableDecl variableDecl) {
    if (_variables.containsKey(variableDecl.name.lexeme)) {
      _issues.add((variableDecl.name.location, "Duplicate variable declaration."));
      return VariableDecl(
        variableDecl.name.copyWith(lexeme: _variables[variableDecl.name.lexeme]),
        variableDecl.init?.accept(this)
      );
    }
    
    final String uniqueName = _makeTemp(variableDecl.name.lexeme);
    _variables[variableDecl.name.lexeme] = uniqueName;
    
    return VariableDecl(
      variableDecl.name.copyWith(lexeme: uniqueName), 
      variableDecl.init?.accept(this)
    );
  }
  
  String _makeTemp(String lexeme) => "r.$lexeme.${_counter++}";
}


class MultiErrors implements Exception {
  final List<(Location, String)> issues;
  final String? message;

  MultiErrors(this.issues, [this.message]);

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
  Location visitUnaryExpr(UnaryExpr unaryExpr) => unaryExpr.operator.location;

  @override
  Location visitVarExpr(VarExpr varExpr) => varExpr.identifier.location;
}