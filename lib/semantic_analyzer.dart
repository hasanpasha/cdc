
import 'package:cdc/cdc.dart';
import 'package:equatable/equatable.dart';

ProgramAst analyze(ProgramAst programAst) {
  ProgramAst newProgram = programAst;

  int counter = 0;
  (counter, newProgram) = LabelsResolver.transform(newProgram, counter);
  (counter, newProgram) = LoopAndSwitchLabeling.transform(newProgram, counter);

  TypeChecker.check(newProgram);

  return newProgram;
}

typedef Issues = List<(Location, String)>;

enum LabelsResolverStage { labeledStmt, goto }

class LabelsResolver implements 
  ProgramAstVisitor<(Issues, (int, ProgramAst))>,
  DeclVisitor<Decl>,
  BlockVisitor<Block>,
  BlockItemVisitor<BlockItem>,
  StmtVisitor<Stmt>,
  ForInitVisitor<ForInit>
{
  Map<String, String> _labels = {};
  LabelsResolverStage _stage = .labeledStmt;
  final Issues _issues = [];
  int _counter = 0;
  
  LabelsResolver(int counter): _counter = counter;

  static (int, ProgramAst) transform(ProgramAst program, int counter) {
    final (issues, (result)) = program.accept(LabelsResolver(counter));
    if (issues.isNotEmpty) {
      throw MultiIssues(issues);
    }
    return result;
  }

  String _makeLabel(String lexeme) => "$lexeme${_counter++}";

  @override
  (Issues, (int, ProgramAst)) visitProgramAst(ProgramAst program) => 
    (_issues, (_counter, ProgramAst(program.functions.map((function) => function.accept(this)).toList() )));

  @override
  FunctionDecl visitFunctionDecl(FunctionDecl function) {
    final prevLabels = _labels;

    try {
      _labels = {};
      _stage = .labeledStmt;
      Block? newBody = function.body?.accept(this);
      _stage = .goto;
      newBody = newBody?.accept(this);

      return FunctionDecl(function.name, function.params, newBody);
    } finally {
      _labels = prevLabels;
    }
  }

  @override
  VariableDecl visitVariableDecl(VariableDecl variableDecl) => variableDecl;

  @override
  Block visitBlock(Block block) => Block(block.items.map((item) => item.accept(this)).toList());

  @override
  BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => 
    DeclBlockItem(declBlockItem.decl.accept(this));

  @override
  Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => expressionStmt;

  @override
  Stmt visitGotoStmt(GotoStmt gotoStmt) {
    if (_stage != .goto) return gotoStmt;

    if (!_labels.containsKey(gotoStmt.dest.lexeme)) {
      _issues.add((gotoStmt.dest.location, "label \"${gotoStmt.dest.lexeme}\" was referenced but not defined"));
      return gotoStmt;
    }
    
    return GotoStmt(gotoStmt.dest.copyWith(lexeme: _labels[gotoStmt.dest.lexeme]));
  }

  @override
  Stmt visitIfStmt(IfStmt ifStmt) => 
    IfStmt(ifStmt.cond, ifStmt.then.accept(this), ifStmt.else$?.accept(this));

  @override
  Stmt visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) {
    if (_stage != .labeledStmt) return LabeledStmtStmt(labeledStmtStmt.label, labeledStmtStmt.stmt.accept(this));
    
    if (_labels.containsKey(labeledStmtStmt.label.lexeme)) {
      _issues.add((labeledStmtStmt.label.location, "duplicate label \"${labeledStmtStmt.label.lexeme}\""));
      return LabeledStmtStmt(labeledStmtStmt.label, labeledStmtStmt.stmt.accept(this));
    }

    final uniqueLabel = _makeLabel(labeledStmtStmt.label.lexeme);
    _labels[labeledStmtStmt.label.lexeme] = uniqueLabel;

    return LabeledStmtStmt(
      labeledStmtStmt.label.copyWith(lexeme: uniqueLabel),
      labeledStmtStmt.stmt.accept(this),
    );
  }

  @override
  Stmt visitNullStmt(NullStmt nullStmt) => nullStmt;

  @override
  Stmt visitReturnStmt(ReturnStmt returnStmt) => returnStmt;

  @override
  BlockItem visitStmtBlockItem(StmtBlockItem stmtBlockItem) => 
    StmtBlockItem(stmtBlockItem.stmt.accept(this));
    
  @override
  Stmt visitCompoundStmt(CompoundStmt compoundStmt) => 
    CompoundStmt(compoundStmt.block.accept(this));
    
  @override
  Stmt visitBreakStmt(BreakStmt breakStmt) => breakStmt;

  @override
  Stmt visitContinueStmt(ContinueStmt continueStmt) => continueStmt;

  @override
  Stmt visitDoWhileStmt(DoWhileStmt doWhileStmt) => 
    DoWhileStmt(doWhileStmt.body.accept(this), doWhileStmt.cond, doWhileStmt.label);

  @override
  Stmt visitForStmt(ForStmt forStmt) => 
    ForStmt(forStmt.init.accept(this), forStmt.cond, forStmt.post, forStmt.body.accept(this), forStmt.label);

  @override
  Stmt visitWhileStmt(WhileStmt whileStmt) => WhileStmt(whileStmt.cond, whileStmt.body.accept(this), whileStmt.label);
  
  @override
  ForInit visitInitDeclForInit(InitDeclForInit initDeclForInit) => initDeclForInit;
  
  @override
  ForInit visitInitExpForInit(InitExpForInit initExpForInit) => initExpForInit;
  
  @override
  Stmt visitCaseStmt(CaseStmt caseStmt) => CaseStmt(caseStmt.expr, caseStmt.stmt?.accept(this), caseStmt.token, caseStmt.label);
  
  @override
  Stmt visitDefaultStmt(DefaultStmt defaultStmt) => DefaultStmt(defaultStmt.stmt?.accept(this), defaultStmt.token, defaultStmt.label);
  
  @override
  Stmt visitSwitchStmt(SwitchStmt switchStmt) => 
    SwitchStmt(switchStmt.expr, switchStmt.body.accept(this), switchStmt.cases, switchStmt.defaultCase, switchStmt.label);
}

