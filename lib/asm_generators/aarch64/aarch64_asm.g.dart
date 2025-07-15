part of 'aarch64_asm.dart';

class AArch64FunctionASM with EquatableMixin {
  AArch64FunctionASM(this.name, this.instructions);

  final String name;

  final List<AArch64Instr> instructions;

  @override
  List<Object?> get props => [name, instructions];

  @override
  bool? get stringify => true;

  R accept<R>(AArch64FunctionASMVisitor<R> visitor) {
    return visitor.visitAArch64FunctionASM(this);
  }
}

abstract class AArch64FunctionASMVisitor<R> {
  R visitAArch64FunctionASM(AArch64FunctionASM aArch64FunctionAsm);
}

abstract class AArch64Instr {
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    throw UnimplementedError();
  }
}

abstract class AArch64InstrVisitor<R> {
  R visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr);
  R visitMoveZAArch64Instr(MoveZAArch64Instr moveZaArch64Instr);
  R visitMoveKAArch64Instr(MoveKAArch64Instr moveKaArch64Instr);
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
  R visitCmpAArch64Instr(CmpAArch64Instr cmpAArch64Instr);
  R visitSetCCAArch64Instr(SetCCAArch64Instr setCcaArch64Instr);
  R visitSelCCAArch64Instr(SelCCAArch64Instr selCcaArch64Instr);
  R visitLabelAArch64Instr(LabelAArch64Instr labelAArch64Instr);
  R visitBranchAArch64Instr(BranchAArch64Instr branchAArch64Instr);
  R visitBranchCCAArch64Instr(BranchCCAArch64Instr branchCcaArch64Instr);
  R visitBranchIfZeroAArch64Instr(
    BranchIfZeroAArch64Instr branchIfZeroAArch64Instr,
  );
  R visitBranchIfNotZeroAArch64Instr(
    BranchIfNotZeroAArch64Instr branchIfNotZeroAArch64Instr,
  );
  R visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr);
}

class MoveAArch64Instr extends AArch64Instr with EquatableMixin {
  MoveAArch64Instr(this.src, this.dst);

  final AArch64Operand src;

  final AArch64Operand dst;

  @override
  List<Object?> get props => [src, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitMoveAArch64Instr(this);
  }
}

class MoveZAArch64Instr extends AArch64Instr with EquatableMixin {
  MoveZAArch64Instr(this.src, this.dst, this.shift);

  final ImmediateAArch64Operand src;

  final AArch64Operand dst;

  final int? shift;

  @override
  List<Object?> get props => [src, dst, shift];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitMoveZAArch64Instr(this);
  }
}

class MoveKAArch64Instr extends AArch64Instr with EquatableMixin {
  MoveKAArch64Instr(this.src, this.dst, this.shift);

  final ImmediateAArch64Operand src;

  final AArch64Operand dst;

  final int? shift;

  @override
  List<Object?> get props => [src, dst, shift];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitMoveKAArch64Instr(this);
  }
}

class UnaryAArch64Instr extends AArch64Instr with EquatableMixin {
  UnaryAArch64Instr(this.operator, this.operand, this.dst);

  final AArch64Operator operator;

  final AArch64Operand operand;

  final AArch64Operand dst;

  @override
  List<Object?> get props => [operator, operand, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitUnaryAArch64Instr(this);
  }
}

class BinaryAArch64Instr extends AArch64Instr with EquatableMixin {
  BinaryAArch64Instr(this.operator, this.lhs, this.rhs, this.dst);

  final AArch64Operator operator;

  final AArch64Operand lhs;

  final AArch64Operand rhs;

  final AArch64Operand dst;

  @override
  List<Object?> get props => [operator, lhs, rhs, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBinaryAArch64Instr(this);
  }
}

class AllocateStackAArch64Instr extends AArch64Instr with EquatableMixin {
  AllocateStackAArch64Instr(this.amount);

  final int amount;

  @override
  List<Object?> get props => [amount];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitAllocateStackAArch64Instr(this);
  }
}

class DeallocateStackAArch64Instr extends AArch64Instr with EquatableMixin {
  DeallocateStackAArch64Instr(this.amount);

  final int amount;

  @override
  List<Object?> get props => [amount];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitDeallocateStackAArch64Instr(this);
  }
}

class LoadMemoryAArch64Instr extends AArch64Instr with EquatableMixin {
  LoadMemoryAArch64Instr(this.src, this.dst);

