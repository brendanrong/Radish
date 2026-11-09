#!/bin/bash
# Renders Resources/AppIcon.svg into Resources/AppIcon.icns.
#
#   Tools/render_icon.sh
#
# The SVG is rasterized once at 1024 px and sips scales it down for the smaller
# sizes. The rendered files are committed, so regular app builds need no renderer.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
RSVG="$(command -v rsvg-convert || true)"
[ -n "$RSVG" ] || [ -x "$CHROME" ] || {
  echo "rsvg-convert or Google Chrome is needed to render the icon" >&2
  exit 1
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp Resources/AppIcon.svg "$WORK/AppIcon.svg"
if [ -n "$RSVG" ]; then
  "$RSVG" -w 1024 -h 1024 "$WORK/AppIcon.svg" -o "$WORK/1024.png"
else
  printf '<html><body style="margin:0;background:transparent"><img src="AppIcon.svg" width="1024" height="1024"></body></html>' > "$WORK/icon.html"
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --default-background-color=00000000 --virtual-time-budget=2000 --window-size=1024,1024 \
    --screenshot="$WORK/1024.png" "file://$WORK/icon.html" >/dev/null 2>&1
fi
[ -s "$WORK/1024.png" ] || { echo "Chrome did not render the icon" >&2; exit 1; }

ICONSET="$WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x 128:icon_128x128 \
            256:icon_128x128@2x 256:icon_256x256 512:icon_256x256@2x 512:icon_512x512 1024:icon_512x512@2x; do
  px=${spec%%:*}
  sips -z "$px" "$px" "$WORK/1024.png" --out "$ICONSET/${spec#*:}.png" >/dev/null
done
python3 Tools/pack_icns.py "$ICONSET" Resources/AppIcon.icns
echo "✓ Resources/AppIcon.icns"
