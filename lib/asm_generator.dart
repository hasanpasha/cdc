
import 'package:cdc/cdc.dart';

abstract class AsmGenerator {
  ProgramASM generate(ProgramIR program);
}