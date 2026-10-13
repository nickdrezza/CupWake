#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"
compiler_dir=$(dirname -- "$(xcrun --find swift)")
macro_plugin="$compiler_dir/../lib/swift/host/plugins/testing/libTestingMacros.dylib"

# Some Apple command-line tools do not find the bundled test macros.
if [ -f "$macro_plugin" ]; then
    swift test -Xswiftc -load-plugin-library -Xswiftc "$macro_plugin" "$@"
else
    swift test "$@"
fi
