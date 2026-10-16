#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Wallflow.app/Contents/Info.plist)

mkdir -p dist
STAGING=$(mktemp -d dist/.staging.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
cp -R Wallflow.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "Wallflow" -srcfolder "$STAGING" -format UDZO -ov "dist/Wallflow-$VERSION.dmg" -quiet
(
    cd dist
    shasum -a 256 "Wallflow-$VERSION.dmg" > "Wallflow-$VERSION.dmg.sha256"
)

echo "已生成 dist/Wallflow-$VERSION.dmg"
