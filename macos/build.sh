#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/scintilla/cocoa/ScintillaTest"
PROJECT_FILE="$PROJECT_DIR/ScintillaTest.xcodeproj"
BUILD_ROOT="$ROOT_DIR/macos/build"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
CONFIGURATION="${CONFIGURATION:-Debug}"
ARCH="${ARCH:-arm64}"
SCHEME="${SCHEME:-ScintillaTest}"
APP_NAME="ScintillaTest.app"
APP_BUNDLE_PATH="$DERIVED_DATA/Build/Products/${CONFIGURATION}/${APP_NAME}"
OUTPUT_APP="$BUILD_ROOT/NotepadPlusPlus-mac-preview.app"
OUTPUT_ZIP="$BUILD_ROOT/NotepadPlusPlus-mac-preview.zip"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild not found. Install full Xcode first."
  exit 1
fi

DEVELOPER_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEVELOPER_PATH" == "/Library/Developer/CommandLineTools" ]]; then
  cat <<'MSG'
error: Full Xcode is required (xcodebuild currently points to CommandLineTools).

Install Xcode from the App Store, then run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
MSG
  exit 1
fi

mkdir -p "$BUILD_ROOT"
rm -rf "$DERIVED_DATA" "$OUTPUT_APP" "$OUTPUT_ZIP"

echo "Building ScintillaTest (${CONFIGURATION}, ${ARCH})..."
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -arch "$ARCH" \
  -derivedDataPath "$DERIVED_DATA" \
  OTHER_CPLUSPLUSFLAGS='$(inherited) -DLEXILLA_INCLUDE_MISSING_LEXERS=1' \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$APP_BUNDLE_PATH" ]]; then
  echo "error: expected app bundle not found at $APP_BUNDLE_PATH"
  exit 1
fi

cp -R "$APP_BUNDLE_PATH" "$OUTPUT_APP"

if command -v codesign >/dev/null 2>&1; then
  # Re-sign the copied bundle to avoid invalid signature metadata after repackaging.
  codesign --force --deep --sign - "$OUTPUT_APP" >/dev/null 2>&1 || true
fi

(
  cd "$BUILD_ROOT"
  ditto -c -k --sequesterRsrc --keepParent "$(basename "$OUTPUT_APP")" "$(basename "$OUTPUT_ZIP")"
)

cat <<MSG
Build complete.
App: $OUTPUT_APP
Zip: $OUTPUT_ZIP
Run:
  open "$OUTPUT_APP"
MSG
