#!/bin/bash
# create-windows-package.sh - Create a Windows distribution package

echo "🪟 Creating Windows Distribution Package"
echo "======================================="

# Check if Windows build exists
if [ ! -f "Builds/client/3d-game-client.exe" ]; then
    echo "❌ Windows client not found. Building it first..."
    echo ""
    ./build.sh
    echo ""
fi

# Verify the build was successful
if [ ! -f "Builds/client/3d-game-client.exe" ]; then
    echo "❌ Failed to build Windows client. Check export preset:"
    echo ""
    echo "🔧 TO FIX:"
    echo "   1. Open Godot Editor"
    echo "   2. Project → Export → Check 'Windows Desktop' preset exists"
    echo "   3. Export Path: Builds/client/3d-game-client.exe"
    echo "   4. Check 'Embed PCK' option"
    echo "   5. Architecture: x86_64"
    echo "   6. Run this script again"
    exit 1
fi

echo "✅ Found Windows client: Builds/client/3d-game-client.exe"

# Create distribution folder
echo "📁 Creating distribution folder..."
DIST_DIR="Builds/client/windows-distribution"
mkdir -p "$DIST_DIR"

# Copy executable
echo "📋 Copying executable..."
cp "Builds/client/3d-game-client.exe" "$DIST_DIR/"

# Create instructions file
echo "📋 Creating instructions..."
cat > "$DIST_DIR/README.txt" << 'EOF'
🎮 3D Multiplayer Game - Windows

== HOW TO PLAY ==

1. Double-click "3d-game-client.exe" to start the game
2. When the game opens:
   - Server Address: 3d-game-production.up.railway.app
   - Port: 8080 (or leave default)
   - Click "Connect to Server"

== CONTROLS ==

- WASD: Move around
- Mouse: Look around  
- ESC: Release mouse cursor
- Click: Capture mouse again

== TROUBLESHOOTING ==

- Antivirus blocking: Add exception for game folder
- Connection fails: Check internet connection
- Choppy movement: Normal internet latency

== REQUIREMENTS ==

- Windows 10/11 (64-bit)
- DirectX 11 compatible graphics
- Internet connection for multiplayer

== NOTES ==

- This is a portable game - no installation required!
- You can copy this entire folder to any Windows computer
- Game connects to cloud server for real-time multiplayer
- Move around to test real-time multiplayer with other players

---
Created: $(date)
EOF

# Create ZIP package
echo "📦 Creating ZIP package..."
cd "Builds/client"
TIMESTAMP=$(date +"%Y%m%d-%H%M")
ZIP_NAME="3d-game-windows-${TIMESTAMP}.zip"

if zip -r "$ZIP_NAME" "windows-distribution/"; then
    echo "✅ Created: Builds/client/${ZIP_NAME}"
    
    # Get file size
    SIZE=$(ls -lh "$ZIP_NAME" | awk '{print $5}')
    echo "   File size: $SIZE"
else
    echo "❌ Failed to create ZIP file"
    exit 1
fi

cd ../..

# Final summary
echo ""
echo "🎯 WINDOWS DISTRIBUTION READY!"
echo "=============================="
echo ""
echo "📦 **Files to distribute:**"
echo "   • Builds/client/${ZIP_NAME}"
echo ""
echo "📤 **Distribution methods:**"
echo "   • Email the ZIP file"
echo "   • Upload to Google Drive/Dropbox"
echo "   • Share via USB drive" 
echo "   • Upload to file sharing service"
echo ""
echo "🎮 **For recipients:**"
echo "   1. Extract the ZIP file"
echo "   2. Open the extracted folder"
echo "   3. Double-click '3d-game-client.exe'"
echo "   4. Connect to: 3d-game-production.up.railway.app"
echo ""
echo "✨ **Ready for worldwide multiplayer gaming!**" 