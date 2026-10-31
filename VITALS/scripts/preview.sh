#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
"$ROOT/dist/VITALS.app/Contents/MacOS/VITALS" --render-preview "$ROOT/docs"