class LoopAndSwitchLabeling implements 
  ProgramAstVisitor<(Issues, (int, ProgramAst))>,
  DeclVisitor<Decl>,
  BlockVisitor<Block>,
  BlockItemVisitor<BlockItem>,
  StmtVisitor<Stmt>,
  ForInitVisitor<ForInit>
{
  final Issues _issues = [];
  int _counter = 0;
  var labels = Stack<String>();
  var switchLabels = Stack<String>();
  var cases = Stack<List<CaseStmt>>();
  var defaults = Stack<List<DefaultStmt>>();
  
  LoopAndSwitchLabeling(int counter): _counter = counter;

  static (int, ProgramAst) transform(ProgramAst program, int counter) {
    final (issues, result) = program.accept(LoopAndSwitchLabeling(counter));
    if (issues.isNotEmpty) {
      throw MultiIssues(issues);
    }

    return result;
  }

  String _makeLabel(String lexeme) => "$lexeme${_counter++}";

  @override
  (Issues, (int, ProgramAst)) visitProgramAst(ProgramAst program) => 
    (_issues, (_counter, ProgramAst(program.functions.map((function) => function.accept(this)).toList() )));

  @override
  FunctionDecl visitFunctionDecl(FunctionDecl function) {
    final prevLabels = labels;
    final prevSwitchLabels = switchLabels;
    final prevCases = cases;
    final prevDefaults = defaults;
    try {
      labels = Stack<String>();
      switchLabels = Stack<String>();
      cases = Stack<List<CaseStmt>>();
      defaults = Stack<List<DefaultStmt>>();
      Block? newBody = function.body?.accept(this);
      return FunctionDecl(function.name, function.params, newBody);
    } finally {
      labels = prevLabels; 
      switchLabels = prevSwitchLabels; 
      cases = prevCases; 
      defaults = prevDefaults; 
    }
  }

  @override
  Decl visitVariableDecl(VariableDecl variableDecl) => variableDecl;

  @override
  Block visitBlock(Block block) => Block(block.items.map((item) => item.accept(this)).toList());

  @override
  BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => declBlockItem;

  @override
  Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => expressionStmt;

  @override
  Stmt visitGotoStmt(GotoStmt gotoStmt) => gotoStmt;

  @override
  Stmt visitIfStmt(IfStmt ifStmt) => 
    IfStmt(ifStmt.cond, ifStmt.then.accept(this), ifStmt.else$?.accept(this));

  @override
  Stmt visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) => 
    LabeledStmtStmt(labeledStmtStmt.label, labeledStmtStmt.stmt.accept(this));

  @override
  Stmt visitNullStmt(NullStmt nullStmt) => nullStmt;

  @override
  Stmt visitReturnStmt(ReturnStmt returnStmt) => returnStmt;

  @override
  BlockItem visitStmtBlockItem(StmtBlockItem stmtBlockItem) => 
    StmtBlockItem(stmtBlockItem.stmt.accept(this));   
  
  @override
  Stmt visitCompoundStmt(CompoundStmt compoundStmt) => 
    CompoundStmt(compoundStmt.block.accept(this));
    
  @override
  Stmt visitBreakStmt(BreakStmt breakStmt) {
    if (labels.peek() == null) {
      _issues.add((breakStmt.token.location, "`break` statement must be inside a loop or a switch statement."));
    }

    return BreakStmt(breakStmt.token, labels.peek() ?? "");
  }

  @override
  Stmt visitContinueStmt(ContinueStmt continueStmt) {
    if (labels.peekUntil((label) => !label.startsWith("switch")) == null) {
      _issues.add((continueStmt.token.location, "`continue` statement must be inside a loop statement."));
    }

    return ContinueStmt(continueStmt.token, labels.peekUntil((label) => !label.startsWith("switch")) ?? "");
  }

  @override
  Stmt visitDoWhileStmt(DoWhileStmt doWhileStmt) {
    final label = _makeLabel("do.while");
    try {
      labels.push(label);
      return DoWhileStmt(doWhileStmt.body.accept(this), doWhileStmt.cond, label);
    } finally {
      labels.pop();
    }
  }

  @override
  Stmt visitForStmt(ForStmt forStmt) {
    final label = _makeLabel("for");

    try {
      labels.push(label);
      return ForStmt(
        forStmt.init.accept(this), 
        forStmt.cond, 
        forStmt.post, 
        forStmt.body.accept(this), 
        label
      );
    } finally {
      labels.pop();
    }
  }

  @override
  Stmt visitWhileStmt(WhileStmt whileStmt) {
    final label = _makeLabel("while");
    try {
      labels.push(label);
      return WhileStmt(whileStmt.cond, whileStmt.body.accept(this), label);
    } finally {
      labels.pop();
    }
  }
  
  @override
  ForInit visitInitDeclForInit(InitDeclForInit initDeclForInit) => initDeclForInit;
  
  @override
  ForInit visitInitExpForInit(InitExpForInit initExpForInit) => initExpForInit;
  
  @override
  Stmt visitCaseStmt(CaseStmt caseStmt) {
    if (switchLabels.peek() == null) {
      _issues.add((caseStmt.token.location, "`case` statement must be inside a switch statement."));
      return CaseStmt(caseStmt.expr, caseStmt.stmt?.accept(this), caseStmt.token, caseStmt.label);
    }

    final caseBody = caseStmt.stmt?.accept(this);
    final thisCases = cases.peek()!;
    final caseIdx = thisCases.length; 
    final stmt = CaseStmt(caseStmt.expr, caseBody, caseStmt.token, "case_${caseIdx}_${switchLabels.peek() ?? ""}");
    
    for (CaseStmt case$ in thisCases) {
      if (case$.expr == stmt.expr) {
        _issues.add((stmt.token.location, "case lvalue has already appeared at line ${case$.expr.value.location.line}"));
      }
    }
    
    thisCases.add(stmt);
    return stmt;
  }
  
  @override
  Stmt visitDefaultStmt(DefaultStmt defaultStmt) {
    if (switchLabels.peek() == null) {
      _issues.add((defaultStmt.token.location, "`default` statement must be inside a switch statement."));
      return DefaultStmt(defaultStmt.stmt?.accept(this), defaultStmt.token, defaultStmt.label);
    }

    final defaultBody = defaultStmt.stmt?.accept(this);
    final thisDefaults = defaults.peek()!;
    final defaultIdx = thisDefaults.length; 
    final stmt = DefaultStmt(defaultBody, defaultStmt.token, "default_${defaultIdx}_${switchLabels.peek() ?? ""}");
    thisDefaults.add(stmt);

    if (thisDefaults.length > 1) {
      for (DefaultStmt stmt in thisDefaults.sublist(1)) {
        _issues.add((stmt.token.location, "Only one default statement is allowed per switch statment."));
      }
    }

    return stmt;
  }
  
  @override
  Stmt visitSwitchStmt(SwitchStmt switchStmt) {
    final label = _makeLabel("switch");
    late final Stmt body;
    final List<CaseStmt> thisCases = [];
    final List<DefaultStmt> thisDefaults = [];
    try {
      switchLabels.push(label);
      labels.push(label);
      cases.push(thisCases);
      defaults.push(thisDefaults);
      body = switchStmt.body.accept(this);
    } finally {
      labels.pop();
      switchLabels.pop();
      cases.pop();
      defaults.pop();
    }

    return SwitchStmt(switchStmt.expr, body, thisCases, thisDefaults.firstOrNull, label);
  }
}

