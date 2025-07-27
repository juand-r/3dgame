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

# Headless server configuration (easily toggleable for testing)
@export var headless_server_mode: bool = false  # Can be toggled in editor for testing
@export var dedicated_server: bool = false      # Command line will set this
@export var allow_server_player: bool = true    # Easy toggle for server player spawning

# Player management
var connected_players: Dictionary = {}  # player_id -> player_data
var spawned_players: Dictionary = {}  # player_id -> PlayerController instance
var local_player_id: int = -1
var local_player_name: String = "Player"

# World management
var current_world_scene: Node = null
var spawn_points: Array[Vector3] = []

# Player scene reference
const PlayerScene = preload("res://Scenes/Player/Player.tscn")

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	GameEvents.log_info("GameManager initialized")
	
	# Parse command line arguments for headless server mode
	_parse_command_line_arguments()
	# Connect to network events
	GameEvents.server_started.connect(_on_server_started)
	GameEvents.server_stopped.connect(_on_server_stopped)
	GameEvents.client_connected_to_server.connect(_on_client_connected_to_server)
	GameEvents.client_disconnected_from_server.connect(_on_client_disconnected_from_server)
	GameEvents.player_joined.connect(_on_player_joined)
	GameEvents.player_left.connect(_on_player_left)
	GameEvents.player_spawned.connect(_on_player_spawned)
	GameEvents.player_position_updated.connect(_on_player_position_updated)
	GameEvents.network_error.connect(_on_network_error)
	
	# Connect to world events
	GameEvents.world_loaded.connect(_on_world_loaded)
	GameEvents.world_unloaded.connect(_on_world_unloaded)
	
	# Set up basic spawn points (will be replaced when world loads)
	setup_default_spawn_points()
	
	# Show main menu (unless we're a dedicated server)
	if dedicated_server:
		setup_dedicated_server()
	else:
		change_state(GameState.MENU)

# ============================================================================
# COMMAND LINE ARGUMENT PARSING
# ============================================================================

func _parse_command_line_arguments():
	"""Parse command line arguments for server deployment modes"""
	var args = OS.get_cmdline_args()
	
	GameEvents.log_info("Command line args: %s" % str(args))
	
	for arg in args:
		match arg:
			"--server":
				dedicated_server = true
				headless_server_mode = true
				allow_server_player = false  # Dedicated servers don't spawn local players
				GameEvents.log_info("Command line: Dedicated server mode enabled")
			"--headless":
				headless_server_mode = true
				GameEvents.log_info("Command line: Headless mode enabled")
			"--with-server-player":
				allow_server_player = true  # Override for testing dedicated server with player
				GameEvents.log_info("Command line: Server player enabled (testing mode)")
			"--port":
				# Next argument should be port number
				var port_index = args.find("--port") + 1
				if port_index < args.size():
					server_port = int(args[port_index])
					GameEvents.log_info("Command line: Port set to %d" % server_port)
	
	# Log final configuration
	GameEvents.log_info("=== SERVER CONFIGURATION ===")
	GameEvents.log_info("Dedicated Server: %s" % dedicated_server)
	GameEvents.log_info("Headless Mode: %s" % headless_server_mode) 
	GameEvents.log_info("Allow Server Player: %s" % allow_server_player)
	GameEvents.log_info("Server Port: %d" % server_port)

func setup_dedicated_server():
	"""Initialize dedicated server mode (no GUI, no local player)"""
	GameEvents.log_info("Setting up dedicated server mode")
	
	is_server = true
	is_client = false
	local_player_id = -1  # Dedicated server has no local player
	
	# Defer server startup to next frame to ensure NetworkManager is fully ready
	call_deferred("_start_dedicated_server_deferred")

func _start_dedicated_server_deferred():
	"""Start the dedicated server after NetworkManager is fully initialized"""
	# Double-check that NetworkManager is ready
	if not NetworkManager:
		GameEvents.log_error("NetworkManager still not available")
		get_tree().quit(1)
		return
	
	GameEvents.log_info("Starting dedicated server on port %d" % server_port)
	var success = NetworkManager.start_server(server_port)
	
	if success:
		GameEvents.log_info("Dedicated server started successfully - waiting for clients")
		load_game_world()  # Load world for coordinating players
	else:
		GameEvents.log_error("Failed to start dedicated server")
		get_tree().quit(1)  # Exit with error code

