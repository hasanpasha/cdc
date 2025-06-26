part of 'tacky_ir.dart';

abstract class Instr {
  R accept<R>(InstrVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class InstrVisitor<R> {
  R visitReturnInstr(ReturnInstr returnInstr);
  R visitUnaryInstr(UnaryInstr unaryInstr);
  R visitBinaryInstr(BinaryInstr binaryInstr);
}

class ReturnInstr extends Instr {
  ReturnInstr(this.value);

  final Value value;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitReturnInstr(this);
  }
}

class UnaryInstr extends Instr {
  UnaryInstr(this.operator, this.src, this.dst);

  final UnaryOperator operator;

  final Value src;

  final Value dst;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitUnaryInstr(this);
  }
}

class BinaryInstr extends Instr {
  BinaryInstr(this.operator, this.lhs, this.rhs, this.dst);

  final BinaryOperator operator;

  final Value lhs;

  final Value rhs;

  final Value dst;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitBinaryInstr(this);
  }
}

abstract class Value {
  R accept<R>(ValueVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class ValueVisitor<R> {
  R visitConstantValue(ConstantValue constantValue);
  R visitVariableValue(VariableValue variableValue);
}

class ConstantValue extends Value {
  ConstantValue(this.value);

  final String value;

  @override
  R accept<R>(ValueVisitor<R> visitor) {
    return visitor.visitConstantValue(this);
  }
}

class VariableValue extends Value {
  VariableValue(this.name);

  final String name;

  @override
  R accept<R>(ValueVisitor<R> visitor) {
    return visitor.visitVariableValue(this);
  }
}
