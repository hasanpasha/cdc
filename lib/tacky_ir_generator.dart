
import 'package:cdc/ast.dart';
import 'package:cdc/tacky_ir.dart';
import 'package:cdc/token.dart';

class TackyIRGenerator implements StmtVisitor, ExprVisitor<Value>, DeclVisitor, BlockItemVisitor {
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
      for (var item in function.body) {
        item.accept(this);
      }
      _instrs.add(ReturnInstr(ConstantValue('0')));
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
  Value visitPrefixUnaryExpr(PrefixUnaryExpr unary) {
    final src = unary.operand.accept(this);
    final dst = _makeTempVariable();

    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(unary.operator.kind)) {
      final BinaryOperator operator = switch(unary.operator.kind) {
        .plusPlus => .add,
        .hyphenHyphen => .subtract,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };

      _instrs.addAll([
        BinaryInstr(operator, src, ConstantValue('1'), src),
        CopyInstr(src, dst),
      ]);
    } else {
      final UnaryOperator operator = switch(unary.operator.kind) {
        .hyphen => .negate,
        .tilde => .complement,
        .bang => .not,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };
      _instrs.add(UnaryInstr(operator, src, dst));
    }

    return dst;
  }

  @override
  Value visitPostfixUnaryExpr(PostfixUnaryExpr unary) {
    final src = unary.operand.accept(this);
    final dst = _makeTempVariable();

    if (<TokenKind>[.plusPlus, .hyphenHyphen].contains(unary.operator.kind)) {
      final BinaryOperator operator = switch(unary.operator.kind) {
        .plusPlus => .add,
        .hyphenHyphen => .subtract,
        _ => throw UnimplementedError("Can't convert ${unary.operator.kind} to unary operator."),
      };
      _instrs.addAll([
        CopyInstr(src, dst),
        BinaryInstr(operator, src, ConstantValue('1'), src),
      ]);
    } else {
      
    }

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
    final result = assignmentExpr.rhs.accept(this);
    final dst = assignmentExpr.lhs.accept(this);
    
    if (assignmentExpr.operator.kind == .equal) {
      _instrs.add(CopyInstr(result, dst));
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

      _instrs.addAll([
        BinaryInstr(operator, dst, result, dst),
      ]);
    }

    return dst;
  }
  
  @override
  visitDeclBlockItem(DeclBlockItem declBlockItem) => declBlockItem.decl.accept(this);
  
  @override
  visitExpressionStmt(ExpressionStmt expressionStmt) => expressionStmt.expr.accept(this);
  
  @override
  visitNullStmt(NullStmt nullStmt) {}
  
  @override
  visitStmtBlockItem(StmtBlockItem stmtBlockItem) => stmtBlockItem.stmt.accept(this);
  
  @override
  Value visitVarExpr(VarExpr varExpr) => VariableValue(varExpr.identifier.lexeme);
  
  @override
  visitVariableDecl(VariableDecl variableDecl) {
    if (variableDecl.init != null) {
      final init = variableDecl.init!.accept(this);
      _instrs.add(CopyInstr(init, VariableValue(variableDecl.name.lexeme)));
    }
  }
  
  @override
  visitIfStmt(IfStmt ifStmt) {
    final cond = ifStmt.cond.accept(this);
    final String ifEndLabel = (ifStmt.else$ != null) ? _makeLabel("else") : _makeLabel("end");
    final String? elseEndLabel = (ifStmt.else$ != null) ? _makeLabel("end"): null;

    _instrs.add(JumpIfZeroInstr(cond, ifEndLabel));
    ifStmt.then.accept(this);
    if (elseEndLabel != null) {
      _instrs.add(JumpInstr(elseEndLabel));
    }
    _instrs.add(LabelInstr(ifEndLabel));
    if (elseEndLabel != null) {
      ifStmt.else$?.accept(this);
      _instrs.add(LabelInstr(elseEndLabel));
    }
  }
  
  @override
  Value visitConditionalExpr(ConditionalExpr conditionalExpr) {
    final cond = conditionalExpr.cond.accept(this);
    final dst = _makeTempVariable();
  
    final endLabel = _makeLabel("end");
    final elseLabel = _makeLabel("else");


    _instrs.add(JumpIfZeroInstr(cond, elseLabel));
    _instrs.addAll([
      CopyInstr(conditionalExpr.lhs.accept(this), dst),
      JumpInstr(endLabel),
      LabelInstr(elseLabel),
    ]);
    _instrs.addAll([
      CopyInstr(conditionalExpr.rhs.accept(this), dst),
      LabelInstr(endLabel),
    ]);
  
    return dst;
  }
}