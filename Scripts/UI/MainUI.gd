# MainUI.gd - Main Menu System & UI Handler
# Handles the multi-screen menu interface and game state management
extends CanvasLayer

# ============================================================================
# SCREEN REFERENCES
# ============================================================================

# Main screen containers
@onready var menu_system = $MenuSystem
@onready var welcome_screen = $MenuSystem/WelcomeScreen
@onready var single_player_screen = $MenuSystem/SinglePlayerScreen
@onready var multiplayer_screen = $MenuSystem/MultiplayerScreen
@onready var settings_screen = $MenuSystem/SettingsScreen
@onready var game_maker_screen = $MenuSystem/GameMakerScreen
@onready var game_hud = $GameHUD

# Settings Panel References
@onready var settings_main_container = $MenuSystem/SettingsScreen/SettingsContainer
@onready var audio_panel = $MenuSystem/SettingsScreen/AudioPanel
@onready var graphics_panel = $MenuSystem/SettingsScreen/GraphicsPanel
@onready var controls_panel = $MenuSystem/SettingsScreen/ControlsPanel

# Audio Controls
@onready var master_volume_slider = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/MasterVolumeContainer/MasterVolumeValue
@onready var music_volume_slider = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/MusicVolumeContainer/MusicVolumeValue
@onready var sfx_volume_slider = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value = $MenuSystem/SettingsScreen/AudioPanel/AudioContainer/SFXVolumeContainer/SFXVolumeValue

# Audio Feedback Players
@onready var master_volume_feedback = $MenuSystem/SettingsScreen/AudioPanel/MasterVolumeFeedback
@onready var sfx_volume_feedback = $MenuSystem/SettingsScreen/AudioPanel/SFXVolumeFeedback

# Menu Music Player
@onready var menu_music_player = $"../MenuMusicPlayer"

# Game Music Player
@onready var game_music_player = $"../GameMusicPlayer"

# Button Click Sound Player
@onready var button_click_player = $"../ButtonClickPlayer"

# Background Elements
@onready var background_image = $MenuBackground/BackgroundImage
@onready var menu_background = $MenuBackground

# Graphics Controls
@onready var resolution_option = $MenuSystem/SettingsScreen/GraphicsPanel/GraphicsContainer/ResolutionContainer/ResolutionOption
@onready var fullscreen_toggle = $MenuSystem/SettingsScreen/GraphicsPanel/GraphicsContainer/FullscreenContainer/FullscreenToggle
@onready var vsync_toggle = $MenuSystem/SettingsScreen/GraphicsPanel/GraphicsContainer/VSyncContainer/VSyncToggle
@onready var quality_option = $MenuSystem/SettingsScreen/GraphicsPanel/GraphicsContainer/QualityContainer/QualityOption

# Multiplayer UI elements (from old system, kept for compatibility)
@onready var address_input = $MenuSystem/MultiplayerScreen/MultiplayerContainer/CustomServerSection/AddressInput
@onready var port_input = $MenuSystem/MultiplayerScreen/MultiplayerContainer/CustomServerSection/PortInput
@onready var status_label = $MenuSystem/MultiplayerScreen/MultiplayerContainer/StatusLabel

# GameHUD elements
@onready var hud_connection_status = $GameHUD/TopLeft/ConnectionStatus
@onready var hud_player_count = $GameHUD/TopLeft/PlayerCount
@onready var hud_network_stats = $GameHUD/TopLeft/NetworkStats

# ============================================================================
# MENU STATE MANAGEMENT
# ============================================================================

enum MenuState {
    WELCOME,
    SINGLE_PLAYER,
    MULTIPLAYER,
    SETTINGS,
    GAME_MAKER,
    IN_GAME
}

var current_menu_state: MenuState = MenuState.WELCOME