# ============================================================================
# GAME STATE MANAGEMENT
# ============================================================================

func change_state(new_state: GameState):
	var old_state = current_state
	current_state = new_state
	
	GameEvents.log_info("Game state changed: %s -> %s" % [GameState.keys()[old_state], GameState.keys()[new_state]])
	GameEvents.game_state_changed.emit(new_state)
	
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
		# Client transitions to IN_GAME after successful connection
		change_state(GameState.IN_GAME)
		# Defer client world setup to next frame to allow WebSocket to fully establish
		call_deferred("setup_client_world")
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

func get_spawn_point_for_player(player_id: int) -> Vector3:
	# Use deterministic player ID-based assignment to ensure different spawn points
	var spawn_index = abs(player_id) % spawn_points.size()
	var spawn_pos = spawn_points[spawn_index]
	GameEvents.log_debug("DEBUG: Player %d assigned to spawn_points[%d] = %s (based on player_id %% %d)" % [player_id, spawn_index, spawn_pos, spawn_points.size()])
	return spawn_pos

func spawn_player(player_id: int, position: Vector3):
	if player_id in spawned_players:
		GameEvents.log_warning("Player %d already spawned" % player_id)
		return
	
	if not current_world_scene:
		GameEvents.log_error("Cannot spawn player: no world loaded")
		return
	
	GameEvents.log_debug("SPAWN DEBUG: Spawning player %d at position %s" % [player_id, position])
	
	# Create player instance
	var player_instance = PlayerScene.instantiate()
	
	# Determine if this is the local player
	var is_local = false
	if is_server and player_id == 1:
		is_local = true  # Server is always local player ID 1
	elif is_client and player_id == local_player_id:
		is_local = true  # Client's own player should be local
	
	GameEvents.log_debug("Player %d - is_local: %s (server: %s, client: %s, local_player_id: %s)" % [player_id, is_local, is_server, is_client, local_player_id])
	
	# Set player data
	player_instance.set_player_data(player_id, is_local)
	
	# Add to world first
	current_world_scene.add_child(player_instance)
	
	# Then set position (after it's in the tree)
	player_instance.global_position = position
	
	GameEvents.log_debug("SPAWN DEBUG: Player %d final position after adding to tree: %s" % [player_id, player_instance.global_position])
	
	# Track spawned player
	spawned_players[player_id] = player_instance
	
	GameEvents.log_info("Player %d spawned at %s (local: %s)" % [player_id, position, is_local])
	
	# Debug: Show spatial context for multiplayer understanding
	if spawned_players.size() > 1:
		GameEvents.log_debug("=== SPATIAL DEBUG ===")
		for existing_id in spawned_players.keys():
			var existing_player = spawned_players[existing_id]
			var dist = existing_player.global_position.distance_to(position) if existing_player != player_instance else 0.0
			var local_marker = "(YOU)" if existing_player.is_local_player else "(REMOTE)"
			GameEvents.log_debug("Player %d %s at %s - Distance: %.2f" % [existing_id, local_marker, existing_player.global_position, dist])
		GameEvents.log_debug("==================")
	
	# If this is the local player, store the reference
	if is_local:
		local_player_id = player_id

func despawn_player(player_id: int):
	if player_id in spawned_players:
		var player_instance = spawned_players[player_id]
		player_instance.queue_free()
		spawned_players.erase(player_id)
		GameEvents.log_info("Player %d despawned" % player_id)
		
		# Clear local player reference if needed
		if player_id == local_player_id:
			local_player_id = -1

