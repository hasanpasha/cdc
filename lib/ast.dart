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
  final Stmt body;

  FunctionAST({required this.name, required this.body});
}

class ASTPrinter implements StmtVisitor<String>, ExprVisitor<String> {
  String visitProgram(ProgramAST program) => "ProgramAST(${visitFunction(program.function)})"; 

  String visitFunction(FunctionAST function) => "Function(${function.name.lexeme}, ${function.body.accept(this)})";

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
}

class ASTPrettier implements StmtVisitor<String>, ExprVisitor<String> {
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
        "Function($_indent${function.name.lexeme},$_indent${function.body.accept(this)}$_indentLast)",
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
        "Unary($_indent${unary.operator.kind.name},$_indent${unary.operand.accept(this)})$_indentLast",
  );
  
  @override
  String visitConstantExpr(ConstantExpr constant) => _withIndent(() => "Constant(${constant.value})");
}

class ExprPolishNotation implements ExprVisitor<String> {
  @override
  String visitBinaryExpr(BinaryExpr binaryExpr) =>
      "(${binaryExpr.operator.lexeme} ${binaryExpr.lhs.accept(this)} ${binaryExpr.rhs.accept(this)})";

  @override
  String visitUnaryExpr(UnaryExpr unaryExpr) =>
      "(${unaryExpr.operator.lexeme} ${unaryExpr.operand.accept(this)})";

  @override
  String visitConstantExpr(ConstantExpr constantExpr) => constantExpr.value;
}