func _ready():
    _load_settings()
    _initialize_settings_ui()
    
    # Setup menu music
    _setup_menu_music()
    
    # Setup game music
    _setup_game_music()
    
    # Setup button click sound
    _setup_button_click_sound()
    
    # Setup background image
    _setup_background()
    
    GameEvents.log_info("MainUI initialized - Multi-screen menu system")
    
    # Initialize UI state and start menu music
    _update_ui_state()
    _start_menu_music()
    
    # Connect to game events
    GameEvents.game_state_changed.connect(_on_game_state_changed)
    GameEvents.player_connected.connect(_on_player_connected)
    GameEvents.player_disconnected.connect(_on_player_disconnected)
    GameEvents.connection_status_updated.connect(_on_connection_status_updated)

func _input(event):
    # Handle ESC for menu navigation and P for return to menu
    if event.is_action_pressed("ui_cancel"):  # ESC key
        if current_menu_state == MenuState.IN_GAME:
            # ESC in-game just shows TODO message (mouse capture handled by PlayerController)
            GameEvents.log_info("ESC pressed in-game - Settings menu (TODO)")
        elif current_menu_state != MenuState.WELCOME:
            # ESC in menus = go back to main menu
            show_welcome_screen()
    
    # Handle P key for pause/return to menu during gameplay
    if event is InputEventKey and event.pressed and event.keycode == KEY_P:
        if current_menu_state == MenuState.IN_GAME:
            GameEvents.log_info("P pressed - Returning to menu")
            GameManager.disconnect_game()  # This will return to appropriate menu
    
    # Handle F11 for fullscreen toggle and F9 for dev window toggle
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_F11:
            toggle_fullscreen()
        elif event.keycode == KEY_F9:
            toggle_dev_window()
        elif event.keycode == KEY_F10:
            toggle_vsync()

# ============================================================================
# SCREEN NAVIGATION
# ============================================================================

func show_welcome_screen():
    """Show the main welcome screen with 4 main options"""
    _hide_all_screens()
    welcome_screen.visible = true
    current_menu_state = MenuState.WELCOME
    GameEvents.log_info("UI: Switched to Welcome screen")

func show_single_player_screen():
    """Show the single player options screen"""
    _hide_all_screens()
    single_player_screen.visible = true
    current_menu_state = MenuState.SINGLE_PLAYER
    GameEvents.log_info("UI: Switched to Single Player screen")

func show_multiplayer_screen():
    """Show the multiplayer connection screen"""
    _hide_all_screens()
    multiplayer_screen.visible = true
    current_menu_state = MenuState.MULTIPLAYER
    GameEvents.log_info("UI: Switched to Multiplayer screen")

func show_settings_screen():
    """Show the settings configuration screen"""
    _hide_all_screens()
    settings_screen.visible = true
    current_menu_state = MenuState.SETTINGS
    GameEvents.log_info("UI: Switched to Settings screen")

func show_game_maker_screen():
    """Show Game Maker screen"""
    GameEvents.log_info("UI: Switched to Game Maker screen")
    _hide_all_screens()
    game_maker_screen.visible = true
    current_menu_state = MenuState.GAME_MAKER
    
    # Show placeholder functionality
    _show_game_maker_info()

func _hide_all_screens():
    """Hide all menu screens"""
    welcome_screen.visible = false
    single_player_screen.visible = false
    multiplayer_screen.visible = false
    settings_screen.visible = false
    game_maker_screen.visible = false

# ============================================================================
# WELCOME SCREEN BUTTON HANDLERS
# ============================================================================

func _on_single_player_button_pressed():
    """Handle single player button press"""
    _play_button_click()
    GameEvents.log_info("UI: Single Player button pressed")
    show_single_player_screen()

func _on_multiplayer_button_pressed():
    """Handle multiplayer button press"""
    _play_button_click()
    GameEvents.log_info("UI: Multiplayer button pressed")
    show_multiplayer_screen()

func _on_settings_button_pressed():
    """Handle settings button press"""
    _play_button_click()
    GameEvents.log_info("UI: Settings button pressed")
    show_settings_screen()

