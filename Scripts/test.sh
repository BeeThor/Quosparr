#!/usr/bin/env bash
set -euo pipefail

swift test
swift run Quosparr --self-check
