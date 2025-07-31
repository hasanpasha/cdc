import 'token.dart';

import 'package:equatable/equatable.dart';

part 'ast.g.dart';

class ASTPrettier
    with ExprPolishNotation
    implements
        ProgramAstVisitor<String>,
        BlockVisitor<String>,
        StmtVisitor<String>,
        ForInitVisitor<String>,
        DeclVisitor<String>,
        BlockItemVisitor<String> {
  int level = 0;
  final bool showLines;

  ASTPrettier({this.showLines = true});

  String get _indent =>
      '\n${'  ${showLines ? '|' : ''}' * (level - 1) + ((level > 0) ? '  ' : '')}';
  String get _indentLast =>
      '\n${'  ${showLines ? '|' : ''}' * (level - 2) + ((level - 1 > 0) ? '  ' : '')}';

  String _withIndent(String Function() fn) {
    _push();
    final str = fn();
    _pop();
    return str;
  }

  void _push() => level++;
  void _pop() => level--;

  @override
  String visitProgramAst(ProgramAst program) => _withIndent(
    () =>
        "ProgramAST($_indent${program.functions.map((function) => function.accept(this)).join(_indent)}$_indentLast)",
  );

  @override
  String visitFunctionDecl(FunctionDecl function) => _withIndent(
    () =>
        "Function($_indent${function.name.lexeme},$_indent[$_indent${function.params.map((param) => param.lexeme).join(",$_indent")}$_indent],"
        "$_indent[$_indent${function.body?.accept(this)}$_indentLast])",
  );

  @override
  String visitBlock(Block block) =>
      _withIndent(
    () => block.items.map((item) => item.accept(this)).join(",$_indent"),
  );

  @override
  String visitReturnStmt(ReturnStmt ret) =>
      _withIndent(() => "Return($_indent${ret.expr.accept(this)}$_indentLast)");

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
  String visitGotoStmt(GotoStmt gotoStmt) =>
      _withIndent(() => "GotoStmt(${gotoStmt.dest.lexeme})");

  @override
  String visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) => _withIndent(
    () =>
        "LabeledStmt($_indent${labeledStmtStmt.label.lexeme},$_indent${labeledStmtStmt.stmt.accept(this)}$_indentLast)",
  );

  @override
  String visitCompoundStmt(CompoundStmt compoundStmt) =>
      _withIndent(() => "Compound(${compoundStmt.block.accept(this)})");

  @override
  String visitBreakStmt(BreakStmt breakStmt) => "Break(${breakStmt.label})";

  @override
  String visitContinueStmt(ContinueStmt continueStmt) =>
      "Continue(${continueStmt.label})";

  @override
  String visitDoWhileStmt(DoWhileStmt doWhileStmt) => _withIndent(
    () =>
        "DoWhile($_indent${doWhileStmt.body.accept(this)},$_indent${doWhileStmt.cond.accept(this)},$_indent${doWhileStmt.label}$_indentLast)",
  );

  @override
  String visitForStmt(ForStmt forStmt) => _withIndent(
    () =>
        "For($_indent${forStmt.init.accept(this)},$_indent${forStmt.cond?.accept(this)},"
        "$_indent${forStmt.post?.accept(this)},$_indent${forStmt.body.accept(this)},$_indent${forStmt.label}$_indentLast)",
  );

  @override
  String visitWhileStmt(WhileStmt whileStmt) => _withIndent(
    () =>
        "While($_indent${whileStmt.cond.accept(this)},$_indent${whileStmt.body.accept(this)},$_indent${whileStmt.label}$_indentLast)",
  );

  @override
  String visitInitDeclForInit(InitDeclForInit initDeclForInit) =>
      _withIndent(() => "InitDecl(${initDeclForInit.decl.accept(this)})");

  @override
  String visitInitExpForInit(InitExpForInit initExpForInit) =>
      _withIndent(() => "InitExp(${initExpForInit.expr?.accept(this)})");
      
  @override
  String visitCaseStmt(CaseStmt caseStmt) => _withIndent(
    () =>
        "Case($_indent${caseStmt.expr.accept(this)},$_indent${caseStmt.stmt?.accept(this)},$_indent${caseStmt.label}$_indentLast)",
  );

  @override
  String visitDefaultStmt(DefaultStmt defaultStmt) => _withIndent(
    () =>
        "Default($_indent${defaultStmt.stmt?.accept(this)},$_indent${defaultStmt.label}$_indentLast)",
  );

  @override
  String visitSwitchStmt(SwitchStmt switchStmt) => _withIndent(
    () =>
        "Switch($_indent${switchStmt.expr.accept(this)},$_indent${switchStmt.body.accept(this)},"
        "$_indent${switchStmt.cases.map((caseStmt) => caseStmt.accept(this))},$_indent${switchStmt.defaultCase?.accept(this)}$_indentLast)",
  );

}

mixin ExprPolishNotation implements ExprVisitor<String> {
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
      
  @override
  String visitFunctionCallExpr(FunctionCallExpr functionCallExpr) =>
      "${functionCallExpr.identifier.lexeme} ${functionCallExpr.args?.map((arg) => arg.accept(this)).join(" ")}";
}
