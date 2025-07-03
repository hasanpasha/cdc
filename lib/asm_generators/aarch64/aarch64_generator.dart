import 'package:cdc/asm.dart';
import 'package:cdc/asm_generator.dart';
import 'package:cdc/asm_generators/aarch64/aarch64_asm.dart';
import 'package:cdc/tacky_ir.dart';

class AArch64Generator implements AsmGenerator, InstrVisitor<List<AArch64Instr>>, ValueVisitor<AArch64Operand> {
  @override
  ProgramASM generate(ProgramIR program) {
    AArch64ProgramASM programAsm = visitProgram(program);

    programAsm = PseudoEliminator.transform(programAsm);
    programAsm = InstructionsFixer.transform(programAsm);
    programAsm = MoveMemoryEliminator.transform(programAsm);

    return programAsm;
  }

  AArch64ProgramASM visitProgram(ProgramIR program) {
    return AArch64ProgramASM(visitFunction(program.functionDefinition));
  }
  
  AArch64FunctionASM visitFunction(FunctionIR functionDefinition) {
    return AArch64FunctionASM(
      functionDefinition.name, 
      functionDefinition.instructions
        .map((instr) => instr.accept(this))
        .expand((e) => e.toList())
        .toList());
  }

  @override
  List<AArch64Instr> visitBinaryInstr(BinaryInstr binaryInstr) {
    final dst = binaryInstr.dst.accept(this);
    final lhs = binaryInstr.lhs.accept(this);
    final rhs = binaryInstr.rhs.accept(this);

    switch (binaryInstr.operator) {
      case .add || .subtract || .multiply || .divide || .band || .bor || .xor || .shl || .shr:
        final AArch64Operator operator = switch(binaryInstr.operator) {
          .add => .add,
          .subtract => .sub,
          .multiply => .mul,
          .divide => .sdiv,
          .band => .and,
          .bor => .orr,
          .xor => .eor,
          .shl => .lsl,
          .shr => .asr,
          _ => throw UnimplementedError("can't match TackyIR binary operator `${binaryInstr.operator}` to aarch64 operator."),
        };
        return [BinaryAArch64Instr(operator, lhs, rhs, dst)];
      case BinaryOperator.remainder:
        return [
          BinaryAArch64Instr(.sdiv, lhs, rhs, dst), // dst = lhs / rhs
          BinaryAArch64Instr(.mul, dst, rhs, dst),  // dst = dst * rhs
          BinaryAArch64Instr(.sub, dst, lhs, dst),  // dst = lhs - dst
        ];
}  }

  @override
  List<AArch64Instr> visitReturnInstr(ReturnInstr returnInstr) {
    return [
      MoveAArch64Instr(returnInstr.value.accept(this), RegisterAArch64Operand(.of(0), .word)),
      ReturnAArch64Instr()
    ];
  }

  @override
  List<AArch64Instr> visitUnaryInstr(UnaryInstr unaryInstr) {
    final dst = unaryInstr.dst.accept(this);
    final src = unaryInstr.src.accept(this);
    final AArch64Operator operator = switch (unaryInstr.operator) {
      .negate => .neg,
      .complement => .mvn,
    };
    return [UnaryAArch64Instr(operator, src, dst)];
  }

  @override
  AArch64Operand visitConstantValue(ConstantValue constantValue) {
    return ImmediateAArch64Operand(constantValue.value);
  }

  @override
  AArch64Operand visitVariableValue(VariableValue variableValue) {
    return PseudoAArch64Operand(variableValue.name);
  }
}

class MoveMemoryEliminator implements AArch64InstrVisitor<List<AArch64Instr>> {
  static AArch64ProgramASM transform(AArch64ProgramASM programAsm) => MoveMemoryEliminator().visitProgram(programAsm);

  AArch64ProgramASM visitProgram(AArch64ProgramASM programAsm) => 
    AArch64ProgramASM(visitFunction(programAsm.function));
    
