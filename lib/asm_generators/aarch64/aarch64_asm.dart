import 'dart:io';

import 'package:cdc/asm.dart';
import 'package:cdc/cdc.dart';

part 'aarch64_asm.g.dart';

class AArch64ProgramASM implements ProgramASM {
  final AArch64FunctionASM function;

  AArch64ProgramASM(this.function);
  
  @override
  String emit() => AArch64AsmEmitter.emit(this);

  @override
  String toString() => AArch64AsmPrettier.prettify(this);
  
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
  static String emit(AArch64ProgramASM aArch64ProgramASM) => AArch64AsmEmitter().visitProgram(aArch64ProgramASM);
  
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
}

class AArch64AsmPrettier implements AArch64InstrVisitor<String>, AArch64OperandVisitor<String> {
  static AArch64AsmPrettier singleton = AArch64AsmPrettier();

  static String prettify(AArch64ProgramASM program) => singleton.visitProgram(program);
  
  String visitProgram(AArch64ProgramASM program) =>
    "AArch64ProgramAsm(${visitFunction(program.function)})";
    
  visitFunction(AArch64FunctionASM function) =>
    "Function(${function.name}, [${function.instructions.map((instr) => instr.accept(this)).join(", ")}])";
    
  @override
  String visitAllocateStackAArch64Instr(AllocateStackAArch64Instr allocateStackAArch64Instr) =>
    "AllocateStack(${allocateStackAArch64Instr.amount})";

  @override
  String visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr) =>
    "Binary(${binaryAArch64Instr.operator.name}, ${binaryAArch64Instr.dst.accept(this)}"
    ", ${binaryAArch64Instr.lhs.accept(this)}, ${binaryAArch64Instr.rhs.accept(this)})";

  @override
  String visitImmediateAArch64Operand(ImmediateAArch64Operand immediateAArch64Operand) =>
    "Immediate(${immediateAArch64Operand.value})";

  @override
  String visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr) =>
    "Move(${moveAArch64Instr.dst.accept(this)}, ${moveAArch64Instr.src.accept(this)})";

  @override
  String visitPseudoAArch64Operand(PseudoAArch64Operand pseudoAArch64Operand) =>
    "Pseudo(${pseudoAArch64Operand.id})";

  @override
  String visitRegisterAArch64Operand(RegisterAArch64Operand registerAArch64Operand) =>
    "Register(${registerAArch64Operand.reg.toString()}, ${registerAArch64Operand.size.name})";

  @override
  String visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr) =>
    "Return()";

  @override
  String visitStackAArch64Operand(StackAArch64Operand stackAArch64Operand) =>
    "Stack(${stackAArch64Operand.value})";

  @override
  String visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr) =>
    "Unary(${unaryAArch64Instr.operator.name}, ${unaryAArch64Instr.dst.accept(this)}, ${unaryAArch64Instr.operand.accept(this)})";
    
  @override
  String visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr) =>
    "LoadMemory(${loadMemoryAArch64Instr.dst.accept(this)}, ${loadMemoryAArch64Instr.src.accept(this)})";

  @override
  String visitStoreMemoryAArch64Instr(StoreMemoryAArch64Instr storeMemoryAArch64Instr) =>
    "StoreMemory(${storeMemoryAArch64Instr.dst.accept(this)}, ${storeMemoryAArch64Instr.src.accept(this)})";
    
  @override
  String visitDeallocateStackAArch64Instr(DeallocateStackAArch64Instr deallocateStackAArch64Instr) =>
    "DeallocateStack(${deallocateStackAArch64Instr.amount})";
}

class AArch64FunctionASM {
  final String name;
  final List<AArch64Instr> instructions;

  AArch64FunctionASM(this.name, this.instructions); 
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