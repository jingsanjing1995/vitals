#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh" >/dev/null
"$ROOT/dist/VITALS.app/Contents/MacOS/VITALS" --dump-metrics
