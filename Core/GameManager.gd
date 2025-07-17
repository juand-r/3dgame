# GameManager.gd - Main Game Coordinator
# Manages overall game state, player connections, and scene transitions
extends Node

# ============================================================================
# GAME STATE
# ============================================================================

enum GameState {
	MENU,
	CONNECTING,
	IN_GAME,
	PAUSED,
	DISCONNECTED
}

var current_state: GameState = GameState.MENU
var is_server: bool = false
var is_client: bool = false
var max_players: int = 4
var server_port: int = 8080

# Player management
var connected_players: Dictionary = {}  # player_id -> player_data
var local_player_id: int = -1
var local_player_name: String = "Player"

# World management
var current_world_scene: Node = null
var spawn_points: Array[Vector3] = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	GameEvents.log_info("GameManager initialized")
	
	# Connect to network events
	GameEvents.server_started.connect(_on_server_started)
	GameEvents.server_stopped.connect(_on_server_stopped)
	GameEvents.client_connected_to_server.connect(_on_client_connected_to_server)
	GameEvents.client_disconnected_from_server.connect(_on_client_disconnected_from_server)
	GameEvents.player_joined.connect(_on_player_joined)
	GameEvents.player_left.connect(_on_player_left)
	GameEvents.network_error.connect(_on_network_error)
	
	# Connect to world events
	GameEvents.world_loaded.connect(_on_world_loaded)
	GameEvents.world_unloaded.connect(_on_world_unloaded)
	
	# Set up basic spawn points (will be replaced when world loads)
	setup_default_spawn_points()
	
	# Show main menu
	change_state(GameState.MENU)

# ============================================================================
# GAME STATE MANAGEMENT
# ============================================================================

