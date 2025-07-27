#!/bin/bash
# create-portable-app.sh - Create a portable Mac app for distribution

echo "📦 Creating Portable Mac App for Distribution"
echo "============================================"

# Check if the app exists
if [ ! -d "Builds/client/3d-game-client.app" ]; then
    echo "❌ Mac app not found. Building it first..."
    echo ""
    ./build.sh
    echo ""
fi

# Verify the app was built
if [ ! -d "Builds/client/3d-game-client.app" ]; then
    echo "❌ Failed to build Mac app. Check export presets in Godot."
    echo ""
    echo "🔧 TO FIX:"
    echo "   1. Open Godot Editor"
    echo "   2. Project → Export → Add macOS preset"
    echo "   3. Set Bundle Identifier: com.yourname.3dgame"
    echo "   4. Check 'Embed PCK' option"
    echo "   5. Run this script again"
    exit 1
fi

echo "✅ Found Mac app: Builds/client/3d-game-client.app"

# Fix permissions for portability
echo "🔧 Fixing permissions for cross-computer compatibility..."
chmod +x "Builds/client/3d-game-client.app/Contents/MacOS/"*

# Remove quarantine flag (for your local computer)
echo "🔓 Removing quarantine flag..."
xattr -rd com.apple.quarantine "Builds/client/3d-game-client.app" 2>/dev/null || true

# Test the app locally first
echo "🧪 Testing app locally..."
if ! open "Builds/client/3d-game-client.app"; then
    echo "⚠️  App failed to launch locally. Check for issues before distributing."
else
    echo "✅ App launched successfully"
    echo "   (You can close the game window to continue)"
    sleep 3
fi

# Create ZIP for distribution
echo ""
echo "📦 Creating ZIP file for distribution..."
cd "Builds/client"

# Generate filename with timestamp
TIMESTAMP=$(date +"%Y%m%d-%H%M")
ZIP_NAME="3d-game-multiplayer-mac-${TIMESTAMP}.zip"

# Create the ZIP
if zip -r "$ZIP_NAME" "3d-game-client.app"; then
    echo "✅ Created: Builds/client/${ZIP_NAME}"
    
    # Get file size
    SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
    echo "   File size: $SIZE"
else
    echo "❌ Failed to create ZIP file"
    exit 1
fi

cd ../..

# Create instructions file
echo ""
echo "📋 Creating instruction file..."
cat > "Builds/client/INSTRUCTIONS.md" << 'EOF'
# 🎮 3D Multiplayer Game

## 🚀 How to Run

1. **Extract the ZIP file**
2. **Right-click** `3d-game-client.app` → **Open** (don't double-click)
3. Click **"Open"** in the security dialog
4. The game will launch!

## 🌐 Connect to Multiplayer Server

When the game starts:
- **Address:** `3d-game-production.up.railway.app`
- **Port:** `8080` (or leave default)
- Click **"Connect to Server"**

## 🎮 Controls

- **WASD:** Move around
- **Mouse:** Look around  
- **ESC:** Release mouse cursor
- **Click:** Capture mouse again

## 🔧 Troubleshooting

- **"Cannot open" error:** Right-click → Open (don't double-click)
- **Connection fails:** Check internet connection
- **Choppy movement:** Normal internet latency (~100ms)

## 💡 Tips

- Move around to test real-time multiplayer
- Other players will appear as white capsules
- ESC to access menus, click to return to game

---

*This is a portable Mac app - no installation required!*
EOF

echo "✅ Created: Builds/client/INSTRUCTIONS.md"

# Final summary
echo ""
echo "🎯 PORTABLE MAC APP READY FOR DISTRIBUTION!"
echo "================================================"
echo ""
echo "📦 **Files to share:**"
echo "   • Builds/client/${ZIP_NAME}"
echo "   • Builds/client/INSTRUCTIONS.md"
echo ""
echo "📤 **Transfer methods:**"
echo "   • AirDrop the ZIP file"
echo "   • Upload to Google Drive/Dropbox"
echo "   • Copy to USB drive"
echo "   • Email attachment (if under 25MB)"
echo ""
echo "🎮 **On target computer:**"
echo "   1. Unzip the file"  
echo "   2. Right-click .app → Open"
echo "   3. Connect to: 3d-game-production.up.railway.app"
echo "   4. Enjoy multiplayer gaming!"
echo ""
echo "✅ Ready for cross-Mac multiplayer testing! 🚀" 