func _on_game_maker_button_pressed():
    """Handle game maker button press"""
    _play_button_click()
    GameEvents.log_info("UI: Game Maker button pressed")
    show_game_maker_screen()

func _on_exit_button_pressed():
    """Handle exit button press"""
    _play_button_click()
    GameEvents.log_info("UI: Exit Game button pressed")
    get_tree().quit()

# ============================================================================
# SINGLE PLAYER SCREEN HANDLERS
# ============================================================================

func _on_new_game_button_pressed():
    """Handle new game button press"""
    _play_button_click()
    GameEvents.log_info("UI: Starting Single Player New Game")
    _start_single_player_mode()

func _start_single_player_mode():
    """Start single player mode - simplified approach"""
    GameEvents.log_info("Single Player: Initializing...")
    
    # Get an available port for local server
    var local_port = _get_available_port()
    
    # Update status
    status_label.text = "Single Player: Starting..."
    
    # Use GameManager's simple single player mode
    var success = GameManager.start_single_player_mode(local_port)
    
    if success:
        GameEvents.log_info("Single Player: Started successfully!")
        status_label.text = "Single Player: Ready!"
    else:
        GameEvents.log_error("Single Player: Failed to start")
        status_label.text = "Single Player: Failed to start"

func _get_available_port() -> int:
    """Get an available port for local server (simple implementation)"""
    # For now, use a default port range for single player
    # In production, we'd check if ports are actually available
    return 8080 + randi() % 100  # Random port between 8080-8179

# ============================================================================
# MULTIPLAYER SCREEN HANDLERS
# ============================================================================

func _on_quick_join_button_pressed():
    """Handle quick join button press"""
    _play_button_click()
    GameEvents.log_info("UI: Quick Join button pressed")
    
    # Get default server info
    var default_address = address_input.text if address_input.text.strip_edges() != "" else "3d-game-production.up.railway.app"
    var default_port = int(port_input.text) if port_input.text.strip_edges() != "" else 443
    
    # Attempt connection
    _connect_to_server(default_address, default_port)

func _on_connect_button_pressed():
    """Handle connect button press"""
    _play_button_click()
    GameEvents.log_info("UI: Connect button pressed")
    _connect_to_server(address_input.text, int(port_input.text))

func _on_host_server_button_pressed():
    """Handle host server button press"""
    _play_button_click()
    GameEvents.log_info("UI: Host Server button pressed")
    # TODO: Implement host server functionality

func _connect_to_server(address: String = "127.0.0.1", port: int = 8080):
    """Connect to server using current address/port inputs"""
    GameManager.connect_to_server(address, port)

# ============================================================================
# BACK BUTTON HANDLERS  
# ============================================================================

func _on_back_to_main_pressed():
    """Handle back to main menu button press"""
    _play_button_click()
    GameEvents.log_info("UI: Back to Main Menu")
    show_welcome_screen()

# ============================================================================
# SETTINGS SCREEN HANDLERS
# ============================================================================

func _on_audio_button_pressed():
    """Handle audio settings button press"""
    _play_button_click()
    GameEvents.log_info("UI: Opening Audio settings panel")
    _show_audio_panel()

func _on_controls_button_pressed():
    """Handle controls settings button press"""
    _play_button_click()
    GameEvents.log_info("UI: Opening Controls settings panel")
    _show_controls_panel()

func _on_graphics_button_pressed():
    """Handle graphics settings button press"""
    _play_button_click()
    GameEvents.log_info("UI: Opening Graphics settings panel")
    _show_graphics_panel()

func _show_audio_panel():
    """Show the audio settings panel"""
    _hide_all_settings_panels()
    settings_main_container.visible = false
    audio_panel.visible = true
    
func _show_controls_panel():
    """Show the controls settings panel"""
    _hide_all_settings_panels()
    settings_main_container.visible = false
    controls_panel.visible = true
    
func _show_graphics_panel():
    """Show the graphics settings panel"""
    _hide_all_settings_panels()
    settings_main_container.visible = false
    graphics_panel.visible = true

