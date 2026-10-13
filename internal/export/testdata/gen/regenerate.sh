#!/bin/bash
# Rebuilds the Swift-encoded fixtures under internal/*/testdata from the real
# QuosparrCore sources (needs swiftc on macOS; takes about a minute).
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
swiftc -parse-as-library -module-name QuosparrCore -emit-module -emit-library -Onone -enable-testing \
  "$repo"/Sources/QuosparrCore/*.swift \
  -o "$work/libQuosparrCore.dylib" -emit-module-path "$work/QuosparrCore.swiftmodule" 2>/dev/null
swiftc -I "$work" -L "$work" -lQuosparrCore -Xlinker -rpath -Xlinker "$work" -module-name gen \
  "$repo/internal/export/testdata/gen/main.swift" \
  "$repo/Tests/QuosparrCoreTests/RateLimitResetTodayTestSupport.swift" -o "$work/gen"
"$work/gen" "$repo"
