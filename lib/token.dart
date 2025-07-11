import 'package:equatable/equatable.dart';

enum TokenKind {
  identifier,
  constant,
  int,
  void$,
  return$,
  leftParen,
  rightParen,
  leftBraces,
  rightBraces,
  semicolon,
  tilde,
  hyphen,
  hyphenHyphen,
  plus,
  plusPlus,
  asterisk,
  forwardSlash,
  percent,
  and,
  andAnd,
  or,
  orOr,
  xor,
  less,
  lessLess,
  greater,
  greaterGreater,
  equal,
  equalEqual,
  bang,
  bangEqual,
  lessEqual,
  greaterEqual,
  plusEqual,
  hyphenEqual,
  starEqual,
  forwardSlashEqual,
  percentEqual,
  andEqual,
  orEqual,
  xorEqual,
  lessLessEqual,
  greaterGreaterEqual,
  if$,
  else$,
  questionMark,
  colon,
  goto,
  do$,
  while$,
  for$,
  break$,
  continue$,
  switch$,
  case$,
  default$,
  eoi,
  error,
}

class Location {
  int line = 1;
  int column = 1;
  final String? filename;

  Location(this.line, this.column, [this.filename]);
  
  void advanceLine() => line++;
  void advanceColumn() => column++;
  void resetColumn() => column = 1;
  
  Location copyWith({int? line, int? column, String? filename}) {
    return Location(line ?? this.line, column ?? this.column, filename ?? this.filename);
  }

  @override
  String toString() => "${filename != null ? "${filename!}:" : ''}$line:$column";
}

class Token extends Equatable {
  final TokenKind kind;
  final String lexeme;
  final Location location;

  const Token(this.kind, this.lexeme, this.location);

  Token copyWith({TokenKind? kind, String? lexeme, Location? location}) => 
    Token(kind ?? this.kind, lexeme ?? this.lexeme, location ?? this.location);
    
  @override
  List<Object> get props => [kind, lexeme];

  @override
  bool get stringify => true;
}

class ErrorToken extends Token {
  final String message;

  ErrorToken(Location location, String lexeme, this.message) : super(.error, lexeme, location);
}
