
import 'dart:math';

import 'package:cdc/cdc.dart';

import 'x86_64_asm.dart';

class X8664Generator implements AsmGenerator, ProgramTirVisitor<X8664ProgramASM>, FunctionTirVisitor<X8664FunctionAsm>, InstrVisitor<void>, ValueVisitor<X8664Operand> {
  List<X8664Instr> _instrs = [];
  
// TODO: refactor
  @override
  ProgramASM generate(ProgramTir program) {
    var asmProgram = program.accept(this);

    asmProgram = PseudoEliminator.transform(asmProgram);
    asmProgram = InstructionsFixer.transform(asmProgram);
    // TODO: interface passess 

    return asmProgram;

  }

  @override
  X8664ProgramASM visitProgramTir(ProgramTir program) {
    return X8664ProgramASM(program.functions.map((func) => func.accept(this)).toList());
  }

  @override
  X8664FunctionAsm visitFunctionTir(FunctionTir function) {
    final current = _instrs;

    try {
      final newInstrs = <X8664Instr>[];
      _instrs = newInstrs;

      final regs = <X8664Register>[.di, .si, .dx, .cx, .r8, .r9];
      final params = function.params;
      final registerParams = params.sublist(0, min(regs.length, params.length));
      final stackParams = params.sublist(params.length > regs.length ? regs.length : params.length);

      _instrs.add(CommentX8664Instr("save register params"));
      for (final (index, param) in registerParams.indexed) {
        _instrs.add(CommentX8664Instr(param));
        _instrs.add(MoveX8664Instr(RegisterX8664Operand(regs[index], .word), PseudoX8664Operand(param)));
      }

      _instrs.add(CommentX8664Instr("save stack params"));
      for (final (index, param) in stackParams.indexed) {
        _instrs.add(CommentX8664Instr(param));
        _instrs.add(MoveX8664Instr(StackX8664Operand(16+(index*8)), PseudoX8664Operand(param)));
      }

      
      for (var instr in function.instructions) {
        instr.accept(this);
      }
      
      return X8664FunctionAsm(function.name, newInstrs, 0);
    } finally {
      _instrs = current;
    }

  }
  
  @override
  void visitBinaryInstr(BinaryInstr binaryInstr) {
    final lhs = binaryInstr.lhs.accept(this);
    final rhs = binaryInstr.rhs.accept(this);
    final dst = binaryInstr.dst.accept(this);

    switch(binaryInstr.operator) {
      case .add || .subtract || .multiply || .band || .bor || .xor || .shl || .shr:
        final X8664BinaryOperator operatpr = switch (binaryInstr.operator) {
          .add => .add,
          .subtract => .sub,
          .multiply => .imul,
          .band => .and,
          .bor => .or,
          .xor => .xor,
          // TODO: reconsider the use arithmatic shift
          .shl => .sal,
          .shr => .sar,
          _ => throw Exception("unexpect operator ${binaryInstr.operator}")
        };
        _instrs.addAll([
          MoveX8664Instr(lhs, dst),
          BinaryX8664Instr(operatpr, rhs, dst),
        ]);
      case .divide || .remainder:
        final eax = RegisterX8664Operand(.ax, .word);
        final edx = RegisterX8664Operand(.dx, .word);
        _instrs.addAll([
          MoveX8664Instr(lhs, eax),
          CdqX8664Instr(),
          IdivX8664Instr(rhs),
          MoveX8664Instr(binaryInstr.operator == .divide ? eax : edx, dst),
        ]);
      case .equal || .notEqual || .less || .lessEqual || .greater || .greaterEqual:
        final X8664CondCode condCode = switch (binaryInstr.operator) {
          .equal => .e,
          .notEqual =>  .ne,
          .less => .l,
          .lessEqual => .le,
          .greater => .g,
          .greaterEqual => .ge,
          _ => throw Exception("unexpect operator ${binaryInstr.operator}"),
        };
        _instrs.addAll([
          CmpX8664Instr(rhs, lhs),
          MoveX8664Instr(ImmediateX8664Operand("0"), dst),
          SetCCX8664Instr(condCode, dst),
        ]);
    }
  }
  
