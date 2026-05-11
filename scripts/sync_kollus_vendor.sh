#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_ROOT="$ROOT_DIR/Vendor/KollusSDK"

if [[ $# -lt 1 ]]; then
  echo "[sync_kollus_vendor] usage: $0 /path/to/KollusSDK" >&2
  exit 1
fi

SOURCE_SDK="$1"

if [[ ! -d "$SOURCE_SDK/include/KollusSDK" || ! -f "$SOURCE_SDK/lib/libKollusSDK.a" ]]; then
  echo "[sync_kollus_vendor] 원본 SDK 구조를 찾지 못했습니다: $SOURCE_SDK" >&2
  exit 1
fi

rm -rf "$VENDOR_ROOT"
mkdir -p "$VENDOR_ROOT"

rsync -a "$SOURCE_SDK/include/" "$VENDOR_ROOT/include/"
rsync -a "$SOURCE_SDK/lib/" "$VENDOR_ROOT/lib/"

echo "[sync_kollus_vendor] synced source SDK -> $VENDOR_ROOT"
echo "[sync_kollus_vendor] source remains untouched: $SOURCE_SDK"
