import 'token.dart';

part 'ast.g.dart';

class ProgramAST {
  final FunctionAST function;

  ProgramAST({required this.function});

  @override
  String toString() => ASTPrinter().visitProgram(this);

  String prettyTree() => ASTPrettier(showLines: true).visitProgram(this);
}

class FunctionAST {
  final Token name;
  final List<BlockItem> body;

  FunctionAST({required this.name, required this.body});
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
  String visitUnaryExpr(UnaryExpr unary) => "Unary(${unary.operator.kind.name}, ${unary.operand.accept(this)})";
  
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
  String visitUnaryExpr(UnaryExpr unary) => _withIndent(
    () =>
        "Unary($_indent${unary.operator.kind.name},$_indent${unary.operand.accept(this)}$_indentLast)",
  );
  
  @override
  String visitConstantExpr(ConstantExpr constant) => _withIndent(() => "Constant(${constant.value})");
  
  @override
  String visitAssignmentExpr(AssignmentExpr assignmentExpr) => _withIndent(
    () =>
        "Assignment($_indent${assignmentExpr.lhs.accept(this)},$_indent${assignmentExpr.rhs.accept(this)}$_indentLast)",
  );

  @override
  String visitVarExpr(VarExpr varExpr) =>
      _withIndent(() => "Var(${varExpr.identifier})");

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
}

class ExprPolishNotation implements ExprVisitor<String> {
  @override
  String visitBinaryExpr(BinaryExpr binaryExpr) =>
      "(${binaryExpr.operator.lexeme} ${binaryExpr.lhs.accept(this)} ${binaryExpr.rhs.accept(this)})";

  @override
  String visitUnaryExpr(UnaryExpr unaryExpr) =>
      "(${unaryExpr.operator.lexeme} ${unaryExpr.operand.accept(this)})";

  @override
  String visitConstantExpr(ConstantExpr constantExpr) =>
      constantExpr.value.lexeme;
  
  @override
  String visitAssignmentExpr(AssignmentExpr assignmentExpr) =>
      "= ${assignmentExpr.lhs.accept(this)}, ${assignmentExpr.rhs.accept(this)}";

  @override
  String visitVarExpr(VarExpr varExpr) => varExpr.identifier.lexeme;
}