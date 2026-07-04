#!/bin/zsh
#
# Empaqueta la app para distribución: compila en Release y crea un DMG
# listo para adjuntar a una release de GitHub.
#
# Uso: ./Scripts/make-release.sh <versión>   (p. ej. 0.1.0)
#
set -euo pipefail

VERSION="${1:?Indica la versión, p. ej.: ./Scripts/make-release.sh 0.1.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGING="$DIST/dmg"
DMG="$DIST/local-llm-studio-$VERSION.dmg"

echo "▸ Compilando en Release…"
xcodebuild -scheme local-llm-studio \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$ROOT/build" \
  build | grep -E "error:|BUILD" || true

APP="$ROOT/build/Build/Products/Release/local-llm-studio.app"
[[ -d "$APP" ]] || { echo "No se encontró la app compilada en $APP"; exit 1; }

echo "▸ Preparando el contenido del DMG…"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "▸ Creando $DMG…"
hdiutil create -volname "local-llm-studio" \
  -srcfolder "$STAGING" \
  -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

echo "✔ Listo: $DMG"
