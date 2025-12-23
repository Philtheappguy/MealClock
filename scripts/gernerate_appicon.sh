#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./scripts/generate_appicon.sh path/to/icon_1024.png
#
# Expects a square 1024x1024 PNG.

SRC_ICON="${1:-}"
if [[ -z "${SRC_ICON}" || ! -f "${SRC_ICON}" ]]; then
  echo "Usage: $0 path/to/icon_1024.png" >&2
  exit 1
fi

APPICON_DIR="MealClock/Assets.xcassets/AppIcon.appiconset"
mkdir -p "${APPICON_DIR}"

# sips is built into macOS.
# Note: sips can slightly change color profiles; if that bothers you, generate with another tool and just keep the filenames.

gen() {
  local px="$1"; local out="$2"
  sips -Z "${px}" "${SRC_ICON}" --out "${APPICON_DIR}/${out}" >/dev/null
}

# iPhone
# 20@2x (40), 20@3x (60)
# 29@2x (58), 29@3x (87)
# 40@2x (80), 40@3x (120)
# 60@2x (120), 60@3x (180)

gen 40  "Icon-20@2x.png"
gen 60  "Icon-20@3x.png"

gen 58  "Icon-29@2x.png"
gen 87  "Icon-29@3x.png"

gen 80  "Icon-40@2x.png"
gen 120 "Icon-40@3x.png"

gen 120 "Icon-60@2x.png"
gen 180 "Icon-60@3x.png"

# iPad

gen 20  "Icon-20.png"
# Icon-20@2x already generated (40)

gen 29  "Icon-29.png"
# Icon-29@2x already generated (58)

gen 40  "Icon-40.png"
# Icon-40@2x already generated (80)

gen 76  "Icon-76.png"
gen 152 "Icon-76@2x.png"

gen 167 "Icon-83.5@2x.png"

# App Store marketing
cp "${SRC_ICON}" "${APPICON_DIR}/Icon-1024.png"

echo "✅ Generated icons in ${APPICON_DIR}"
