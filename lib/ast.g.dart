part of 'ast.dart';

class ProgramAst with EquatableMixin {
  ProgramAst(this.main);

  final FunctionAst main;

  @override
  List<Object?> get props => [main];

  @override
  bool? get stringify => true;

  R accept<R>(ProgramAstVisitor<R> visitor) {
    return visitor.visitProgramAst(this);
  }
}

abstract class ProgramAstVisitor<R> {
  R visitProgramAst(ProgramAst programAst);
}

class FunctionAst with EquatableMixin {
  FunctionAst(this.name, this.body);

  final Token name;

  final Block body;

  @override
  List<Object?> get props => [name, body];

  @override
  bool? get stringify => true;

  R accept<R>(FunctionAstVisitor<R> visitor) {
    return visitor.visitFunctionAst(this);
  }
}

abstract class FunctionAstVisitor<R> {
  R visitFunctionAst(FunctionAst functionAst);
}

class Block with EquatableMixin {
  Block(this.items);

  final List<BlockItem> items;

  @override
  List<Object?> get props => [items];

  @override
  bool? get stringify => true;

  R accept<R>(BlockVisitor<R> visitor) {
    return visitor.visitBlock(this);
  }
}

abstract class BlockVisitor<R> {
  R visitBlock(Block block);
}

abstract class BlockItem {
  R accept<R>(BlockItemVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class BlockItemVisitor<R> {
  R visitStmtBlockItem(StmtBlockItem stmtBlockItem);
  R visitDeclBlockItem(DeclBlockItem declBlockItem);
}

class StmtBlockItem extends BlockItem with EquatableMixin {
  StmtBlockItem(this.stmt);

  final Stmt stmt;

  @override
  List<Object?> get props => [stmt];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(BlockItemVisitor<R> visitor) {
    return visitor.visitStmtBlockItem(this);
  }
}

class DeclBlockItem extends BlockItem with EquatableMixin {
  DeclBlockItem(this.decl);

  final Decl decl;

  @override
  List<Object?> get props => [decl];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(BlockItemVisitor<R> visitor) {
    return visitor.visitDeclBlockItem(this);
  }
}

abstract class Stmt {
  R accept<R>(StmtVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class StmtVisitor<R> {
  R visitReturnStmt(ReturnStmt returnStmt);
  R visitExpressionStmt(ExpressionStmt expressionStmt);
  R visitIfStmt(IfStmt ifStmt);
  R visitGotoStmt(GotoStmt gotoStmt);
  R visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt);
  R visitCompoundStmt(CompoundStmt compoundStmt);
  R visitBreakStmt(BreakStmt breakStmt);
  R visitContinueStmt(ContinueStmt continueStmt);
  R visitWhileStmt(WhileStmt whileStmt);
  R visitDoWhileStmt(DoWhileStmt doWhileStmt);
  R visitForStmt(ForStmt forStmt);
  R visitNullStmt(NullStmt nullStmt);
}

class ReturnStmt extends Stmt with EquatableMixin {
  ReturnStmt(this.keyword, this.expr);

  final Token keyword;

  final Expr expr;

  @override
  List<Object?> get props => [keyword, expr];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitReturnStmt(this);
  }
}

class ExpressionStmt extends Stmt with EquatableMixin {
  ExpressionStmt(this.expr);

  final Expr expr;

  @override
  List<Object?> get props => [expr];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitExpressionStmt(this);
  }
}

class IfStmt extends Stmt with EquatableMixin {
  IfStmt(this.cond, this.then, this.else$);

  final Expr cond;

  final Stmt then;

  final Stmt? else$;

  @override
  List<Object?> get props => [cond, then, else$];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitIfStmt(this);
  }
}

class GotoStmt extends Stmt with EquatableMixin {
  GotoStmt(this.dest);

  final Token dest;

  @override
  List<Object?> get props => [dest];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitGotoStmt(this);
  }
}

class LabeledStmtStmt extends Stmt with EquatableMixin {
  LabeledStmtStmt(this.label, this.stmt);

  final Token label;

  final Stmt stmt;

  @override
  List<Object?> get props => [label, stmt];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitLabeledStmtStmt(this);
  }
}

class CompoundStmt extends Stmt with EquatableMixin {
  CompoundStmt(this.block);

  final Block block;

  @override
  List<Object?> get props => [block];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitCompoundStmt(this);
  }
}

class BreakStmt extends Stmt with EquatableMixin {
  BreakStmt(this.token, this.label);

  final Token token;

  final String label;

  @override
  List<Object?> get props => [token, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitBreakStmt(this);
  }
}

class ContinueStmt extends Stmt with EquatableMixin {
  ContinueStmt(this.token, this.label);

  final Token token;

  final String label;

  @override
  List<Object?> get props => [token, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitContinueStmt(this);
  }
}

