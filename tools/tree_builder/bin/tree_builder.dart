import 'dart:convert';
import 'dart:io';
import 'package:change_case/change_case.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

typedef Scheme = Map<String, Map<String, Map<String, String>>>;

class Grammer {
  final String name;
  final List<Directive> directives;
  final Scheme scheme;
  final String? outputPath;

  Grammer({
    required this.name,
    required this.directives,
    required this.scheme,
    required this.outputPath,
  });

  factory Grammer.fromJson(Map<String, dynamic> json) {
    return Grammer(
      name: json['name'],
      outputPath: json['output'],
      directives: (json['directives'] as List)
          .map(
            (d) => switch (d["kind"]!) {
              "partof" => Directive.partOf(d["value"]),
              Object() => throw Exception("unknown kind"),
              null => throw Exception("no `kind` field"),
            },
          )
          .toList(),
      scheme: (json['scheme'] as Map<String, dynamic>).map(
        (nodeKind, variants) => MapEntry(
          nodeKind,
          (variants as Map<String, dynamic>).map(
            (variantName, fields) => MapEntry(
              variantName,
              (fields as Map<String, dynamic>).map(
                (fieldName, fieldType) =>
                    MapEntry(fieldName, fieldType as String),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main(List<String> args) async {
  if (args.isEmpty) {
    print("ast_generator <FILE> [OUTPUT]");
    exit(0);
  }

  final file = args[0];
  final output = args.elementAtOrNull(1);
  try {
    final str = await File(file).readAsString();
    final json = jsonDecode(str);

    if (json is List) {
      json.map((e) => Grammer.fromJson(e)).forEach((grammer) {
        generate(
          grammer.scheme,
          grammer.outputPath ?? "$output/${grammer.name}.dart",
          directives: grammer.directives,
        );
      });
    } else {
      final grammer = Grammer.fromJson(json);
      generate(
        grammer.scheme,
        grammer.outputPath ?? output ?? "${grammer.name}.dart",
        directives: grammer.directives,
      );
    }
  } catch (e) {
    print("failed to compile `$file`: $e");
  }
}

void generate(
  Scheme grammar,
  String outputPath, {
  List<Directive>? directives,
}) {
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