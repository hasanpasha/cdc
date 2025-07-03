part of 'aarch64_asm.dart';

abstract class AArch64Instr {
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class AArch64InstrVisitor<R> {
  R visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr);
  R visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr);
  R visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr);
  R visitAllocateStackAArch64Instr(
    AllocateStackAArch64Instr allocateStackAArch64Instr,
  );
  R visitDeallocateStackAArch64Instr(
    DeallocateStackAArch64Instr deallocateStackAArch64Instr,
  );
  R visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr);
  R visitStoreMemoryAArch64Instr(
    StoreMemoryAArch64Instr storeMemoryAArch64Instr,
  );
  R visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr);
}

class MoveAArch64Instr extends AArch64Instr {
  MoveAArch64Instr(this.src, this.dst);

  final AArch64Operand src;

  final AArch64Operand dst;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitMoveAArch64Instr(this);
  }
}

class UnaryAArch64Instr extends AArch64Instr {
  UnaryAArch64Instr(this.operator, this.operand, this.dst);

  final AArch64Operator operator;

  final AArch64Operand operand;

  final AArch64Operand dst;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitUnaryAArch64Instr(this);
  }
}

class BinaryAArch64Instr extends AArch64Instr {
  BinaryAArch64Instr(this.operator, this.lhs, this.rhs, this.dst);

  final AArch64Operator operator;

  final AArch64Operand lhs;

  final AArch64Operand rhs;

  final AArch64Operand dst;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBinaryAArch64Instr(this);
  }
}

class AllocateStackAArch64Instr extends AArch64Instr {
  AllocateStackAArch64Instr(this.amount);

  final int amount;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitAllocateStackAArch64Instr(this);
  }
}

class DeallocateStackAArch64Instr extends AArch64Instr {
  DeallocateStackAArch64Instr(this.amount);

  final int amount;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitDeallocateStackAArch64Instr(this);
  }
}

class LoadMemoryAArch64Instr extends AArch64Instr {
  LoadMemoryAArch64Instr(this.src, this.dst);

  final StackAArch64Operand src;

  final RegisterAArch64Operand dst;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitLoadMemoryAArch64Instr(this);
  }
}

class StoreMemoryAArch64Instr extends AArch64Instr {
  StoreMemoryAArch64Instr(this.src, this.dst);

  final RegisterAArch64Operand src;

  final StackAArch64Operand dst;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitStoreMemoryAArch64Instr(this);
  }
}

class ReturnAArch64Instr extends AArch64Instr {
  ReturnAArch64Instr();

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitReturnAArch64Instr(this);
  }
}

abstract class AArch64Operand {
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class AArch64OperandVisitor<R> {
  R visitImmediateAArch64Operand(
    ImmediateAArch64Operand immediateAArch64Operand,
  );
  R visitRegisterAArch64Operand(RegisterAArch64Operand registerAArch64Operand);
  R visitPseudoAArch64Operand(PseudoAArch64Operand pseudoAArch64Operand);
  R visitStackAArch64Operand(StackAArch64Operand stackAArch64Operand);
}

class ImmediateAArch64Operand extends AArch64Operand {
  ImmediateAArch64Operand(this.value);

  final String value;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitImmediateAArch64Operand(this);
  }
}

class RegisterAArch64Operand extends AArch64Operand {
  RegisterAArch64Operand(this.reg, this.size);

  final AArch64RegisterNumber reg;

  final AArch64RegisterSize size;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitRegisterAArch64Operand(this);
  }
}

class PseudoAArch64Operand extends AArch64Operand {
  PseudoAArch64Operand(this.id);

  final String id;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitPseudoAArch64Operand(this);
  }
}

class StackAArch64Operand extends AArch64Operand {
  StackAArch64Operand(this.value);

  final int value;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitStackAArch64Operand(this);
  }
}
