
import 'package:cdc/cdc.dart';

ProgramAst analyze(ProgramAst programAst) {
  ProgramAst newProgram;

  newProgram = LabelsResolver.transform(programAst);

  return newProgram;
}

enum LabelsResolverStage { labeledStmt, goto }

class LabelsResolver implements ProgramAstVisitor<(List<(Location, String)>, ProgramAst)>, FunctionAstVisitor<FunctionAst>, BlockVisitor<Block>, BlockItemVisitor<BlockItem>, StmtVisitor<Stmt> {
  final Map<String, String> labels = {};
  LabelsResolverStage _stage = .labeledStmt;
  final List<(Location, String)> _issues = [];
  int _counter = 0;
  

  static ProgramAst transform(ProgramAst program) {
    final (issues, newProgram) = program.accept(LabelsResolver());
    if (issues.isNotEmpty) {
      throw MultiIssues(issues);
    }
    return newProgram;
  }

  @override
  (List<(Location, String)>, ProgramAst) visitProgramAst(ProgramAst program) => 
    (_issues, ProgramAst(program.main.accept(this)));

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
    
  String _makeLabel(String lexeme) => ".L$lexeme${_counter++}";
  
  @override
  Stmt visitCompoundStmt(CompoundStmt compoundStmt) => 
    CompoundStmt(compoundStmt.block.accept(this));
}