func broadcast_existing_players_to_new_client(new_client_id: int):
	"""Send current positions of all existing players to a newly connected client"""
	GameEvents.log_info("Broadcasting existing player positions to new client %d" % new_client_id)
	
	for existing_player_id in spawned_players.keys():
		# Don't send the new client's own player back to them
		if existing_player_id == new_client_id:
			continue
			
		var existing_player = spawned_players[existing_player_id]
		if existing_player:
			# Create a position update message for this existing player
			var position_data = {
				"type": "player_position",
				"player_id": existing_player_id,
				"pos_x": existing_player.global_position.x,
				"pos_y": existing_player.global_position.y,
				"pos_z": existing_player.global_position.z,
				"rot_x": existing_player.rotation.x,
				"rot_y": existing_player.rotation.y,
				"rot_z": existing_player.rotation.z,
				"vel_x": existing_player.velocity.x,
				"vel_y": existing_player.velocity.y,
				"vel_z": existing_player.velocity.z,
				"timestamp": Time.get_ticks_msec(),
				"is_grounded": existing_player.is_on_floor()
			}
			
			# Send this existing player's position to the new client
			NetworkManager.send_data(position_data, new_client_id)
			GameEvents.log_debug("Sent existing player %d position to new client %d: %s" % [existing_player_id, new_client_id, existing_player.global_position])

func broadcast_new_player_to_existing_clients(new_player_id: int, spawn_position: Vector3):
	"""Send new player's spawn data to all existing clients"""
	print("DEBUG SERVER: Broadcasting new player %d to existing clients" % new_player_id)
	GameEvents.log_info("Broadcasting new player %d to existing clients" % new_player_id)
	
	# DEBUG: Show what clients we're iterating over
	print("DEBUG SERVER: connected_players.keys() = %s" % connected_players.keys())
	GameEvents.log_debug("DEBUG: connected_players.keys() = %s" % connected_players.keys())
	
	for existing_client_id in connected_players.keys():
		# Don't send to the new player themselves
		if existing_client_id == new_player_id:
			print("DEBUG SERVER: Skipping new player %d (don't send to self)" % existing_client_id)
			GameEvents.log_debug("DEBUG: Skipping new player %d (don't send to self)" % existing_client_id)
			continue
		
		print("DEBUG SERVER: About to send player_spawn message to existing client %d" % existing_client_id)
		GameEvents.log_debug("DEBUG: About to send player_spawn message to existing client %d" % existing_client_id)
		
		# Create spawn notification for this new player
		var spawn_data = {
			"type": "player_spawn",
			"player_id": new_player_id,
			"pos_x": spawn_position.x,
			"pos_y": spawn_position.y,
			"pos_z": spawn_position.z,
			"timestamp": Time.get_ticks_msec()
		}
		
		NetworkManager.send_message_to_client(existing_client_id, spawn_data)
		print("DEBUG SERVER: player_spawn message sent to existing client %d" % existing_client_id)
		GameEvents.log_debug("DEBUG: player_spawn message sent to existing client %d" % existing_client_id)

func _broadcast_new_player_after_spawn(player_id: int):
	"""Broadcast new player position after physics adjustment (deferred call)"""
	GameEvents.log_debug("DEBUG: _broadcast_new_player_after_spawn called for player %d" % player_id)
	
	# Get the actual spawned player's current position (after physics adjustment)
	if player_id in spawned_players:
		var player_instance = spawned_players[player_id]
		var actual_position = player_instance.global_position
		
		GameEvents.log_debug("DEBUG: Broadcasting actual position %s for player %d (after physics)" % [actual_position, player_id])
		broadcast_new_player_to_existing_clients(player_id, actual_position)
		print("PRINT DEBUG: broadcast_new_player_to_existing_clients completed with actual position")
		GameEvents.log_debug("DEBUG: broadcast_new_player_to_existing_clients completed with actual position")
	else:
		GameEvents.log_warning("WARNING: Player %d not found in spawned_players during deferred broadcast" % player_id)

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
	
	# TEMPORARILY DISABLED: Use default spawn points instead of world markers
	# This ensures server and client use identical spawn points
	# 
	# if current_world_scene:
	#     # Look for spawn point nodes
	#     var spawn_nodes = current_world_scene.find_children("*", "Marker3D")
	#     for node in spawn_nodes:
	#         if "spawn" in node.name.to_lower():
	#             spawn_points.append(node.global_position)
	
	# Always use default spawn points for now
	setup_default_spawn_points()
	
	GameEvents.log_info("Updated spawn points: %d available (using defaults)" % spawn_points.size())

