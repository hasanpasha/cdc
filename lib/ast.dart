import 'token.dart';

import 'package:equatable/equatable.dart';

part 'ast.g.dart';

class ProgramAST extends Equatable {
  final FunctionAST function;

  ProgramAST({required this.function});

  @override
  String toString() => ASTPrinter().visitProgram(this);

  String prettyTree() => ASTPrettier(showLines: true).visitProgram(this);
  
  @override
  List<Object?> get props => [function];

  @override
  bool? get stringify => true;
}

class FunctionAST extends Equatable {
  final Token name;
  final List<BlockItem> body;

  FunctionAST({required this.name, required this.body});

  @override
  List<Object?> get props => [name, body];

  @override
  bool? get stringify => true;
}

class ASTPrinter
    implements
        StmtVisitor<String>,
        ExprVisitor<String>,
        DeclVisitor<String>,
        BlockItemVisitor<String> {
  String visitProgram(ProgramAST program) => "ProgramAST(${visitFunction(program.function)})"; 

  String visitFunction(FunctionAST function) =>
      "Function(${function.name.lexeme}, [${function.body.map((item) => item.accept(this)).join(", ")}])";

  @override
  String visitReturnStmt(ReturnStmt ret) => "Return(${ret.expr.accept(this)})";
  
  @override
  String visitBinaryExpr(BinaryExpr binary) =>
      "Binary(${binary.operator.kind.name}"
      ", ${binary.lhs.accept(this)}, ${binary.rhs.accept(this)})"; 

  @override
  String visitPrefixUnaryExpr(PrefixUnaryExpr unary) =>
      "PrefixUnary(${unary.operator.kind.name}, ${unary.operand.accept(this)})";

  @override
  String visitPostfixUnaryExpr(PostfixUnaryExpr unary) =>
      "PostfixUnary(${unary.operator.kind.name}, ${unary.operand.accept(this)})";
  
  @override
  String visitConstantExpr(ConstantExpr constant) => "Constant(${constant.value})";
  
  @override
  String visitAssignmentExpr(AssignmentExpr assignmentExpr) =>
      "Assignment(${assignmentExpr.lhs.accept(this)}, ${assignmentExpr.rhs.accept(this)})";

  @override
  String visitVarExpr(VarExpr varExpr) => "Var(${varExpr.identifier})";

  @override
  String visitExpressionStmt(ExpressionStmt expressionStmt) =>
      "Expression(${expressionStmt.expr.accept(this)})";

  @override
  String visitNullStmt(NullStmt nullStmt) => "Null";

  @override
  String visitVariableDecl(VariableDecl variableDecl) =>
      "Variable(${variableDecl.name.lexeme}, ${variableDecl.init?.accept(this)})";

  @override
  String visitDeclBlockItem(DeclBlockItem declBlockItem) =>
      "Decl(${declBlockItem.accept(this)})";

  @override
  String visitStmtBlockItem(StmtBlockItem stmtBlockItem) =>
      "Stmt(${stmtBlockItem.stmt.accept(this)})";
      
  @override
  String visitIfStmt(IfStmt ifStmt) =>
      "If(${ifStmt.cond.accept(this)}, ${ifStmt.then.accept(this)}, ${ifStmt.else$?.accept(this)})";
      
  @override
  String visitConditionalExpr(ConditionalExpr conditionalExpr) =>
      "Conditional(${conditionalExpr.cond.accept(this)}, ${conditionalExpr.lhs.accept(this)}, ${conditionalExpr.rhs.accept(this)})";
      
  @override
  String visitGotoStmt(GotoStmt gotoStmt) =>
      "GotoStmt(${gotoStmt.dest.lexeme})";

  @override
  String visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) =>
      "LabeledStmt(${labeledStmtStmt.label.lexeme}, ${labeledStmtStmt.stmt.accept(this)})";
}

