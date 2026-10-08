#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build-app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Wallflow.app/Contents/Info.plist)

rm -rf dist
mkdir -p dist/staging
cp -R Wallflow.app dist/staging/
ln -s /Applications dist/staging/Applications

hdiutil create -volname "Wallflow" -srcfolder dist/staging -format UDZO -ov "dist/Wallflow-$VERSION.dmg" -quiet
rm -rf dist/staging

echo "已生成 dist/Wallflow-$VERSION.dmg"
