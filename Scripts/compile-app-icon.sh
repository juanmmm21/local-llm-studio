#!/bin/zsh
#
# Genera iconos compatibles con macOS 26 (Tahoe) y los instala en el .app.
#
# Tahoe encierra en marco gris los .icns con alpha ≤ 252 en los bordes.
# Este script fuerza alpha = 255 y compila AppIcon.icon con actool.
#
# Uso (desde Xcode):  Scripts/compile-app-icon.sh "$CODESIGNING_FOLDER_PATH"
# Uso (manual):       Scripts/compile-app-icon.sh path/to/local-llm-studio.app
#
set -euo pipefail

APP_BUNDLE="${1:?Indica la ruta al .app compilado}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$APP_BUNDLE/Contents/Resources"
ICONSET="$ROOT/build/AppIcon.iconset"
ACTOOL_OUT="$ROOT/build/icon-actool"
ASSETS="$ROOT/local-llm-studio/Resources/Assets.xcassets"
TAHOE_ICON="$ROOT/local-llm-studio/Resources/AppIcon.icon"

mkdir -p "$RESOURCES" "$ICONSET" "$ACTOOL_OUT"

echo "▸ Generando arte del icono…"
swift "$ROOT/Scripts/make-slash-icon.swift"
swift "$ROOT/Scripts/make-app-icon.swift" \
  "$ROOT/Scripts/icon-source.png" \
  "$ASSETS/AppIcon.appiconset"

echo "▸ Compilando AppIcon.icon para macOS 26…"
rm -rf "$ACTOOL_OUT"
mkdir -p "$ACTOOL_OUT"
xcrun actool \
  "$ASSETS" \
  "$TAHOE_ICON" \
  --compile "$ACTOOL_OUT" \
  --output-format human-readable-text \
  --notices --warnings --errors \
  --app-icon AppIcon \
  --include-all-app-icons \
  --enable-icon-stack-fallback-generation disabled \
  --enable-on-demand-resources NO \
  --development-region es \
  --target-device mac \
  --minimum-deployment-target 14.0 \
  --platform macosx \
  --output-partial-info-plist "$ACTOOL_OUT/partial.plist"

if [[ -f "$ACTOOL_OUT/Assets.car" ]]; then
  cp "$ACTOOL_OUT/Assets.car" "$RESOURCES/Assets.car"
fi

echo "▸ Creando AppIcon.icns legacy con alpha opaco…"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
cp "$ASSETS/AppIcon.appiconset/icon_16.png"      "$ICONSET/icon_16x16.png"
cp "$ASSETS/AppIcon.appiconset/icon_16@2x.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ASSETS/AppIcon.appiconset/icon_32.png"      "$ICONSET/icon_32x32.png"
cp "$ASSETS/AppIcon.appiconset/icon_32@2x.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ASSETS/AppIcon.appiconset/icon_128.png"     "$ICONSET/icon_128x128.png"
cp "$ASSETS/AppIcon.appiconset/icon_128@2x.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ASSETS/AppIcon.appiconset/icon_256.png"     "$ICONSET/icon_256x256.png"
cp "$ASSETS/AppIcon.appiconset/icon_256@2x.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ASSETS/AppIcon.appiconset/icon_512.png"     "$ICONSET/icon_512x512.png"
cp "$ASSETS/AppIcon.appiconset/icon_512@2x.png"  "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

touch "$APP_BUNDLE"
echo "✔ Iconos instalados en $RESOURCES"
