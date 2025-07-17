# MainUI.gd - Main UI Controller
# Handles menu interactions and provides networking test interface
extends CanvasLayer

# ============================================================================
# UI REFERENCES
# ============================================================================

# Main Menu Elements
@onready var main_menu = $MainMenu
@onready var game_hud = $GameHUD

# Server Section
@onready var port_input = $MainMenu/ServerSection/PortInput
@onready var start_server_button = $MainMenu/ServerSection/StartServerButton

# Client Section  
@onready var address_input = $MainMenu/ClientSection/AddressInput
@onready var client_port_input = $MainMenu/ClientSection/ClientPortInput
@onready var connect_button = $MainMenu/ClientSection/ConnectButton

# Status Section
@onready var status_label = $MainMenu/StatusSection/StatusLabel
@onready var players_label = $MainMenu/StatusSection/PlayersLabel

# Action Section
@onready var disconnect_button = $MainMenu/ActionSection/DisconnectButton
@onready var test_message_button = $MainMenu/ActionSection/TestMessageButton

# Game HUD Elements
@onready var hud_connection_status = $GameHUD/TopLeft/ConnectionStatus
@onready var hud_player_count = $GameHUD/TopLeft/PlayerCount
@onready var hud_network_stats = $GameHUD/TopLeft/NetworkStats

# ============================================================================
# STATE VARIABLES
# ============================================================================

var current_ui_state: String = "MENU"  # MENU, CONNECTING, IN_GAME

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	GameEvents.log_info("MainUI initialized")
	
	# Connect to GameEvents
	GameEvents.ui_show_main_menu.connect(_on_show_main_menu)
	GameEvents.ui_show_connection_dialog.connect(_on_show_connection_dialog)
	GameEvents.ui_show_game_hud.connect(_on_show_game_hud)
	GameEvents.ui_connection_status_changed.connect(_on_connection_status_changed)
	GameEvents.ui_player_count_changed.connect(_on_player_count_changed)
	
	# Connect to network events for debugging
	GameEvents.network_data_received.connect(_on_network_data_received)
	
	# Start with main menu
	show_main_menu()
	
	# Set up update timer for network stats
	var timer = Timer.new()
	timer.wait_time = 1.0  # Update every second
	timer.timeout.connect(_update_network_stats)
	timer.autostart = true
	add_child(timer)

# ============================================================================
# UI STATE MANAGEMENT
# ============================================================================

func show_main_menu():
	current_ui_state = "MENU"
	main_menu.visible = true
	game_hud.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameEvents.log_info("UI: Showing main menu")

func show_connection_dialog():
	current_ui_state = "CONNECTING"
	# Keep menu visible but disable some buttons
	_update_button_states()
	GameEvents.log_info("UI: Showing connection dialog")

func show_game_hud():
	current_ui_state = "IN_GAME"
	main_menu.visible = false
	game_hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameEvents.log_info("UI: Showing game HUD")

func _update_button_states():
	var is_connecting = (current_ui_state == "CONNECTING")
	var is_connected = GameManager.is_server or GameManager.is_client
	
	start_server_button.disabled = is_connecting or is_connected
	connect_button.disabled = is_connecting or is_connected
	disconnect_button.disabled = not is_connected
	test_message_button.disabled = not is_connected

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func _on_start_server_button_pressed():
	var port = int(port_input.text)
	if port <= 0 or port > 65535:
		port = 8080
		port_input.text = "8080"
	
	GameEvents.log_info("UI: Starting server on port %d" % port)
	GameManager.start_server(port)

func _on_connect_button_pressed():
	var address = address_input.text.strip_edges()
	var port = int(client_port_input.text)
	
	if address == "":
		address = "127.0.0.1"
		address_input.text = address
	
	if port <= 0 or port > 65535:
		port = 8080
		client_port_input.text = "8080"
	
	GameEvents.log_info("UI: Connecting to %s:%d" % [address, port])
	GameManager.connect_to_server(address, port)