  final StackAArch64Operand src;

  final RegisterAArch64Operand dst;

  @override
  List<Object?> get props => [src, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitLoadMemoryAArch64Instr(this);
  }
}

class StoreMemoryAArch64Instr extends AArch64Instr with EquatableMixin {
  StoreMemoryAArch64Instr(this.src, this.dst);

  final RegisterAArch64Operand src;

  final StackAArch64Operand dst;

  @override
  List<Object?> get props => [src, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitStoreMemoryAArch64Instr(this);
  }
}

class CmpAArch64Instr extends AArch64Instr with EquatableMixin {
  CmpAArch64Instr(this.lhs, this.rhs);

  final AArch64Operand lhs;

  final AArch64Operand rhs;

  @override
  List<Object?> get props => [lhs, rhs];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitCmpAArch64Instr(this);
  }
}

class SetCCAArch64Instr extends AArch64Instr with EquatableMixin {
  SetCCAArch64Instr(this.code, this.operand);

  final AArch64ConditionalCode code;

  final AArch64Operand operand;

  @override
  List<Object?> get props => [code, operand];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitSetCCAArch64Instr(this);
  }
}

class SelCCAArch64Instr extends AArch64Instr with EquatableMixin {
  SelCCAArch64Instr(this.code, this.trueSrc, this.falseSrc, this.dst);

  final AArch64ConditionalCode code;

  final AArch64Operand trueSrc;

  final AArch64Operand falseSrc;

  final AArch64Operand dst;

  @override
  List<Object?> get props => [code, trueSrc, falseSrc, dst];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitSelCCAArch64Instr(this);
  }
}

class LabelAArch64Instr extends AArch64Instr with EquatableMixin {
  LabelAArch64Instr(this.name);

  final String name;

  @override
  List<Object?> get props => [name];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitLabelAArch64Instr(this);
  }
}

class BranchAArch64Instr extends AArch64Instr with EquatableMixin {
  BranchAArch64Instr(this.label);

  final String label;

  @override
  List<Object?> get props => [label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBranchAArch64Instr(this);
  }
}

class BranchCCAArch64Instr extends AArch64Instr with EquatableMixin {
  BranchCCAArch64Instr(this.code, this.label);

  final AArch64ConditionalCode code;

  final String label;

  @override
  List<Object?> get props => [code, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBranchCCAArch64Instr(this);
  }
}

class BranchIfZeroAArch64Instr extends AArch64Instr with EquatableMixin {
  BranchIfZeroAArch64Instr(this.operand, this.label);

  final AArch64Operand operand;

  final String label;

  @override
  List<Object?> get props => [operand, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBranchIfZeroAArch64Instr(this);
  }
}

class BranchIfNotZeroAArch64Instr extends AArch64Instr with EquatableMixin {
  BranchIfNotZeroAArch64Instr(this.operand, this.label);

  final AArch64Operand operand;

  final String label;

  @override
  List<Object?> get props => [operand, label];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64InstrVisitor<R> visitor) {
    return visitor.visitBranchIfNotZeroAArch64Instr(this);
  }
}

class ReturnAArch64Instr extends AArch64Instr with EquatableMixin {
  ReturnAArch64Instr();

  @override
  List<Object?> get props => [];

  @override
  bool? get stringify => true;

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

class ImmediateAArch64Operand extends AArch64Operand with EquatableMixin {
  ImmediateAArch64Operand(this.value);

  final String value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitImmediateAArch64Operand(this);
  }
}

class RegisterAArch64Operand extends AArch64Operand with EquatableMixin {
  RegisterAArch64Operand(this.reg, this.size);

  final AArch64RegisterNumber reg;

  final AArch64RegisterSize size;

  @override
  List<Object?> get props => [reg, size];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitRegisterAArch64Operand(this);
  }
}

class PseudoAArch64Operand extends AArch64Operand with EquatableMixin {
  PseudoAArch64Operand(this.id);

  final String id;

  @override
  List<Object?> get props => [id];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitPseudoAArch64Operand(this);
  }
}

class StackAArch64Operand extends AArch64Operand with EquatableMixin {
  StackAArch64Operand(this.value);

  final int value;

  @override
  List<Object?> get props => [value];

  @override
  bool? get stringify => true;

  @override
  R accept<R>(AArch64OperandVisitor<R> visitor) {
    return visitor.visitStackAArch64Operand(this);
  }
}
