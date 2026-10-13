#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export GOCACHE="${GOCACHE:-$ROOT/.build/v1-go-cache}"
DIST="${1:?asset directory required}"
CONFIG="${2:-$ROOT/mygo.json}"
TAG="${3:?release tag required}"
[[ -n "${SPARKLE_PUBLIC_KEY:-}" && -n "${SPARKLE_PRIVATE_KEY:-}" ]] || { printf 'Missing Sparkle signing secrets\n' >&2; exit 1; }
python3 - "$CONFIG" <<'PY'
import json,os,sys
expected=json.load(open(sys.argv[1]))["macos"]["infoPlist"]["SUPublicEDKey"]
if os.environ["SPARKLE_PUBLIC_KEY"].strip()!=expected:
 raise SystemExit("SPARKLE_PUBLIC_KEY must match the existing SUPublicEDKey")
PY
TOOLS="${SPARKLE_TOOLS_DIR:-$ROOT/.build/artifacts/sparkle/Sparkle/bin}"
[[ -x "$TOOLS/generate_appcast" && -x "$TOOLS/sign_update" ]]
WORK="$(mktemp -d "${TMPDIR:-/tmp}/runway-appcast.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
# Preserve the installed Go module/toolchain cache before isolating Sparkle
export GOPATH="${GOPATH:-$(go env GOPATH)}"
export GOMODCACHE="${GOMODCACHE:-$(go env GOMODCACHE)}"
# Keep Sparkle's extraction cache separate from the real user's cache
export HOME="$WORK/home"
export CFFIXED_USER_HOME="$HOME"
mkdir -p "$HOME" "$WORK/arm64" "$WORK/x86_64"
cd "$ROOT"
IFS=',' read -r -a ARCHES <<< "${4:-arm64,x86_64}"
for arch in "${ARCHES[@]}"; do
  case "$arch" in arm64|x86_64) ;; *) exit 2 ;; esac
  ZIP="$DIST/Quosparr-macos-$arch.zip"
  cp "$ZIP" "$WORK/$arch/"
  printf '%s' "$SPARKLE_PRIVATE_KEY" | "$TOOLS/generate_appcast" \
    --ed-key-file - --maximum-deltas 0 \
    --download-url-prefix "https://github.com/Licoy/Quosparr/releases/download/$TAG/" \
    -o "$DIST/quosparr-appcast-$arch.xml" "$WORK/$arch"
  # A different bundle ID cannot be installed over the previous app by Sparkle.
  # Its original feed offers the manual download page, never the new archive.
  python3 "$ROOT/Scripts/legacy-install-notice.py" "$CONFIG" "$DIST/appcast-$arch.xml" "$TAG"
done
python3 "$ROOT/Scripts/verify-legacy-appcast.py" "$DIST" "$CONFIG" "$TAG" "${4:-arm64,x86_64}"