func setup_default_spawn_points():
	spawn_points = [
		Vector3(0, 1, 0),      # Spawn point 0 - origin
		Vector3(2, 1, 0),      # Spawn point 1 - 2 units right
		Vector3(-2, 1, 0),     # Spawn point 2 - 2 units left  
		Vector3(0, 1, 2)       # Spawn point 3 - 2 units forward
	]

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func cleanup_connections():
	is_server = false
	is_client = false
	connected_players.clear()
	
	# Despawn all players
	for player_id in spawned_players.keys():
		despawn_player(player_id)
	
	local_player_id = -1
	unload_game_world()
	
	GameEvents.ui_player_count_changed.emit(0, max_players)
	GameEvents.log_info("Connections cleaned up")

func is_local_player(player_id: int) -> bool:
	return player_id == local_player_id

func get_local_player_data() -> Dictionary:
	return get_player_data(local_player_id)

func on_client_id_assigned(assigned_id: int):
	"""Handle client ID assignment from server"""
	print("DEBUG: GameManager: Client ID assigned by server: %d" % assigned_id)
	GameEvents.log_info("GameManager: Client ID assigned by server: %d" % assigned_id)
	
	# Update our local player ID to match server assignment
	if is_client and local_player_id == -1:
		local_player_id = assigned_id
		print("DEBUG: Updated local player ID to server-assigned ID: %d" % assigned_id)
		GameEvents.log_info("Updated local player ID to server-assigned ID: %d" % assigned_id)
		
		# Update connected players data from -1 to real ID
		if -1 in connected_players:
			var player_data = connected_players[-1]
			player_data.id = assigned_id
			connected_players[assigned_id] = player_data
			connected_players.erase(-1)
			print("DEBUG: Updated connected player data from -1 to %d" % assigned_id)
			GameEvents.log_info("Updated connected player data from -1 to %d" % assigned_id)
		
		# NOW spawn the local player with the correct server-assigned ID
		print("DEBUG: About to spawn local player with correct ID %d" % assigned_id)
		var spawn_pos = get_spawn_point_for_player(assigned_id)
		print("DEBUG: Spawn position for player %d: %s" % [assigned_id, spawn_pos])
		spawn_player(assigned_id, spawn_pos)
		print("DEBUG: Local player spawned with correct ID %d at %s" % [assigned_id, spawn_pos])

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
	print("PRINT DEBUG: GameManager._on_player_joined called with player_id: ", player_id, ", player_name: ", player_name)
	GameEvents.log_debug("DEBUG: GameManager._on_player_joined called with player_id: %d, player_name: %s" % [player_id, player_name])
	add_player(player_id, player_name)
	
	# Emit player connected signal for UI
	var player_data = {"id": player_id, "name": player_name}
	GameEvents.player_connected.emit(player_data)
	
	# Spawn player at appropriate location using deterministic assignment
	var spawn_pos = get_spawn_point_for_player(player_id)
	GameEvents.player_spawned.emit(player_id, spawn_pos)
	
	# NEW: Broadcast existing player positions to the new client
	broadcast_existing_players_to_new_client(player_id)
	
	# FIXED: Wait for player to be spawned and physics-adjusted, then broadcast actual position
	print("PRINT DEBUG: About to call call_deferred for broadcast after spawn")
	GameEvents.log_debug("DEBUG: Deferring broadcast until after player spawn and physics adjustment")
	call_deferred("_broadcast_new_player_after_spawn", player_id)

func _on_player_left(player_id: int, player_name: String):
	remove_player(player_id)
	
	# Despawn player
	despawn_player(player_id)
	
	# Emit player disconnected signal for UI
	GameEvents.player_disconnected.emit(player_id)

func _on_player_spawned(player_id: int, position: Vector3):
	# DEBUG: Add logging to trace spawn signal processing
	print("DEBUG: _on_player_spawned called - player_id: %d, position: %s" % [player_id, position])
	GameEvents.log_debug("DEBUG: _on_player_spawned called - player_id: %d, position: %s" % [player_id, position])
	
	# For clients: Don't spawn our own player from server signals
	# We handle our own spawning in on_client_id_assigned() now
	if is_client:
		print("DEBUG: Client mode - checking if this is our own player (local_player_id: %d)" % local_player_id)
		if player_id == local_player_id:
			print("DEBUG: Client ignoring own player spawn signal - already handled in on_client_id_assigned()")
			GameEvents.log_debug("Client ignoring own player spawn signal - already handled in on_client_id_assigned()")
			return
		else:
			print("DEBUG: This is a REMOTE player spawn - proceeding with spawn_player()")
	
	print("DEBUG: About to call spawn_player(%d, %s)" % [player_id, position])
	GameEvents.log_debug("DEBUG: About to call spawn_player(%d, %s)" % [player_id, position])
	spawn_player(player_id, position)