  @override
  void visitReturnInstr(ReturnInstr returnInstr) {
    _instrs.addAll([
      MoveX8664Instr(returnInstr.value.accept(this), RegisterX8664Operand(.ax, .word)),
      ReturnX8664Instr(),
    ]);
  }
  
  @override
  void visitUnaryInstr(UnaryInstr unaryInstr) {
    final src = unaryInstr.src.accept(this);
    final dst = unaryInstr.dst.accept(this);
    
    if (unaryInstr.operator == .not) {
      _instrs.addAll([
        CmpX8664Instr(ImmediateX8664Operand("0"), src),
        MoveX8664Instr(ImmediateX8664Operand("0"), dst),
        SetCCX8664Instr(.e, dst),
      ]);
    } else {
      final X8664UnaryOperator operator  = switch (unaryInstr.operator) {
        .negate => .neg,
        .complement => .not,
        _ => throw Exception("unexpect operator ${unaryInstr.operator}"),
      };

      _instrs.addAll([
        MoveX8664Instr(src, dst),
        UnaryX8664Instr(operator, dst),
      ]);
    }
  }
  
  @override
  X8664Operand visitVariableValue(VariableValue variableValue) {
    return PseudoX8664Operand(variableValue.name);
  }

  @override
  X8664Operand visitConstantValue(ConstantValue constantValue) {
    return ImmediateX8664Operand(constantValue.value);
  }
  
  @override
  void visitCopyInstr(CopyInstr copyInstr) => 
    _instrs.add(MoveX8664Instr(copyInstr.src.accept(this), copyInstr.dst.accept(this)));
  
  @override
  void visitJumpIfNotZeroInstr(JumpIfNotZeroInstr jumpIfNotZeroInstr) => 
    _instrs.addAll([
      CmpX8664Instr(ImmediateX8664Operand("0"), jumpIfNotZeroInstr.condition.accept(this)),
      JmpCCX8664Instr(.ne, jumpIfNotZeroInstr.target)
    ]);
  
  @override
  void visitJumpIfZeroInstr(JumpIfZeroInstr jumpIfZeroInstr) =>
    _instrs.addAll([
      CmpX8664Instr(ImmediateX8664Operand("0"), jumpIfZeroInstr.condition.accept(this)),
      JmpCCX8664Instr(.e, jumpIfZeroInstr.target)
    ]);
  
  @override
  void visitJumpInstr(JumpInstr jumpInstr) => 
    _instrs.add(JmpX8664Instr(jumpInstr.target));
  
  
  @override
  void visitLabelInstr(LabelInstr labelInstr) => 
    _instrs.add(LabelX8664Instr(labelInstr.value));
    
