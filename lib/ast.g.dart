part of 'ast.dart';

abstract class Stmt {
  R accept<R>(StmtVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class StmtVisitor<R> {
  R visitReturnStmt(ReturnStmt returnStmt);
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

abstract class Expr {
  R accept<R>(ExprVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class ExprVisitor<R> {
  R visitConstantExpr(ConstantExpr constantExpr);
  R visitUnaryExpr(UnaryExpr unaryExpr);
  R visitBinaryExpr(BinaryExpr binaryExpr);
  R visitCondTernaryExpr(CondTernaryExpr condTernaryExpr);
}

class ConstantExpr extends Expr {
  ConstantExpr(this.value);

  final String value;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitConstantExpr(this);
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

class CondTernaryExpr extends Expr {
  CondTernaryExpr(this.cond, this.lhs, this.rhs);

  final Expr cond;

  final Expr lhs;

  final Expr rhs;

  @override
  R accept<R>(ExprVisitor<R> visitor) {
    return visitor.visitCondTernaryExpr(this);
  }
}
