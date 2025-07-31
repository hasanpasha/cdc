import 'dart:io';

import 'package:cdc/cdc.dart';
import 'package:cdc/asm_generators/x86_64/x86_64_asm_emitter.dart';
import 'package:equatable/equatable.dart';

part 'x86_64_asm.g.dart';

class X8664ProgramASM implements ProgramASM {
  final List<X8664FunctionAsm> functions;

  X8664ProgramASM(this.functions);

  @override
  String emit({bool pic = true}) => X8664AsmEmitter.emit(this, pic: pic);

  @override
  Future<void> compile(Uri output, {bool preserveAsmFile = false}) async {
    final asmOutput = output.replaceExtension('.s');
    final file = await File(asmOutput.path).create();
    await file.writeAsString(emit());
  

    if ((exitCode = await command(Uri.file("/usr/bin/gcc"), [asmOutput.path, '-o', output.path])) != 0) {
      print("failed compiling file $asmOutput: $exitCode");
      exit(exitCode);
    }
    
    if (!preserveAsmFile) {
      await File(asmOutput.path).delete();
    }
  }

  @override
  String toString() => "X8664ProgramASM(${functions.map((func) => func.toString())})";
}

enum X8664RegisterSize {
  lowByte,
  highByte,
  short,
  word,
  quadWord,
}

enum X8664Register {
  ax({ 
    .lowByte: 'al',
    .highByte: 'ah',
    .short: 'ax',
    .word: 'eax',
    .quadWord: 'rax',
  }),
  cx({ 
    .lowByte: 'cl',
    .highByte: 'ch',
    .short: 'cx',
    .word: 'ecx',
    .quadWord: 'rcx',
  }),
  dx({ 
    .lowByte: 'dl',
    .highByte: 'dh',
    .short: 'dx',
    .word: 'edx',
    .quadWord: 'rdx',
  }),
  bx({ 
    .lowByte: 'bl',
    .highByte: 'bh',
    .short: 'bx',
    .word: 'ebx',
    .quadWord: 'rbx',
  }),
  si({ 
    .lowByte: 'sil',
    .short: 'si',
    .word: 'esi',
    .quadWord: 'rsi',
  }),
  di({ 
    .lowByte: 'dil',
    .short: 'di',
    .word: 'edi',
    .quadWord: 'rdi',
  }),
  r8({
    .lowByte: 'r8b',
    .short: 'r8w',
    .word: 'r8d',
    .quadWord: 'r8',  
  }),
  r9({
    .lowByte: 'r9b',
    .short: 'r9w',
    .word: 'r9d',
    .quadWord: 'r9',  
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
  }),
  r13({
    .lowByte: 'r13b',
    .short: 'r13w',
    .word: 'r13d',
    .quadWord: 'r13',
  }),
  r14({
    .lowByte: 'r14b',
    .short: 'r14w',
    .word: 'r14d',
    .quadWord: 'r14',
  }),
  r15({
    .lowByte: 'r15b',
    .short: 'r15w',
    .word: 'r15d',
    .quadWord: 'r15',
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