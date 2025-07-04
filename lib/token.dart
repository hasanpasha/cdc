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
  eoi,
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

class Token {
  final TokenKind kind;
  final String lexeme;
  final Location location;

  const Token(this.kind, this.lexeme, this.location);

  @override
  String toString() => "$location: $kind $lexeme";
}