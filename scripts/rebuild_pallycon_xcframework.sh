#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FRAMEWORK="${SOURCE_FRAMEWORK:-$ROOT_DIR/Vendor/PallyConFPSSDK.framework}"
OUTPUT_XCFRAMEWORK="${OUTPUT_XCFRAMEWORK:-$ROOT_DIR/Binaries/PallyConFPSSDK.xcframework}"
WORK_DIR="$ROOT_DIR/.build/pallycon-xcframework"
SIM_FRAMEWORK_DIR="$WORK_DIR/PallyConFPSSDK.framework"
SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"

if [[ ! -d "$SOURCE_FRAMEWORK" || ! -f "$SOURCE_FRAMEWORK/PallyConFPSSDK" ]]; then
  echo "[rebuild_pallycon_xcframework] source framework not found: $SOURCE_FRAMEWORK" >&2
  exit 1
fi

rm -rf "$WORK_DIR" "$OUTPUT_XCFRAMEWORK"
mkdir -p "$SIM_FRAMEWORK_DIR/Headers" "$SIM_FRAMEWORK_DIR/Modules"

cat >"$WORK_DIR/pallycon_stub.c" <<'EOF'
void PallyConFPSSDKStubSymbol(void) {}
EOF

clang -target arm64-apple-ios15.0-simulator \
  -dynamiclib \
  -isysroot "$SDK_PATH" \
  -install_name @rpath/PallyConFPSSDK.framework/PallyConFPSSDK \
  "$WORK_DIR/pallycon_stub.c" \
  -o "$WORK_DIR/PallyConFPSSDK-arm64"

clang -target x86_64-apple-ios15.0-simulator \
  -dynamiclib \
  -isysroot "$SDK_PATH" \
  -install_name @rpath/PallyConFPSSDK.framework/PallyConFPSSDK \
  "$WORK_DIR/pallycon_stub.c" \
  -o "$WORK_DIR/PallyConFPSSDK-x86_64"

lipo -create \
  "$WORK_DIR/PallyConFPSSDK-arm64" \
  "$WORK_DIR/PallyConFPSSDK-x86_64" \
  -output "$WORK_DIR/PallyConFPSSDK-simulator"

cp "$WORK_DIR/PallyConFPSSDK-simulator" "$SIM_FRAMEWORK_DIR/PallyConFPSSDK"

cp "$SOURCE_FRAMEWORK/Headers/PallyConFPSSDK.h" "$SIM_FRAMEWORK_DIR/Headers/"
cp "$SOURCE_FRAMEWORK/Headers/PallyConFPSSDK-ObjC.h" "$SIM_FRAMEWORK_DIR/Headers/"

cat >"$SIM_FRAMEWORK_DIR/Modules/module.modulemap" <<'EOF'
framework module PallyConFPSSDK {
  umbrella header "PallyConFPSSDK.h"
  export *
  module * { export * }
}
EOF

cat >"$SIM_FRAMEWORK_DIR/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.codex.stub.PallyConFPSSDK</string>
  <key>CFBundleName</key>
  <string>PallyConFPSSDK</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
</dict>
</plist>
EOF

xcodebuild -create-xcframework \
  -framework "$SOURCE_FRAMEWORK" \
  -framework "$SIM_FRAMEWORK_DIR" \
  -output "$OUTPUT_XCFRAMEWORK"

echo "[rebuild_pallycon_xcframework] rebuilt: $OUTPUT_XCFRAMEWORK"