  AArch64FunctionASM visitFunction(AArch64FunctionASM function) => 
    AArch64FunctionASM(
      function.name,
      function.instructions
        .map((instr) => instr.accept(this))
        .expand((e) => e)
        .toList()
    );
  
  @override
  List<AArch64Instr> visitAllocateStackAArch64Instr(AllocateStackAArch64Instr allocateStackAArch64Instr) => [allocateStackAArch64Instr];
  
  @override
  List<AArch64Instr> visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr) {
    if (binaryAArch64Instr.lhs is StackAArch64Operand || binaryAArch64Instr.dst is StackAArch64Operand || binaryAArch64Instr.rhs is StackAArch64Operand) {
      final w4 = RegisterAArch64Operand(.of(4), .word);
      final w5 = RegisterAArch64Operand(.of(5), .word);
      final w6 = RegisterAArch64Operand(.of(6), .word);
      return [
        if (binaryAArch64Instr.lhs is StackAArch64Operand) LoadMemoryAArch64Instr(binaryAArch64Instr.lhs as StackAArch64Operand, w4),
        if (binaryAArch64Instr.rhs is StackAArch64Operand) LoadMemoryAArch64Instr(binaryAArch64Instr.rhs as StackAArch64Operand, w5),
        BinaryAArch64Instr(
          binaryAArch64Instr.operator,
          binaryAArch64Instr.lhs is StackAArch64Operand ? w4 : binaryAArch64Instr.lhs,
          binaryAArch64Instr.rhs is StackAArch64Operand ? w5 : binaryAArch64Instr.rhs,
          binaryAArch64Instr.dst is StackAArch64Operand ? w6 : binaryAArch64Instr.dst,
        ),
        if (binaryAArch64Instr.dst is StackAArch64Operand) StoreMemoryAArch64Instr(w6, binaryAArch64Instr.dst as StackAArch64Operand),
      ];
    } else {
      return [binaryAArch64Instr];
    }
  }
  
  @override
  List<AArch64Instr> visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr) => [loadMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr) {
    if (moveAArch64Instr.src is StackAArch64Operand && moveAArch64Instr.dst is StackAArch64Operand) {
      final w10 = RegisterAArch64Operand(.of(10), .word);
      return [
        LoadMemoryAArch64Instr(moveAArch64Instr.src as StackAArch64Operand, w10),
        StoreMemoryAArch64Instr(w10, moveAArch64Instr.dst as StackAArch64Operand),
      ];
    } else if (moveAArch64Instr.src is StackAArch64Operand && moveAArch64Instr.dst is RegisterAArch64Operand) {
      return [
        LoadMemoryAArch64Instr(moveAArch64Instr.src as StackAArch64Operand, moveAArch64Instr.dst as RegisterAArch64Operand),
      ];
    } else if (moveAArch64Instr.src is RegisterAArch64Operand && moveAArch64Instr.dst is StackAArch64Operand) {
      return [
        StoreMemoryAArch64Instr(moveAArch64Instr.src as RegisterAArch64Operand, moveAArch64Instr.dst as StackAArch64Operand),
      ];
    } else if (moveAArch64Instr.src is ImmediateAArch64Operand && moveAArch64Instr.dst is StackAArch64Operand) {
      final w10 = RegisterAArch64Operand(.of(10), .word);
      return [
        MoveAArch64Instr(moveAArch64Instr.src, w10),
        StoreMemoryAArch64Instr(w10, moveAArch64Instr.dst as StackAArch64Operand),
      ];
    } else {
      return [moveAArch64Instr];
    }
  }
  
  @override
  List<AArch64Instr> visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr) => 
    [returnAArch64Instr];
  
  @override
  List<AArch64Instr> visitStoreMemoryAArch64Instr(StoreMemoryAArch64Instr storeMemoryAArch64Instr) => 
    [storeMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr) => [unaryAArch64Instr];
  
  @override
  List<AArch64Instr> visitDeallocateStackAArch64Instr(DeallocateStackAArch64Instr deallocateStackAArch64Instr) => 
    [deallocateStackAArch64Instr];
  
}

