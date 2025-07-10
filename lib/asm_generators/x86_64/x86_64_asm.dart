import 'package:cdc/cdc.dart';
import 'package:cdc/asm_generators/x86_64/x86_64_asm_emitter.dart';
import 'package:equatable/equatable.dart';

part 'x86_64_asm.g.dart';

class X8664ProgramASM implements ProgramASM {
  final X8664FunctionAsm mainFunction;

  X8664ProgramASM(this.mainFunction);

  @override
  String toString() => "X8664ProgramASM($mainFunction)";

  @override
  String emit() => X8664AsmEmitter.emit(this);
}

// class X8664FunctionASM {
//   final String name;
//   final List<X8664Instr> instrs;

//   X8664FunctionASM(this.name, this.instrs);
// }

enum X8664RegisterSize {
  lowByte,
  highByte,
  short,
  word,
  quadWord,
}

enum X8664Register {
  xa({ 
    .lowByte: 'al',
    .highByte: 'ah',
    .short: 'ax',
    .word: 'eax',
    .quadWord: 'rax',
  }),
  xb({ 
    .lowByte: 'bl',
    .highByte: 'bh',
    .short: 'bx',
    .word: 'ebx',
    .quadWord: 'rbx',
  }),
  xc({ 
    .lowByte: 'cl',
    .highByte: 'ch',
    .short: 'cx',
    .word: 'ecx',
    .quadWord: 'rcx',
  }),
  xd({ 
    .lowByte: 'dl',
    .highByte: 'dh',
    .short: 'dx',
    .word: 'edx',
    .quadWord: 'rdx',
  }),
  r10({
    .lowByte: 'r10b',
    .short: 'r10w',
    .word: 'r10d',
    .quadWord: 'r10',  
  }),
  r11({
    .lowByte: 'r11b',
    .short: 'r11w',
    .word: 'r11d',
    .quadWord: 'r11',  
  }),
  r12({
    .lowByte: 'r12b',
    .short: 'r12w',
    .word: 'r12d',
    .quadWord: 'r12',
  });

  final Map<X8664RegisterSize, String> names;

  const X8664Register(this.names);
}

enum X8664BinaryOperator {
  add,
  sub,
  imul,
  xor,
  and,
  or,
  shl,
  sal,
  shr,
  sar,
}

enum X8664UnaryOperator {
  neg,
  not,
}

enum X8664CondCode {
  e,
  ne,
  g,
  ge,
  l,
  le,
}