func _on_disconnect_button_pressed():
	GameEvents.log_info("UI: Disconnecting...")
	
	if GameManager.is_server:
		GameManager.stop_server()
	elif GameManager.is_client:
		GameManager.disconnect_from_server()

func _on_test_message_button_pressed():
	GameEvents.log_info("UI: Sending test message")
	
	# Send a test chat message
	if NetworkManager:
		NetworkManager.send_chat_message("Hello from MainUI! Time: %s" % Time.get_datetime_string_from_system())

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_show_main_menu():
	show_main_menu()

func _on_show_connection_dialog():
	show_connection_dialog()

func _on_show_game_hud():
	show_game_hud()

func _on_connection_status_changed(status: String, message: String):
	var display_text = "Status: %s" % status
	if message != "":
		display_text += " - %s" % message
	
	status_label.text = display_text
	
	if game_hud.visible:
		hud_connection_status.text = display_text
	
	_update_button_states()

func _on_player_count_changed(count: int, max_count: int):
	var display_text = "Players: %d/%d" % [count, max_count]
	players_label.text = display_text
	
	if game_hud.visible:
		hud_player_count.text = display_text

func _on_network_data_received(from_id: int, data: Dictionary):
	# Log received network data for debugging
	var message_type = data.get("type", "unknown")
	GameEvents.log_debug("UI: Received %s from player %d" % [message_type, from_id])

# ============================================================================
# NETWORK STATISTICS
# ============================================================================

func _update_network_stats():
	if not game_hud.visible:
		return
	
	if NetworkManager and NetworkManager._implementation:
		var stats = NetworkManager.get_network_stats()
		
		var ping = stats.get("average_ping", 0)
		var sent_kb = stats.get("bytes_sent", 0) / 1024.0
		var received_kb = stats.get("bytes_received", 0) / 1024.0
		
		var stats_text = "Ping: %dms | Sent: %.1fKB | Received: %.1fKB" % [ping, sent_kb, received_kb]
		hud_network_stats.text = stats_text

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if current_ui_state == "IN_GAME":
					# Return to menu
					if GameManager.is_server:
						GameManager.stop_server()
					elif GameManager.is_client:
						GameManager.disconnect_from_server()
			
			KEY_F4:  # Toggle debug info
				if current_ui_state == "IN_GAME":
					_print_debug_info()
			
			KEY_T:  # Quick test message (only in game)
				if current_ui_state == "IN_GAME" and NetworkManager:
					NetworkManager.send_chat_message("Quick test from F key!")

# ============================================================================
# DEBUG FUNCTIONS
# ============================================================================

func _print_debug_info():
	GameEvents.log_debug("=== UI DEBUG INFO ===")
	GameEvents.log_debug("Current UI State: %s" % current_ui_state)
	GameEvents.log_debug("Main Menu Visible: %s" % main_menu.visible)
	GameEvents.log_debug("Game HUD Visible: %s" % game_hud.visible)
	GameEvents.log_debug("Mouse Mode: %s" % Input.mouse_mode)
	
	# Print network stats
	if NetworkManager and NetworkManager._implementation:
		var stats = NetworkManager.get_network_stats()
		for key in stats.keys():
			GameEvents.log_debug("Network %s: %s" % [key, stats[key]])

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func set_status_message(message: String, is_error: bool = false):
	var color = Color.RED if is_error else Color.WHITE
	status_label.modulate = color
	status_label.text = "Status: %s" % message

func get_server_port() -> int:
	return int(port_input.text) if port_input.text.is_valid_int() else 8080

func get_client_address() -> String:
	return address_input.text.strip_edges() if address_input.text.strip_edges() != "" else "127.0.0.1"

func get_client_port() -> int:
	return int(client_port_input.text) if client_port_input.text.is_valid_int() else 8080

# ============================================================================
# TESTING HELPERS
# ============================================================================

# For automated testing
func simulate_start_server():
	_on_start_server_button_pressed()

func simulate_connect_to_server():
	_on_connect_button_pressed()

func simulate_disconnect():
	_on_disconnect_button_pressed()

func simulate_test_message():
	_on_test_message_button_pressed() 