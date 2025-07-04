import 'token.dart';

class Lexer extends Iterable<Token> {
  final String _sourceCode;
  final List<Token> _tokens = [];
  final Location _location;
  int _start = 0;
  int _current = 0;

  static List<Token> lex(String source, [String? filepath]) {
    final lexer = Lexer(source, filepath);
    return lexer.toList();
  }

  Lexer(this._sourceCode, [String? filepath]) : 
    _location = Location(1, 1, filepath) {
    _lex();
  }

  @override
  Iterator<Token> get iterator => _tokens.iterator;
  
  bool get _isAtEnd => _current >= _sourceCode.length;
  
  void _lex() {
    while(true) {
      final tok = _lexNext();
      _tokens.add(tok);
      if (tok.kind == .eoi) break;
    }
  }
  
  
  Token _lexNext() {
    _skipWhitespace();
    if (_isAtEnd) return _token(.eoi);

    _start = _current;
    final char = _advance();

    if (_isAlpha(char)) {
      return _keywordOrIdentifier();
    } else if (_isDigit(char)) {
      return _number();
    } else {
      return _token(switch (char) {
        '(' => .leftParen,
        ')' => .rightParen,
        '{' => .leftBraces,
        '}' => .rightBraces,
        ';' => .semicolon,
        '~' => .tilde,
        '-' => _match(char) ? .hyphenHyphen : .hyphen,
        '+' => _match(char) ? .plusPlus : .plus,
        '*' => .asterisk,
        '/' => .forwardSlash,
        '%' => .percent,
        '&' => _match(char) ? .andAnd : .and,
        '|' => _match(char) ? .orOr : .or,
        '^' => .xor,
        '<' => _match(char) ? .lessLess : _match('=') ? .lessEqual : .less,
        '>' => _match(char) ? .greaterGreater : _match('=') ? .greaterEqual : .greater,
        '=' => _match(char) ? .equalEqual : .equal,
        '!' => _match('=') ? .bangEqual : .bang,
        String() => throw Exception("unknown char: $char."),
      });
    }

  }
  
  String _advance() {
    if (_isAtEnd) return '';
    String next = _peek();
    _current++;

    if (next == '\n') {
      _location.advanceLine();
      _location.resetColumn();
    } else {
      _location.advanceColumn();
    }

    return next;
  }
  
  String _peek() => _sourceCode[_current];
  
  void _skipWhitespace() {
    while (!_isAtEnd && _isWhitespace(_peek())) {
      _advance();
    }
    _skipComments();
  }
  
  void _skipComments() {
    if (!_isAtEnd && _matchString("//")) {
      while (!_isAtEnd && _match('\n')) {
        _advance();
      }
      _skipWhitespace();
    }

    if (!_isAtEnd && _matchString("/*")) {
      while (!_isAtEnd && _match('*/')) {
        _advance();
      }
      _skipWhitespace();
    }
  }
  
  bool _matchString(String needle) {
    if (_isAtEnd) return false;
    final needleLen = needle.length;
    if (_current+needleLen >= _sourceCode.length) return false;
    return (_sourceCode.substring(_current, _current+needleLen) == needle);
  }
  
  bool _match(String needle) {
    if (_isAtEnd) return false;
    assert (needle.length == 1);
    if (needle == _peek()) {
      _advance();
      return true;
    }
    return false;
  }
  
  Token _token(TokenKind kind) {
    final String lexeme = _currentLexeme();
    final Location location = _currentLexemeLocation();
    return Token(kind, lexeme, location);
  }
  
  String _currentLexeme() {
    return _sourceCode.substring(_start, _current);
  }
  
  Location _currentLexemeLocation() {
    return _location.copyWith(column: _location.column-(_current-_start));
  }
  
  Token _keywordOrIdentifier() {
    while (!_isAtEnd && (_isAlphaNumeric(_peek()) || _peek() == '_')) {
      _advance();
    }
    
    return switch (_currentLexeme()) {
      "int" => _token(.int),
      "void" => _token(.void$),
      "return" => _token(.return$),
      String() => _token(.identifier),
    };
  }
  
  Token _number() {
    while (!_isAtEnd && _isDigit(_peek())) {
      _advance();
    }
    if (_isAlpha(_peek())) {
      throw Exception("Found alpha characters attached to number.");
    }
    return _token(.constant);
  }

  static const _alphas = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
  static const _digits =  "0123456789";
  
  bool _isAlpha(String char) => _alphas.contains(char);
  bool _isDigit(String char) => _digits.contains(char);
  bool _isAlphaNumeric(String char) => _isAlpha(char) || _isDigit(char);
  bool _isWhitespace(String char) => " \t\n\r".contains(char);
}

extension LexerExtension on String {
  List<Token> lex([String? filepath]) => Lexer.lex(this, filepath);
}