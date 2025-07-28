#!/bin/bash
# build.sh - Build server and client exports

echo "🏗️  Building game exports..."

# Ensure build directories exist
mkdir -p Builds/server Builds/client

# Export server build (Linux headless for Railway)
echo "🖥️  Exporting Linux server build..."
godot --headless --export-release "Linux Server" "Builds/server/3d-game-server"

if [ -f "Builds/server/3d-game-server" ]; then
    echo "✅ Server build successful: Builds/server/3d-game-server"
    chmod +x "Builds/server/3d-game-server"
    
    # Copy for Railway deployment (Railway can't access Builds/ due to .gitignore)
    cp "Builds/server/3d-game-server" "./game-server"
    echo "📦 Copied server executable to ./game-server for Railway deployment"
else
    echo "❌ Server build failed!"
    exit 1
fi

# Export client builds
echo "🎮 Exporting client builds..."
echo ""

# Windows Client
echo "🪟 Building Windows client..."
godot --headless --export-release "Windows Desktop" "Builds/client/3d-game-client.exe"

if [ -f "Builds/client/3d-game-client.exe" ]; then
    echo "✅ Windows Client build successful: Builds/client/3d-game-client.exe"
    
    echo ""
    echo "🪟 TO RUN WINDOWS CLIENT:"
    echo "   1. Copy Builds/client/3d-game-client.exe to Windows computer"
    echo "   2. Double-click to run (no installation needed)"
    echo "   3. Connect to: 3d-game-production.up.railway.app"
    echo ""
else
    echo "⚠️  Windows Client build failed (check export preset configuration)"
fi

# macOS Client  
echo "🍎 Building macOS client..."
echo "⚠️  NOTE: If you see Mac code signing warnings:"
echo "   1. In Godot: Project → Export → macOS Client"
echo "   2. Set Bundle Identifier to: com.yourname.3dgame"  
echo "   3. For testing: Right-click .app → Open (bypasses Gatekeeper)"
echo "   4. For distribution: Need Apple Developer account + code signing"
echo ""

godot --headless --export-release "macOS Client" "Builds/client/3d-game-client.app"

if [ -d "Builds/client/3d-game-client.app" ]; then
    echo "✅ macOS Client build successful: Builds/client/3d-game-client.app"
    chmod +x "Builds/client/3d-game-client.app/Contents/MacOS/"*
    
    echo ""
    echo "🍎 TO RUN MAC CLIENT:"
    echo "   Method 1: ./launch-client.sh"
    echo "   Method 2: Right-click Builds/client/3d-game-client.app → Open"
    echo "   Method 3: open Builds/client/3d-game-client.app (if Gatekeeper allows)"
    echo ""
else
    echo "⚠️  macOS Client build not found (export presets may not be configured)"
    echo "   This is OK - you can still use 'godot .' for client testing"
fi

echo ""
echo "🎯 Build Summary:"
echo "- Server: $(ls -lh Builds/server/3d-game-server 2>/dev/null || echo 'Not found')"
echo "- Windows Client: $(ls -lh Builds/client/3d-game-client.exe 2>/dev/null || echo 'Not found')"
echo "- macOS Client: $(ls -ld Builds/client/3d-game-client.app 2>/dev/null || echo 'Not found')"
echo "- Railway Copy: $(ls -lh ./game-server 2>/dev/null || echo 'Not found')" 