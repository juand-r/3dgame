# MainUI.gd - Simplified UI for networking testing
extends CanvasLayer

# UI References
@onready var status_label = $CenterContainer/VBoxContainer/Status

func _ready():
	GameEvents.log_info("Simple MainUI initialized")
	
	# Connect to events
	GameEvents.ui_connection_status_changed.connect(_on_connection_status_changed)
	GameEvents.player_joined.connect(_on_player_joined)
	GameEvents.player_left.connect(_on_player_left)

# Button handlers
func _on_start_server_pressed():
	GameEvents.log_info("UI: Starting server...")
	status_label.text = "Status: Starting server..."
	GameManager.start_server(8080)

func _on_connect_client_pressed():
	GameEvents.log_info("UI: Connecting to server...")
	status_label.text = "Status: Connecting..."
	GameManager.connect_to_server("127.0.0.1", 8080)

# Event handlers
func _on_connection_status_changed(status: String, message: String):
	var display_text = "Status: %s" % status
	if message != "":
		display_text += " - %s" % message
	status_label.text = display_text

func _on_player_joined(player_id: int, player_name: String):
	GameEvents.log_info("UI: Player %s joined (ID: %d)" % [player_name, player_id])

func _on_player_left(player_id: int, player_name: String):
	GameEvents.log_info("UI: Player %s left (ID: %d)" % [player_name, player_id])

# Debug input handling
func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:  # Start server
				_on_start_server_pressed()
			KEY_F2:  # Connect client
				_on_connect_client_pressed()
			KEY_F3:  # Disconnect
				if GameManager.is_server:
					GameManager.stop_server()
				elif GameManager.is_client:
					GameManager.disconnect_from_server()
			KEY_F12: # Debug info
				GameManager.print_debug_info()
				if NetworkManager and is_instance_valid(NetworkManager) and NetworkManager._implementation:
					NetworkManager._implementation.print_debug_info() 