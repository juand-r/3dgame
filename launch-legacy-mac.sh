#!/bin/bash
# launch-legacy-mac.sh - Simple launcher for older macOS hardware

echo "🎮 Launching 3D Game (macOS Big Sur Compatible)"
echo "=============================================="

# Check if app exists
if [ ! -d "3d-game-client.app" ]; then
    echo "❌ 3d-game-client.app not found"
    echo "   Copy the .app bundle to this folder first"
    exit 1
fi

echo "✅ Found game app"
echo "🔓 Removing quarantine..."
xattr -rd com.apple.quarantine "3d-game-client.app" 2>/dev/null || true

echo "🚀 Launching with GL Compatibility mode..."
echo ""

# Launch with the working compatibility setting
"./3d-game-client.app/Contents/MacOS/GTA-Style Multiplayer Game" --rendering-method gl_compatibility

echo ""
echo "🎉 Game closed successfully!" 