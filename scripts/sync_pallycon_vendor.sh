#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FRAMEWORK="${1:-}"
VENDOR_ROOT="$ROOT_DIR/Vendor/PallyConFPSSDK.framework"

if [[ -z "$SOURCE_FRAMEWORK" ]]; then
  echo "[sync_pallycon_vendor] 사용법: ./scripts/sync_pallycon_vendor.sh /path/to/PallyConFPSSDK.framework" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_FRAMEWORK" || ! -f "$SOURCE_FRAMEWORK/PallyConFPSSDK" ]]; then
  echo "[sync_pallycon_vendor] 원본 framework 구조를 찾지 못했습니다: $SOURCE_FRAMEWORK" >&2
  exit 1
fi

rm -rf "$VENDOR_ROOT"
mkdir -p "$(dirname "$VENDOR_ROOT")"
rsync -a "$SOURCE_FRAMEWORK/" "$VENDOR_ROOT/"

echo "[sync_pallycon_vendor] synced source framework -> $VENDOR_ROOT"
echo "[sync_pallycon_vendor] source remains untouched: $SOURCE_FRAMEWORK"