  @override
  void visitFunCallInstr(FunCallInstr funCallInstr) {
    _instrs.add(CommentX8664Instr("start call to `${funCallInstr.name}`"));

    final argRegs = <X8664Register>[.di, .si, .dx, .cx, .r8, .r9];
    final args = funCallInstr.args.map((arg) => arg.accept(this)).toList();
    final registerArgs = args.sublist(0, min(argRegs.length, args.length));
    final stackArgs = args.sublist(args.length > argRegs.length ? argRegs.length : args.length);

    final int stackPadding = stackArgs.length.isOdd ? 8 : 0;
    if (stackPadding != 0) {
      _instrs.add(AllocateStackX8664Instr(stackPadding));
    }

    _instrs.add(CommentX8664Instr("push register args"));
    for (final (index, arg) in registerArgs.indexed) {
      _instrs.add(MoveX8664Instr(arg, RegisterX8664Operand(argRegs[index], .word)));
    }

    _instrs.add(CommentX8664Instr("push stack args"));
    for (final arg in stackArgs.reversed) {
      if (arg is RegisterX8664Operand || arg is ImmediateX8664Operand) {
        _instrs.add(PushX8664Instr(arg));
      } else {
        final ebx = RegisterX8664Operand(.bx, .word);
        final rbx = RegisterX8664Operand(.bx, .quadWord);
        _instrs.addAll([
          MoveX8664Instr(arg, ebx),
          PushX8664Instr(rbx),
        ]);
      }
    }

    _instrs.add(CallX8664Instr(funCallInstr.name));

    final bytesToRemove = 8 * stackArgs.length + stackPadding;
    if (bytesToRemove != 0) {
      _instrs.add(DeallocateStackX8664Instr(bytesToRemove));
    }

    _instrs.add(CommentX8664Instr("save return value"));
    final dst = funCallInstr.dst.accept(this);
    _instrs.add(MoveX8664Instr(RegisterX8664Operand(.ax, .word), dst));
  
    _instrs.add(CommentX8664Instr("done call to `${funCallInstr.name}`"));
  }
}

// TODO: move asm passes to separate files
class InstructionsFixer implements X8664FunctionAsmVisitor<X8664FunctionAsm>, X8664InstrVisitor<List<X8664Instr>> {
  static X8664ProgramASM transform(X8664ProgramASM asmProgram) => InstructionsFixer().visitProgram(asmProgram);
  
  X8664ProgramASM visitProgram(X8664ProgramASM asmProgram) => X8664ProgramASM(asmProgram.functions.map((func) => func.accept(this)).toList());
  
  @override
  X8664FunctionAsm visitX8664FunctionAsm(X8664FunctionAsm function) {
    final alignedStackSpace = (function.allocatedStackSize + 15) & ~15; 
    final newInstrs = function.instrs.map((instr) => instr.accept(this)).expand((instrs) => instrs).toList()
      ..insert(0, AllocateStackX8664Instr(alignedStackSpace));
    return X8664FunctionAsm(function.name, newInstrs, alignedStackSpace);
  }
  
  @override
  List<X8664Instr> visitAllocateStackX8664Instr(AllocateStackX8664Instr allocateStackX8664Instr) => 
    [allocateStackX8664Instr];
  
  @override
  List<X8664Instr> visitBinaryX8664Instr(BinaryX8664Instr binaryX8664Instr) {
    if (binaryX8664Instr.operator == .imul && (binaryX8664Instr.lhs is! RegisterX8664Operand || binaryX8664Instr.rhs is! RegisterX8664Operand)) {
      final r11d = RegisterX8664Operand(.r11, .word);
      final r12d = RegisterX8664Operand(.r12, .word);
      return [
        MoveX8664Instr(binaryX8664Instr.lhs, r11d),
        MoveX8664Instr(binaryX8664Instr.rhs, r12d),
        BinaryX8664Instr(binaryX8664Instr.operator, r11d, r12d),
        MoveX8664Instr(r12d, binaryX8664Instr.rhs),
      ];
    } if (<X8664BinaryOperator>[.sal, .shl, .sar, .shr].contains(binaryX8664Instr.operator)) {
      return [
        MoveX8664Instr(binaryX8664Instr.lhs, RegisterX8664Operand(.cx, .word)),
        BinaryX8664Instr(binaryX8664Instr.operator, RegisterX8664Operand(.cx, .lowByte), binaryX8664Instr.rhs),
      ];
    } else if (binaryX8664Instr.lhs is StackX8664Operand && binaryX8664Instr.rhs is StackX8664Operand) {
      final r10d = RegisterX8664Operand(.r10, .word);
      return [
        MoveX8664Instr(binaryX8664Instr.lhs, r10d),
        BinaryX8664Instr(binaryX8664Instr.operator, r10d, binaryX8664Instr.rhs),
      ];
    } else {
      return [binaryX8664Instr];
    }
  }
  
