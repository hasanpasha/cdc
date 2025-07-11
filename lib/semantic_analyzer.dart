
import 'package:cdc/cdc.dart';

ProgramAst analyze(ProgramAst programAst) {
  ProgramAst newProgram;

  int counter = 0;
  (counter, newProgram) = LabelsResolver.transform(programAst, counter);
  (counter, newProgram) = LoopAndSwitchLabeling.transform(programAst, counter);

  return newProgram;
}

typedef Issues = List<(Location, String)>;

enum LabelsResolverStage { labeledStmt, goto }

class LabelsResolver implements 
  ProgramAstVisitor<(Issues, (int, ProgramAst))>,
  FunctionAstVisitor<FunctionAst>,
  BlockVisitor<Block>,
  BlockItemVisitor<BlockItem>,
  StmtVisitor<Stmt>,
  ForInitVisitor<ForInit>
{
  final Map<String, String> labels = {};
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
    (_issues, (_counter, ProgramAst(program.main.accept(this))));

  @override
  FunctionAst visitFunctionAst(FunctionAst function) {
    _stage = .labeledStmt;
    Block newBody = function.body.accept(this);
    _stage = .goto;
    newBody = newBody.accept(this);

    return FunctionAst(function.name, newBody);
  }

  @override
  Block visitBlock(Block block) => Block(block.items.map((item) => item.accept(this)).toList());

  @override
  BlockItem visitDeclBlockItem(DeclBlockItem declBlockItem) => declBlockItem;

  @override
  Stmt visitExpressionStmt(ExpressionStmt expressionStmt) => expressionStmt;

  @override
  Stmt visitGotoStmt(GotoStmt gotoStmt) {
    if (_stage != .goto) return gotoStmt;
    
    if (!labels.containsKey(gotoStmt.dest.lexeme)) {
      _issues.add((gotoStmt.dest.location, "label \"${gotoStmt.dest.lexeme}\" was referenced but not defined"));
      return gotoStmt;
    }
    
    return GotoStmt(gotoStmt.dest.copyWith(lexeme: labels[gotoStmt.dest.lexeme]));
  }

  @override
  Stmt visitIfStmt(IfStmt ifStmt) => 
    IfStmt(ifStmt.cond, ifStmt.then.accept(this), ifStmt.else$?.accept(this));

  @override
  Stmt visitLabeledStmtStmt(LabeledStmtStmt labeledStmtStmt) {
    if (_stage != .labeledStmt) return labeledStmtStmt;
    
    if (labels.containsKey(labeledStmtStmt.label.lexeme)) {
      _issues.add((labeledStmtStmt.label.location, "duplicate label \"${labeledStmtStmt.label.lexeme}\""));
      return LabeledStmtStmt(labeledStmtStmt.label, labeledStmtStmt.stmt.accept(this));
    }

    final uniqueLabel = _makeLabel(labeledStmtStmt.label.lexeme);
    labels[labeledStmtStmt.label.lexeme] = uniqueLabel;

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
  FunctionAstVisitor<FunctionAst>,
  BlockVisitor<Block>,
  BlockItemVisitor<BlockItem>,
  StmtVisitor<Stmt>,
  ForInitVisitor<ForInit>
{
  final Issues _issues = [];
  int _counter = 0;
  final labels = Stack<String>();
  final switchLabels = Stack<String>();
  final cases = Stack<List<CaseStmt>>();
  final defaults = Stack<List<DefaultStmt>>();
  
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
    (_issues, (_counter, ProgramAst(program.main.accept(this))));

  @override
  FunctionAst visitFunctionAst(FunctionAst function) {
    Block newBody = function.body.accept(this);
    return FunctionAst(function.name, newBody);
  }

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