part of 'ast.dart';

abstract class BlockItem {
  R accept<R>(BlockItemVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class BlockItemVisitor<R> {
  R visitStmtBlockItem(StmtBlockItem stmtBlockItem);
  R visitDeclBlockItem(DeclBlockItem declBlockItem);
}

class StmtBlockItem extends BlockItem {
  StmtBlockItem(this.stmt);

  final Stmt stmt;

  @override
  R accept<R>(BlockItemVisitor<R> visitor) {
    return visitor.visitStmtBlockItem(this);
  }
}

class DeclBlockItem extends BlockItem {
  DeclBlockItem(this.decl);

  final Decl decl;

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
  R visitNullStmt(NullStmt nullStmt);
}

class ReturnStmt extends Stmt {
  ReturnStmt(this.keyword, this.expr);

  final Token keyword;

  final Expr expr;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitReturnStmt(this);
  }
}

class ExpressionStmt extends Stmt {
  ExpressionStmt(this.expr);

  final Expr expr;

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitExpressionStmt(this);
  }
}

class NullStmt extends Stmt {
  NullStmt();

  @override
  R accept<R>(StmtVisitor<R> visitor) {
    return visitor.visitNullStmt(this);
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

class VariableDecl extends Decl {
  VariableDecl(this.name, this.init);

  final Token name;

  final Expr? init;

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
  R visitUnaryExpr(UnaryExpr unaryExpr);
  R visitBinaryExpr(BinaryExpr binaryExpr);
  R visitAssignmentExpr(AssignmentExpr assignmentExpr);
}

class ConstantExpr extends Expr {
  ConstantExpr(this.value);

  final String value;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitConstantExpr(this);
  }
}

class VarExpr extends Expr {
  VarExpr(this.identifier);

  final String identifier;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitVarExpr(this);
  }
}

class UnaryExpr extends Expr {
  UnaryExpr(this.operator, this.operand);

  final Token operator;

  final Expr operand;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitUnaryExpr(this);
  }
}

class BinaryExpr extends Expr {
  BinaryExpr(this.operator, this.lhs, this.rhs);

  final Token operator;

  final Expr lhs;

  final Expr rhs;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitBinaryExpr(this);
  }
}

class AssignmentExpr extends Expr {
  AssignmentExpr(this.lhs, this.rhs);

  final Expr lhs;

  final Expr rhs;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitAssignmentExpr(this);
  }
}
