
import 'package:cdc/cdc.dart';

class X8664Generator implements AsmGenerator, InstrVisitor, ValueVisitor<X8664Operand> {
  List<X8664Instr> _instrs = [];
  
  @override
  ProgramASM generate(ProgramIR program) {
    var asmProgram = visitProgram(program);

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
      case BinaryOperator.add || BinaryOperator.subtract:
        final temp = RegisterX8664Operand(X8664Register.xa, X8664RegisterSize.word);
        final X8664BinaryOperator operatpr = switch (binaryInstr.operator) {
          BinaryOperator.add => X8664BinaryOperator.add,
          BinaryOperator.subtract => X8664BinaryOperator.sub,
          _ => throw Exception("unexpect operator ${binaryInstr.operator}")
        };
        _instrs.addAll([
          MoveX8664Instr(lhs, temp),
          BinaryX8664Instr(operatpr, temp, rhs),
          MoveX8664Instr(temp, dst)
        ]);
      case BinaryOperator.multiply:
        final temp = RegisterX8664Operand(X8664Register.xa, X8664RegisterSize.word);
        _instrs.addAll([
          BinaryX8664Instr(X8664BinaryOperator.xor, temp, temp),
          MoveX8664Instr(lhs, temp),
          UnaryX8664Instr(X8664UnaryOperator.mul, rhs),
          MoveX8664Instr(temp, dst)
        ]);
      case BinaryOperator.divide:
        final temp = RegisterX8664Operand(X8664Register.xa, X8664RegisterSize.word);
        _instrs.addAll([
          BinaryX8664Instr(X8664BinaryOperator.xor, temp, temp),
          MoveX8664Instr(lhs, temp),
          UnaryX8664Instr(X8664UnaryOperator.div, rhs),
          MoveX8664Instr(temp, dst)
        ]);
      case BinaryOperator.remainder:
        final temp = RegisterX8664Operand(X8664Register.xa, X8664RegisterSize.word);
        final rem = RegisterX8664Operand(X8664Register.xd, X8664RegisterSize.word);
        _instrs.addAll([
          BinaryX8664Instr(X8664BinaryOperator.xor, temp, temp),
          MoveX8664Instr(lhs, temp),
          UnaryX8664Instr(X8664UnaryOperator.div, rhs),
          MoveX8664Instr(rem, dst),
        ]);
    }
  }
  
  @override
  void visitReturnInstr(ReturnInstr returnInstr) {
    _instrs.addAll([
      MoveX8664Instr(returnInstr.value.accept(this), RegisterX8664Operand(X8664Register.xa, X8664RegisterSize.word)),
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
      UnaryX8664Instr(operator, src),
      MoveX8664Instr(src, dst),
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
    if ((binaryX8664Instr.lhs is StackX8664Operand && binaryX8664Instr.rhs is StackX8664Operand) || binaryX8664Instr.lhs is ImmediateX8664Operand) {
      final temp = RegisterX8664Operand(X8664Register.r10, X8664RegisterSize.word);
      return [
        MoveX8664Instr(binaryX8664Instr.lhs, temp),
        BinaryX8664Instr(binaryX8664Instr.operator, temp, binaryX8664Instr.rhs),
      ];
    } else {
      return [binaryX8664Instr];
    }
  }
  
  @override
  List<X8664Instr> visitMoveX8664Instr(MoveX8664Instr moveX8664Instr) {
    if (moveX8664Instr.src is StackX8664Operand && moveX8664Instr.dst is StackX8664Operand) {
      final temp = RegisterX8664Operand(X8664Register.r10, X8664RegisterSize.word);
      return [
        MoveX8664Instr(moveX8664Instr.src, temp),
        MoveX8664Instr(temp, moveX8664Instr.dst),
      ];
    } else {
      return [moveX8664Instr];
    }
  }

  @override
  List<X8664Instr> visitUnaryX8664Instr(UnaryX8664Instr unaryX8664Instr) {
    if (unaryX8664Instr.operand is ImmediateX8664Operand) {
      final temp = RegisterX8664Operand(X8664Register.r10, X8664RegisterSize.word);
      return [
        MoveX8664Instr(unaryX8664Instr.operand, temp),
        UnaryX8664Instr(unaryX8664Instr.operator, temp),
      ];
    } else {
      return [unaryX8664Instr];
    }
  }
  
  @override
  List<X8664Instr> visitReturnX8664Instr(ReturnX8664Instr returnX8664Instr) => [returnX8664Instr];
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
  X8664Operand visitPseudoX8664Operand(PseudoX8664Operand pseudoX8664Operand) => StackX8664Operand(_variablesOffset[pseudoX8664Operand.id] ?? (() {
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
}