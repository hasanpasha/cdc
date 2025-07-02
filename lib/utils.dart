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