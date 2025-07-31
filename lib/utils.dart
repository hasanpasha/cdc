import 'dart:io';

Future<int> command(Uri binUri, List<String> args, {bool verbose = false}) async {
  final binPath = binUri.hasAbsolutePath ? binUri.path : "./${binUri.path}";

  print("\$ $binPath ${args.join(' ')}");
  final result = await Process.run(binPath, args);
  
  if (verbose) {
    stdout.write(result.stdout.toString());
  }
  
  if (result.exitCode != 0) {
    print("abnormal exit ${result.exitCode}: ${result.stderr}");
  }
  
  return result.exitCode;
}// TODO Implement this library.

String prettifier(Object object, {bool lines = false, int tabsize = 2}) {
  final buffer = StringBuffer();
  int count = 0;
  final tab = '${lines ? '|' : ''}${' ' * tabsize}';
  object
      .toString()
      .split('')
      .forEach(
        (c) => switch (c) {
          '(' || '[' => buffer.write('$c\n${tab * (++count)}'),
          ')' || ']' => buffer.write('\n${tab * (--count)}$c'),
          ',' => buffer.write('$c\n${tab * count}'),
          _ => buffer.write(c),
        },
      );
  return buffer.toString();
}
