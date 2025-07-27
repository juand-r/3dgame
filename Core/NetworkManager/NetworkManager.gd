# NetworkManager.gd - Network Manager with WebSocket Implementation
# Provides networking interface for multiplayer functionality
extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal player_connected(id: int)
signal player_disconnected(id: int)
signal data_received(from_id: int, data: Dictionary)
signal connection_failed(error: String)
signal server_started_successfully(port: int)
signal server_stopped()

# ============================================================================
# NETWORKING IMPLEMENTATION
# ============================================================================

var _implementation: Node = null
var max_connections: int = 4

func _ready():
	GameEvents.log_info("NetworkManager base initialized")
	_setup_implementation()

func _setup_implementation():
	# Use WebSocket implementation
	var websocket_script = preload("res://Core/NetworkManager/WebSocketManager.gd")
	_implementation = websocket_script.new()
	add_child(_implementation)
	
	# Connect implementation signals to our signals
	_implementation.player_connected.connect(_on_player_connected)
	_implementation.player_disconnected.connect(_on_player_disconnected)
	_implementation.data_received.connect(_on_data_received)
	_implementation.connection_failed.connect(_on_connection_failed)
	_implementation.server_started_successfully.connect(_on_server_started_successfully)
	_implementation.server_stopped.connect(_on_server_stopped)
	
	GameEvents.log_info("Using WebSocket networking implementation")

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

func start_server(port: int) -> bool:
	if _implementation:
		return _implementation.start_server(port)
	return false

func stop_server():
	if _implementation:
		_implementation.stop_server()

func connect_to_server(address: String, port: int) -> bool:
	if _implementation:
		return _implementation.connect_to_server(address, port)
	return false

func disconnect_from_server():
	if _implementation:
		_implementation.disconnect_from_server()

func send_data(data: Dictionary, to_id: int = -1):
	if _implementation:
		_implementation.send_data(data, to_id)

func get_connection_count() -> int:
	if _implementation:
		return _implementation.get_connection_count()
	return 0

func is_server_running() -> bool:
	if _implementation:
		return _implementation.is_server_running()
	return false

func is_connected_to_server() -> bool:
	if _implementation:
		return _implementation.is_connected_to_server()
	return false

func is_game_connected() -> bool:
	return is_server_running() or is_connected_to_server()

func get_unique_id() -> int:
	if _implementation:
		return _implementation.get_unique_id()
	return -1

# ============================================================================
# EVENT FORWARDING
# ============================================================================

func _on_player_connected(id: int):
	print("PRINT DEBUG: NetworkManager._on_player_connected called with id: ", id)
	GameEvents.log_debug("DEBUG: NetworkManager._on_player_connected called with id: %d" % id)
	GameEvents.log_info("Player connected: %d" % id)
	print("PRINT DEBUG: About to emit GameEvents.player_joined(", id, ", \"Player", id, "\")")
	GameEvents.log_debug("DEBUG: About to emit GameEvents.player_joined(%d, \"Player%d\")" % [id, id])
	GameEvents.player_joined.emit(id, "Player%d" % id)
	print("PRINT DEBUG: GameEvents.player_joined.emit completed for id: ", id)
	GameEvents.log_debug("DEBUG: GameEvents.player_joined.emit completed for id: %d" % id)
	player_connected.emit(id)

func _on_player_disconnected(id: int):
	GameEvents.log_info("Player disconnected: %d" % id)
	GameEvents.player_left.emit(id, "Player%d" % id)
	player_disconnected.emit(id)

func _on_data_received(from_id: int, data: Dictionary):
	# Process and forward data
	process_received_data(from_id, data)
	data_received.emit(from_id, data)

func _on_connection_failed(error: String):
	GameEvents.log_error("Connection failed: %s" % error)
	GameEvents.network_error.emit(error)
	connection_failed.emit(error)

func _on_server_started_successfully(port: int):
	GameEvents.log_info("Server started on port %d" % port)
	GameEvents.server_started.emit(port)
	server_started_successfully.emit(port)