func _on_player_position_updated(player_id: int, position: Vector3, rotation: Vector3, velocity: Vector3):
	"""Handle position updates from remote players"""
	GameEvents.log_debug("GameManager received position update - player_id: %d, local_player_id: %d, pos: %s" % [player_id, local_player_id, position])
	
	# Don't process updates for our own player (avoid feedback loop)
	if player_id == local_player_id:
		GameEvents.log_debug("Ignoring position update for local player %d" % player_id)
		return
	
	# Don't process position updates if no world is loaded (client timing issue)
	if not current_world_scene:
		GameEvents.log_debug("Ignoring position update - no world loaded yet")
		return
		
	# Ensure we have this player spawned
	if player_id not in spawned_players:
		GameEvents.log_info("Creating remote player %d from position update" % player_id)
		# Create player data if it doesn't exist
		if player_id not in connected_players:
			add_player(player_id, "Remote Player %d" % player_id)
		# Spawn the player
		spawn_player(player_id, position)
		return
	
	# Apply position update to existing remote player
	var remote_player = spawned_players[player_id]
	if remote_player and not remote_player.is_local_player:
		remote_player.apply_remote_position_update(position, rotation, velocity)
		GameEvents.log_debug("Applied position update to remote player %d: %s" % [player_id, position])
	else:
		GameEvents.log_debug("Skipped position update - remote_player: %s, is_local: %s" % [remote_player, remote_player.is_local_player if remote_player else "N/A"])

func _on_network_error(error_message: String):
	GameEvents.log_error("Network error: %s" % error_message)
	change_state(GameState.DISCONNECTED)

func setup_client_world():
	"""Setup world and spawn local player for client"""
	GameEvents.log_info("Setting up client world")
	
	# Load the world scene for client
	load_game_world()
	
	# Get client player ID from NetworkManager
	var client_id = NetworkManager.get_unique_id()
	local_player_id = client_id
	
	GameEvents.log_info("Client player ID: %d" % client_id)
	
	# If we got -1, try a few more times with small delays
	if client_id == -1:
		GameEvents.log_warning("Client ID is -1, attempting to retry...")
		for i in range(3):
			await get_tree().process_frame
			client_id = NetworkManager.get_unique_id()
			GameEvents.log_info("Retry %d: Client player ID: %d" % [i+1, client_id])
			if client_id != -1:
				local_player_id = client_id
				break
	
	# Add client as player
	add_player(client_id, "Client Player")
	
	# NOTE: Do NOT spawn the local player here - wait for server-assigned ID
	# The local player will be spawned in on_client_id_assigned() with the correct ID
	print("DEBUG: Client world setup complete, waiting for server-assigned ID before spawning local player")
	GameEvents.log_info("Client world setup complete, waiting for server-assigned ID before spawning local player")

func _on_world_loaded():
	GameEvents.log_info("World loaded successfully")
	
	# If we're the server, optionally spawn our own player (toggleable for dedicated servers)
	if is_server and allow_server_player:
		GameEvents.log_info("Spawning server player (allow_server_player=true)")
		# Add server as player 1
		add_player(1, "Server Player")
		# Spawn the server player at deterministic position
		var spawn_pos = get_spawn_point_for_player(1)
		GameEvents.player_spawned.emit(1, spawn_pos)
	elif is_server and not allow_server_player:
		GameEvents.log_info("Dedicated server mode: No server player spawned (allow_server_player=false)")
	elif is_server:
		GameEvents.log_info("Server ready - no local player spawned")

func _on_world_unloaded():
	GameEvents.log_info("World unloaded successfully")

# ============================================================================
# UI SUPPORT METHODS
# ============================================================================

func get_current_state() -> GameState:
	return current_state

func get_player_count() -> int:
	return connected_players.size()

func disconnect_game():
	if is_server:
		stop_server()
	elif is_client:
		disconnect_from_server()

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
	
	# Also print network debug info
	if NetworkManager:
		NetworkManager.print_debug_info()