  @override
  List<X8664Instr> visitMoveX8664Instr(MoveX8664Instr moveX8664Instr) {
    if (moveX8664Instr.src is StackX8664Operand && moveX8664Instr.dst is StackX8664Operand) {
      final ebx = RegisterX8664Operand(.bx, .word);
      return [
        MoveX8664Instr(moveX8664Instr.src, ebx),
        MoveX8664Instr(ebx, moveX8664Instr.dst),
      ];
    }  else {
      return [moveX8664Instr];
    }
  }

  @override
  List<X8664Instr> visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr) {
      return [unaryX8664Instr];
  }
  
  @override
  List<X8664Instr> visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr) => [returnX8664Instr];
  
  @override
  List<X8664Instr> visitCdqX8664Instr(CdqX8664Instr cdqX8664Instr) => [cdqX8664Instr];
  
  @override
  List<X8664Instr> visitIdivX8664Instr(IdivX8664Instr idivX8664Instr) {
    final r10d = RegisterX8664Operand(.r10, .word);
    return [
      MoveX8664Instr(idivX8664Instr.operand, r10d),
      IdivX8664Instr(r10d),
    ];
  }
  
  @override
  List<X8664Instr> visitCmpX8664Instr(CmpX8664Instr cmpX8664Instr) {
    if (cmpX8664Instr.lhs is StackX8664Operand && cmpX8664Instr.rhs is StackX8664Operand) {
      final r10d = RegisterX8664Operand(X8664Register.r10, .word);
      return [
        MoveX8664Instr(cmpX8664Instr.lhs, r10d),
        CmpX8664Instr(r10d, cmpX8664Instr.rhs),
      ];
    } else if (cmpX8664Instr.rhs is ImmediateX8664Operand) {
      final r10d = RegisterX8664Operand(X8664Register.r10, .word);
      return [
        MoveX8664Instr(cmpX8664Instr.rhs, r10d),
        CmpX8664Instr(cmpX8664Instr.lhs, r10d),
      ];
    } else {
      return [cmpX8664Instr];
    }
  }
  
  @override
  List<X8664Instr> visitJmpCCX8664Instr(JmpCCX8664Instr jmpCcx8664Instr) => [jmpCcx8664Instr];
  
  @override
  List<X8664Instr> visitJmpX8664Instr(JmpX8664Instr jmpX8664Instr) => [jmpX8664Instr];
  
  @override
  List<X8664Instr> visitLabelX8664Instr(LabelX8664Instr labelX8664Instr) => [labelX8664Instr];
  
  @override
  List<X8664Instr> visitSetCCX8664Instr(SetCCX8664Instr setCcx8664Instr) => [setCcx8664Instr];
  
  @override
  List<X8664Instr> visitCallX8664Instr(CallX8664Instr callX8664Instr) => [callX8664Instr];
  
  @override
  List<X8664Instr> visitDeallocateStackX8664Instr(DeallocateStackX8664Instr deallocateStackX8664Instr) =>
    [deallocateStackX8664Instr];
  
  @override
  List<X8664Instr> visitPushX8664Instr(PushX8664Instr pushX8664Instr) => [pushX8664Instr];
  
  @override
  List<X8664Instr> visitCommentX8664Instr(CommentX8664Instr commentX8664Instr) => [commentX8664Instr];
}

class PseudoEliminator implements X8664FunctionAsmVisitor<X8664FunctionAsm>, X8664InstrVisitor<X8664Instr>, X8664OperandVisitor<X8664Operand> {
  final Map<String, int> _variablesOffset = {};
  int _stackOffset = 0;

  static X8664ProgramASM transform(X8664ProgramASM asmProgram) => PseudoEliminator().visitProgram(asmProgram);
  
