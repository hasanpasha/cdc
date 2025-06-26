import 'package:cdc/cdc.dart';

part 'x86_64_asm.g.dart';

class X8664ProgramASM implements ProgramASM {
  final X8664FunctionASM function;

  X8664ProgramASM(this.function);

  @override
  String emit() => X8664AsmEmitter.emit(this);

  @override
  String toString() => X8664AsmPrettifier.prettify(this);
}

class X8664AsmEmitter implements X8664InstrVisitor<String>, X8664OperandVisitor<String> {
  static String emit(X8664ProgramASM program) => X8664AsmEmitter().visitProgram(program);
  
  String visitProgram(X8664ProgramASM x8664programASM) =>
    """
.section .text
${visitFunction(x8664programASM.function)}
.section .note.GNU-stack,"",@progbits""";
  
  String visitFunction(X8664FunctionASM function) => 
"""
.global ${function.name}
${function.name}:
pushq %rbp
movq %rsp, %rbp
${function.instrs.map((inst) => inst.accept(this)).join('\n')}""";

  @override
  String visitAllocateStackX8664Instr(AllocateStackX8664Instr alloc) => "subq \$${alloc.amount}, %rsp";
  
  @override
  String visitBinaryX8664Instr(BinaryX8664Instr binaryX8664Instr) => 
    "${binaryX8664Instr.operator.name} ${binaryX8664Instr.rhs.accept(this)}, ${binaryX8664Instr.lhs.accept(this)}";
  
  @override
  String visitImmediateX8664Operand(ImmediateX8664Operand immediateX8664Operand) => "\$${immediateX8664Operand.value}";
  
  @override
  String visitMoveX8664Instr(MoveX8664Instr moveX8664Instr) => 
    "movl ${moveX8664Instr.src.accept(this)}, ${moveX8664Instr.dst.accept(this)}";
  
  @override
  String visitPseudoX8664Operand(PseudoX8664Operand pseudoX8664Operand) => throw Exception("final asm program ast must not contain pseudo operand.");
  
  @override
  String visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr) => 
    """
movq %rbp, %rsp
popq %rbp
ret""";
  
  @override
  String visitStackX8664Operand(StackX8664Operand stackX8664Operand) => "-${stackX8664Operand.value}(%rbp)";
  
  @override
  String visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr) => 
    "${unaryX8664Instr.operator.name}l ${unaryX8664Instr.operand.accept(this)}";
  
  @override
  String visitRegisterX8664Operand(RegisterX8664Operand registerX8664Operand) => 
    "%${registerX8664Operand.reg.names[registerX8664Operand.size]}";
}

class X8664AsmPrettifier implements X8664InstrVisitor<String>, X8664OperandVisitor<String> {
  static String prettify(X8664ProgramASM x8664programASM) => X8664AsmPrettifier().visitProgram(x8664programASM);
  
  String visitProgram(X8664ProgramASM x8664programASM) => "X8664ProgramAsm(${visitFunction(x8664programASM.function)})";
  
  String visitFunction(X8664FunctionASM function) => "Function(${function.name}, ${function.instrs.map((instr) => instr.accept(this)).join(", ")})";

  @override
  String visitAllocateStackX8664Instr(AllocateStackX8664Instr alloc) => "AllocateStack(${alloc.amount})";
  
  @override
  String visitBinaryX8664Instr(BinaryX8664Instr binaryX8664Instr) => "Binary(${binaryX8664Instr.operator.name}, ${binaryX8664Instr.lhs.accept(this)}, ${binaryX8664Instr.rhs.accept(this)})";
  
  @override
  String visitImmediateX8664Operand(ImmediateX8664Operand immediateX8664Operand) => "Immediate(${immediateX8664Operand.value})";
  
  @override
  String visitMoveX8664Instr(MoveX8664Instr moveX8664Instr) => "Move(${moveX8664Instr.src.accept(this)}, ${moveX8664Instr.dst.accept(this)})";
  
  @override
  String visitPseudoX8664Operand(PseudoX8664Operand pseudoX8664Operand) => "Pseudo(${pseudoX8664Operand.id})";
  
  @override
  String visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr) => "Return()";
  
  @override
  String visitStackX8664Operand(StackX8664Operand stackX8664Operand) => "Stack(${stackX8664Operand.value})";
  
  @override
  String visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr) => "Unary(${unaryX8664Instr.operator.name}, ${unaryX8664Instr.operand.accept(this)})";
  
  @override
  String visitRegisterX8664Operand(RegisterX8664Operand registerX8664Operand) => "Register(${registerX8664Operand.reg}, ${registerX8664Operand.size})";
}

class X8664FunctionASM {
  final String name;
  final List<X8664Instr> instrs;

  X8664FunctionASM(this.name, this.instrs);
}

enum X8664RegisterSize {
  lowByte,
  highByte,
  short,
  word,
  quadWord,
}

enum X8664Register {
  xa({ 
    X8664RegisterSize.lowByte: 'al',
    X8664RegisterSize.highByte: 'ah',
    X8664RegisterSize.short: 'ax',
    X8664RegisterSize.word: 'eax',
    X8664RegisterSize.quadWord: 'rax',
  }),
  xb({ 
    X8664RegisterSize.lowByte: 'bl',
    X8664RegisterSize.highByte: 'bh',
    X8664RegisterSize.short: 'bx',
    X8664RegisterSize.word: 'ebx',
    X8664RegisterSize.quadWord: 'rbx',
  }),
  xc({ 
    X8664RegisterSize.lowByte: 'cl',
    X8664RegisterSize.highByte: 'ch',
    X8664RegisterSize.short: 'cx',
    X8664RegisterSize.word: 'ecx',
    X8664RegisterSize.quadWord: 'rcx',
  }),
  xd({ 
    X8664RegisterSize.lowByte: 'dl',
    X8664RegisterSize.highByte: 'dh',
    X8664RegisterSize.short: 'dx',
    X8664RegisterSize.word: 'edx',
    X8664RegisterSize.quadWord: 'rdx',
  }),
  r10({
    X8664RegisterSize.lowByte: 'r10b',
    X8664RegisterSize.short: 'r10w',
    X8664RegisterSize.word: 'r10d',
    X8664RegisterSize.quadWord: 'r10',  
  });

  final Map<X8664RegisterSize, String> names;

  const X8664Register(this.names);
}

enum X8664BinaryOperator {
  add,
  sub,
  xor,
}

enum X8664UnaryOperator {
  neg,
  not,
  mul,
  div,
}