abstract class CType with EquatableMixin {
  @override
  bool? get stringify => true;
}

class Int extends CType {
  @override
  List<Object?> get props => [];
}

class Fun extends CType {
  final int paramCount;

  Fun({required this.paramCount});
  
  @override
  List<Object?> get props => [paramCount];
}

class SymbolEntry {
  final CType type;
  final bool defined;

  SymbolEntry({required this.type, this.defined = false});
}

class TypeChecker implements 
  ProgramAstVisitor<Issues>, 
  BlockVisitor, 
  BlockItemVisitor,
  StmtVisitor,
  DeclVisitor, 
  ExprVisitor,
  ForInitVisitor
{
  final Map<String, SymbolEntry> _symbols = {};
  final Issues _issues = [];
  
  static void check(ProgramAst program) {
    final issues = program.accept(TypeChecker());
    
    if (issues.isNotEmpty) {
      throw MultiIssues(issues);
    }
  }
  
  @override
  Issues visitProgramAst(ProgramAst programAst) {
    for (var fun in programAst.functions) {
      fun.accept(this);
    }
    return _issues;
  }
  
  @override
  visitBlock(Block block) {
    for (var item in block.items) {
      item.accept(this);
    }
  }
  
  @override
  visitDeclBlockItem(DeclBlockItem declBlockItem) => declBlockItem.decl.accept(this);
  
  @override
  visitStmtBlockItem(StmtBlockItem stmtBlockItem) => stmtBlockItem.stmt.accept(this);
  
  @override
  visitBreakStmt(BreakStmt breakStmt) {}
  
  @override
  visitCaseStmt(CaseStmt caseStmt) => 
    caseStmt.stmt?.accept(this);
  
  @override
  visitCompoundStmt(CompoundStmt compoundStmt) => 
    compoundStmt.block.accept(this);
  
  @override
  visitContinueStmt(ContinueStmt continueStmt) {}
  
  @override
  visitDefaultStmt(DefaultStmt defaultStmt) => 
    defaultStmt.stmt?.accept(this);
  
  @override
  visitDoWhileStmt(DoWhileStmt doWhileStmt) {
    doWhileStmt.cond.accept(this);
    doWhileStmt.body.accept(this);
  }
  
  @override
  visitExpressionStmt(ExpressionStmt expressionStmt) => 
    expressionStmt.expr.accept(this);
  
  @override
  visitForStmt(ForStmt forStmt) {
    forStmt.init.accept(this);
    forStmt.cond?.accept(this);
    forStmt.post?.accept(this);
    forStmt.body.accept(this);
  }
  
  @override
  visitGotoStmt(GotoStmt gotoStmt) {}
  
  @override
  visitIfStmt(IfStmt ifStmt) {
    ifStmt.cond.accept(this);
    ifStmt.then.accept(this);
    ifStmt.else$?.accept(this);
  }
  
  @override
  visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) => 
    labeledStmtStmt.stmt.accept(this);
  
  @override
  visitNullStmt(NullStmt nullStmt) {}
  
  @override
  visitReturnStmt(ReturnStmt returnStmt) {
    returnStmt.expr.accept(this);
  }
  
  @override
  visitSwitchStmt(SwitchStmt switchStmt) {
    switchStmt.expr.accept(this);
    switchStmt.body.accept(this);
  }
  
  @override
  visitWhileStmt(WhileStmt whileStmt) {
    whileStmt.cond.accept(this);
    whileStmt.body.accept(this);
  }
  
  @override
  visitFunctionDecl(FunctionDecl functionDecl) {
    final funType = Fun(paramCount: functionDecl.params.length);
    final hasBody = functionDecl.body != null;
    bool alreadyDefined = false;

    if (_symbols.containsKey(functionDecl.name.lexeme)) {
      final oldDecl = _symbols[functionDecl.name.lexeme]!;
      if (oldDecl.type != funType) {
        _issues.add((functionDecl.name.location, "Incompatible function declaration."));
      }
      
      alreadyDefined = oldDecl.defined;
      if (alreadyDefined && hasBody) {
        _issues.add((functionDecl.name.location, "Function is defined more than once."));
      }
    }

    _symbols[functionDecl.name.lexeme] = SymbolEntry(type: funType, defined: alreadyDefined || hasBody);

    if (hasBody) {
      for (var param in functionDecl.params) {
        _symbols[param.lexeme] = SymbolEntry(type: Int());
      }

      functionDecl.body?.accept(this);
    }
  }
  
  @override
  visitVariableDecl(VariableDecl variableDecl) {
    _symbols[variableDecl.name.lexeme] = SymbolEntry(type: Int());
    variableDecl.init?.accept(this);
  }
  
  @override
  visitAssignmentExpr(AssignmentExpr assignmentExpr) {
    assignmentExpr.lhs.accept(this);
    assignmentExpr.rhs.accept(this);
  }
  
  @override
  visitBinaryExpr(BinaryExpr binaryExpr) {
    binaryExpr.lhs.accept(this);
    binaryExpr.rhs.accept(this);
  }
  
  @override
  visitConditionalExpr(ConditionalExpr conditionalExpr) {
    conditionalExpr.cond.accept(this);
    conditionalExpr.lhs.accept(this);
    conditionalExpr.rhs.accept(this);
  }
  
  @override
  visitConstantExpr(ConstantExpr constantExpr) {
  }
  
  @override
  visitFunctionCallExpr(FunctionCallExpr functionCallExpr) {
    final decl = _symbols[functionCallExpr.identifier.lexeme]!;
    final funType = decl.type;

    if (funType is Int) {
      _issues.add((functionCallExpr.identifier.location, "Variable used as function name."));
    }

    if (funType is Fun && funType.paramCount != (functionCallExpr.args?.length ?? 0)) {
      _issues.add((functionCallExpr.identifier.location, "Function called with the wrong number of arguments."));
    }

    for (final arg in functionCallExpr.args ?? <Expr>[]) {
      arg.accept(this);
    }

  }
  
  @override
  visitPostfixUnaryExpr(PostfixUnaryExpr postfixUnaryExpr) {
    postfixUnaryExpr.operand.accept(this);
  }
  
  @override
  visitPrefixUnaryExpr(PrefixUnaryExpr prefixUnaryExpr) {
    prefixUnaryExpr.operand.accept(this);
  }
  
  @override
  visitVarExpr(VarExpr varExpr) {
    final type = _symbols[varExpr.identifier.lexeme]!;
    if (type.type is! Int) {
      _issues.add((varExpr.identifier.location, "Function name used as variable"));
    }
  }
  
  @override
  visitInitDeclForInit(InitDeclForInit initDeclForInit) {
    if (initDeclForInit.decl is FunctionDecl) {
      final location = (initDeclForInit.decl as FunctionDecl).name.location;
      _issues.add((location, "Function declarations aren't permitted in for loop headers."));
    }
    
    initDeclForInit.decl.accept(this);
  }
  
  @override
  visitInitExpForInit(InitExpForInit initExpForInit) {
    initExpForInit.expr?.accept(this);
  }
  

}

class Stack<E> {
  final List<E> _inner = [];
  void push(E e) => _inner.add(e);
  E? pop() => _inner.isEmpty ? null : _inner.removeLast();
  E? peek() => _inner.isEmpty ? null : _inner.last;
  E? peekUntil(bool Function(E p0) peeker) {
    for (var element in _inner.reversed) {
      if (peeker(element)) return element;
    }
    return null;
  }
  
}