  X8664ProgramASM visitProgram(X8664ProgramASM asmProgram) =>
    X8664ProgramASM(asmProgram.functions.map((func) => func.accept(this)).toList());
  
  
  @override
  X8664FunctionAsm visitX8664FunctionAsm(X8664FunctionAsm function) {
    _stackOffset = 0;
    final newInstrs = function.instrs.map((instr) => instr.accept(this)).toList();
    return X8664FunctionAsm(function.name, newInstrs, _stackOffset);
  }
  
  @override
  X8664Instr visitAllocateStackX8664Instr(AllocateStackX8664Instr allocateStackX8664Instr) => allocateStackX8664Instr;
  
  @override
  X8664Instr visitBinaryX8664Instr(BinaryX8664Instr binaryX8664Instr) =>
    BinaryX8664Instr(binaryX8664Instr.operator, binaryX8664Instr.lhs.accept(this), binaryX8664Instr.rhs.accept(this));
  
  @override
  X8664Operand visitImmediateX8664Operand(ImmediateX8664Operand immediateX8664Operand) => immediateX8664Operand;
  
  @override
  X8664Instr visitMoveX8664Instr(MoveX8664Instr moveX8664Instr) =>
    MoveX8664Instr(moveX8664Instr.src.accept(this), moveX8664Instr.dst.accept(this));
  
  @override
  X8664Operand visitPseudoX8664Operand(PseudoX8664Operand pseudoX8664Operand) => 
    StackX8664Operand(-(_variablesOffset[pseudoX8664Operand.id] ?? (() {
      _stackOffset += 4;
      _variablesOffset[pseudoX8664Operand.id] = _stackOffset;
      return _stackOffset;
    })()));
  
  @override
  X8664Operand visitRegisterX8664Operand(RegisterX8664Operand registerX8664Operand) => registerX8664Operand;
  
  @override
  X8664Instr visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr) => returnX8664Instr;
  
  @override
  X8664Operand visitStackX8664Operand(StackX8664Operand stackX8664Operand) => stackX8664Operand;
  
  @override
  X8664Instr visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr) =>
    UnaryX8664Instr(unaryX8664Instr.operator, unaryX8664Instr.operand.accept(this));
    
  @override
  X8664Instr visitCdqX8664Instr(CdqX8664Instr cdqX8664Instr) => cdqX8664Instr;

  @override
  X8664Instr visitIdivX8664Instr(IdivX8664Instr idivX8664Instr) => 
    IdivX8664Instr(idivX8664Instr.operand.accept(this));
    
  @override
  X8664Instr visitCmpX8664Instr(CmpX8664Instr cmpX8664Instr) =>
    CmpX8664Instr(cmpX8664Instr.lhs.accept(this), cmpX8664Instr.rhs.accept(this));

  @override
  X8664Instr visitJmpCCX8664Instr(JmpCCX8664Instr jmpCcx8664Instr) => jmpCcx8664Instr;

  @override
  X8664Instr visitJmpX8664Instr(JmpX8664Instr jmpX8664Instr) => jmpX8664Instr;

  @override
  X8664Instr visitLabelX8664Instr(LabelX8664Instr labelX8664Instr) => labelX8664Instr;

  @override
  X8664Instr visitSetCCX8664Instr(SetCCX8664Instr setCcx8664Instr) =>
    SetCCX8664Instr(setCcx8664Instr.condCode, setCcx8664Instr.operand.accept(this));
    
  @override
  X8664Instr visitCallX8664Instr(CallX8664Instr callX8664Instr) => 
    callX8664Instr;

  @override
  X8664Instr visitDeallocateStackX8664Instr(DeallocateStackX8664Instr deallocateStackX8664Instr) => 
    deallocateStackX8664Instr;

  @override
  X8664Instr visitPushX8664Instr(PushX8664Instr pushX8664Instr) => 
    PushX8664Instr(pushX8664Instr.operand.accept(this));
    
  @override
  X8664Instr visitCommentX8664Instr(CommentX8664Instr commentX8664Instr) => commentX8664Instr;
}