func _hide_all_settings_panels():
    """Hide all settings sub-panels"""
    audio_panel.visible = false
    graphics_panel.visible = false
    controls_panel.visible = false

func _show_settings_main():
    """Show the main settings screen"""
    _hide_all_settings_panels()
    settings_main_container.visible = true

# ============================================================================
# SETTINGS FUNCTIONALITY
# ============================================================================

func _initialize_settings_ui():
    """Initialize all settings UI elements with current values"""
    _setup_audio_controls()
    _setup_graphics_controls()
    
func _setup_audio_controls():
    """Setup audio controls with current volume levels"""
    # Master volume (bus 0)
    var master_db = AudioServer.get_bus_volume_db(0)
    var master_percent = int((master_db + 80) * 100 / 80)  # Convert dB to percentage
    master_percent = max(0, min(100, master_percent))  # Clamp to 0-100
    master_volume_slider.value = master_percent
    master_volume_value.text = str(master_percent) + "%"
    
    # Music volume (bus 1) - create if doesn't exist
    if AudioServer.bus_count <= 1:
        AudioServer.add_bus(1)
        AudioServer.set_bus_name(1, "Music")
    var music_db = AudioServer.get_bus_volume_db(1)
    var music_percent = int((music_db + 80) * 100 / 80)
    music_percent = max(0, min(100, music_percent))
    music_volume_slider.value = music_percent
    music_volume_value.text = str(music_percent) + "%"
    
    # SFX volume (bus 2) - create if doesn't exist
    if AudioServer.bus_count <= 2:
        AudioServer.add_bus(2)
        AudioServer.set_bus_name(2, "SFX")
    var sfx_db = AudioServer.get_bus_volume_db(2)
    var sfx_percent = int((sfx_db + 80) * 100 / 80)
    sfx_percent = max(0, min(100, sfx_percent))
    sfx_volume_slider.value = sfx_percent
    sfx_volume_value.text = str(sfx_percent) + "%"
    
    # Setup volume feedback sounds
    _setup_volume_feedback_sounds()

func _setup_volume_feedback_sounds():
    """Create simple beep sounds for volume feedback"""
    var beep_sound = _create_beep_sound()
    master_volume_feedback.stream = beep_sound
    sfx_volume_feedback.stream = beep_sound

func _create_beep_sound() -> AudioStreamWAV:
    """Create a simple sine wave beep sound"""
    var audio_stream = AudioStreamWAV.new()
    
    # Create a short 440Hz sine wave (musical note A4)
    var sample_rate = 22050
    var duration = 0.1  # 100ms
    var frequency = 440.0  # A4 note
    var sample_count = int(sample_rate * duration)
    
    var data = PackedByteArray()
    for i in range(sample_count):
        var t = float(i) / sample_rate
        var sample = sin(2.0 * PI * frequency * t) * 0.3  # 30% volume to avoid being too loud
        # Convert float sample to 16-bit integer
        var sample_16 = int(sample * 32767)
        # Add as little-endian 16-bit data
        data.append(sample_16 & 0xFF)
        data.append((sample_16 >> 8) & 0xFF)
    
    audio_stream.data = data
    audio_stream.format = AudioStreamWAV.FORMAT_16_BITS
    audio_stream.mix_rate = sample_rate
    audio_stream.stereo = false
    
    return audio_stream

func _setup_graphics_controls():
    """Setup graphics controls with current values"""
    var window = get_window()
    
    # Setup resolution dropdown
    resolution_option.clear()
    var common_resolutions = [
        "1280x720", "1366x768", "1600x900", "1920x1080", 
        "2560x1440", "3840x2160"
    ]
    var current_size = window.size
    var current_res = str(current_size.x) + "x" + str(current_size.y)
    
    for i in range(common_resolutions.size()):
        resolution_option.add_item(common_resolutions[i])
        if common_resolutions[i] == current_res:
            resolution_option.selected = i
    
    # Add current resolution if not in list
    if resolution_option.selected == -1:
        resolution_option.add_item(current_res + " (Current)")
        resolution_option.selected = resolution_option.get_item_count() - 1
    
    # Setup fullscreen toggle
    fullscreen_toggle.button_pressed = (window.mode == Window.MODE_FULLSCREEN)
    
    # Setup VSync toggle
    vsync_toggle.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
    
    # Setup quality dropdown
    quality_option.clear()
    quality_option.add_item("Low")
    quality_option.add_item("Medium")
    quality_option.add_item("High")
    quality_option.add_item("Ultra")
    quality_option.selected = 2  # Default to High

