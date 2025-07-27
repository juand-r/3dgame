# 🍎 Mac Gatekeeper & Code Signing Fix Guide

## 🚨 **The Problem**

When you build a Mac client with Godot, you get these warnings:
```
❌ Invalid bundle identifier: Identifier is missing
⚠️  Warning: Notarization is disabled
⚠️  Code signing: Using ad-hoc signature
🚫 The exported project will be blocked by Gatekeeper
```

**Result:** Double-clicking the `.app` shows "cannot be opened because it is from an unidentified developer"

---

## 🔧 **Quick Fix for Local Testing**

### **Method 1: Right-Click to Open (Easiest)**
```bash
# Instead of double-clicking:
1. Right-click the .app file
2. Select "Open" from context menu
3. Click "Open" in the security dialog
4. App will run and be remembered as safe
```

### **Method 2: Remove Quarantine Flag**
```bash
# Remove the quarantine attribute
xattr -rd com.apple.quarantine "Builds/client/3d-game-client.app"

# Then double-click works normally
open "Builds/client/3d-game-client.app"
```

### **Method 3: Use Launch Script**
```bash
# Our launch script automatically handles this
./launch-client.sh
```

---

## 🏗️ **Proper Fix: Bundle Identifier**

### **Step 1: Configure in Godot Editor**
```
1. Open Godot Editor
2. Project → Export
3. Select "macOS Client" preset (or create it)
4. In export settings, find "Bundle Identifier"
5. Set to: com.yourname.3dgame
   Example: com.john.3dgame, com.studiox.racergame
```

### **Step 2: Other Recommended Settings**
```
Application Category: Games
Copyright: Your Name or Studio
Version: 1.0.0
Bundle Identifier: com.yourname.3dgame (REQUIRED)
```

### **Step 3: Export and Test**
```bash
# Build with new settings
./build.sh

# Should have fewer warnings now
```

---

## 🚀 **For Actual Distribution**

### **What You Need for Real Mac App Store / Distribution:**

#### **Apple Developer Account** ($99/year)
- Required for code signing certificates
- Required for notarization
- Required for App Store submission

#### **Code Signing Certificate**
```bash
# After getting Apple Developer account:
1. Download certificates from Apple Developer portal
2. Install in Keychain Access
3. Configure in Godot export settings:
   - Codesign Identity: "Developer ID Application: Your Name"
   - Provisioning Profile: Your downloaded profile
```

#### **Notarization Process**
```bash
# Apple's security scanning process
1. Upload signed app to Apple for scanning
2. Apple checks for malware/security issues  
3. Apple returns notarization ticket
4. Staple ticket to your app
5. Now distributable without Gatekeeper warnings
```

---

## 🎮 **Alternative: Use Godot Editor for Testing**

Instead of building Mac apps, just use Godot directly:

```bash
# Terminal 1: Start server
godot . --headless --server

# Terminal 2: Start client 
godot .  # Then F2 to connect

# No Gatekeeper issues because Godot is already trusted
```

---

## 📱 **Multi-Device Testing Options**

### **Option A: Mobile Hotspot + Laptop**
```
Device 1: Your Mac (home WiFi)
Device 2: Laptop (mobile hotspot)
Both connect to: 3d-game-production.up.railway.app
```

### **Option B: Friend's Computer**
```
You: Send them the Railway server URL
Friend: Uses Godot editor to connect
Both: Test multiplayer over real internet
```

### **Option C: Virtual Machine**
```
Main Mac: Run Godot normally
VM (Windows/Linux): Run Godot client
Both: Connect to Railway server
```

---

## 🔍 **Why This Happens**

### **Apple's Security Model:**
- **Gatekeeper**: Blocks unsigned apps from unknown developers
- **Code Signing**: Proves the app hasn't been tampered with
- **Notarization**: Apple scans for malware before allowing distribution
- **Bundle ID**: Unique identifier for your app (like domain name)

### **Godot's Default Behavior:**
- Creates "ad-hoc" signature (works locally but not for distribution)
- No bundle identifier by default
- No Apple Developer account integration
- Fine for development, not for distribution

---

## ✅ **What Works Right Now**

### **For Local Testing:**
```bash
✅ ./launch-client.sh          # Automatically handles quarantine
✅ Right-click → Open          # Manual Gatekeeper bypass  
✅ godot . (F2 to connect)     # Use editor directly
✅ xattr -rd com.apple.quarantine # Remove quarantine flag
```

### **For Multi-Device:**
```bash
✅ Mobile hotspot + laptop     # Different networks
✅ Friend with Railway URL     # Remote testing
✅ Virtual machine setup      # Controlled environment
```

### **For Distribution (Future):**
```bash
⏳ Apple Developer Account    # $99/year for real code signing
⏳ Proper certificates       # For App Store submission
⏳ Notarization process      # For public distribution
```

---

## 🎯 **Recommended Approach**

### **For This Project:**
1. **Use `godot .` for local testing** (no Gatekeeper issues)
2. **Use mobile hotspot for multi-device testing**
3. **Fix bundle identifier** to reduce warnings
4. **Keep using Railway for internet server**

### **For Future Distribution:**
1. **Get Apple Developer account** when ready for real distribution
2. **Set up proper code signing** for App Store submission
3. **Implement notarization** for public distribution outside App Store

---

## 💡 **Key Insight**

**The Gatekeeper warnings don't affect functionality** - they're just Apple's security checks. Your game works perfectly, you just need to tell Mac "yes, I trust this app" using one of the methods above.

For multiplayer testing, the **internet infrastructure is working perfectly** via Railway. The Mac signing is just a local app security issue, not a networking problem.

---

*This guide covers Mac-specific issues. The core multiplayer networking (Railway + WebSocket) works identically on all platforms.* 