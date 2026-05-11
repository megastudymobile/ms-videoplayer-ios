#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_ROOT="${VENDOR_ROOT:-$ROOT_DIR/Vendor/KollusSDK}"
DEVICE_LIB="${1:-}"
SIM_LIB="${2:-}"
OUTPUT_PATH="${3:-$ROOT_DIR/Binaries/KollusSDK.xcframework}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/.build/package-kollus-xcframework}"
PATCHED_HEADERS="$BUILD_ROOT/headers"

if [[ -z "$DEVICE_LIB" || -z "$SIM_LIB" ]]; then
  echo "[package_kollus_xcframework] usage: $0 /path/to/device.a /path/to/simulator.a [output.xcframework]" >&2
  exit 1
fi

if [[ ! -d "$VENDOR_ROOT/include/KollusSDK" ]]; then
  echo "[package_kollus_xcframework] vendor headers not found: $VENDOR_ROOT/include/KollusSDK" >&2
  exit 1
fi

if [[ ! -f "$DEVICE_LIB" ]]; then
  echo "[package_kollus_xcframework] device lib not found: $DEVICE_LIB" >&2
  exit 1
fi

if [[ ! -f "$SIM_LIB" ]]; then
  echo "[package_kollus_xcframework] simulator lib not found: $SIM_LIB" >&2
  exit 1
fi

prepare_headers() {
  local source_headers="$1"
  local target_headers="$2"

  rm -rf "$target_headers"
  mkdir -p "$target_headers"
  rsync -a "$source_headers/" "$target_headers/"

  cat > "$target_headers/module.modulemap" <<'EOF'
module KollusSDKBinary {
    umbrella "."
    export *
}
EOF

  ruby - "$target_headers/KollusPlayerBookmarkDelegate.h" <<'RUBY'
path = ARGV.fetch(0)
text = File.read(path)
unless text.include?("@class KollusPlayerView;")
  text.sub!("#import \"KollusSDK.h\"\n", "#import \"KollusSDK.h\"\n\n@class KollusPlayerView;\n")
  File.write(path, text)
end
RUBY

  ruby - "$target_headers/KollusPlayerDRMDelegate.h" <<'RUBY'
path = ARGV.fetch(0)
text = File.read(path)
unless text.include?("@class KollusPlayerView;")
  text.sub!("#import \"KollusSDK.h\"\n", "#import \"KollusSDK.h\"\n\n@class KollusPlayerView;\n")
  File.write(path, text)
end
RUBY

  ruby - "$target_headers/KollusPlayerLMSDelegate.h" <<'RUBY'
path = ARGV.fetch(0)
text = File.read(path)
unless text.include?("@class KollusPlayerView;")
  text.sub!("#import \"KollusSDK.h\"\n", "#import \"KollusSDK.h\"\n\n@class KollusPlayerView;\n")
  File.write(path, text)
end
RUBY
}

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT" "$(dirname "$OUTPUT_PATH")"
prepare_headers "$VENDOR_ROOT/include/KollusSDK" "$PATCHED_HEADERS"

rm -rf "$OUTPUT_PATH"
xcodebuild -create-xcframework \
  -library "$DEVICE_LIB" \
  -headers "$PATCHED_HEADERS" \
  -library "$SIM_LIB" \
  -headers "$PATCHED_HEADERS" \
  -output "$OUTPUT_PATH" >/dev/null

echo "[package_kollus_xcframework] packaged -> $OUTPUT_PATH"
