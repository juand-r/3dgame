# 🔧 To Fix Later - Active TODOs

## 🚨 **High Priority**

### 1. **Host Server Functionality**
**Location:** `Scripts/UI/MainUI.gd:263`
**Issue:** The "Host Server" button in the multiplayer menu does nothing
**TODO:** Implement actual local server hosting for other players to join

```gdscript
func _on_host_server_button_pressed():
    """Handle host server button press"""
    _play_button_click()
    GameEvents.log_info("UI: Host Server button pressed")
    # TODO: Implement host server functionality
```

**Requirements:**
- Start local server on specified port
- Show server status/IP address to user
- Allow other players to connect via IP
- Handle server shutdown when returning to menu

---

### 2. **Graphics Quality Settings**
**Location:** `Scripts/UI/MainUI.gd:517`
**Issue:** Graphics quality dropdown shows options but doesn't actually change anything
**TODO:** Implement actual graphics quality changes

```gdscript
func _on_quality_selected(index: int):
    """Handle graphics quality selection"""
    var quality_options = ["Low", "Medium", "High", "Ultra"]
    var selected_quality = quality_options[index]
    GameEvents.log_info("Graphics quality changed to: %s" % selected_quality)
    _save_graphics_setting("quality", selected_quality)
    # TODO: Implement actual quality changes
```

**Requirements:**
- Define quality presets (Low/Medium/High/Ultra)
- Adjust render settings, shadows, effects based on selection
- Apply changes immediately without restart
- Persist quality setting across sessions

---

## 📝 **Medium Priority**

### 3. **ESC In-Game Settings Menu**
**Location:** `Scripts/UI/MainUI.gd:105`
**Issue:** ESC during gameplay shows "TODO" message instead of opening settings
**TODO:** Implement in-game settings overlay

```gdscript
GameEvents.log_info("ESC pressed in-game - Settings menu (TODO)")
```

**Requirements:**
- Create overlay settings menu that appears during gameplay
- Allow access to audio/graphics/controls settings while playing
- Resume game when settings are closed
- Handle ESC key properly (pause game, show menu)

---

## ✅ **Completed**
- ✅ Main menu redesign with 4 options
- ✅ Single player mode implementation  
- ✅ Multiplayer screen with Quick Join
- ✅ Settings screen with audio/graphics/controls
- ✅ Game Maker screen placeholder
- ✅ Menu button click sounds
- ✅ Background music system (menu + game)
- ✅ Volume sliders with audio feedback

---

*Last Updated: 2025-01-29* 