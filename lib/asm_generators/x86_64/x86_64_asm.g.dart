part of 'x86_64_asm.dart';

abstract class X8664Instr {
  R accept<R>(X8664InstrVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class X8664InstrVisitor<R> {
  R visitMoveX8664Instr(MoveX8664Instr moveX8664Instr);
  R visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr);
  R visitBinaryX8664Instr(BinaryX8664Instr binaryX8664Instr);
  R visitCmpX8664Instr(CmpX8664Instr cmpX8664Instr);
  R visitIdivX8664Instr(IdivX8664Instr idivX8664Instr);
  R visitCdqX8664Instr(CdqX8664Instr cdqX8664Instr);
  R visitJmpX8664Instr(JmpX8664Instr jmpX8664Instr);
  R visitJmpCCX8664Instr(JmpCCX8664Instr jmpCcx8664Instr);
  R visitSetCCX8664Instr(SetCCX8664Instr setCcx8664Instr);
  R visitLabelX8664Instr(LabelX8664Instr labelX8664Instr);
  R visitAllocateStackX8664Instr(
    AllocateStackX8664Instr allocateStackX8664Instr,
  );
  R visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr);
}

class MoveX8664Instr extends X8664Instr {
  MoveX8664Instr(this.src, this.dst);

  final X8664Operand src;

  final X8664Operand dst;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitMoveX8664Instr(this);
  }
}

class UnaryX8664Instr extends X8664Instr {
  UnaryX8664Instr(this.operator, this.operand);

  final X8664UnaryOperator operator;

  final X8664Operand operand;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitUnaryX8664Instr(this);
  }
}

class BinaryX8664Instr extends X8664Instr {
  BinaryX8664Instr(this.operator, this.lhs, this.rhs);

  final X8664BinaryOperator operator;

  final X8664Operand lhs;

  final X8664Operand rhs;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitBinaryX8664Instr(this);
  }
}

class CmpX8664Instr extends X8664Instr {
  CmpX8664Instr(this.lhs, this.rhs);

  final X8664Operand lhs;

  final X8664Operand rhs;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitCmpX8664Instr(this);
  }
}

class IdivX8664Instr extends X8664Instr {
  IdivX8664Instr(this.operand);

  final X8664Operand operand;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitIdivX8664Instr(this);
  }
}

class CdqX8664Instr extends X8664Instr {
  CdqX8664Instr();

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitCdqX8664Instr(this);
  }
}

class JmpX8664Instr extends X8664Instr {
  JmpX8664Instr(this.identifier);

  final String identifier;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitJmpX8664Instr(this);
  }
}

class JmpCCX8664Instr extends X8664Instr {
  JmpCCX8664Instr(this.condCode, this.identifier);

  final X8664CondCode condCode;

  final String identifier;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitJmpCCX8664Instr(this);
  }
}

class SetCCX8664Instr extends X8664Instr {
  SetCCX8664Instr(this.condCode, this.operand);

  final X8664CondCode condCode;

  final X8664Operand operand;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitSetCCX8664Instr(this);
  }
}

class LabelX8664Instr extends X8664Instr {
  LabelX8664Instr(this.identifier);

  final String identifier;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitLabelX8664Instr(this);
  }
}

class AllocateStackX8664Instr extends X8664Instr {
  AllocateStackX8664Instr(this.amount);

  final int amount;

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitAllocateStackX8664Instr(this);
  }
}

class ReturnX8664Instr extends X8664Instr {
  ReturnX8664Instr();

  @override
  R accept<R>(X8664InstrVisitor<R> visitor) {
    return visitor.visitReturnX8664Instr(this);
  }
}

abstract class X8664Operand {
  R accept<R>(X8664OperandVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class X8664OperandVisitor<R> {
  R visitImmediateX8664Operand(ImmediateX8664Operand immediateX8664Operand);
  R visitRegisterX8664Operand(RegisterX8664Operand registerX8664Operand);
  R visitPseudoX8664Operand(PseudoX8664Operand pseudoX8664Operand);
  R visitStackX8664Operand(StackX8664Operand stackX8664Operand);
}

class ImmediateX8664Operand extends X8664Operand {
  ImmediateX8664Operand(this.value);

  final String value;

  @override
  R accept<R>(X8664OperandVisitor<R> visitor) {
    return visitor.visitImmediateX8664Operand(this);
  }
}

class RegisterX8664Operand extends X8664Operand {
  RegisterX8664Operand(this.reg, this.size);

  final X8664Register reg;

  final X8664RegisterSize size;

  @override
  R accept<R>(X8664OperandVisitor<R> visitor) {
    return visitor.visitRegisterX8664Operand(this);
  }
}

class PseudoX8664Operand extends X8664Operand {
  PseudoX8664Operand(this.id);

  final String id;

  @override
  R accept<R>(X8664OperandVisitor<R> visitor) {
    return visitor.visitPseudoX8664Operand(this);
  }
}

class StackX8664Operand extends X8664Operand {
  StackX8664Operand(this.value);

  final int value;

  @override
  R accept<R>(X8664OperandVisitor<R> visitor) {
    return visitor.visitStackX8664Operand(this);
  }
}