# ============================================================================
# AUDIO CONTROL HANDLERS
# ============================================================================

func _on_master_volume_changed(value: float):
    """Handle master volume slider change"""
    var db = (value * 80 / 100) - 80  # Convert percentage to dB
    AudioServer.set_bus_volume_db(0, db)
    master_volume_value.text = str(int(value)) + "%"
    _save_audio_setting("master_volume", value)
    GameEvents.log_info("Master volume set to %d%%" % int(value))
    
    # No beep feedback for master volume to avoid confusion

func _on_music_volume_changed(value: float):
    """Handle music volume slider change"""
    var db = (value * 80 / 100) - 80
    AudioServer.set_bus_volume_db(1, db)
    music_volume_value.text = str(int(value)) + "%"
    _save_audio_setting("music_volume", value)
    GameEvents.log_info("Music volume set to %d%%" % int(value))

func _on_sfx_volume_changed(value: float):
    """Handle SFX volume slider change"""
    var db = (value * 80 / 100) - 80
    AudioServer.set_bus_volume_db(2, db)
    sfx_volume_value.text = str(int(value)) + "%"
    _save_audio_setting("sfx_volume", value)
    GameEvents.log_info("SFX volume set to %d%%" % int(value))
    
    # Play volume feedback beep on SFX bus
    if sfx_volume_feedback and sfx_volume_feedback.stream:
        sfx_volume_feedback.play()

# ============================================================================
# GRAPHICS CONTROL HANDLERS
# ============================================================================

func _on_resolution_selected(index: int):
    """Handle resolution dropdown selection"""
    var resolution_text = resolution_option.get_item_text(index)
    var parts = resolution_text.split("x")
    if parts.size() == 2:
        var width = int(parts[0])
        var height = int(parts[1].split(" ")[0])  # Remove "(Current)" if present
        get_window().size = Vector2i(width, height)
        _save_graphics_setting("resolution", resolution_text)
        GameEvents.log_info("Resolution changed to %s" % resolution_text)

func _on_fullscreen_toggled(pressed: bool):
    """Handle fullscreen toggle"""
    var window = get_window()
    if pressed:
        window.mode = Window.MODE_FULLSCREEN
        GameEvents.log_info("Fullscreen enabled")
    else:
        window.mode = Window.MODE_WINDOWED
        GameEvents.log_info("Fullscreen disabled")
    _save_graphics_setting("fullscreen", pressed)

func _on_vsync_toggled(pressed: bool):
    """Handle VSync toggle"""
    if pressed:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
        GameEvents.log_info("VSync enabled")
    else:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
        GameEvents.log_info("VSync disabled")
    _save_graphics_setting("vsync", pressed)

func _on_quality_selected(index: int):
    """Handle graphics quality selection"""
    var quality_names = ["Low", "Medium", "High", "Ultra"]
    var quality_name = quality_names[index]
    _save_graphics_setting("quality", quality_name)
    GameEvents.log_info("Graphics quality set to %s" % quality_name)
    # TODO: Implement actual quality changes

# ============================================================================
# SETTINGS PANEL BACK BUTTONS
# ============================================================================

func _on_audio_back_pressed():
    """Handle audio back button press"""
    _play_button_click()
    GameEvents.log_info("UI: Returning to main settings from audio")
    _show_settings_main()

func _on_graphics_back_pressed():
    """Handle graphics back button press"""
    _play_button_click()
    GameEvents.log_info("UI: Returning to main settings from graphics")
    _show_settings_main()