func _on_server_stopped():
	GameEvents.log_info("Server stopped")
	GameEvents.server_stopped.emit()
	server_stopped.emit()

# ============================================================================
# DATA PROCESSING
# ============================================================================

func process_received_data(from_id: int, data: Dictionary):
	# Process different types of network messages
	var message_type = data.get("type", "unknown")
	
	match message_type:
		"client_id_assignment":
			_handle_client_id_assignment(from_id, data)
		"player_position":
			_handle_player_position(from_id, data)
		"player_spawn":
			_handle_player_spawn(from_id, data)
		"vehicle_position":
			_handle_vehicle_position(from_id, data)
		"player_enter_vehicle":
			_handle_player_enter_vehicle(from_id, data)
		"player_exit_vehicle":
			_handle_player_exit_vehicle(from_id, data)
		"chat_message":
			_handle_chat_message(from_id, data)
		_:
			GameEvents.log_warning("Unknown message type: %s" % message_type)

func _handle_client_id_assignment(from_id: int, data: Dictionary):
	"""Handle client ID assignment from server"""
	var assigned_id = data.get("your_client_id", -1)
	
	if assigned_id != -1:
		GameEvents.log_info("Received client ID assignment: %d" % assigned_id)
		
		# Store the assigned ID in the WebSocket implementation
		if _implementation and _implementation.has_method("set_assigned_client_id"):
			_implementation.set_assigned_client_id(assigned_id)
		
		# Notify GameManager about the ID assignment
		if GameManager:
			GameManager.on_client_id_assigned(assigned_id)
	else:
		GameEvents.log_error("Invalid client ID assignment received")

func _handle_player_position(from_id: int, data: Dictionary):
	var position = Vector3(data.get("pos_x", 0), data.get("pos_y", 0), data.get("pos_z", 0))
	var rotation = Vector3(data.get("rot_x", 0), data.get("rot_y", 0), data.get("rot_z", 0))
	var velocity = Vector3(data.get("vel_x", 0), data.get("vel_y", 0), data.get("vel_z", 0))
	var player_id = data.get("player_id", from_id)  # Use player_id from message if available
	
	GameEvents.log_debug("Received position update - from_id: %d, player_id: %d, pos: %s" % [from_id, player_id, position])
	
	# SERVER LOGIC: Broadcast position updates to other clients  
	if GameManager and GameManager.is_server:
		GameEvents.log_debug("SERVER: Received client position update - player_id: %d, pos: %s" % [player_id, position])
		# Broadcast to all other connected clients
		for client_id in _implementation.connected_clients.keys():
			if client_id != from_id:  # Don't send back to sender
				GameEvents.log_debug("SERVER: Sending position update to client %d" % client_id)
				_implementation.send_data(data, client_id)  # Relay the original data
	
	# CLIENT LOGIC: Apply position update to local game state
	GameEvents.emit_player_update(player_id, position, rotation, velocity)



func _handle_player_spawn(from_id: int, data: Dictionary):
	var player_id = data.get("player_id", from_id)
	var position = Vector3(data.get("pos_x", 0), data.get("pos_y", 0), data.get("pos_z", 0))
	var rotation = Vector3(data.get("rot_x", 0), data.get("rot_y", 0), data.get("rot_z", 0))
	
	print("DEBUG CLIENT: _handle_player_spawn received - from_id: %d, player_id: %d, pos: %s" % [from_id, player_id, position])
	GameEvents.log_debug("DEBUG: _handle_player_spawn received - from_id: %d, player_id: %d, pos: %s" % [from_id, player_id, position])
	
	print("DEBUG CLIENT: About to call GameEvents.emit_player_spawn(%d, %s, %s)" % [player_id, position, rotation])
	GameEvents.log_debug("DEBUG: About to call GameEvents.emit_player_spawn(%d, %s, %s)" % [player_id, position, rotation])
	GameEvents.emit_player_spawn(player_id, position, rotation)
	print("DEBUG CLIENT: GameEvents.emit_player_spawn completed")
	GameEvents.log_debug("DEBUG: GameEvents.emit_player_spawn completed")

