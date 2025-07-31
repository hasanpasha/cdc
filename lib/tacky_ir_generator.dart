
import 'package:cdc/ast.dart';
import 'package:cdc/tacky_ir.dart';
import 'package:cdc/token.dart';

class TackyIRGenerator implements 
  ProgramAstVisitor<ProgramTir>,
  DeclVisitor<(FunctionTir?, List<Instr>)>,
  BlockVisitor<List<Instr>>,
  StmtVisitor<List<Instr>>,
  ForInitVisitor<List<Instr>>,
  ExprVisitor<(Value, List<Instr>)>,
  BlockItemVisitor<List<Instr>> {
  
  int _tmpCount = 0;
  int _labelCount = 0;
  

  TackyIRGenerator();

  static ProgramTir generate(ProgramAst program) => program.accept(TackyIRGenerator());
  
  @override
  ProgramTir visitProgramAst(ProgramAst program) => ProgramTir(program.functions
      .map((func) => func.accept(this)
        .$1
        ?..instructions.add(ReturnInstr(ConstantValue('0')))
      )
      .nonNulls
      .toList()
    );

  @override
  (FunctionTir?, List<Instr>) visitFunctionDecl(FunctionDecl function) => 
    (function.body != null 
      ? FunctionTir(
        function.name.lexeme, 
        function.params.map((param) => param.lexeme).toList(), 
        function.body!.accept(this)
      ) 
      : null,
    []);

  @override
  List<Instr> visitBlock(Block block) => 
    block.items.map((item) => item.accept(this)).expand((e) => e).toList();

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
    final name = "tacky.$prefix${_labelCount++}";
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
    declBlockItem.decl.accept(this).$2;
  
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
  (FunctionTir?, List<Instr>) visitVariableDecl(VariableDecl variableDecl) => 
    (null, variableDecl.init?.accept(this)
      .map((value) => CopyInstr(value, VariableValue(variableDecl.name.lexeme))) ?? []);
  
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
  
  @override
  List<Instr> visitCompoundStmt(CompoundStmt compoundStmt) => 
    compoundStmt.block.accept(this);
    
  String breakLabel(String suffix) => "break_$suffix";
  String continueLabel(String suffix) => "continue_$suffix";

  @override
  List<Instr> visitBreakStmt(BreakStmt breakStmt) => [JumpInstr(breakLabel(breakStmt.label))];

  @override
  List<Instr> visitContinueStmt(ContinueStmt continueStmt) => [JumpInstr(continueLabel(continueStmt.label))];

  @override
  List<Instr> visitDoWhileStmt(DoWhileStmt doWhileStmt) => [
    LabelInstr("start_${doWhileStmt.label}"),
    ...doWhileStmt.body.accept(this),
    LabelInstr(continueLabel(doWhileStmt.label)),
    ...doWhileStmt.cond.accept(this)
      .map((value) => JumpIfNotZeroInstr(value, "start_${doWhileStmt.label}")),
    LabelInstr(breakLabel(doWhileStmt.label)),
  ];

  @override
  List<Instr> visitWhileStmt(WhileStmt whileStmt) => [
    LabelInstr(continueLabel(whileStmt.label)),
    ...whileStmt.cond.accept(this)
      .map((value) => JumpIfZeroInstr(value, breakLabel(whileStmt.label))),
    ...whileStmt.body.accept(this),
    JumpInstr(continueLabel(whileStmt.label)),
    LabelInstr(breakLabel(whileStmt.label)),
  ];

  @override
  List<Instr> visitForStmt(ForStmt forStmt) => [
    ...forStmt.init.accept(this),
    LabelInstr("start_${forStmt.label}"),
    ...forStmt.cond?.accept(this)
      .map((value) => JumpIfZeroInstr(value, breakLabel(forStmt.label))) ?? [],
    ...forStmt.body.accept(this),
    LabelInstr(continueLabel(forStmt.label)),
    ...forStmt.post?.accept(this).$2 ?? [],
    JumpInstr("start_${forStmt.label}"),
    LabelInstr(breakLabel(forStmt.label))
  ];

  @override
  List<Instr> visitInitDeclForInit(InitDeclForInit initDeclForInit) => 
    initDeclForInit.decl.accept(this).$2;

  @override
  List<Instr> visitInitExpForInit(InitExpForInit initExpForInit) => initExpForInit.expr?.accept(this).$2 ?? [];
  
  @override
  List<Instr> visitCaseStmt(CaseStmt caseStmt) => [
    LabelInstr(caseStmt.label),
    ...caseStmt.stmt?.accept(this) ?? [],
  ];
  
  @override
  List<Instr> visitDefaultStmt(DefaultStmt defaultStmt) => [
    LabelInstr(defaultStmt.label),
    ...defaultStmt.stmt?.accept(this) ?? [],
  ];
  
  @override
  List<Instr> visitSwitchStmt(SwitchStmt switchStmt) {
    final (switchValue, switchValueInstrs) = switchStmt.expr.accept(this);
    final tmp = _makeTempVariable();

    return [
      ...switchValueInstrs,
      ...switchStmt.cases.map((case$) => [
        case$.expr.accept(this)
          .mapInstrs((value) => [BinaryInstr(.equal, switchValue, value, tmp), JumpIfNotZeroInstr(tmp, case$.label)]),
      ]).expand((e) => e).expand((e) => e),
      if (switchStmt.defaultCase != null) JumpInstr(switchStmt.defaultCase!.label),
      JumpInstr(breakLabel(switchStmt.label)),
      ...switchStmt.body.accept(this),
      LabelInstr(breakLabel(switchStmt.label))
    ];
  }
  
  @override
  (Value, List<Instr>) visitFunctionCallExpr(FunctionCallExpr functionCallExpr) {
    final dst = _makeTempVariable();

    final args = functionCallExpr.args?.map((arg) => arg.accept(this)).toList() ?? [];
    return (dst, [
      ...args.map((arg) => arg.$2).expand((e) => e),
      FunCallInstr(functionCallExpr.identifier.lexeme, args.map((arg) => arg.$1).toList(), dst)
    ]);
  }
}

extension on ((Value, List<Instr>), (Value, List<Instr>)) {
  List<Instr> mapTwo(BinaryInstr Function(Value lhsValue, Value rhsValue) mapper) => 
    [...$1.$2, ...$2.$2, mapper($1.$1, $2.$1)];
}

extension on (Value, List<Instr>) {
  List<Instr> map(Instr Function(Value value) mapper) => [...$2, mapper($1)];
  Instr mapValue(Instr Function(Value value) mapper) => mapper($1);
  List<Instr> mapInstrs(List<Instr> Function(Value value) mapper) => [...$2, ...mapper($1)];
}