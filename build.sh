#!/bin/bash
set -e

# echo "🔧 Switching to Xcode developer tools..."
# sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

echo "🏗  Building TrafficMonitor (Release)..."
xcodebuild \
  -project "$(dirname "$0")/TrafficMonitor.xcodeproj" \
  -scheme TrafficMonitor \
  -configuration Release \
  -derivedDataPath "$(dirname "$0")/build" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

APP_PATH="$(dirname "$0")/build/Build/Products/Release/TrafficMonitor.app"

echo ""
echo "✅ Done! App is at:"
echo "   $APP_PATH"
echo ""
echo "📦 Copying to ~/Applications..."
mkdir -p ~/Applications
rm -rf ~/Applications/TrafficMonitor.app
cp -R "$APP_PATH" ~/Applications/
echo "✅ TrafficMonitor.app installed to ~/Applications/"

echo "🔄 Refreshing macOS icon caches..."
touch ~/Applications/TrafficMonitor.app
if [ -f "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister" ]; then
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f ~/Applications/TrafficMonitor.app
fi
killall Dock
echo "✅ Done!"
