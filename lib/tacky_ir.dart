part 'tacky_ir.g.dart';

class ProgramIR {
  final FunctionIR functionDefinition;

  ProgramIR(this.functionDefinition);
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
}

class TackyIRPrettier implements InstrVisitor<String>, ValueVisitor<String> {
  @override
  String visitBinaryInstr(BinaryInstr node) {
    // TODO: implement visitBinaryInstr
    throw UnimplementedError();
  }

  @override
  String visitConstantValue(ConstantValue node) {
    // TODO: implement visitConstantValue
    throw UnimplementedError();
  }

  @override
  String visitReturnInstr(ReturnInstr node) {
    // TODO: implement visitReturnInstr
    throw UnimplementedError();
  }

  @override
  String visitUnaryInstr(UnaryInstr node) {
    // TODO: implement visitUnaryInstr
    throw UnimplementedError();
  }

  @override
  String visitVariableValue(VariableValue node) {
    // TODO: implement visitVariableValue
    throw UnimplementedError();
  }

}