class ASTPrettier
    implements
        StmtVisitor<String>,
        ExprVisitor<String>,
        DeclVisitor<String>,
        BlockItemVisitor<String> {
  int level = 0;
  final bool showLines;

  ASTPrettier({this.showLines = true});

  String get _indent => '\n${'  ${showLines ? '|' : ''}'*(level-1) + ((level > 0) ? '  ' : '')}';
  String get _indentLast => '\n${'  ${showLines ? '|' : ''}'*(level-2) + ((level-1 > 0) ? '  ' : '')}';

  String _withIndent(String Function() fn) {
    _push();
    final str = fn();
    _pop();
    return str;
  }
  
  void _push() => level++;
  void _pop() => level--;

  String visitProgram(ProgramAST program) => _withIndent(
    () => "ProgramAST($_indent${visitFunction(program.function)}$_indentLast)",
  ); 

  String visitFunction(FunctionAST function) => _withIndent(
    () =>
        "Function($_indent${function.name.lexeme},$_indent[$_indent${function.body.map((item) => item.accept(this)).join(",$_indent")}$_indentLast]$_indentLast)",
  );

  @override
  String visitReturnStmt(ReturnStmt ret) => _withIndent(() => "Return($_indent${ret.expr.accept(this)}$_indentLast)");
  
  @override
  String visitBinaryExpr(BinaryExpr binary) => _withIndent(
    () =>
        "Binary($_indent${binary.operator.kind.name},$_indent${binary.lhs.accept(this)},"
        "$_indent${binary.rhs.accept(this)}$_indentLast)",
  ); 

  @override
  String visitPrefixUnaryExpr(PrefixUnaryExpr unary) => _withIndent(
    () =>
        "PrefixUnary($_indent${unary.operator.kind.name},$_indent${unary.operand.accept(this)}$_indentLast)",
  );

  @override
  String visitPostfixUnaryExpr(PostfixUnaryExpr unary) => _withIndent(
    () =>
        "PostfixUnary($_indent${unary.operator.kind.name},$_indent${unary.operand.accept(this)}$_indentLast)",
  );
  
  @override
  String visitConstantExpr(ConstantExpr constant) =>
      _withIndent(() => "Constant(${constant.value.lexeme})");
  
  @override
  String visitAssignmentExpr(AssignmentExpr assignmentExpr) => _withIndent(
    () =>
        "Assignment($_indent${assignmentExpr.lhs.accept(this)},$_indent${assignmentExpr.rhs.accept(this)}$_indentLast)",
  );

  @override
  String visitVarExpr(VarExpr varExpr) =>
      _withIndent(() => "Var(${varExpr.identifier.lexeme})");

  @override
  String visitExpressionStmt(ExpressionStmt expressionStmt) => _withIndent(
    () => "Expression($_indent${expressionStmt.expr.accept(this)}$_indentLast)",
  );

  @override
  String visitNullStmt(NullStmt nullStmt) => "Null";

  @override
  String visitVariableDecl(VariableDecl variableDecl) => _withIndent(
    () =>
        "Variable($_indent${variableDecl.name.lexeme},$_indent${variableDecl.init?.accept(this)}$_indentLast)",
  );

  @override
  String visitDeclBlockItem(DeclBlockItem declBlockItem) => _withIndent(
    () => "Decl($_indent${declBlockItem.decl.accept(this)}$_indentLast)",
  );

  @override
  String visitStmtBlockItem(StmtBlockItem stmtBlockItem) => _withIndent(
    () => "Stmt($_indent${stmtBlockItem.stmt.accept(this)}$_indentLast)",
  );
  
  @override
  String visitIfStmt(IfStmt ifStmt) => _withIndent(
    () =>
        "If($_indent${ifStmt.cond.accept(this)},$_indent${ifStmt.then.accept(this)},$_indent${ifStmt.else$?.accept(this)}$_indentLast)",
  );
  
  @override
  String visitConditionalExpr(ConditionalExpr conditionalExpr) => _withIndent(
    () =>
        "Conditional($_indent${conditionalExpr.cond.accept(this)},$_indent${conditionalExpr.lhs.accept(this)},$_indent${conditionalExpr.rhs.accept(this)}$_indentLast)",
  );
  
  @override
  String visitGotoStmt(GotoStmt gotoStmt) =>
      _withIndent(() => "GotoStmt(${gotoStmt.dest.lexeme})");

  @override
  String visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) => _withIndent(
    () =>
        "LabeledStmt($_indent${labeledStmtStmt.label.lexeme},$_indent${labeledStmtStmt.stmt.accept(this)}$_indentLast)",
  );
}

class ExprPolishNotation implements ExprVisitor<String> {
  @override
  String visitBinaryExpr(BinaryExpr binaryExpr) =>
      "(${binaryExpr.operator.lexeme} ${binaryExpr.lhs.accept(this)} ${binaryExpr.rhs.accept(this)})";

  // TODO: distinguish between pre and postfix unary
  @override
  String visitPrefixUnaryExpr(PrefixUnaryExpr unaryExpr) =>
      "(${unaryExpr.operator.lexeme} ${unaryExpr.operand.accept(this)})";

  @override
  String visitPostfixUnaryExpr(PostfixUnaryExpr unaryExpr) =>
      "(${unaryExpr.operator.lexeme} ${unaryExpr.operand.accept(this)})";

  @override
  String visitConstantExpr(ConstantExpr constantExpr) =>
      constantExpr.value.lexeme;
  
  @override
  String visitAssignmentExpr(AssignmentExpr assignmentExpr) =>
      "= ${assignmentExpr.lhs.accept(this)}, ${assignmentExpr.rhs.accept(this)}";

  @override
  String visitVarExpr(VarExpr varExpr) => varExpr.identifier.lexeme;
  
  @override
  String visitConditionalExpr(ConditionalExpr conditionalExpr) =>
      "?: ${conditionalExpr.cond.accept(this)} ${conditionalExpr.lhs.accept(this)} ${conditionalExpr.rhs.accept(this)}";
}