class InstructionsFixer implements AArch64InstrVisitor<List<AArch64Instr>> {
  static AArch64ProgramASM transform(AArch64ProgramASM programAsm) => InstructionsFixer().visitProgram(programAsm);
  
  AArch64ProgramASM visitProgram(AArch64ProgramASM programAsm) => AArch64ProgramASM(visitFunction(programAsm.function));
  
  AArch64FunctionASM visitFunction(AArch64FunctionASM function) => 
    AArch64FunctionASM(
      function.name, 
      function.instructions
        .map((instr) => instr.accept(this))
        .expand((instr) => instr)
        .toList(),
    );
  
  @override
  List<AArch64Instr> visitAllocateStackAArch64Instr(AllocateStackAArch64Instr allocateStackAArch64Instr) =>
    [allocateStackAArch64Instr];

  @override
  List<AArch64Instr> visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr) {
    if (<AArch64Operator>[.add, .sub, .and, .orr, .eor].contains(binaryAArch64Instr.operator) && binaryAArch64Instr.lhs is! RegisterAArch64Operand) {
      return [
        MoveAArch64Instr(binaryAArch64Instr.lhs, binaryAArch64Instr.dst),
        BinaryAArch64Instr(binaryAArch64Instr.operator, binaryAArch64Instr.dst, binaryAArch64Instr.rhs, binaryAArch64Instr.dst),
      ];
    } else if (<AArch64Operator>[.mul, .sdiv, .lsl, .asr].contains(binaryAArch64Instr.operator) && (binaryAArch64Instr.lhs is! RegisterAArch64Operand || binaryAArch64Instr.rhs is! RegisterAArch64Operand)) {
      final w0 = RegisterAArch64Operand(.of(0), .word);
      final w1 = RegisterAArch64Operand(.of(1), .word);
      final w2 = RegisterAArch64Operand(.of(2), .word);
      return [
        MoveAArch64Instr(binaryAArch64Instr.lhs, w0),
        MoveAArch64Instr(binaryAArch64Instr.rhs, w1),
        BinaryAArch64Instr(binaryAArch64Instr.operator, w0, w1, w2),
        MoveAArch64Instr(w2, binaryAArch64Instr.dst),
      ];
    } else {
      return [binaryAArch64Instr];
    }
  }

  @override
  List<AArch64Instr> visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr) => [moveAArch64Instr];

  @override
  List<AArch64Instr> visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr) => [returnAArch64Instr];

  @override
  List<AArch64Instr> visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr) {
    final w2 = RegisterAArch64Operand(.of(2), .word);
    final w3 = RegisterAArch64Operand(.of(3), .word);
    return [
      MoveAArch64Instr(unaryAArch64Instr.operand, w2),
      UnaryAArch64Instr(unaryAArch64Instr.operator, w2, w3),
      MoveAArch64Instr(w3, unaryAArch64Instr.dst),
    ];
  }
  
  @override
  List<AArch64Instr> visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr) => 
    [loadMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitStoreMemoryAArch64Instr(StoreMemoryAArch64Instr storeMemoryAArch64Instr) => 
    [storeMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitDeallocateStackAArch64Instr(DeallocateStackAArch64Instr deallocateStackAArch64Instr) => 
    [deallocateStackAArch64Instr];
}

enum IterationKind {
  elimination,
  insertion,
}

class PseudoEliminator implements AArch64InstrVisitor<List<AArch64Instr>>, AArch64OperandVisitor<AArch64Operand> {
  final Map<String, int> _variablesOffset = {};
  int _stackOffset = 0;
  IterationKind _iterationKind = .elimination;


  int get _stackAllocatedAmount => (_stackOffset + 15) & ~15;  // align stack allocation to 16 in arm64

  static AArch64ProgramASM transform(AArch64ProgramASM programAsm) => PseudoEliminator().visitProgram(programAsm);
  
  AArch64ProgramASM visitProgram(AArch64ProgramASM programAsm) => AArch64ProgramASM(visitFunction(programAsm.function));
  
  AArch64FunctionASM visitFunction(AArch64FunctionASM function) {
    _stackOffset = 0;
    _variablesOffset.clear();
    
    _iterationKind = .elimination;
    var newInstrs = function.instructions
      .map((inst) => inst.accept(this)) // eliminate pseudos (_stackAllocatedAmount gets fixed to a certain amount)
      .expand((e) => e)
      .toList();

    _iterationKind = .insertion;
    newInstrs = newInstrs
      .map((inst) => inst.accept(this)) // insert deallocte stack intrs into every return instr
      .expand((e) => e)
      .toList()
      ..insert(0, AllocateStackAArch64Instr(_stackAllocatedAmount)); // at start of the function

    return AArch64FunctionASM(function.name, newInstrs);
  }
    
  @override
  List<AArch64Instr> visitAllocateStackAArch64Instr(AllocateStackAArch64Instr allocateStackAArch64Instr) => [allocateStackAArch64Instr];

  @override
  List<AArch64Instr> visitBinaryAArch64Instr(BinaryAArch64Instr binaryAArch64Instr) => [BinaryAArch64Instr(
      binaryAArch64Instr.operator, 
      binaryAArch64Instr.lhs.accept(this), 
      binaryAArch64Instr.rhs.accept(this), 
      binaryAArch64Instr.dst.accept(this)
    )];

  @override
  List<AArch64Instr> visitUnaryAArch64Instr(UnaryAArch64Instr unaryAArch64Instr) => [UnaryAArch64Instr(
      unaryAArch64Instr.operator, 
      unaryAArch64Instr.operand.accept(this), 
      unaryAArch64Instr.dst.accept(this)
    )];

  @override
  List<AArch64Instr> visitMoveAArch64Instr(MoveAArch64Instr moveAArch64Instr) => [MoveAArch64Instr(
      moveAArch64Instr.src.accept(this), 
      moveAArch64Instr.dst.accept(this)
    )];

  @override
  List<AArch64Instr> visitReturnAArch64Instr(ReturnAArch64Instr returnAArch64Instr) => 
    _iterationKind == .insertion 
      ? [DeallocateStackAArch64Instr(_stackAllocatedAmount), returnAArch64Instr] 
      : [returnAArch64Instr];
  
  @override
  AArch64Operand visitImmediateAArch64Operand(ImmediateAArch64Operand immediateAArch64Operand) => immediateAArch64Operand;
  
  @override
  AArch64Operand visitPseudoAArch64Operand(PseudoAArch64Operand pseudoAArch64Operand) {
    if (_variablesOffset.containsKey(pseudoAArch64Operand.id)) {
      return StackAArch64Operand(_variablesOffset[pseudoAArch64Operand.id]!);
    } else {
      _stackOffset += 4;
      _variablesOffset[pseudoAArch64Operand.id] = _stackOffset;
      return StackAArch64Operand(_stackOffset);
    }
  }

  @override
  AArch64Operand visitRegisterAArch64Operand(RegisterAArch64Operand registerAArch64Operand) => registerAArch64Operand;

  @override
  AArch64Operand visitStackAArch64Operand(StackAArch64Operand stackAArch64Operand) => stackAArch64Operand;
  
  @override
  List<AArch64Instr> visitLoadMemoryAArch64Instr(LoadMemoryAArch64Instr loadMemoryAArch64Instr) => [loadMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitStoreMemoryAArch64Instr(StoreMemoryAArch64Instr storeMemoryAArch64Instr) => [storeMemoryAArch64Instr];
  
  @override
  List<AArch64Instr> visitDeallocateStackAArch64Instr(DeallocateStackAArch64Instr deallocateStackAArch64Instr) => [deallocateStackAArch64Instr];
}