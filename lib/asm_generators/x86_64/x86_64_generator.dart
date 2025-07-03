
import 'dart:async';

import 'package:cdc/cdc.dart';

import 'x86_64_asm.dart';

class X8664Generator implements AsmGenerator, InstrVisitor<void>, ValueVisitor<X8664Operand> {
  List<X8664Instr> _instrs = [];
  
// TODO: refactor
  @override
  ProgramASM generate(ProgramIR program) {
    var asmProgram = visitProgram(program);

    asmProgram = PseudoEliminator.transform(asmProgram);
    asmProgram = InstructionsFixer.transform(asmProgram);
    // TODO: interface passess 

    return asmProgram;

  }

  X8664ProgramASM visitProgram(ProgramIR program) {
    return X8664ProgramASM(visitFunction(program.functionDefinition));
  }

  X8664FunctionASM visitFunction(FunctionIR function) {
    final current = _instrs;

    try {
      final newInstrs = <X8664Instr>[];
      _instrs = newInstrs;
      
      for (var instr in function.instructions) {
        instr.accept(this);
      }
      
      return X8664FunctionASM(function.name, newInstrs);
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
        final eax = RegisterX8664Operand(.xa, .word);
        final edx = RegisterX8664Operand(.xd, .word);
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
      MoveX8664Instr(returnInstr.value.accept(this), RegisterX8664Operand(.xa, .word)),
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
}

// TODO: move asm passes to separate files
class InstructionsFixer implements X8664InstrVisitor<List<X8664Instr>> {
  static X8664ProgramASM transform(X8664ProgramASM asmProgram) => InstructionsFixer().visitProgram(asmProgram);
  
  X8664ProgramASM visitProgram(X8664ProgramASM asmProgram) => X8664ProgramASM(visitFunction(asmProgram.function));
  
  X8664FunctionASM visitFunction(X8664FunctionASM function) {
    final newInstrs = function.instrs.map((instr) => instr.accept(this)).expand((instrs) => instrs).toList();
    return X8664FunctionASM(function.name, newInstrs);
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
        MoveX8664Instr(binaryX8664Instr.lhs, RegisterX8664Operand(.xc, .word)),
        BinaryX8664Instr(binaryX8664Instr.operator, RegisterX8664Operand(.xc, .lowByte), binaryX8664Instr.rhs),
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
      final ebx = RegisterX8664Operand(.xb, .word);
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
}

class PseudoEliminator implements X8664InstrVisitor<X8664Instr>, X8664OperandVisitor<X8664Operand> {
  final Map<String, int> _variablesOffset = {};
  int _stackOffset = 0;

  static X8664ProgramASM transform(X8664ProgramASM asmProgram) => PseudoEliminator().visitProgram(asmProgram);
  
  X8664ProgramASM visitProgram(X8664ProgramASM asmProgram) =>
    X8664ProgramASM(visitFunction(asmProgram.function));
  
  
  X8664FunctionASM visitFunction(X8664FunctionASM function) {
    final newInstrs = function.instrs.map((instr) => instr.accept(this)).toList()
      ..insert(0, AllocateStackX8664Instr(_stackOffset));
    return X8664FunctionASM(function.name, newInstrs);
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
    StackX8664Operand(_variablesOffset[pseudoX8664Operand.id] ?? (() {
      _stackOffset += 4;
      _variablesOffset[pseudoX8664Operand.id] = _stackOffset;
      return _stackOffset;
    })());
  
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
}