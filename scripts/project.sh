#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
command -v xcodegen >/dev/null 2>&1 || {
    echo "xcodegen is required: brew install xcodegen" >&2
    exit 1
}
xcodegen generate
echo "Regenerated VITALS.xcodeproj"
