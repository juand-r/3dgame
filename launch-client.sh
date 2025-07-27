#!/bin/bash
# launch-client.sh - Launch the macOS client build

echo "🎮 Launching 3D Game Client..."

if [ -d "Builds/client/3d-game-client.app" ]; then
    echo "✅ Found macOS client build"
    
    # Check if app is quarantined (blocked by Gatekeeper)
    if xattr "Builds/client/3d-game-client.app" | grep -q "com.apple.quarantine"; then
        echo "⚠️  App is quarantined by Gatekeeper"
        echo "🔧 Removing quarantine flag..."
        xattr -rd com.apple.quarantine "Builds/client/3d-game-client.app"
        echo "✅ Quarantine removed - app should now launch"
    fi
    
    echo "🚀 Starting game..."
    open "Builds/client/3d-game-client.app"
    
    # Alternative methods if the above fails
    echo ""
    echo "💡 If the app still won't start:"
    echo "   1. Right-click the .app → Open (bypasses Gatekeeper)"
    echo "   2. Or run: sudo spctl --master-disable (disables Gatekeeper)"
    echo "   3. Or fix bundle identifier in Godot export settings"
    
else
    echo "❌ macOS client build not found!"
    echo ""
    echo "🔧 TO CREATE MAC CLIENT BUILD:"
    echo "   1. Open Godot Editor"
    echo "   2. Project → Export → Add macOS preset"
    echo "   3. Set Bundle Identifier: com.yourname.3dgame"
    echo "   4. Run './build.sh' to create the build"
    echo ""
    echo "🎮 OR USE GODOT DIRECTLY:"
    echo "   Run 'godot .' to launch from editor"
fi 