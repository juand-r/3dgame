# 📦 Creating a Portable Mac App

## 🎯 **Goal: Mac App You Can Copy to Other Computers**

Create a self-contained `.app` bundle that you can:
- Copy to a USB drive
- Transfer to another Mac  
- Email/AirDrop to friends
- Run without installing Godot

---

## 🔧 **Step 1: Configure Godot Export Properly**

### **In Godot Editor:**
```
1. Project → Export
2. Select "macOS Client" preset  
3. CRITICAL SETTINGS:

Bundle Identifier: com.yourname.3dgame
Application Category: Games
Embed PCK: ✅ CHECKED (embeds game data in app)
Export Mode: Release
Architecture: Universal (works on Intel + Apple Silicon)

4. Optional but recommended:
   Version: 1.0.0
   Copyright: Your Name
   Icon: (upload a custom icon if you have one)
```

### **Why These Settings Matter:**
- **Embed PCK**: Puts all game files inside the .app (no external dependencies)
- **Universal**: Works on both Intel and Apple Silicon Macs
- **Bundle ID**: Required for proper Mac app behavior
- **Release Mode**: Optimized performance

---

## 🏗️ **Step 2: Build the Portable App**

### **Method A: Use Build Script**
```bash
# Make sure export preset is configured first
./build.sh

# Result: Builds/client/3d-game-client.app
```

### **Method B: Manual Export**
```bash
# From Godot Editor
godot --headless --export-release "macOS Client" "Builds/client/3d-game-client.app"
```

---

## 📋 **Step 3: Prepare for Distribution**

### **Fix Permissions (Important!)**
```bash
# Make executable on any Mac
chmod +x "Builds/client/3d-game-client.app/Contents/MacOS/"*

# Remove quarantine (for your computer)
xattr -rd com.apple.quarantine "Builds/client/3d-game-client.app"
```

### **Test Locally First**
```bash
# Test the app works on your Mac
open "Builds/client/3d-game-client.app"

# Or use our launch script  
./launch-client.sh
```

---

## 📤 **Step 4: Transfer to Other Computer**

### **Best Transfer Methods:**

**Method 1: ZIP for Transfer**
```bash
# Create a ZIP file (preserves permissions and structure)
cd Builds/client
zip -r "3d-game-client.zip" "3d-game-client.app"

# Transfer the ZIP file to other Mac
# Unzip on target Mac preserves everything
```

**Method 2: AirDrop (Direct)**
```bash
# Right-click 3d-game-client.app → Share → AirDrop
# Works if both Macs are nearby
```

**Method 3: USB Drive**
```bash
# Copy the .app to USB drive
# FAT32 USB drives might lose permissions - use ZIP instead
```

**Method 4: Cloud Storage (Dropbox, Google Drive)**
```bash
# Upload the ZIP file to cloud storage
# Download and unzip on target Mac
```

---

## 🖥️ **Step 5: Running on Target Computer**

### **First Launch on New Mac:**
```bash
# The other person needs to:
1. Right-click the .app → Open (bypasses Gatekeeper)
2. Click "Open" in security dialog  
3. App will run and be trusted for future launches

# Or remove quarantine flag:
xattr -rd com.apple.quarantine "3d-game-client.app"
open "3d-game-client.app"
```

### **Connect to Your Railway Server:**
```
When the game starts:
1. Address: 3d-game-production.up.railway.app
2. Port: 8080 (or leave default)
3. Click "Connect to Server"
4. Should connect to your Railway server!
```

---

## ✅ **Verification Checklist**

### **Before Transferring:**
- [ ] App launches on your Mac ✅
- [ ] App connects to Railway server ✅
- [ ] Can move around and see yourself ✅
- [ ] ZIP preserves app structure ✅

### **After Transferring:**
- [ ] App launches on target Mac ✅
- [ ] App connects to Railway server ✅
- [ ] Both players can see each other ✅
- [ ] Real-time multiplayer works ✅

---

## 🎮 **Testing Script for Other Computer**

Create this file to send with your app:

**test-connection.md:**
```markdown
# Testing 3D Game Client

1. **Launch App:**
   - Right-click 3d-game-client.app → Open
   - Click "Open" if security dialog appears

2. **Connect to Server:**
   - Address: 3d-game-production.up.railway.app
   - Port: 8080  
   - Click "Connect to Server"

3. **Test Movement:**
   - WASD to move around
   - Mouse to look around
   - ESC to release mouse cursor

4. **Troubleshooting:**
   - If blocked: Right-click → Open (don't double-click)
   - If won't connect: Check internet connection
   - If choppy: Normal internet latency (~100ms)
```

---

## 🔍 **Advanced: App Bundle Contents**

### **What's Inside a Proper .app:**
```
3d-game-client.app/
├── Contents/
│   ├── Info.plist          # App metadata
│   ├── MacOS/
│   │   └── 3d-game-client  # Main executable
│   ├── Resources/          # Game assets (when PCK embedded)
│   └── _CodeSignature/     # Automatic signature
```

### **Why It's Portable:**
- **Self-contained**: All game files embedded in .app
- **No dependencies**: Doesn't need Godot installed
- **Universal binary**: Runs on Intel + Apple Silicon
- **Standard Mac app**: Behaves like any other Mac application

---

## 🚀 **Distribution Strategies**

### **For Friends/Testing:**
```bash
✅ ZIP file transfer (easiest)
✅ AirDrop (if nearby)  
✅ Cloud storage link
✅ USB drive (with ZIP)
```

### **For Wider Distribution:**
```bash
⏳ Apple Developer Account + Code Signing
⏳ Notarization for public distribution
⏳ Mac App Store submission
⏳ DMG installer creation
```

### **For Game Jams/Demos:**
```bash
✅ itch.io uploads (supports Mac .app in ZIP)
✅ GitHub releases (ZIP attachments)
✅ Direct download links (from your website)
```

---

## 💡 **Pro Tips**

### **Naming Convention:**
```bash
# Good naming for distribution:
3d-game-v1.0-mac.zip        # Clear version and platform
gta-multiplayer-mac.app.zip  # Descriptive name
multiplayer-demo-mac.zip     # Indicates it's a demo
```

### **File Size Optimization:**
```bash
# Typical sizes:
- Basic 3D game: 50-100MB
- With assets: 100-500MB  
- AAA-style: 1GB+

# Your current game is probably <100MB (minimal assets)
```

### **Testing on Different Macs:**
```bash
# Test compatibility:
- Intel Mac (if available)
- Apple Silicon Mac (M1/M2/M3)
- Different macOS versions (12+)
- Different internet connections
```

---

## 🎯 **Quick Start for Your Use Case**

```bash
# 1. Configure export in Godot (bundle ID, embed PCK)
# 2. Build the app
./build.sh

# 3. Test locally  
./launch-client.sh

# 4. Create ZIP for transfer
cd Builds/client
zip -r "3d-game-mac.zip" "3d-game-client.app"

# 5. Transfer ZIP to other computer
# 6. Unzip and right-click → Open
# 7. Connect to: 3d-game-production.up.railway.app
# 8. Enjoy multiplayer gaming! 🎮
```

---

*This creates a truly portable Mac app that runs on any Mac without requiring Godot installation.* 