func _on_controls_back_pressed():
    """Handle controls back button press"""
    _play_button_click()
    GameEvents.log_info("UI: Returning to main settings from controls")
    _show_settings_main()

# ============================================================================
# SETTINGS PERSISTENCE
# ============================================================================

func _save_audio_setting(key: String, value):
    """Save audio setting to config"""
    var config = ConfigFile.new()
    config.load("user://settings.cfg")
    config.set_value("audio", key, value)
    config.save("user://settings.cfg")

func _save_graphics_setting(key: String, value):
    """Save graphics setting to config"""
    var config = ConfigFile.new()
    config.load("user://settings.cfg")
    config.set_value("graphics", key, value)
    config.save("user://settings.cfg")

func _load_settings():
    """Load settings from file"""
    var config = ConfigFile.new()
    var err = config.load("user://settings.cfg")
    
    if err != OK:
        GameEvents.log_info("No settings file found, creating defaults")
        _create_default_settings()
        return
    
    # Load audio settings  
    var master_volume = config.get_value("audio", "master_volume", 100.0)
    var music_volume = config.get_value("audio", "music_volume", 80.0)
    var sfx_volume = config.get_value("audio", "sfx_volume", 90.0)
    
    # Apply audio settings
    AudioServer.set_bus_volume_db(0, (master_volume * 80 / 100) - 80)
    if AudioServer.bus_count > 1:
        AudioServer.set_bus_volume_db(1, (music_volume * 80 / 100) - 80)
    if AudioServer.bus_count > 2:
        AudioServer.set_bus_volume_db(2, (sfx_volume * 80 / 100) - 80)
    
    # Load graphics settings
    var fullscreen = config.get_value("graphics", "fullscreen", false)
    var vsync = config.get_value("graphics", "vsync", true)
    var resolution = config.get_value("graphics", "resolution", "1152x648")
    
    # Apply graphics settings
    var window = get_window()
    var res_parts = resolution.split("x")
    if res_parts.size() == 2:
        window.size = Vector2i(int(res_parts[0]), int(res_parts[1]))
    window.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
    
    GameEvents.log_info("Settings loaded from user://settings.cfg")

func _create_default_settings():
    """Create default settings file"""
    var config = ConfigFile.new()
    
    # Default audio settings
    config.set_value("audio", "master_volume", 100.0)
    config.set_value("audio", "music_volume", 80.0)
    config.set_value("audio", "sfx_volume", 90.0)
    
    # Default graphics settings
    config.set_value("graphics", "fullscreen", false)
    config.set_value("graphics", "vsync", true)
    config.set_value("graphics", "resolution", "1152x648")
    config.set_value("graphics", "quality", "High")
    
    config.save("user://settings.cfg")
    GameEvents.log_info("Default settings created")

# ============================================================================
# SETTINGS FUNCTIONALITY
# ============================================================================

func toggle_fullscreen():
    """Toggle fullscreen mode (F11 shortcut)"""
    if fullscreen_toggle:
        fullscreen_toggle.button_pressed = !fullscreen_toggle.button_pressed
        _on_fullscreen_toggled(fullscreen_toggle.button_pressed)

func toggle_vsync():
    """Toggle VSync (F10 shortcut)"""
    if vsync_toggle:
        vsync_toggle.button_pressed = !vsync_toggle.button_pressed
        _on_vsync_toggled(vsync_toggle.button_pressed)

func toggle_dev_window():
    """Toggle between a small dev window (800x600) and player-friendly size (1920x1080 windowed)"""
    var window = get_window()
    var current_size = window.size
    var target_size = Vector2i(800, 600) if current_size == Vector2i(1920, 1080) else Vector2i(1920, 1080)
    
    window.size = target_size
    GameEvents.log_info("Dev window toggled to %s" % target_size)

# ============================================================================
# GAME EVENT HANDLERS (Legacy - kept for compatibility)
# ============================================================================

