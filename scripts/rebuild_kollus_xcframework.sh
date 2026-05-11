#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SOURCE_SDK="$ROOT_DIR/Vendor/KollusSDK"
DEFAULT_STUB_PACKAGE="$ROOT_DIR/Packaging/Kollus/Stub"

SOURCE_SDK="${SOURCE_SDK:-$DEFAULT_SOURCE_SDK}"
STUB_PACKAGE="${STUB_PACKAGE:-$DEFAULT_STUB_PACKAGE}"
OUTPUT_XCFRAMEWORK="${OUTPUT_XCFRAMEWORK:-$ROOT_DIR/Binaries/KollusSDK.xcframework}"
DEVICE_LIB_NAME="libKollusSDK.a"
STUB_CONFIGURATION="Release"
BUILD_ROOT="$ROOT_DIR/.build/kollus-xcframework/release"

VENDOR_ROOT="$ROOT_DIR/Vendor/KollusSDK"
SIM_BUILD_DIR="$BUILD_ROOT/stub-derived-data"

if [[ ! -d "$SOURCE_SDK/include/KollusSDK" || ! -f "$SOURCE_SDK/lib/libKollusSDK.a" ]]; then
  echo "[rebuild_kollus_xcframework] 원본 SDK 구조를 찾지 못했습니다: $SOURCE_SDK" >&2
  exit 1
fi

if [[ ! -f "$SOURCE_SDK/lib/$DEVICE_LIB_NAME" ]]; then
  echo "[rebuild_kollus_xcframework] device library not found: $SOURCE_SDK/lib/$DEVICE_LIB_NAME" >&2
  exit 1
fi

if [[ ! -f "$STUB_PACKAGE/Package.swift" ]]; then
  echo "[rebuild_kollus_xcframework] Kollus stub 패키지를 찾지 못했습니다: $STUB_PACKAGE" >&2
  exit 1
fi

if [[ "$SOURCE_SDK" != "$VENDOR_ROOT" ]]; then
  "$ROOT_DIR/scripts/sync_kollus_vendor.sh" "$SOURCE_SDK"
fi

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

pushd "$STUB_PACKAGE" >/dev/null
xcodebuild \
  -scheme KollusSDK \
  -configuration "$STUB_CONFIGURATION" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$SIM_BUILD_DIR" \
  build >/dev/null
popd >/dev/null

SIM_LIB="$(find "$SIM_BUILD_DIR/Build/Products/${STUB_CONFIGURATION}-iphonesimulator" -name 'libKollusSDK.a' | head -n 1)"
DEVICE_LIB="$VENDOR_ROOT/lib/$DEVICE_LIB_NAME"

if [[ -z "$SIM_LIB" ]]; then
  SIM_OBJECT="$(find "$SIM_BUILD_DIR/Build/Products/${STUB_CONFIGURATION}-iphonesimulator" -name 'KollusSDK.o' | head -n 1)"
  if [[ -n "$SIM_OBJECT" && -f "$SIM_OBJECT" ]]; then
    SIM_LIB="$BUILD_ROOT/libKollusSDK-simulator.a"
    libtool -static -o "$SIM_LIB" "$SIM_OBJECT"
  fi
fi

if [[ -z "$SIM_LIB" || ! -f "$SIM_LIB" ]]; then
  echo "[rebuild_kollus_xcframework] simulator stub libKollusSDK.a를 찾지 못했습니다." >&2
  exit 1
fi

"$ROOT_DIR/scripts/package_kollus_xcframework.sh" "$DEVICE_LIB" "$SIM_LIB" "$OUTPUT_XCFRAMEWORK" >/dev/null
echo "[rebuild_kollus_xcframework] rebuilt canonical xcframework -> $OUTPUT_XCFRAMEWORK"
