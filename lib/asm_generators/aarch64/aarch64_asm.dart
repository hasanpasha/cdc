import 'dart:io';

import 'package:cdc/cdc.dart';

import 'package:equatable/equatable.dart';

part 'aarch64_asm.g.dart';

class AArch64ProgramASM implements ProgramASM {
  final AArch64FunctionASM function;

  AArch64ProgramASM(this.function);
  
  @override
  String emit({bool pic = true}) => AArch64AsmEmitter.emit(this, pic: pic);

  @override
  String toString() => "AArch64ProgramASM($function)";
  
  @override
  Future<void> compile(Uri output, {bool preserveAsmFile = false}) async {
    final asmOutput = output.replaceExtension('.s');
    final file = await File(asmOutput.path).create();
    await file.writeAsString(emit());
  

    if ((exitCode = await command(Uri.file("/usr/bin/aarch64-linux-gnu-gcc-14"), [asmOutput.path, '-o', output.path])) != 0) {
      print("failed compiling file $asmOutput: $exitCode");
      exit(exitCode);
    }

    if (!preserveAsmFile) {
      await File(asmOutput.path).delete();
    }
  }
}

class AArch64AsmEmitter implements AArch64InstrVisitor<String>, AArch64OperandVisitor<String> {
  final bool pic;

  AArch64AsmEmitter({required this.pic});

  static String emit(
    AArch64ProgramASM aArch64ProgramASM, {
    required bool pic,
  }) => AArch64AsmEmitter(pic: pic).visitProgram(aArch64ProgramASM);
  
  String visitProgram(AArch64ProgramASM aArch64ProgramASM) => 
"""
.text
${visitFunction(aArch64ProgramASM.function)}
""";

  visitFunction(AArch64FunctionASM function) =>
"""
.global ${function.name}
${function.name}:
${function.instructions.map((instr) => instr.accept(this)).join('\n')}""";

  @override
  String visitAllocateStackAArch64Instr(AllocateStackAArch64Instr allocateStackAArch64Instr) =>
"""
stp x29, x30, [sp, #-16]!
mov x29, sp
sub sp, sp, #${allocateStackAArch64Instr.amount}""";

