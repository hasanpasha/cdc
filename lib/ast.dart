import 'token.dart';

part 'ast.g.dart';

class ProgramAST {
  final FunctionAST function;

  ProgramAST({required this.function});

  @override
  String toString() => ASTPrettier.prettify(this);
}

class FunctionAST {
  final Token name;
  final Stmt body;

  FunctionAST({required this.name, required this.body});
}


class ASTPrettier implements ExprVisitor<String>, StmtVisitor<String> {
  static final ASTPrettier _prettier = ASTPrettier();
  
  static String prettify(ProgramAST program) => _prettier.visitProgram(program); 

  String visitProgram(ProgramAST program) => "ProgramAST(${visitFunction(program.function)})";

  String visitFunction(FunctionAST function) => "Function(${function.name.lexeme}, ${function.body.accept(this)})";

  @override
  String visitReturnStmt(ReturnStmt ret) => "Return(${ret.expr.accept(this)})";
  
  @override
  String visitBinaryExpr(BinaryExpr binary) => "Binary(${binary.operator.kind}, ${binary.lhs.accept(this)}, ${binary.rhs.accept(this)})"; 

  @override
  String visitUnaryExpr(UnaryExpr unary) => "Unary(${unary.operator.kind}, ${unary.operand.accept(this)})";
  
  @override
  String visitConstantExpr(ConstantExpr constant) => "Constant(${constant.value})"; 
}