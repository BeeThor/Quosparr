#!/usr/bin/env bash
# Some Swift model tests use the default cache stores; isolate Foundation HOME.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/quosparr-swift-tests.XXXXXX")"
cleanup() {
  # Xcode may mount a read-only Metal toolchain inside the isolated home.
  # Detach only images owned by this test directory before removing it.
  python3 - "$TEST_HOME" <<'PY'
import pathlib
import plistlib
import shutil
import subprocess
import sys

root = pathlib.Path(sys.argv[1]).resolve()
images = plistlib.loads(subprocess.check_output(["hdiutil", "info", "-plist"]))
mounts = {
    pathlib.Path(entity["mount-point"]).resolve()
    for image in images.get("images", [])
    for entity in image.get("system-entities", [])
    if "mount-point" in entity
}
for mount in sorted(mounts, key=lambda path: len(path.parts), reverse=True):
    if root in mount.parents:
        subprocess.run(["hdiutil", "detach", str(mount)], check=True)
shutil.rmtree(root)
PY
}
trap cleanup EXIT
CFFIXED_USER_HOME="$TEST_HOME" swift test --package-path "$ROOT" "$@"
