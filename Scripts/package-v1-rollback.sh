#!/usr/bin/env bash
# Prepare a higher-version Swift recovery release; never upload or publish it
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GOCACHE="${GOCACHE:-$ROOT/.build/v1-go-cache}"
SWIFT_ROOT="${SWIFT_SOURCE_DIR:?Set SWIFT_SOURCE_DIR to a clean Quosparr Swift checkout}"
export SPARKLE_TOOLS_DIR="${SPARKLE_TOOLS_DIR:-$SWIFT_ROOT/.build/artifacts/sparkle/Sparkle/bin}"
CONFIG="${V1_CONFIG_PATH:?Set V1_CONFIG_PATH to a reviewed higher-version rollback configuration}"
DIST="${V1_BUILD_DIR:-$ROOT/build/v1-rollback}"
[[ -z "$(git -C "$SWIFT_ROOT" status --porcelain)" ]] || { printf 'Rollback source must be clean\n' >&2; exit 1; }
[[ -d "$SWIFT_ROOT/Sources/Quosparr" && -d "$SWIFT_ROOT/Sources/QuosparrCore" ]] || {
  printf 'Rollback source must already use Quosparr modules and bundle identity\n' >&2; exit 1;
}
[[ -n "${MYGO_UPDATE_PRIVATE_KEY:-}" && -n "${SPARKLE_PUBLIC_KEY:-}" && -n "${SPARKLE_PRIVATE_KEY:-}" ]] || { printf 'Three update signing secrets are required\n' >&2; exit 1; }
python3 - "$ROOT/mygo.json" "$CONFIG" <<'PY'
import json,re,sys
current,candidate=[json.load(open(path)) for path in sys.argv[1:]]
def version(text):
 if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+",text):
  raise SystemExit("rollback requires a stable semantic version")
 return tuple(map(int,text.split(".")))
if version(candidate["version"])<=version(current["version"]):
 raise SystemExit("rollback version must be greater than current Go version")
if int(candidate["macos"]["infoPlist"]["CFBundleVersion"])<=int(current["macos"]["infoPlist"]["CFBundleVersion"]):
 raise SystemExit("rollback build must be greater than current Go build")
if candidate["updates"]["publicKey"]!=current["updates"]["publicKey"]:
 raise SystemExit("rollback must retain the Go update public key")
if candidate["macos"]["infoPlist"]["SUPublicEDKey"]!=current["macos"]["infoPlist"]["SUPublicEDKey"]:
 raise SystemExit("rollback must retain the legacy Sparkle public key")
PY
python3 "$ROOT/Scripts/check-v1-build-number.py" --config "$CONFIG" --require-new-version
mkdir -p "$DIST"
python3 - "$CONFIG" "$DIST/rollback-config.json" <<'PY'
import json,sys
config=json.load(open(sys.argv[1]))
config["releaseRuntime"]="swift"
open(sys.argv[2],"w").write(json.dumps(config,indent=2)+"\n")
PY
VERSION="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$CONFIG")"
BUILD="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["macos"]["infoPlist"]["CFBundleVersion"])' "$CONFIG")"
cd "$ROOT"
for arch in arm64 x86_64; do
  WORK="$DIST/swift-$arch"
  # Use the v1 packaging script against Swift main, with only version/build overrides
  # No Swift source, preferences, credentials or official auth files are modified
  RUNWAY_DIST_DIR="$WORK" RUNWAY_VERSION="$VERSION" RUNWAY_BUILD_NUMBER="$BUILD" \
    ARCH="$arch" bash "$ROOT/Scripts/package-app.sh" --source-root "$SWIFT_ROOT"
  bash "$ROOT/Scripts/verify-packaged-app.sh" "$WORK/Quosparr.app" "$arch" local
  GOARCH="$arch"; [[ "$GOARCH" != x86_64 ]] || GOARCH=amd64
  cp "$WORK/Quosparr-macos-$arch.zip" "$WORK/Quosparr-macos-$arch.dmg" "$DIST/"
  cp "$WORK/Quosparr-macos-$arch.app.tar.gz" "$DIST/quosparr-$VERSION-darwin-$GOARCH.tar.gz"
  go run ./Scripts/release-assets sign -config "$DIST/rollback-config.json" -dir "$DIST" -targets "darwin-$GOARCH"
done
[[ -x "$SPARKLE_TOOLS_DIR/generate_appcast" && -x "$SPARKLE_TOOLS_DIR/sign_update" ]] || {
  printf 'Sparkle tools missing from the Swift source checkout or explicit SPARKLE_TOOLS_DIR\n' >&2
  exit 1
}
bash "$ROOT/Scripts/legacy-appcast.sh" "$DIST" "$DIST/rollback-config.json" "v$VERSION"
python3 "$ROOT/Scripts/release-checksums.py" write "$DIST"
V1_SWIFT_ROLLBACK=1 V1_RELEASE_TAG="v$VERSION" bash "$ROOT/Scripts/verify-v1-release.sh" "$DIST" "$DIST/rollback-config.json" darwin-arm64,darwin-amd64
printf 'Swift rollback assets prepared; no release was created\n'
