part of 'tacky_ir.dart';

class ProgramIR with EquatableMixin {
  ProgramIR(this.functionDefinition);

  final FunctionIR functionDefinition;

  @override
  List<Object?> get props => [functionDefinition];

  @override
  bool? get stringify => true;

  R accept<R>(ProgramIRVisitor<R> visitor) {
    return visitor.visitProgramIR(this);
  }
}

abstract class ProgramIRVisitor<R> {
  R visitProgramIR(ProgramIR programIr);
}

class FunctionIR with EquatableMixin {
  FunctionIR(this.name, this.instructions);

  final String name;

  final List<Instr> instructions;

  @override
  List<Object?> get props => [name, instructions];

  @override
  bool? get stringify => true;

  R accept<R>(FunctionIRVisitor<R> visitor) {
    return visitor.visitFunctionIR(this);
  }
}

abstract class FunctionIRVisitor<R> {
  R visitFunctionIR(FunctionIR functionIr);
}

abstract class Instr {
  R accept<R>(InstrVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class InstrVisitor<R> {
  R visitReturnInstr(ReturnInstr returnInstr);
  R visitUnaryInstr(UnaryInstr unaryInstr);
  R visitBinaryInstr(BinaryInstr binaryInstr);
  R visitCopyInstr(CopyInstr copyInstr);
  R visitJumpInstr(JumpInstr jumpInstr);
  R visitJumpIfZeroInstr(JumpIfZeroInstr jumpIfZeroInstr);
  R visitJumpIfNotZeroInstr(JumpIfNotZeroInstr jumpIfNotZeroInstr);
  R visitLabelInstr(LabelInstr labelInstr);
}

class ReturnInstr extends Instr with EquatableMixin {
  ReturnInstr(this.value);

  final Value value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitReturnInstr(this);
  }
}

class UnaryInstr extends Instr with EquatableMixin {
  UnaryInstr(this.operator, this.src, this.dst);

  final UnaryOperator operator;

  final Value src;

  final Value dst;

  @override
  List<Object?> get props => [operator, src, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitUnaryInstr(this);
  }
}

class BinaryInstr extends Instr with EquatableMixin {
  BinaryInstr(this.operator, this.lhs, this.rhs, this.dst);

  final BinaryOperator operator;

  final Value lhs;

  final Value rhs;

  final Value dst;

  @override
  List<Object?> get props => [operator, lhs, rhs, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitBinaryInstr(this);
  }
}

class CopyInstr extends Instr with EquatableMixin {
  CopyInstr(this.src, this.dst);

  final Value src;

  final Value dst;

  @override
  List<Object?> get props => [src, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitCopyInstr(this);
  }
}

class JumpInstr extends Instr with EquatableMixin {
  JumpInstr(this.target);

  final String target;

  @override
  List<Object?> get props => [target];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitJumpInstr(this);
  }
}

class JumpIfZeroInstr extends Instr with EquatableMixin {
  JumpIfZeroInstr(this.condition, this.target);

  final Value condition;

  final String target;

  @override
  List<Object?> get props => [condition, target];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitJumpIfZeroInstr(this);
  }
}

class JumpIfNotZeroInstr extends Instr with EquatableMixin {
  JumpIfNotZeroInstr(this.condition, this.target);

  final Value condition;

  final String target;

  @override
  List<Object?> get props => [condition, target];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitJumpIfNotZeroInstr(this);
  }
}

class LabelInstr extends Instr with EquatableMixin {
  LabelInstr(this.value);

  final String value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(InstrVisitor<R> visitor) {
    return visitor.visitLabelInstr(this);
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

class ConstantValue extends Value with EquatableMixin {
  ConstantValue(this.value);

  final String value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ValueVisitor<R> visitor) {
    return visitor.visitConstantValue(this);
  }
}

class VariableValue extends Value with EquatableMixin {
  VariableValue(this.name);

  final String name;

  @override
  List<Object?> get props => [name];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(ValueVisitor<R> visitor) {
    return visitor.visitVariableValue(this);
  }
}