func _on_game_state_changed(new_state: GameManager.GameState):
    """Handle game state changes for UI visibility"""
    GameEvents.log_info("UI: Game state changed to %s" % GameManager.GameState.keys()[new_state])
    
    # Update UI visibility using existing function
    _update_ui_state()
    
    # Handle menu music based on state
    match new_state:
        GameManager.GameState.MENU:
            _start_menu_music()
            _stop_game_music()
        GameManager.GameState.IN_GAME:
            _stop_menu_music()
            _start_game_music()
        _:
            # For CONNECTING and other states, don't change music
            pass

func _on_player_connected(player_data):
    GameEvents.log_info("UI: Player %s joined (ID: %d)" % [player_data.name, player_data.id])
    _update_player_count()

func _on_player_disconnected(player_id):
    GameEvents.log_info("UI: Player disconnected (ID: %d)" % player_id)
    _update_player_count()

func _on_connection_status_updated(status_text):
    status_label.text = "Status: " + status_text
    if game_hud.visible:
        hud_connection_status.text = status_text

# ============================================================================
# UI STATE MANAGEMENT
# ============================================================================

func _update_ui_state():
    """Update UI based on current game state"""
    if not GameManager:
        return  # GameManager not ready yet
        
    var current_state = GameManager.get_current_state()
    
    # Update status text
    var status_text = ""
    match current_state:
        GameManager.GameState.MENU:
            status_text = "Ready"
            menu_system.visible = true
            game_hud.visible = false
            menu_background.visible = true
        GameManager.GameState.CONNECTING:
            status_text = "Connecting..."
            menu_system.visible = true
            game_hud.visible = false
            menu_background.visible = true
        GameManager.GameState.IN_GAME:
            status_text = "In Game"
            menu_system.visible = false
            game_hud.visible = true
            menu_background.visible = false
            current_menu_state = MenuState.IN_GAME
        GameManager.GameState.DISCONNECTED:
            status_text = "Disconnected"
            menu_system.visible = true
            game_hud.visible = false
            menu_background.visible = true
            # Return to appropriate menu based on mode
            if GameManager.single_player_mode:
                show_welcome_screen()  # Single player returns to main menu
            else:
                show_multiplayer_screen()  # Multiplayer returns to multiplayer screen
    
    status_label.text = "Status: " + status_text
    _update_player_count()
    
    # Update network stats if in game
    if current_state == GameManager.GameState.IN_GAME:
        _update_network_stats()

func _update_player_count():
    """Update player count display"""
    if not GameManager:
        return  # GameManager not ready yet
        
    var count = GameManager.get_player_count()
    var max_players = 4
    var count_text = "Players: %d/%d" % [count, max_players]
    
    # Update both menu and HUD displays
    # (No players label in new menu design, but keep for HUD)
    if game_hud.visible:
        hud_player_count.text = count_text

func _update_network_stats():
    """Update network statistics display"""
    if not NetworkManager:
        return  # NetworkManager not ready yet
        
    if not NetworkManager.is_game_connected():
        return
    
    var stats = NetworkManager.get_network_stats()
    var stats_text = "Ping: %dms | Sent: %.1fKB | Received: %.1fKB" % [
        stats.get("average_ping", 0),
        stats.get("bytes_sent", 0) / 1024.0,
        stats.get("bytes_received", 0) / 1024.0
    ]
    
    if game_hud.visible:
        hud_network_stats.text = stats_text

# ============================================================================
# PERIODIC UPDATES
# ============================================================================

func _process(_delta):
    # Update network stats periodically when in game
    if GameManager and GameManager.get_current_state() == GameManager.GameState.IN_GAME:
        _update_network_stats()

func _show_game_maker_info():
    """Show Game Maker placeholder information"""
    GameEvents.log_info("Game Maker: Level Editor - Coming Soon!")
    GameEvents.log_info("Game Maker: Future features - Terrain editing, Object placement, Texture painting")
    GameEvents.log_info("Game Maker: Save/Load custom maps, Share with friends")
    GameEvents.log_info("Game Maker: Press ESC or Back button to return to main menu")

