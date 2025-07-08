
import 'package:cdc/ast.dart';
import 'package:cdc/tacky_ir.dart';
import 'package:cdc/token.dart';

class TackyIRGenerator implements 
  StmtVisitor<List<Instr>>, 
  ExprVisitor<(Value, List<Instr>)>,
  DeclVisitor<List<Instr>>,
  BlockItemVisitor<List<Instr>> {
  
  int _tmpCount = 0;
  int _labelCount = 0;
  

  TackyIRGenerator();

  static ProgramIR generate(ProgramAST program) => 
    TackyIRGenerator().visitProgram(program);
  
  ProgramIR visitProgram(ProgramAST program) {
    final functionDefinition = visitFuction(program.function);
    
    return ProgramIR(functionDefinition);
  }

  FunctionIR visitFuction(FunctionAST function) => FunctionIR(
      function.name.lexeme,
      function.body.map((instr) => instr.accept(this)).expand((e) => e).toList()
        ..add(ReturnInstr(ConstantValue('0')))
    );

  @override
  List<Instr> visitReturnStmt(ReturnStmt ret) => 
    ret.expr.accept(this).map((value) => ReturnInstr(value));
  
  @override
  (Value, List<Instr>) visitBinaryExpr(BinaryExpr binary) {
    final lhs = binary.lhs.accept(this);
    final rhs = binary.rhs.accept(this);
    final dst = _makeTempVariable();

    final List<Instr> instrs = [];
    if (binary.operator.kind == .andAnd) {
      final falseLabel = _makeLabel("false");
      final endLabel = _makeLabel("end");
      instrs.addAll([
        ...lhs.map((value) => JumpIfZeroInstr(value, falseLabel)),
        ...rhs.map((value) => JumpIfZeroInstr(value, falseLabel)),
        CopyInstr(ConstantValue("1"), dst),
        JumpInstr(endLabel),
        LabelInstr(falseLabel),
        CopyInstr(ConstantValue("0"), dst),
        LabelInstr(endLabel),
      ]);
    } else if (binary.operator.kind == .orOr) {
      final trueLabel = _makeLabel("true");
      final endLabel = _makeLabel("end");
      instrs.addAll([
        ...lhs.map((value) => JumpIfNotZeroInstr(value, trueLabel)),
        ...rhs.map((value) => JumpIfNotZeroInstr(value, trueLabel)),
        CopyInstr(ConstantValue("0"), dst),
        JumpInstr(endLabel),
        LabelInstr(trueLabel),
        CopyInstr(ConstantValue("1"), dst),
        LabelInstr(endLabel),
      ]);
    } else {
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
      instrs.addAll(
        (lhs, rhs)
          .mapTwo((lhsValue, rhsValue) => BinaryInstr(operator, lhsValue, rhsValue, dst)),
      );
    }

    return (dst, instrs);
  }
  
  @override
  (Value, List<Instr>) visitPrefixUnaryExpr(PrefixUnaryExpr unary) {
    final (srcValue, srcInstrs) = unary.operand.accept(this);
    final dst = _makeTempVariable();
    final instrs = <Instr>[];

    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(unary.operator.kind)) {
      final BinaryOperator operator = switch(unary.operator.kind) {
        .plusPlus => .add,
        .hyphenHyphen => .subtract,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };

      instrs.addAll([
        ...srcInstrs,
        BinaryInstr(operator, srcValue, ConstantValue('1'), srcValue),
        CopyInstr(srcValue, dst),
      ]);
    } else {
      final UnaryOperator operator = switch(unary.operator.kind) {
        .hyphen => .negate,
        .tilde => .complement,
        .bang => .not,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };
      instrs.addAll([
        ...srcInstrs,
        UnaryInstr(operator, srcValue, dst)
      ]);
    }

    return (dst, instrs);
  }

  @override
  (Value, List<Instr>) visitPostfixUnaryExpr(PostfixUnaryExpr unary) {
    final src = unary.operand.accept(this);
    final dst = _makeTempVariable();
    final instrs = <Instr>[];

    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(unary.operator.kind)) {
      final BinaryOperator operator = switch(unary.operator.kind) {
        .plusPlus => .add,
        .hyphenHyphen => .subtract,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };
      instrs.addAll([
        ...src.map((value) => CopyInstr(value, dst)),
        src.mapValue((value) => BinaryInstr(operator, value, ConstantValue('1'), value)),
      ]);
    } else {
      
    }

    return (dst, instrs);
  }
  
  @override
  (Value, List<Instr>) visitConstantExpr(ConstantExpr constant) {
    return (ConstantValue(constant.value.lexeme), []);
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
  (Value, List<Instr>) visitAssignmentExpr(AssignmentExpr assignmentExpr) {
    final (resultValue, resultInstrs) = assignmentExpr.rhs.accept(this);
    final (dstValue, dstInstrs) = assignmentExpr.lhs.accept(this);
    final instrs = <Instr>[];

    if (assignmentExpr.operator.kind == .equal) {
      instrs.addAll([
        ...resultInstrs,
        ...dstInstrs,
        CopyInstr(resultValue, dstValue),
      ]);
    } else {
      final BinaryOperator operator = switch (assignmentExpr.operator.kind) {
        .plusEqual => .add,
        .hyphenEqual => .subtract,
        .starEqual => .multiply,
        .forwardSlashEqual => .divide,
        .percentEqual => .remainder,
        .andEqual => .band,
        .orEqual => .bor,
        .xorEqual => .xor,
        .lessLessEqual => .shl,
        .greaterGreaterEqual => .shr,
        _ => throw Exception("unhandled."),
      };

      instrs.addAll([
        ...resultInstrs,
        ...dstInstrs,
        BinaryInstr(operator, dstValue, resultValue, dstValue),
      ]);
    }

    return (dstValue, instrs);
  }
  
  @override
  List<Instr> visitDeclBlockItem(DeclBlockItem declBlockItem) => 
    declBlockItem.decl.accept(this);
  
  @override
  List<Instr> visitExpressionStmt(ExpressionStmt expressionStmt) => 
    expressionStmt.expr.accept(this).$2;
  
  @override
  List<Instr> visitNullStmt(NullStmt nullStmt) => [];
  
  @override
  List<Instr> visitStmtBlockItem(StmtBlockItem stmtBlockItem) => 
    stmtBlockItem.stmt.accept(this);
  
  @override
  (Value, List<Instr>) visitVarExpr(VarExpr varExpr) => 
    (VariableValue(varExpr.identifier.lexeme), []);
  
  @override
  List<Instr> visitVariableDecl(VariableDecl variableDecl) => 
    variableDecl.init?.accept(this)
      .map((value) => CopyInstr(value, VariableValue(variableDecl.name.lexeme))) ?? [];
  
  @override
  List<Instr> visitIfStmt(IfStmt ifStmt) {
    final String ifEndLabel = (ifStmt.else$ != null) ? _makeLabel("else") : _makeLabel("end");
    final String? elseEndLabel = (ifStmt.else$ != null) ? _makeLabel("end"): null;

    return [
      ...ifStmt.cond.accept(this).map((value) => JumpIfZeroInstr(value, ifEndLabel)),
      ...ifStmt.then.accept(this),
      if (elseEndLabel != null) JumpInstr(elseEndLabel),
      LabelInstr(ifEndLabel),
      ...ifStmt.else$?.accept(this) ?? [],
      if (elseEndLabel != null) LabelInstr(elseEndLabel),
    ];
  }
  
  @override
  (Value, List<Instr>) visitConditionalExpr(ConditionalExpr conditionalExpr) {
    final dst = _makeTempVariable();
    final endLabel = _makeLabel("end");
    final elseLabel = _makeLabel("else");

    return (dst, [
      ...conditionalExpr.cond.accept(this)
        .map((value) => JumpIfZeroInstr(value, elseLabel)),
      ...conditionalExpr.lhs.accept(this)
        .map((value) => CopyInstr(value, dst)),
      JumpInstr(endLabel),
      LabelInstr(elseLabel),
      ...conditionalExpr.rhs.accept(this)
        .map((value) => CopyInstr(value, dst)),
      LabelInstr(endLabel),
    ]);
  }
  
  @override
  List<Instr> visitGotoStmt(GotoStmt gotoStmt) => [
      JumpInstr(gotoStmt.dest.lexeme),
    ];
  
  @override
  List<Instr> visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) => [
    LabelInstr(labeledStmtStmt.label.lexeme),
    ...labeledStmtStmt.stmt.accept(this),
  ];
}

extension on ((Value, List<Instr>), (Value, List<Instr>)) {
  List<Instr> mapTwo(BinaryInstr Function(Value lhsValue, Value rhsValue) mapper) => 
    [...$1.$2, ...$2.$2, mapper($1.$1, $2.$1)];
}

extension on (Value, List<Instr>) {
  List<Instr> map(Instr Function(Value value) mapper) => [...$2, mapper($1)];
  Instr mapValue(Instr Function(Value value) mapper) => mapper($1);
}