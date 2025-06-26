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
      if (tok.kind == TokenKind.eoi) break;
    }
  }
  
  
  Token _lexNext() {
    _skipWhitespace();
    if (_isAtEnd) return _token(TokenKind.eoi);

    _start = _current;
    final char = _advance();

    if (_isAlpha(char)) {
      return _keywordOrIdentifier();
    } else if (_isDigit(char)) {
      return _number();
    } else {
      switch (char) {
        case '(': return _token(TokenKind.leftParen);
        case ')': return _token(TokenKind.rightParen);
        case '{': return _token(TokenKind.leftBraces);
        case '}': return _token(TokenKind.rightBraces);
        case ';': return _token(TokenKind.semicolon);
        case '~': return _token(TokenKind.tilde);
        case '-': return _token(TokenKind.hyphen);
        case '+': return _token(TokenKind.plus);
        case '*': return _token(TokenKind.asterisk);
        case '/': return _token(TokenKind.forwardSlash);
        case '%': return _token(TokenKind.percent);
        default: 
          throw Exception("unknown char: $char.");
      }
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
    final needleLen = needle.length;
    if (_current+needleLen >= _sourceCode.length) return false;
    return (_sourceCode.substring(_current, _current+needleLen) == needle);
  }
  
  bool _match(String needle) {
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
    while (!_isAtEnd && _isAlphaNumeric(_peek())) {
      _advance();
    }
    
    return switch (_currentLexeme()) {
      "int" => _token(TokenKind.int),
      "void" => _token(TokenKind.void$),
      "return" => _token(TokenKind.return$),
      String() => _token(TokenKind.identifier),
    };
  }
  
  Token _number() {
    while (!_isAtEnd && _isDigit(_peek())) {
      _advance();
    }
    if (_isAlpha(_peek())) {
      throw Exception("Found alpha characters attached to number.");
    }
    return _token(TokenKind.constant);
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