func _setup_menu_music():
    """Load and setup the menu music player"""
    if not menu_music_player:
        GameEvents.log_error("Menu music player not found")
        return
        
    var music_path = "res://Audio/awesomeness.wav"
    
    # Check if file exists and is imported
    if ResourceLoader.exists(music_path):
        var music_stream = ResourceLoader.load(music_path)
        if music_stream:
            menu_music_player.stream = music_stream
            GameEvents.log_info("Menu music loaded from %s" % music_path)
        else:
            GameEvents.log_error("Failed to load menu music from %s" % music_path)
    else:
        GameEvents.log_error("Menu music file not found or not imported: %s" % music_path)
        GameEvents.log_info("Please open the project in Godot editor to import audio files")

func _setup_game_music():
    """Load and setup the game music player"""
    if not game_music_player:
        GameEvents.log_error("Game music player not found")
        return
        
    var music_path = "res://Audio/Midnight-HQ.wav"
    
    # Check if file exists and is imported
    if ResourceLoader.exists(music_path):
        var music_stream = ResourceLoader.load(music_path)
        if music_stream:
            game_music_player.stream = music_stream
            GameEvents.log_info("Game music loaded from %s" % music_path)
        else:
            GameEvents.log_error("Failed to load game music from %s" % music_path)
    else:
        GameEvents.log_error("Game music file not found or not imported: %s" % music_path)
        GameEvents.log_info("Please open the project in Godot editor to import audio files")

func _start_menu_music():
    """Start playing menu music if it's loaded and not already playing"""
    if menu_music_player and menu_music_player.stream and not menu_music_player.playing:
        menu_music_player.play()
        GameEvents.log_info("Menu music started")

func _stop_menu_music():
    """Stop playing menu music"""
    if menu_music_player and menu_music_player.playing:
        menu_music_player.stop()
        GameEvents.log_info("Menu music stopped")

func _start_game_music():
    """Start playing game music if it's loaded and not already playing"""
    if game_music_player and game_music_player.stream and not game_music_player.playing:
        game_music_player.play()
        GameEvents.log_info("Game music started")

func _stop_game_music():
    """Stop playing game music"""
    if game_music_player and game_music_player.playing:
        game_music_player.stop()
        GameEvents.log_info("Game music stopped")

func _setup_button_click_sound():
    """Setup the button click sound player"""
    if not button_click_player:
        GameEvents.log_error("Button click player not found")
        return
        
    var sound_path = "res://Audio/MenuSelectionClick.wav"
    
    # Check if file exists and is imported
    if ResourceLoader.exists(sound_path):
        var sound_stream = ResourceLoader.load(sound_path)
        if sound_stream:
            button_click_player.stream = sound_stream
            GameEvents.log_info("Button click sound loaded from %s" % sound_path)
        else:
            GameEvents.log_error("Failed to load button click sound from %s" % sound_path)
    else:
        GameEvents.log_error("Button click sound file not found or not imported: %s" % sound_path)
        GameEvents.log_info("Please open the project in Godot editor to import audio files")

func _play_button_click():
    """Play button click sound"""
    if button_click_player and button_click_player.stream:
        button_click_player.play()

func _setup_background():
    """Load and setup the background image"""
    if not background_image:
        GameEvents.log_error("Background image node not found")
        return
        
    var background_path = "res://Assets/wizards.png"
    
    # Check if file exists and is imported
    if ResourceLoader.exists(background_path):
        var texture = ResourceLoader.load(background_path)
        if texture:
            background_image.texture = texture
            GameEvents.log_info("Background image loaded from %s" % background_path)
        else:
            GameEvents.log_error("Failed to load background image from %s" % background_path)
    else:
        GameEvents.log_error("Background image file not found or not imported: %s" % background_path)
        GameEvents.log_info("Please open the project in Godot editor to import the image")
