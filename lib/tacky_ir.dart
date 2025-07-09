import 'package:equatable/equatable.dart';

part 'tacky_ir.g.dart';

enum UnaryOperator {
  negate,
  complement,
  not,
}

enum BinaryOperator {
  add,
  subtract,
  multiply,
  divide,
  remainder,
  band,
  bor,
  xor,
  shl,
  shr,
  equal,
  notEqual,
  less,
  lessEqual,
  greater,
  greaterEqual,
}
