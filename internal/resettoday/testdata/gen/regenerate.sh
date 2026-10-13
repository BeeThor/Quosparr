#!/bin/bash
# Rebuilds internal/resettoday/testdata/swift_cases.json.gz from the real
# QuosparrCore sources (needs swiftc on macOS; takes a few minutes). The
# fixture is committed, so the Go tests do not need Swift.
set -euo pipefail
repo="$(cd "$(dirname "$0")/../../../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
swiftc -parse-as-library -module-name QuosparrCore -emit-module -emit-library -Onone -enable-testing \
  "$repo"/Sources/QuosparrCore/*.swift \
  -o "$work/libQuosparrCore.dylib" -emit-module-path "$work/QuosparrCore.swiftmodule" 2>"$work/core.log" || { cat "$work/core.log"; exit 1; }
swiftc -I "$work" -L "$work" -lQuosparrCore -Xlinker -rpath -Xlinker "$work" -module-name gen \
  "$repo/internal/resettoday/testdata/gen/main.swift" \
  "$repo/Tests/QuosparrCoreTests/RateLimitResetTodayTestSupport.swift" -o "$work/gen"
"$work/gen" "$work/swift_cases.json"
gzip -9nc "$work/swift_cases.json" > "$repo/internal/resettoday/testdata/swift_cases.json.gz"
