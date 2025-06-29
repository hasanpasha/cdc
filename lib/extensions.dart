
import 'package:cdc/cdc.dart';

enum Arch { x86_64 }

extension AsmGenerate on ProgramIR {
  ProgramASM generateAsm(Arch arch) {
    final AsmGenerator generator = switch (arch) {
      Arch.x86_64 => X8664Generator(),
    };

    return generator.generate(this);
  }
}
