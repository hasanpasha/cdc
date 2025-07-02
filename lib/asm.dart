abstract class ProgramASM {
  String emit();
  Future<void> compile(Uri output, {bool preserveAsmFile = false});
}