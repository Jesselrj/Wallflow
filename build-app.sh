#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

CONFIGURATION="${1:-release}"

swift build -c "$CONFIGURATION"

APP="Wallflow.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIGURATION/Wallflow" "$APP/Contents/MacOS/Wallflow"
cp Info.plist "$APP/Contents/"
if [ -f AppIcon.icns ]; then
	cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

for extra in .build/$CONFIGURATION/*.bundle .build/$CONFIGURATION/*.resources; do
	if [ -e "$extra" ]; then
		cp -R "$extra" "$APP/Contents/Resources/"
	fi
done

codesign --force --sign - "$APP"
echo "已构建 $APP"
