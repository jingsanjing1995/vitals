#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/build.sh"
open "$ROOT/dist/VITALS.app"
echo "VITALS is running."
echo "Add the widget: right-click the desktop → 编辑小组件… → search VITALS."