func _handle_vehicle_position(from_id: int, data: Dictionary):
	var vehicle_id = data.get("vehicle_id", -1)
	var position = Vector3(data.get("pos_x", 0), data.get("pos_y", 0), data.get("pos_z", 0))
	var rotation = Vector3(data.get("rot_x", 0), data.get("rot_y", 0), data.get("rot_z", 0))
	var velocity = Vector3(data.get("vel_x", 0), data.get("vel_y", 0), data.get("vel_z", 0))
	
	GameEvents.emit_vehicle_update(vehicle_id, position, rotation, velocity)

func _handle_player_enter_vehicle(from_id: int, data: Dictionary):
	var vehicle_id = data.get("vehicle_id", -1)
	GameEvents.player_entered_vehicle.emit(from_id, vehicle_id)

func _handle_player_exit_vehicle(from_id: int, data: Dictionary):
	var vehicle_id = data.get("vehicle_id", -1)
	GameEvents.player_exited_vehicle.emit(from_id, vehicle_id)

func _handle_chat_message(from_id: int, data: Dictionary):
	var message = data.get("message", "")
	GameEvents.log_info("Chat from Player %d: %s" % [from_id, message])

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func send_player_position(position: Vector3, rotation: Vector3, velocity: Vector3):
	var data = {
		"type": "player_position",
		"pos_x": position.x,
		"pos_y": position.y,
		"pos_z": position.z,
		"rot_x": rotation.x,
		"rot_y": rotation.y,
		"rot_z": rotation.z,
		"vel_x": velocity.x,
		"vel_y": velocity.y,
		"vel_z": velocity.z,
		"timestamp": Time.get_ticks_msec()
	}
	send_data(data)

func send_vehicle_position(vehicle_id: int, position: Vector3, rotation: Vector3, velocity: Vector3):
	var data = {
		"type": "vehicle_position",
		"vehicle_id": vehicle_id,
		"pos_x": position.x,
		"pos_y": position.y,
		"pos_z": position.z,
		"rot_x": rotation.x,
		"rot_y": rotation.y,
		"rot_z": rotation.z,
		"vel_x": velocity.x,
		"vel_y": velocity.y,
		"vel_z": velocity.z,
		"timestamp": Time.get_ticks_msec()
	}
	send_data(data)

func send_player_enter_vehicle(vehicle_id: int):
	var data = {
		"type": "player_enter_vehicle",
		"vehicle_id": vehicle_id,
		"timestamp": Time.get_ticks_msec()
	}
	send_data(data)

func send_player_exit_vehicle(vehicle_id: int):
	var data = {
		"type": "player_exit_vehicle",
		"vehicle_id": vehicle_id,
		"timestamp": Time.get_ticks_msec()
	}
	send_data(data)

func send_chat_message(message: String):
	var data = {
		"type": "chat_message",
		"message": message,
		"timestamp": Time.get_ticks_msec()
	}
	send_data(data)

# ============================================================================
# CONFIGURATION
# ============================================================================

func set_max_connections(count: int):
	max_connections = count
	if _implementation and _implementation.has_method("set_max_connections"):
		_implementation.set_max_connections(count)

func get_network_stats() -> Dictionary:
	if _implementation and _implementation.has_method("get_network_stats"):
		return _implementation.get_network_stats()
	return {
		"connected_players": get_connection_count(),
		"bytes_sent": 0,
		"bytes_received": 0,
		"ping": 0
	}

func print_debug_info():
	GameEvents.log_debug("=== NETWORK MANAGER DEBUG INFO ===")
	GameEvents.log_debug("Implementation: %s" % ("WebSocket" if _implementation else "None"))
	GameEvents.log_debug("Max Connections: %d" % max_connections)
	GameEvents.log_debug("Current Connections: %d" % get_connection_count())
	if _implementation and _implementation.has_method("print_debug_info"):
		_implementation.print_debug_info()
