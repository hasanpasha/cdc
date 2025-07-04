
import 'package:cdc/ast.dart';
import 'package:cdc/tacky_ir.dart';

class TackyIRGenerator implements StmtVisitor, ExprVisitor<Value>, DeclVisitor<Value>, BlockItemVisitor<Value> {
  List<Instr> _instrs = [];
  int _tmpCount = 0;
  int _labelCount = 0;
  

  TackyIRGenerator();

  static ProgramIR generate(ProgramAST program) {
    return TackyIRGenerator().visitProgram(program);
  }
  
  ProgramIR visitProgram(ProgramAST program) {
    final functionDefinition = visitFuction(program.function);
    
    return ProgramIR(functionDefinition);
  }

  FunctionIR visitFuction(FunctionAST function) {
    final currentInstrs = _instrs;
    try {
      final List<Instr> instrs = [];
      _instrs = instrs;
      function.body.forEach((item) => item.accept(this));
      return FunctionIR(function.name.lexeme, instrs);
    } finally {
      _instrs = currentInstrs;
    }
  }

  @override
  void visitReturnStmt(ReturnStmt ret) {
    _instrs.add(ReturnInstr(ret.expr.accept(this)));
  }
  
  @override
  Value visitBinaryExpr(BinaryExpr binary) {
    final dst = _makeTempVariable();

    if (binary.operator.kind == .andAnd) {
      final falseLabel = _makeLabel("false");
      final endLabel = _makeLabel("end");
      _instrs.add(JumpIfZeroInstr(binary.lhs.accept(this), falseLabel));
      _instrs.add(JumpIfZeroInstr(binary.rhs.accept(this), falseLabel));
      _instrs.addAll([
        CopyInstr(ConstantValue("1"), dst),
        JumpInstr(endLabel),
        LabelInstr(falseLabel),
        CopyInstr(ConstantValue("0"), dst),
        LabelInstr(endLabel),
      ]);
    } else if (binary.operator.kind == .orOr) {
      final trueLabel = _makeLabel("true");
      final endLabel = _makeLabel("end");
      _instrs.add(JumpIfNotZeroInstr(binary.lhs.accept(this), trueLabel));
      _instrs.add(JumpIfNotZeroInstr(binary.rhs.accept(this), trueLabel));
      _instrs.addAll([
        CopyInstr(ConstantValue("0"), dst),
        JumpInstr(endLabel),
        LabelInstr(trueLabel),
        CopyInstr(ConstantValue("1"), dst),
        LabelInstr(endLabel),
      ]);
    } else {
      final lhs = binary.lhs.accept(this);
      final rhs = binary.rhs.accept(this);
      final BinaryOperator operator = switch(binary.operator.kind) {
        .plus => .add,
        .hyphen => .subtract,
        .asterisk => .multiply,
        .forwardSlash => .divide,
        .percent => .remainder,
        .and => .band,
        .or => .bor,
        .xor => .xor,
        .lessLess => .shl,
        .greaterGreater => .shr,
        .less => .less,
        .lessEqual => .lessEqual,
        .greater => .greater,
        .greaterEqual => .greaterEqual,
        .equalEqual => .equal,
        .bangEqual => .notEqual,
        _ => throw UnimplementedError("Can't convert ${binary.operator.kind} to binary operator."),
      };
      _instrs.add(BinaryInstr(operator, lhs, rhs, dst));
    }

    return dst;
  }
  
  @override
  Value visitUnaryExpr(UnaryExpr unary) {
    final UnaryOperator operator = switch(unary.operator.kind) {
      .hyphen => .negate,
      .tilde => .complement,
      .bang => .not,
      _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
    };
    final src = unary.operand.accept(this);
    final dst = _makeTempVariable();

    _instrs.add(UnaryInstr(operator, src, dst));

    return dst;
  }
  
  @override
  Value visitConstantExpr(ConstantExpr constant) {
    return ConstantValue(constant.value.lexeme);
  }
  
  Value _makeTempVariable() {
    final name = "tmp.${_tmpCount++}";
    return VariableValue(name);
  }
  
  String _makeLabel(String prefix) {
    final name = "$prefix${_labelCount++}";
    return name;
  }
  
  @override
  Value visitAssignmentExpr(AssignmentExpr assignmentExpr) {
    // TODO: implement visitAssignmentExpr
    throw UnimplementedError();
  }
  
  @override
  Value visitDeclBlockItem(DeclBlockItem declBlockItem) {
    // TODO: implement visitDeclBlockItem
    throw UnimplementedError();
  }
  
  @override
  visitExpressionStmt(ExpressionStmt expressionStmt) {
    // TODO: implement visitExpressionStmt
    throw UnimplementedError();
  }
  
  @override
  visitNullStmt(NullStmt nullStmt) {
    // TODO: implement visitNullStmt
    throw UnimplementedError();
  }
  
  @override
  Value visitStmtBlockItem(StmtBlockItem stmtBlockItem) {
    // TODO: implement visitStmtBlockItem
    throw UnimplementedError();
  }
  
  @override
  Value visitVarExpr(VarExpr varExpr) {
    // TODO: implement visitVarExpr
    throw UnimplementedError();
  }
  
  @override
  Value visitVariableDecl(VariableDecl variableDecl) {
    // TODO: implement visitVariableDecl
    throw UnimplementedError();
  }
}