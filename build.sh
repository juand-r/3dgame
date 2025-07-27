#!/bin/bash
# build.sh - Export Godot project for Railway deployment

set -e  # Exit on any error

echo "🚀 Building GTA-Style Multiplayer Game for Railway Deployment"
echo "============================================================="

# Check if Godot is available
if ! command -v godot &> /dev/null; then
    echo "❌ Error: Godot not found in PATH"
    echo "Please install Godot 4.4 or add it to your PATH"
    exit 1
fi

# Create build directories
echo "📁 Creating build directories..."
mkdir -p Builds/server
mkdir -p Builds/client

# Export server build (headless Linux)
echo "🖥️  Exporting server build..."
godot --headless --export-release "Linux Server" "Builds/server/3d-game-server"

# Export client build (for testing)
echo "🎮 Exporting client build..."
godot --headless --export-release "Desktop Client" "Builds/client/3d-game-client"

# Check if exports were successful
if [ -f "Builds/server/3d-game-server" ]; then
    echo "✅ Server build successful: Builds/server/3d-game-server"
    chmod +x "Builds/server/3d-game-server"
else
    echo "❌ Server build failed"
    exit 1
fi

if [ -f "Builds/client/3d-game-client" ]; then
    echo "✅ Client build successful: Builds/client/3d-game-client"
    chmod +x "Builds/client/3d-game-client"
else
    echo "⚠️  Client build not found (export presets may not be configured)"
fi

echo ""
echo "🎯 Build Summary:"
echo "- Server: $(ls -lh Builds/server/3d-game-server 2>/dev/null || echo 'Not found')"
echo "- Client: $(ls -lh Builds/client/3d-game-client 2>/dev/null || echo 'Not found')"
echo ""
echo "🐳 Ready for Docker build:"
echo "   docker build -t gta-multiplayer-server ."
echo ""
echo "🚄 Ready for Railway deployment:"
echo "   railway up" 