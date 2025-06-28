
import 'package:cdc/ast.dart';
import 'package:cdc/tacky_ir.dart';
import 'package:cdc/token.dart';

class TackyIRGenerator implements StmtVisitor, ExprVisitor<Value> {
  List<Instr> _instrs = [];
  int _tmpCount = 0;

  TackyIRGenerator();

  static ProgramIR generate(ProgramAST program) {
    return TackyIRGenerator().visitProgram(program);
  }
  
  ProgramIR visitProgram(ProgramAST program) {
    final functionDefinition = visitFuction(program.function);
    
    return ProgramIR(functionDefinition);
  }

  FunctionIR visitFuction(FunctionAST function) {
    final currentInstrs = _instrs;
    try {
      final List<Instr> instrs = [];
      _instrs = instrs;
      function.body.accept(this);
      return FunctionIR(function.name.lexeme, instrs);
    } finally {
      _instrs = currentInstrs;
    }
  }

  @override
  void visitReturnStmt(ReturnStmt ret) {
    _instrs.add(ReturnInstr(ret.expr.accept(this)));
  }
  
  @override
  Value visitBinaryExpr(BinaryExpr binary) {
    final BinaryOperator operator = switch(binary.operator.kind) {
      .plus => .add,
      .hyphen => .subtract,
      .asterisk => .multiply,
      .forwardSlash => .divide,
      .percent => .remainder,
      .and => .band,
      .or => .bor,
      .xor => .xor,
      .lessLess => .shl,
      .greaterGreater => .shr,
      _ => throw UnimplementedError("Can't convert ${binary.operator.kind} to binary operator."),
    };
    final lhs = binary.lhs.accept(this);
    final rhs = binary.rhs.accept(this);
    final dst = _makeTempVariable();

    _instrs.add(BinaryInstr(operator, lhs, rhs, dst));

    return dst;
  }
  
  @override
  Value visitUnaryExpr(UnaryExpr unary) {
    final UnaryOperator operator = switch(unary.operator.kind) {
      TokenKind.hyphen => .negate,
      TokenKind.tilde => .complement,
      _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
    };
    final src = unary.operand.accept(this);
    final dst = _makeTempVariable();

    _instrs.add(UnaryInstr(operator, src, dst));

    return dst;
  }
  
  @override
  Value visitConstantExpr(ConstantExpr constant) {
    return ConstantValue(constant.value);
  }
  
  Value _makeTempVariable() {
    final name = "tmp.${_tmpCount++}";
    return VariableValue(name);
  }
  
  @override
  Value visitCondTernaryExpr(CondTernaryExpr condTernaryExpr) {
    // TODO: implement visitCondTernaryExpr
    throw UnimplementedError();
  }
}