  @override
  String visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr) =>
    "${binaryAArch64Instr.operator.name} ${binaryAArch64Instr.dst.accept(this)}, " 
    "${binaryAArch64Instr.lhs.accept(this)}, ${binaryAArch64Instr.rhs.accept(this)}";

  @override
  String visitImmediateAArch64Operand(ImmediateAArch64Operand immediateAArch64Operand) => "#${immediateAArch64Operand.value}";

  @override
  String visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr) => 
    "ldr ${loadMemoryAArch64Instr.dst.accept(this)}, ${loadMemoryAArch64Instr.src.accept(this)}";

  @override
  String visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr) =>
    "mov ${moveAArch64Instr.dst.accept(this)}, ${moveAArch64Instr.src.accept(this)}";

  @override
  String visitPseudoAArch64Operand(PseudoAArch64Operand pseudoAArch64Operand) => throw Exception("pseudo shouldn't be in final asm.");

  @override
  String visitRegisterAArch64Operand(RegisterAArch64Operand registerAArch64Operand) => switch(registerAArch64Operand.size) {
    AArch64RegisterSize.word => "w${registerAArch64Operand.reg.value}",
    AArch64RegisterSize.quadWord => "x${registerAArch64Operand.reg.value}",
  }; 

  @override
  String visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr) => "ret";

  @override
  String visitStackAArch64Operand(StackAArch64Operand stackAArch64Operand) => "[sp, #${stackAArch64Operand.value}]";

  @override
  String visitStoreMemoryAArch64Instr(StoreMemoryAArch64Instr storeMemoryAArch64Instr) => 
    "str ${storeMemoryAArch64Instr.src.accept(this)}, ${storeMemoryAArch64Instr.dst.accept(this)}";

  @override
  String visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr) => 
    "${unaryAArch64Instr.operator.name} ${unaryAArch64Instr.dst.accept(this)}, ${unaryAArch64Instr.operand.accept(this)}";
  
  @override
  String visitDeallocateStackAArch64Instr(DeallocateStackAArch64Instr deallocateStackAArch64Instr) => """
add sp, sp, #${deallocateStackAArch64Instr.amount}
ldp x29, x30, [sp], #16""";

  @override
  String visitBranchCCAArch64Instr(BranchCCAArch64Instr branchCcaArch64Instr) =>
      "b.${branchCcaArch64Instr.code.name}, .L${branchCcaArch64Instr.label}";

  @override
  String visitBranchIfNotZeroAArch64Instr(
    BranchIfNotZeroAArch64Instr branchIfNotZeroAArch64Instr,
  ) =>
      "cbnz ${branchIfNotZeroAArch64Instr.operand.accept(this)}, .L${branchIfNotZeroAArch64Instr.label}";

  @override
  String visitBranchIfZeroAArch64Instr(
    BranchIfZeroAArch64Instr branchIfZeroAArch64Instr,
  ) =>
      "cbz ${branchIfZeroAArch64Instr.operand.accept(this)}, .L${branchIfZeroAArch64Instr.label}";

  @override
  String visitCmpAArch64Instr(CmpAArch64Instr cmpAArch64Instr) =>
      "cmp ${cmpAArch64Instr.lhs.accept(this)}, ${cmpAArch64Instr.rhs.accept(this)}";

  @override
  String visitSelCCAArch64Instr(SelCCAArch64Instr selCcaArch64Instr) =>
      "csel ${selCcaArch64Instr.dst.accept(this)}, ${selCcaArch64Instr.trueSrc.accept(this)}, ${selCcaArch64Instr.falseSrc.accept(this)}, ${selCcaArch64Instr.code.name}";

  @override
  String visitSetCCAArch64Instr(SetCCAArch64Instr setCcaArch64Instr) =>
      "cset ${setCcaArch64Instr.operand.accept(this)}, ${setCcaArch64Instr.code.name}";
      
  @override
  String visitBranchAArch64Instr(BranchAArch64Instr branchAArch64Instr) =>
      "b .L${branchAArch64Instr.label}";

  @override
  String visitLabelAArch64Instr(LabelAArch64Instr labelAArch64Instr) =>
      ".L${labelAArch64Instr.name}:";
      
  @override
  String visitMoveKAArch64Instr(MoveKAArch64Instr moveKaArch64Instr) =>
      "movk ${moveKaArch64Instr.dst.accept(this)}, ${moveKaArch64Instr.src.accept(this)}${moveKaArch64Instr.shift != null ? ", lsl ${moveKaArch64Instr.shift!}" : ""}";

  @override
  String visitMoveZAArch64Instr(MoveZAArch64Instr moveZaArch64Instr) =>
      "movz ${moveZaArch64Instr.dst.accept(this)}, ${moveZaArch64Instr.src.accept(this)}${moveZaArch64Instr.shift != null ? ", lsl ${moveZaArch64Instr.shift!}" : ""}";
}

enum AArch64Operator {
  add,
  sub,
  mul,
  udiv,
  sdiv,
  eor,
  orr,
  and,
  lsl,
  lsr,
  asr,
  abs,
  neg,
  mvn,
}

enum AArch64ConditionalCode {
  eq,
  ne,
  cs,
  hs,
  cc,
  lo,
  mi,
  pl,
  vs,
  vc,
  hi,
  ls,
  ge,
  lt,
  gt,
  le,
  al,
  nv,
}

class AArch64RegisterNumber {
  final int value;

  AArch64RegisterNumber(this.value) 
    : assert(value >= 0 && value <= 31, 'Value must be 0..31');

  static AArch64RegisterNumber of(int number) => AArch64RegisterNumber(number);

  @override
  String toString() => value.toString();
}

enum AArch64RegisterSize {
  word,
  quadWord,
}