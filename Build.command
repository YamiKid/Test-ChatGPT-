#!/bin/zsh

set -euo pipefail

PROJECT_DIR="${0:A:h}"
PROJECT_FILE="$PROJECT_DIR/Chat.xcodeproj"
DERIVED_DATA="$PROJECT_DIR/.build/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/Chat.app"

finish() {
    local exit_code=$?
    echo
    if (( exit_code == 0 )); then
        echo "✅ Garnet successfully built."
        echo "App: $APP_PATH"
    else
        echo "❌ Build failed with exit code $exit_code."
    fi

    if [[ -t 0 ]]; then
        echo
        read "?Press Return to close this window..."
    fi
    exit $exit_code
}
trap finish EXIT

echo "Garnet — reproducible Debug build"
echo "Project: $PROJECT_FILE"
echo

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Xcode command-line tools were not found. Install Xcode and run it once."
    exit 1
fi

if [[ ! -d "$PROJECT_FILE" ]]; then
    echo "Chat.xcodeproj was not found next to Build.command."
    exit 1
fi

mkdir -p "$DERIVED_DATA"

xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme Chat \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "generic/platform=iOS Simulator" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build

# If a simulator is already running, install and launch the verified build.
BOOTED_DEVICE="$(xcrun simctl list devices booted 2>/dev/null | sed -nE 's/.*\(([0-9A-F-]{36})\) \(Booted\).*/\1/p' | head -n 1)"
if [[ -n "$BOOTED_DEVICE" && -d "$APP_PATH" ]]; then
    echo
    echo "Installing Garnet into the running simulator..."
    xcrun simctl install "$BOOTED_DEVICE" "$APP_PATH"
    xcrun simctl launch --terminate-running-process "$BOOTED_DEVICE" nb.Chat
fi
