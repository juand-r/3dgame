# MainUI.gd - Multiplayer Game UI Handler
# Handles the main menu interface and networking status updates
extends CanvasLayer

# UI References
@onready var main_menu = $MainMenu
@onready var game_hud = $GameHUD

# Input fields
@onready var port_input = $MainMenu/ServerSection/PortInput
@onready var address_input = $MainMenu/ClientSection/AddressInput
@onready var client_port_input = $MainMenu/ClientSection/ClientPortInput

# Status labels
@onready var status_label = $MainMenu/StatusSection/StatusLabel
@onready var players_label = $MainMenu/StatusSection/PlayersLabel

# GameHUD elements
@onready var hud_connection_status = $GameHUD/TopLeft/ConnectionStatus
@onready var hud_player_count = $GameHUD/TopLeft/PlayerCount
@onready var hud_network_stats = $GameHUD/TopLeft/NetworkStats

func _ready():
    GameEvents.log_info("MainUI initialized")
    
    # Connect to game events
    GameEvents.game_state_changed.connect(_on_game_state_changed)
    GameEvents.player_connected.connect(_on_player_connected)
    GameEvents.player_disconnected.connect(_on_player_disconnected)
    GameEvents.connection_status_updated.connect(_on_connection_status_updated)
    
    # Initialize UI state
    _update_ui_state()

# Input handling moved to GameManager - UI uses buttons instead

# ============================================================================
# BUTTON SIGNAL METHODS
# ============================================================================

func _on_start_server_button_pressed():
    GameEvents.log_info("UI: Starting server...")
    var port = int(port_input.text) if port_input.text else 8080
    GameManager.start_server(port)

func _on_connect_button_pressed():
    GameEvents.log_info("UI: Connecting to server...")
    var address = address_input.text if address_input.text else "127.0.0.1"
    var port = int(client_port_input.text) if client_port_input.text else 8080
    GameManager.connect_to_server(address, port)

func _on_disconnect_button_pressed():
    GameEvents.log_info("UI: Disconnecting...")
    GameManager.disconnect_game()

func _on_test_message_button_pressed():
    GameEvents.log_info("UI: Sending test message...")
    if NetworkManager.is_game_connected():
        # Send a test message through the network
        var test_data = {
            "type": "test_message",
            "message": "Hello from client!",
            "timestamp": Time.get_unix_time_from_system()
        }
        NetworkManager.send_data(test_data)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_game_state_changed(new_state):
    GameEvents.log_info("UI: Game state changed to %s" % GameManager.GameState.keys()[new_state])
    _update_ui_state()

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
    if not GameManager:
        return  # GameManager not ready yet
        
    var current_state = GameManager.get_current_state()
    
    # Update status text
    var status_text = ""
    match current_state:
        GameManager.GameState.MENU:
            status_text = "Ready"
            main_menu.visible = true
            game_hud.visible = false
        GameManager.GameState.CONNECTING:
            status_text = "Connecting..."
            main_menu.visible = true
            game_hud.visible = false
        GameManager.GameState.IN_GAME:
            status_text = "In Game"
            main_menu.visible = false
            game_hud.visible = true
        GameManager.GameState.DISCONNECTED:
            status_text = "Disconnected"
            main_menu.visible = true
            game_hud.visible = false
    
    status_label.text = "Status: " + status_text
    _update_player_count()
    
    # Update network stats if in game
    if current_state == GameManager.GameState.IN_GAME:
        _update_network_stats()

func _update_player_count():
    if not GameManager:
        return  # GameManager not ready yet
        
    var count = GameManager.get_player_count()
    var max_players = 4
    var count_text = "Players: %d/%d" % [count, max_players]
    
    players_label.text = count_text
    if game_hud.visible:
        hud_player_count.text = count_text

func _update_network_stats():
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

func _toggle_debug_info():
    # Toggle between main menu and game HUD for debugging
    if main_menu.visible:
        main_menu.visible = false
        game_hud.visible = true
    else:
        main_menu.visible = true
        game_hud.visible = false

# ============================================================================
# PERIODIC UPDATES
# ============================================================================

func _process(_delta):
    # Update network stats periodically when in game
    if GameManager and GameManager.get_current_state() == GameManager.GameState.IN_GAME:
        _update_network_stats()
