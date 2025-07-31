import 'package:equatable/equatable.dart';

part 'tacky_ir.g.dart';

enum UnaryOperator { negate, complement, not }

enum BinaryOperator {
  add,
  subtract,
  multiply,
  divide,
  remainder,
  band,
  bor,
  xor,
  shl,
  shr,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
}

class TackyIrInspector
    implements
        ProgramTirVisitor<String>,
        FunctionTirVisitor<String>,
        InstrVisitor<String>,
        ValueVisitor<String> {
  @override
  String visitBinaryInstr(BinaryInstr binaryInstr) =>
      "${binaryInstr.dst.accept(this)} = ${binaryInstr.lhs.accept(this)} ${binaryInstr.operator.symbol} ${binaryInstr.rhs.accept(this)}";

  @override
  String visitConstantValue(ConstantValue constantValue) => constantValue.value;

  @override
  String visitCopyInstr(CopyInstr copyInstr) =>
      "${copyInstr.dst.accept(this)} = ${copyInstr.src.accept(this)}";

  @override
  String visitFunctionTir(FunctionTir functionIr) =>
      "func ${functionIr.name}(${functionIr.params.join(", ")}):\n"
      "  ${functionIr.instructions.map((instr) => instr.accept(this)).join("\n  ")}";

  @override
  String visitJumpIfNotZeroInstr(JumpIfNotZeroInstr jumpIfNotZeroInstr) =>
      "jump_if_not_zero ${jumpIfNotZeroInstr.condition.accept(this)}, ${jumpIfNotZeroInstr.target}";

  @override
  String visitJumpIfZeroInstr(JumpIfZeroInstr jumpIfZeroInstr) =>
      "jump_if_zero ${jumpIfZeroInstr.condition.accept(this)}, ${jumpIfZeroInstr.target}";

  @override
  String visitJumpInstr(JumpInstr jumpInstr) => "jump ${jumpInstr.target}";

  @override
  String visitLabelInstr(LabelInstr labelInstr) => "${labelInstr.value}:";

  @override
  String visitProgramTir(ProgramTir programIr) =>
      programIr.functions.map((func) => func.accept(this)).join("\n");

  @override
  String visitReturnInstr(ReturnInstr returnInstr) =>
      "return ${returnInstr.value.accept(this)}";

  @override
  String visitUnaryInstr(UnaryInstr unaryInstr) =>
      "${unaryInstr.dst.accept(this)} = ${unaryInstr.operator.symbol} ${unaryInstr.src.accept(this)}";

  @override
  String visitVariableValue(VariableValue variableValue) => variableValue.name;
  
  @override
  String visitFunCallInstr(FunCallInstr funCallInstr) => 
    "${funCallInstr.dst.accept(this)} = ${funCallInstr.name}(${funCallInstr.args.map((arg) => arg.accept(this)).join(", ")})";
}

extension on BinaryOperator {
  get symbol => switch(this) {
    .add => "+",
    .subtract => "-",
    .multiply => "*",
    .divide => "/",
    .remainder => "%",
    .band => "&",
    .bor => "|",
    .xor => "^",
    .shl => "<<",
    .shr => ">>",
    .equal => "==",
    .notEqual => "!=",
    .less => "<",
    .lessEqual => "<=",
    .greater => ">",
    .greaterEqual => ">=",
  };
}

extension on UnaryOperator {
  get symbol => switch (this) {
    .negate => "-",
    .complement => "~",
    .not => "!",
  };
}
