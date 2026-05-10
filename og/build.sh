#!/usr/bin/env bash
# Generate OG / social images for ClaudeFlows.
# Run from repo root: bash og/build.sh

set -euo pipefail

cd "$(dirname "$0")/.."

LOGO_B64=$(base64 -i assets/logo.png | tr -d '\n')

# Color tokens (knotpm)
BG_DARK="#242424"
BG_LIGHT="#ffffff"
TEXT_DARK="#e2e2e2"
TEXT_LIGHT="#000000"
MUTED_DARK="#666666"
MUTED_LIGHT="#494949"
SUBTLE_DARK="#494949"
SUBTLE_LIGHT="#666666"
BORDER_DARK="#494949"
BORDER_LIGHT="#e2e2e2"
BRAND_DARK="#6dcfc0"
BRAND_LIGHT="#0c7864"

# Generate one SVG variant at given W x H, theme, and tagline-mode.
# $1 W  $2 H  $3 BG  $4 TEXT  $5 MUTED  $6 SUBTLE  $7 BORDER  $8 BRAND  $9 OUT_PNG
make_image() {
  local W=$1 H=$2 BG=$3 TEXT=$4 MUTED=$5 SUBTLE=$6 BORDER=$7 BRAND=$8 OUT=$9
  local LOGO_W=$((W * 36 / 100))
  local LOGO_H=$((LOGO_W / 2))
  local LOGO_X=$((W * 6 / 100))
  local LOGO_Y=$(( (H - LOGO_H) / 2 ))
  local TEXT_X=$((LOGO_X + LOGO_W + W * 5 / 100))
  local WORDMARK_SIZE=$((W * 7 / 100))
  local TAGLINE_SIZE=$((W * 38 / 1000))
  local SUB_SIZE=$((W * 22 / 1000))
  local URL_SIZE=$((W * 18 / 1000))
  local CENTER_Y=$((H / 2))

  cat > /tmp/og-tmp.svg <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
     width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="100%" height="100%" fill="${BG}"/>
  <rect x="32" y="32" width="$((W-64))" height="$((H-64))" fill="none" stroke="${BORDER}" stroke-width="1"/>

  <image xlink:href="data:image/png;base64,${LOGO_B64}"
         x="${LOGO_X}" y="${LOGO_Y}" width="${LOGO_W}" height="${LOGO_H}"
         preserveAspectRatio="xMidYMid meet"/>

  <g font-family="Lexend, sans-serif">
    <text x="${TEXT_X}" y="$((CENTER_Y - WORDMARK_SIZE / 2 - 8))"
          font-size="${WORDMARK_SIZE}" font-weight="700"
          letter-spacing="-2" fill="${TEXT}">claude<tspan fill="${BRAND}">flows</tspan></text>

    <text x="${TEXT_X}" y="$((CENTER_Y + TAGLINE_SIZE / 2 + 8))"
          font-size="${TAGLINE_SIZE}" font-weight="600"
          letter-spacing="-0.5" fill="${TEXT}">Two minds. One workflow.</text>

    <text x="${TEXT_X}" y="$((CENTER_Y + TAGLINE_SIZE + SUB_SIZE + 28))"
          font-size="${SUB_SIZE}" font-weight="400"
          fill="${MUTED}">Elephant + Goldfish workflows for Claude Code.</text>

    <text x="${TEXT_X}" y="$((H - 64))"
          font-size="${URL_SIZE}" font-weight="500" letter-spacing="0.3"
          fill="${SUBTLE}">omniprag.github.io/claudeflows</text>
  </g>
</svg>
SVG

  rsvg-convert -u /tmp/og-tmp.svg -o "${OUT}"
  rm -f /tmp/og-tmp.svg
  echo "  wrote ${OUT}  ($(sips --getProperty pixelWidth "${OUT}" | tail -1 | tr -d ' ' | cut -d: -f2)x$(sips --getProperty pixelHeight "${OUT}" | tail -1 | tr -d ' ' | cut -d: -f2))"
}

echo "Generating OG images..."

# 1) Primary OG (Facebook, LinkedIn, generic) — dark theme, 1200x630
make_image 1200 630 "${BG_DARK}" "${TEXT_DARK}" "${MUTED_DARK}" "${SUBTLE_DARK}" "${BORDER_DARK}" "${BRAND_DARK}" \
  og/og-image.png

# 2) Light variant of OG — same size
make_image 1200 630 "${BG_LIGHT}" "${TEXT_LIGHT}" "${MUTED_LIGHT}" "${SUBTLE_LIGHT}" "${BORDER_LIGHT}" "${BRAND_LIGHT}" \
  og/og-image-light.png

# 3) Twitter / X large card — 1200x675
make_image 1200 675 "${BG_DARK}" "${TEXT_DARK}" "${MUTED_DARK}" "${SUBTLE_DARK}" "${BORDER_DARK}" "${BRAND_DARK}" \
  og/twitter-card.png

# 4) GitHub social preview — 1280x640
make_image 1280 640 "${BG_DARK}" "${TEXT_DARK}" "${MUTED_DARK}" "${SUBTLE_DARK}" "${BORDER_DARK}" "${BRAND_DARK}" \
  og/github-social.png

echo "Done."
