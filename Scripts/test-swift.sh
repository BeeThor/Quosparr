#!/usr/bin/env bash
# Some Swift model tests use the default cache stores; isolate Foundation HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/quosparr-swift-tests.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT
CFFIXED_USER_HOME="$TEST_HOME" swift test --package-path "$ROOT" "$@"