func change_state(new_state: GameState):
	var old_state = current_state
	current_state = new_state
	
	GameEvents.log_info("Game state changed: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	
	match current_state:
		GameState.MENU:
			GameEvents.ui_show_main_menu.emit()
		GameState.CONNECTING:
			GameEvents.ui_show_connection_dialog.emit()
		GameState.IN_GAME:
			GameEvents.ui_show_game_hud.emit()
		GameState.PAUSED:
			# Keep current UI, just pause game logic
			pass
		GameState.DISCONNECTED:
			cleanup_connections()
			GameEvents.ui_show_main_menu.emit()

# ============================================================================
# SERVER MANAGEMENT
# ============================================================================

func start_server(port: int = 8080) -> bool:
	GameEvents.log_info("Attempting to start server on port %d" % port)
	
	if is_server or is_client:
		GameEvents.log_error("Cannot start server: already connected")
		return false
	
	server_port = port
	change_state(GameState.CONNECTING)
	
	# Create local player entry
	local_player_id = 1  # Server is always player 1
	add_player(local_player_id, local_player_name)
	
	# Tell NetworkManager to start server
	var success = NetworkManager.start_server(port)
	
	if success:
		is_server = true
		GameEvents.log_info("Server started successfully")
		load_game_world()
	else:
		GameEvents.log_error("Failed to start server")
		change_state(GameState.MENU)
	
	return success

func stop_server():
	if not is_server:
		return
	
	GameEvents.log_info("Stopping server")
	
	NetworkManager.stop_server()
	cleanup_connections()
	change_state(GameState.MENU)

# ============================================================================
# CLIENT MANAGEMENT
# ============================================================================

func connect_to_server(address: String, port: int = 8080) -> bool:
	GameEvents.log_info("Attempting to connect to server %s:%d" % [address, port])
	
	if is_server or is_client:
		GameEvents.log_error("Cannot connect: already connected")
		return false
	
	change_state(GameState.CONNECTING)
	
	var success = NetworkManager.connect_to_server(address, port)
	
	if success:
		is_client = true
		GameEvents.log_info("Connected to server successfully")
	else:
		GameEvents.log_error("Failed to connect to server")
		change_state(GameState.MENU)
	
	return success

func disconnect_from_server():
	if not is_client:
		return
	
	GameEvents.log_info("Disconnecting from server")
	
	NetworkManager.disconnect_from_server()
	cleanup_connections()
	change_state(GameState.MENU)

# ============================================================================
# PLAYER MANAGEMENT
# ============================================================================

func add_player(player_id: int, player_name: String):
	var player_data = {
		"id": player_id,
		"name": player_name,
		"position": Vector3.ZERO,
		"rotation": Vector3.ZERO,
		"in_vehicle": false,
		"vehicle_id": -1
	}
	
	connected_players[player_id] = player_data
	GameEvents.log_info("Player added: %s (ID: %d)" % [player_name, player_id])
	GameEvents.ui_player_count_changed.emit(connected_players.size(), max_players)

func remove_player(player_id: int):
	if player_id in connected_players:
		var player_name = connected_players[player_id].name
		connected_players.erase(player_id)
		GameEvents.log_info("Player removed: %s (ID: %d)" % [player_name, player_id])
		GameEvents.ui_player_count_changed.emit(connected_players.size(), max_players)

func get_player_data(player_id: int) -> Dictionary:
	return connected_players.get(player_id, {})

func get_next_spawn_point() -> Vector3:
	if spawn_points.is_empty():
		GameEvents.log_warning("No spawn points available, using origin")
		return Vector3.ZERO
	
	# For now, just cycle through spawn points
	var index = connected_players.size() % spawn_points.size()
	return spawn_points[index]

# ============================================================================
# WORLD MANAGEMENT
# ============================================================================

func load_game_world():
	GameEvents.log_info("Loading game world")
	
	# Load the test world scene
	var world_scene = preload("res://Scenes/World/TestWorld.tscn")
	current_world_scene = world_scene.instantiate()
	
	# Add to scene tree
	get_tree().current_scene.add_child(current_world_scene)
	
	# Update spawn points from world
	update_spawn_points_from_world()
	
	GameEvents.world_loaded.emit()
	change_state(GameState.IN_GAME)

func unload_game_world():
	if current_world_scene:
		GameEvents.log_info("Unloading game world")
		current_world_scene.queue_free()
		current_world_scene = null
		GameEvents.world_unloaded.emit()

func update_spawn_points_from_world():
	spawn_points.clear()
	
	if current_world_scene:
		# Look for spawn point nodes
		var spawn_nodes = current_world_scene.find_children("*", "Marker3D")
		for node in spawn_nodes:
			if "spawn" in node.name.to_lower():
				spawn_points.append(node.global_position)
	
	# Ensure we have at least some spawn points
	if spawn_points.is_empty():
		setup_default_spawn_points()
	
	GameEvents.log_info("Updated spawn points: %d available" % spawn_points.size())

func setup_default_spawn_points():
	spawn_points = [
		Vector3(0, 1, 0),
		Vector3(5, 1, 0),
		Vector3(-5, 1, 0),
		Vector3(0, 1, 5)
	]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func cleanup_connections():
	is_server = false
	is_client = false
	connected_players.clear()
	local_player_id = -1
	unload_game_world()
	
	GameEvents.ui_player_count_changed.emit(0, max_players)
	GameEvents.log_info("Connections cleaned up")

func is_local_player(player_id: int) -> bool:
	return player_id == local_player_id

func get_local_player_data() -> Dictionary:
	return get_player_data(local_player_id)

# ============================================================================
# EVENT HANDLERS
# ============================================================================

func _on_server_started(port: int):
	GameEvents.emit_connection_status("SERVER_RUNNING", "Server running on port %d" % port)

func _on_server_stopped():
	GameEvents.emit_connection_status("DISCONNECTED", "Server stopped")

func _on_client_connected_to_server(address: String, port: int):
	GameEvents.emit_connection_status("CONNECTED", "Connected to %s:%d" % [address, port])

func _on_client_disconnected_from_server():
	GameEvents.emit_connection_status("DISCONNECTED", "Disconnected from server")
	change_state(GameState.DISCONNECTED)

func _on_player_joined(player_id: int, player_name: String):
	add_player(player_id, player_name)
	
	# Spawn player at appropriate location
	var spawn_pos = get_next_spawn_point()
	GameEvents.player_spawned.emit(player_id, spawn_pos)

func _on_player_left(player_id: int, player_name: String):
	remove_player(player_id)

func _on_network_error(error_message: String):
	GameEvents.log_error("Network error: %s" % error_message)
	change_state(GameState.DISCONNECTED)

func _on_world_loaded():
	GameEvents.log_info("World loaded successfully")

func _on_world_unloaded():
	GameEvents.log_info("World unloaded successfully")

# ============================================================================
# DEBUG & TESTING
# ============================================================================

# Quick test functions for development
func _input(event):
	if not OS.is_debug_build():
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:  # Start server
				if current_state == GameState.MENU:
					start_server()
			KEY_F2:  # Connect to localhost
				if current_state == GameState.MENU:
					connect_to_server("127.0.0.1")
			KEY_F3:  # Disconnect
				if is_server:
					stop_server()
				elif is_client:
					disconnect_from_server()
			KEY_F12:  # Debug info
				print_debug_info()

func print_debug_info():
	GameEvents.log_debug("=== GAME MANAGER DEBUG INFO ===")
	GameEvents.log_debug("State: %s" % GameState.keys()[current_state])
	GameEvents.log_debug("Is Server: %s" % is_server)
	GameEvents.log_debug("Is Client: %s" % is_client)
	GameEvents.log_debug("Connected Players: %d" % connected_players.size())
	GameEvents.log_debug("Local Player ID: %d" % local_player_id)
	GameEvents.log_debug("Spawn Points: %d" % spawn_points.size()) 