# NetworkManager.gd - Abstract Network Manager Base Class
# Provides interface for different networking implementations (WebSocket, ENet, etc.)
extends Node
class_name NetworkManager

# ============================================================================
# SIGNALS (Override in implementations)
# ============================================================================

signal player_connected(id: int)
signal player_disconnected(id: int)
signal data_received(from_id: int, data: Dictionary)
signal connection_failed(error: String)
signal server_started_successfully(port: int)
signal server_stopped()

# ============================================================================
# ABSTRACT INTERFACE
# ============================================================================

# These methods MUST be overridden in implementations

func start_server(port: int) -> bool:
	GameEvents.log_error("NetworkManager.start_server() not implemented")
	return false

func stop_server():
	GameEvents.log_error("NetworkManager.stop_server() not implemented")

func connect_to_server(address: String, port: int) -> bool:
	GameEvents.log_error("NetworkManager.connect_to_server() not implemented")
	return false

func disconnect_from_server():
	GameEvents.log_error("NetworkManager.disconnect_from_server() not implemented")

func send_data(data: Dictionary, to_id: int = -1):
	GameEvents.log_error("NetworkManager.send_data() not implemented")

func get_connection_count() -> int:
	GameEvents.log_error("NetworkManager.get_connection_count() not implemented")
	return 0

func is_server_running() -> bool:
	GameEvents.log_error("NetworkManager.is_server_running() not implemented")
	return false

func is_connected_to_server() -> bool:
	GameEvents.log_error("NetworkManager.is_connected_to_server() not implemented")
	return false

# ============================================================================
# SHARED IMPLEMENTATION
# ============================================================================

var _implementation: Node = null
var max_connections: int = 4

func _ready():
	GameEvents.log_info("NetworkManager base initialized")
	_setup_implementation()

func _setup_implementation():
	# For now, always use WebSocket implementation
	# Later we can make this configurable
	_implementation = WebSocketManager.new()
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
# IMPLEMENTATION FORWARDING
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

# ============================================================================
# EVENT FORWARDING
# ============================================================================

func _on_player_connected(id: int):
	GameEvents.log_info("Player connected: %d" % id)
	GameEvents.player_joined.emit(id, "Player%d" % id)
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
		"player_position":
			_handle_player_position(from_id, data)
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

func _handle_player_position(from_id: int, data: Dictionary):
	var position = Vector3(data.get("pos_x", 0), data.get("pos_y", 0), data.get("pos_z", 0))
	var rotation = Vector3(data.get("rot_x", 0), data.get("rot_y", 0), data.get("rot_z", 0))
	var velocity = Vector3(data.get("vel_x", 0), data.get("vel_y", 0), data.get("vel_z", 0))
	
	GameEvents.emit_player_update(from_id, position, rotation, velocity)

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