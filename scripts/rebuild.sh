#!/bin/bash
#
# Builds Quire in Release for the Mac and for the iPhone and iPad simulators. The Mac app is quit
# and installed into /Applications, replacing the copy there, then reopened from there. The iPhone
# and iPad apps are restarted from the new build. Each simulator is the named device on the newest
# runtime that has it, booted if needed. If either build fails, nothing running is touched.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Quire.xcodeproj
DERIVED_DATA=build
PRODUCTS=$DERIVED_DATA/Build/Products
MAC_APP=$PRODUCTS/Release/Quire.app
INSTALLED_APP=/Applications/Quire.app
IOS_APP=$PRODUCTS/Release-iphonesimulator/Quire.app
MAC_PROCESS=Quire.app/Contents/MacOS/Quire
BUNDLE_ID=com.mashoaib.quire
PHONE_NAME="iPhone 18 Pro"
PAD_NAME="iPad Pro 11-inch (M5)"

fail() {
    echo "error: $1" >&2
    exit 1
}

device() {
    xcrun simctl list devices available | sed -n "s/^ *$1 (\([0-9A-F-]*\)) .*/\1/p" | tail -n 1
}

build() {
    local log=$DERIVED_DATA/rebuild-$1.log
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "Quire-$1" \
        -configuration Release \
        -destination "$2" \
        -derivedDataPath "$DERIVED_DATA" \
        > "$log" 2>&1 \
        || fail "Building Quire-$1 failed. See $log"
}

PHONE=$(device "$PHONE_NAME")
PAD=$(device "$PAD_NAME")
[ -n "$PHONE" ] || fail "No $PHONE_NAME simulator. Add one in Xcode > Window > Devices and Simulators."
[ -n "$PAD" ] || fail "No $PAD_NAME simulator. Add one in Xcode > Window > Devices and Simulators."

mkdir -p "$DERIVED_DATA"

xcodegen generate

echo "Building the Mac app"
build macOS "generic/platform=macOS"

echo "Building the iPhone and iPad app"
build iOS "generic/platform=iOS Simulator"

echo "Installing the Mac app in /Applications and reopening it"
pkill -f "$MAC_PROCESS" || true
while pgrep -f "$MAC_PROCESS" > /dev/null; do sleep 0.1; done
rm -rf "$INSTALLED_APP"
ditto "$MAC_APP" "$INSTALLED_APP"
open "$INSTALLED_APP"

echo "Restarting the iPhone and iPad apps"
for SIMULATOR in "$PHONE" "$PAD"; do
    xcrun simctl bootstatus "$SIMULATOR" -b > /dev/null
    xcrun simctl install "$SIMULATOR" "$IOS_APP"
    xcrun simctl launch --terminate-running-process "$SIMULATOR" "$BUNDLE_ID" > /dev/null
done
