part 'tacky_ir.g.dart';

class ProgramIR {
  final FunctionIR functionDefinition;

  ProgramIR(this.functionDefinition);
  
  @override
  String toString() => TackyIRPrettier.prettify(this);
}

class FunctionIR {
  final String name;
  final List<Instr> instructions;

  FunctionIR(this.name, this.instructions);
}

enum UnaryOperator {
  negate,
  complement,
}

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
}

class TackyIRPrettier implements InstrVisitor<String>, ValueVisitor<String> {
  static String prettify(ProgramIR program) => TackyIRPrettier().visitProgram(program);
  
  String visitProgram(ProgramIR program) => "ProgramIR(${visitFunction(program.functionDefinition)})";

  String visitFunction(FunctionIR func) => "Function(${func.name}, ${func.instructions.map((ins) => ins.accept(this)).join(', ')})";
  
  @override
  String visitReturnInstr(ReturnInstr returnInstr) => "Return(${returnInstr.value.accept(this)})";
  
  @override
  String visitBinaryInstr(BinaryInstr binaryInstr) => "Binary(${binaryInstr.operator}, ${binaryInstr.lhs.accept(this)}, ${binaryInstr.rhs.accept(this)}, ${binaryInstr.dst.accept(this)})";

  @override
  String visitUnaryInstr(UnaryInstr unaryInstr) => "Unary(${unaryInstr.operator}, ${unaryInstr.src.accept(this)}, ${unaryInstr.dst.accept(this)})";

  @override
  String visitConstantValue(ConstantValue constantValue) => "Constant(${constantValue.value})";

  @override
  String visitVariableValue(VariableValue variableValue) => "Variable(${variableValue.name})";
}