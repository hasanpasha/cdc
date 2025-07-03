set -x

dart compile exe "tree_builder/bin/tree_builder.dart"
install tree_builder/bin/tree_builder.exe bin/tree_builder