class WhileStmt extends Stmt with EquatableMixin {
  WhileStmt(this.cond, this.body, this.label);

  final Expr cond;

  final Stmt body;

  final String label;

  @override
  List<Object?> get props => [cond, body, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitWhileStmt(this);
  }
}

class DoWhileStmt extends Stmt with EquatableMixin {
  DoWhileStmt(this.body, this.cond, this.label);

  final Stmt body;

  final Expr cond;

  final String label;

  @override
  List<Object?> get props => [body, cond, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitDoWhileStmt(this);
  }
}

class ForStmt extends Stmt with EquatableMixin {
  ForStmt(this.init, this.cond, this.post, this.body, this.label);

  final ForInit init;

  final Expr? cond;

  final Expr? post;

  final Stmt body;

  final String label;

  @override
  List<Object?> get props => [init, cond, post, body, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitForStmt(this);
  }
}

class NullStmt extends Stmt with EquatableMixin {
  NullStmt();

  @override
  List<Object?> get props => [];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitNullStmt(this);
  }
}

abstract class ForInit {
  R accept<R>(ForInitVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class ForInitVisitor<R> {
  R visitInitDeclForInit(InitDeclForInit initDeclForInit);
  R visitInitExpForInit(InitExpForInit initExpForInit);
}

class InitDeclForInit extends ForInit with EquatableMixin {
  InitDeclForInit(this.decl);

  final Decl decl;

  @override
  List<Object?> get props => [decl];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ForInitVisitor<R> visitor) {
    return visitor.visitInitDeclForInit(this);
  }
}

class InitExpForInit extends ForInit with EquatableMixin {
  InitExpForInit(this.expr);

  final Expr? expr;

  @override
  List<Object?> get props => [expr];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ForInitVisitor<R> visitor) {
    return visitor.visitInitExpForInit(this);
  }
}

abstract class Decl {
  R accept<R>(DeclVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class DeclVisitor<R> {
  R visitVariableDecl(VariableDecl variableDecl);
}

class VariableDecl extends Decl with EquatableMixin {
  VariableDecl(this.name, this.init);

  final Token name;

  final Expr? init;

  @override
  List<Object?> get props => [name, init];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(DeclVisitor<R> visitor) {
    return visitor.visitVariableDecl(this);
  }
}

abstract class Expr {
  R accept<R>(ExprVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class ExprVisitor<R> {
  R visitConstantExpr(ConstantExpr constantExpr);
  R visitVarExpr(VarExpr varExpr);
  R visitPrefixUnaryExpr(PrefixUnaryExpr prefixUnaryExpr);
  R visitPostfixUnaryExpr(PostfixUnaryExpr postfixUnaryExpr);
  R visitBinaryExpr(BinaryExpr binaryExpr);
  R visitAssignmentExpr(AssignmentExpr assignmentExpr);
  R visitConditionalExpr(ConditionalExpr conditionalExpr);
}

class ConstantExpr extends Expr with EquatableMixin {
  ConstantExpr(this.value);

  final Token value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitConstantExpr(this);
  }
}

class VarExpr extends Expr with EquatableMixin {
  VarExpr(this.identifier);

  final Token identifier;

  @override
  List<Object?> get props => [identifier];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitVarExpr(this);
  }
}

class PrefixUnaryExpr extends Expr with EquatableMixin {
  PrefixUnaryExpr(this.operator, this.operand);

  final Token operator;

  final Expr operand;

  @override
  List<Object?> get props => [operator, operand];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitPrefixUnaryExpr(this);
  }
}

class PostfixUnaryExpr extends Expr with EquatableMixin {
  PostfixUnaryExpr(this.operator, this.operand);

  final Token operator;

  final Expr operand;

  @override
  List<Object?> get props => [operator, operand];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitPostfixUnaryExpr(this);
  }
}

class BinaryExpr extends Expr with EquatableMixin {
  BinaryExpr(this.operator, this.lhs, this.rhs);

  final Token operator;

  final Expr lhs;

  final Expr rhs;

  @override
  List<Object?> get props => [operator, lhs, rhs];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitBinaryExpr(this);
  }
}

class AssignmentExpr extends Expr with EquatableMixin {
  AssignmentExpr(this.operator, this.lhs, this.rhs);

  final Token operator;

  final Expr lhs;

  final Expr rhs;

  @override
  List<Object?> get props => [operator, lhs, rhs];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitAssignmentExpr(this);
  }
}

class ConditionalExpr extends Expr with EquatableMixin {
  ConditionalExpr(this.cond, this.lhs, this.rhs);

  final Expr cond;

  final Expr lhs;

  final Expr rhs;

  @override
  List<Object?> get props => [cond, lhs, rhs];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitConditionalExpr(this);
  }
}
