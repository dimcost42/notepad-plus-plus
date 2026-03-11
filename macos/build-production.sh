#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIGURATION=Release \
OUTPUT_APP="${OUTPUT_APP:-$ROOT_DIR/macos/build/Notepad++.app}" \
OUTPUT_ZIP="${OUTPUT_ZIP:-$ROOT_DIR/macos/build/Notepad++-mac-production.zip}" \
"$ROOT_DIR/macos/build.sh"
