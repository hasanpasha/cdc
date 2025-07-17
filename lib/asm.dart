abstract class ProgramASM {
  String emit({bool pic = true});
  Future<void> compile(Uri output, {bool preserveAsmFile = false});
}
