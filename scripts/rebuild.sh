#!/bin/bash
#
# Builds Quire in Release for the Mac and for the iPhone and iPad simulators, then restarts all
# three from the new builds, to try a change right away. Each simulator is the named device on the
# newest runtime that has it, booted if needed. If either build fails, nothing running is touched.

set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT=Quire.xcodeproj
DERIVED_DATA=build
PRODUCTS=$DERIVED_DATA/Build/Products
MAC_APP=$PRODUCTS/Release/Quire.app
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

echo "Restarting the Mac app"
pkill -f "$MAC_PROCESS" || true
while pgrep -f "$MAC_PROCESS" > /dev/null; do sleep 0.1; done
open "$MAC_APP"

echo "Restarting the iPhone and iPad apps"
for SIMULATOR in "$PHONE" "$PAD"; do
    xcrun simctl bootstatus "$SIMULATOR" -b > /dev/null
    xcrun simctl install "$SIMULATOR" "$IOS_APP"
    xcrun simctl launch --terminate-running-process "$SIMULATOR" "$BUNDLE_ID" > /dev/null
done
