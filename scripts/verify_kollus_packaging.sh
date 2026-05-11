#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_ROOT="$ROOT_DIR/Vendor/KollusSDK"
PALLYCON_VENDOR_ROOT="$ROOT_DIR/Vendor/PallyConFPSSDK.framework"
STUB_HEADERS_LINK="$ROOT_DIR/Packaging/Kollus/Stub/Sources/KollusSDK/include/KollusSDK"

if [[ ! -d "$VENDOR_ROOT" ]]; then
  echo "[verify_kollus_packaging] vendor copy not found: $VENDOR_ROOT" >&2
  exit 1
fi

if [[ ! -d "$PALLYCON_VENDOR_ROOT" || ! -f "$PALLYCON_VENDOR_ROOT/PallyConFPSSDK" ]]; then
  echo "[verify_kollus_packaging] PallyCon vendor copy not found: $PALLYCON_VENDOR_ROOT" >&2
  exit 1
fi

if [[ -n "${SOURCE_SDK:-}" ]]; then
  if [[ ! -d "$SOURCE_SDK" ]]; then
    echo "[verify_kollus_packaging] source SDK not found: $SOURCE_SDK" >&2
    exit 1
  fi
  diff -rq "$SOURCE_SDK" "$VENDOR_ROOT" >/dev/null
  echo "[verify_kollus_packaging] vendor copy matches source SDK"
else
  echo "[verify_kollus_packaging] vendor source-of-truth present: $VENDOR_ROOT"
fi

if [[ ! -L "$STUB_HEADERS_LINK" ]]; then
  echo "[verify_kollus_packaging] stub headers must be a symlink: $STUB_HEADERS_LINK" >&2
  exit 1
fi

if [[ -e "$ROOT_DIR/Artifacts" ]]; then
  echo "[verify_kollus_packaging] deprecated Artifacts directory still exists: $ROOT_DIR/Artifacts" >&2
  exit 1
fi

pushd "$ROOT_DIR" >/dev/null
./scripts/rebuild_pallycon_xcframework.sh >/dev/null
xcodebuild -scheme videoplayer-ios-ms-Package -destination 'generic/platform=iOS Simulator' build >/dev/null
popd >/dev/null
echo "[verify_kollus_packaging] package build succeeded"
