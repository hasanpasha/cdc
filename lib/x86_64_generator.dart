
import 'package:cdc/cdc.dart';

class X8664Generator implements AsmGenerator, InstrVisitor, ValueVisitor<X8664Operand> {
  List<X8664Instr> _instrs = [];
  
// TODO: refactor
  @override
  ProgramASM generate(ProgramIR program) {
    var asmProgram = visitProgram(program);

    // TODO: interface passess 
    asmProgram = PseudoEliminator.transform(asmProgram);
    asmProgram = FixupInstructions.transform(asmProgram);

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
      case .divide:
        final eax = RegisterX8664Operand(.xa, .word);
        _instrs.addAll([
          MoveX8664Instr(lhs, eax),
          CdqX8664Instr(),
          IdivX8664Instr(rhs),
          MoveX8664Instr(eax, dst),
        ]);
      case .remainder:
        final eax = RegisterX8664Operand(.xa, .word);
        final edx = RegisterX8664Operand(.xd, .word);
        _instrs.addAll([
          MoveX8664Instr(lhs, eax),
          CdqX8664Instr(),
          IdivX8664Instr(rhs),
          MoveX8664Instr(edx, dst),
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
    final X8664UnaryOperator operator  = switch (unaryInstr.operator) {
      UnaryOperator.negate => X8664UnaryOperator.neg,
      UnaryOperator.complement => X8664UnaryOperator.not,
    };

    _instrs.addAll([
      MoveX8664Instr(src, dst),
      UnaryX8664Instr(operator, dst),
    ]);
  }
  
  @override
  X8664Operand visitVariableValue(VariableValue variableValue) {
    return PseudoX8664Operand(variableValue.name);
  }

  @override
  X8664Operand visitConstantValue(ConstantValue constantValue) {
    return ImmediateX8664Operand(constantValue.value);
  }
}

// TODO: move asm passes to separate files
class FixupInstructions implements X8664InstrVisitor<List<X8664Instr>> {
  static X8664ProgramASM transform(X8664ProgramASM asmProgram) => FixupInstructions().visitProgram(asmProgram);
  
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
}