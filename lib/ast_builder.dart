import 'dart:io';
import 'package:change_case/change_case.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

typedef Grammar = Map<String, Map<String, Map<String, String>>>;

void main() {
  generate({
    'Stmt': {
      'Return': {'keyword': 'Token', 'expr': 'Expr'},
    },
    'Expr': {
      'Constant': {'value': 'String'},
      'Unary': {'operator': 'Token', 'operand': 'Expr'},
      'Binary': {'operator': 'Token', 'lhs': 'Expr', 'rhs': 'Expr'},
    },
  }, "ast.g.dart", directives: [Directive.partOf('ast.dart')]);

  generate({
    'Instr': {
      'Return': {'value': 'Value'},
      'Unary': {'operator': 'UnaryOperator', 'src': 'Value', 'dst': 'Value'},
      'Binary': {'operator': 'BinaryOperator', 'lhs': 'Value', 'rhs': 'Value', 'dst': 'Value'},
    },
    'Value': {
      'Constant': {'value': 'String'},
      'Variable': {'name': 'String'},
    },
  }, "tacky_ir.g.dart", directives: [Directive.partOf('tacky_ir.dart')]);
}

void generate(Grammar grammar, String outputPath, {List<Directive>? directives}) {
  final library = LibraryBuilder();
  final emitter = DartEmitter();

  if (directives != null) {
    library.directives.addAll(directives);
  }
  
  for (final baseEntry in grammar.entries) {
    final baseName = baseEntry.key;
    final subclasses = baseEntry.value;
  
    // Abstract base class
    library.body.add(Class((b) => b
      ..name = baseName
      ..abstract = true
      ..methods.add(Method((m) => m
        ..name = 'accept'
        ..returns = refer('R')
        ..types.add(refer('R'))
        ..requiredParameters.add(Parameter((p) => p
          ..name = 'visitor'
          ..type = refer('${baseName}Visitor<R>')))
        ..body = Code('throw UnimplementedError();')))));
  
    // Visitor Interface
    library.body.add(Class((b) => b
      ..name = '${baseName}Visitor'
      ..types.add(refer('R'))
      ..abstract = true
      ..methods.addAll(subclasses.entries.map((entry) {
        final className = '${entry.key}$baseName';
        return Method((m) => m
          ..name = 'visit$className'
          ..returns = refer('R')
          ..requiredParameters.add(Parameter((p) => p
            ..name = className.toCamelCase()
            ..type = refer(className))));
      }))));
  
    // Subclasses with fields + accept method
    for (final subclass in subclasses.entries) {
      final className = '${subclass.key}$baseName';
      final fields = subclass.value;
  
      library.body.add(Class((c) => c
        ..name = className
        ..extend = refer(baseName)
        ..fields.addAll(fields.entries.map((entry) => Field((f) => f
          ..name = entry.key
          ..type = refer(entry.value)
          ..modifier = FieldModifier.final$)))
        ..constructors.add(Constructor((ctor) => ctor
          ..requiredParameters.addAll(fields.entries.map((entry) => Parameter((p) => p
            ..name = entry.key
            ..toThis = true)))))
        ..methods.add(Method((m) => m
          ..name = 'accept'
          ..annotations.add(CodeExpression(Code('override')))
          ..returns = refer('R')
          ..types.add(refer('R'))
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'visitor'
            ..type = refer('${baseName}Visitor<R>')))
          ..body = Code('return visitor.visit$className(this);')))));
    }
  }
  
  final raw = library.build().accept(emitter).toString();
  final formatted = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion).format(raw);
  File(outputPath).writeAsStringSync(formatted);
  print('generated AST was written to "$outputPath"');
}