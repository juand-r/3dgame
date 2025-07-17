# WebSocketManager.gd - WebSocket Networking Implementation
# Handles WebSocket server/client functionality for multiplayer networking
extends Node
class_name WebSocketManager

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
# NETWORKING COMPONENTS
# ============================================================================

var tcp_server: TCPServer = null
var websocket_server: WebSocketMultiplayerPeer = null
var websocket_client: WebSocketMultiplayerPeer = null

# Server state
var is_server: bool = false
var is_client: bool = false
var server_port: int = 8080
var max_connections: int = 4

# Connection management
var connected_clients: Dictionary = {}  # id -> connection_info
var next_client_id: int = 2  # Server is always ID 1
var connection_timeout: float = 30.0

# Statistics
var bytes_sent: int = 0
var bytes_received: int = 0
var last_ping_time: Dictionary = {}

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	GameEvents.log_info("WebSocketManager initialized")
	set_process(true)

func _process(_delta):
	# Poll networking
	if is_server and websocket_server:
		websocket_server.poll()
		_check_server_connections()
	elif is_client and websocket_client:
		websocket_client.poll()
		_check_client_connection()

# ============================================================================
# SERVER MANAGEMENT
# ============================================================================

func start_server(port: int) -> bool:
	if is_server or is_client:
		GameEvents.log_error("WebSocket: Already connected")
		return false
	
	GameEvents.log_info("WebSocket: Starting server on port %d" % port)
	
	# Create WebSocket server
	websocket_server = WebSocketMultiplayerPeer.new()
	
	# Configure server
	var error = websocket_server.create_server(port, "*")
	
	if error != OK:
		GameEvents.log_error("WebSocket: Failed to create server - Error %d" % error)
		websocket_server = null
		connection_failed.emit("Failed to start server on port %d" % port)
		return false
	
	# Set up server
	is_server = true
	server_port = port
	
	# Connect signals
	websocket_server.peer_connected.connect(_on_server_peer_connected)
	websocket_server.peer_disconnected.connect(_on_server_peer_disconnected)
	websocket_server.connection_failed.connect(_on_server_connection_failed)
	
	GameEvents.log_info("WebSocket: Server started successfully on port %d" % port)
	server_started_successfully.emit(port)
	return true

func stop_server():
	if not is_server:
		return
	
	GameEvents.log_info("WebSocket: Stopping server")
	
	# Disconnect all clients
	for client_id in connected_clients.keys():
		_disconnect_client(client_id)
	
	# Clean up server
	if websocket_server:
		websocket_server.close()
		websocket_server = null
	
	is_server = false
	connected_clients.clear()
	next_client_id = 2
	
	server_stopped.emit()

# ============================================================================
# CLIENT MANAGEMENT
# ============================================================================

func connect_to_server(address: String, port: int) -> bool:
	if is_server or is_client:
		GameEvents.log_error("WebSocket: Already connected")
		return false
	
	GameEvents.log_info("WebSocket: Connecting to %s:%d" % [address, port])
	
	# Create WebSocket client
	websocket_client = WebSocketMultiplayerPeer.new()
	
	# Construct WebSocket URL
	var url = "ws://%s:%d" % [address, port]
	
	# Connect to server
	var error = websocket_client.create_client(url)
	
	if error != OK:
		GameEvents.log_error("WebSocket: Failed to connect - Error %d" % error)
		websocket_client = null
		connection_failed.emit("Failed to connect to %s:%d" % [address, port])
		return false
	
	# Set up client
	is_client = true
	
	# Connect signals
	websocket_client.connection_succeeded.connect(_on_client_connection_succeeded)
	websocket_client.connection_failed.connect(_on_client_connection_failed)
	websocket_client.server_disconnected.connect(_on_client_server_disconnected)
	
	return true

func disconnect_from_server():
	if not is_client:
		return
	
	GameEvents.log_info("WebSocket: Disconnecting from server")
	
	# Clean up client
	if websocket_client:
		websocket_client.close()
		websocket_client = null
	
	is_client = false

# ============================================================================
# DATA TRANSMISSION
# ============================================================================

func send_data(data: Dictionary, to_id: int = -1):
	if not (is_server or is_client):
		GameEvents.log_warning("WebSocket: Not connected, cannot send data")
		return
	
	# Convert data to JSON
	var json_string = JSON.stringify(data)
	var packet = json_string.to_utf8_buffer()
	
	if is_server and websocket_server:
		if to_id == -1:
			# Broadcast to all clients
			for client_id in connected_clients.keys():
				websocket_server.get_peer(client_id).put_packet(packet)
				bytes_sent += packet.size()
		else:
			# Send to specific client
			if to_id in connected_clients:
				websocket_server.get_peer(to_id).put_packet(packet)
				bytes_sent += packet.size()
			else:
				GameEvents.log_warning("WebSocket: Client %d not found" % to_id)
	
	elif is_client and websocket_client:
		# Send to server
		websocket_client.put_packet(packet)
		bytes_sent += packet.size()

# ============================================================================
# DATA RECEPTION
# ============================================================================

func _check_server_connections():
	if not websocket_server:
		return
	
	# Check for incoming data from clients
	for client_id in connected_clients.keys():
		var peer = websocket_server.get_peer(client_id)
		if peer and peer.get_available_packet_count() > 0:
			var packet = peer.get_packet()
			bytes_received += packet.size()
			_process_received_packet(client_id, packet)

func _check_client_connection():
	if not websocket_client:
		return
	
	# Check for incoming data from server
	if websocket_client.get_available_packet_count() > 0:
		var packet = websocket_client.get_packet()
		bytes_received += packet.size()
		_process_received_packet(1, packet)  # Server is always ID 1

func _process_received_packet(from_id: int, packet: PackedByteArray):
	# Convert packet to JSON
	var json_string = packet.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		GameEvents.log_error("WebSocket: Failed to parse JSON from client %d" % from_id)
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		GameEvents.log_error("WebSocket: Received invalid data type from client %d" % from_id)
		return
	
	# Update ping time
	var timestamp = data.get("timestamp", 0)
	if timestamp > 0:
		last_ping_time[from_id] = Time.get_ticks_msec() - timestamp
	
	# Emit data received signal
	data_received.emit(from_id, data)

# ============================================================================
# CONNECTION EVENTS
# ============================================================================

func _on_server_peer_connected(id: int):
	if connected_clients.size() >= max_connections:
		GameEvents.log_warning("WebSocket: Max connections reached, rejecting client %d" % id)
		websocket_server.disconnect_peer(id)
		return
	
	# Add client to connected list
	connected_clients[id] = {
		"id": id,
		"connected_at": Time.get_ticks_msec(),
		"last_ping": 0
	}
	
	GameEvents.log_info("WebSocket: Client %d connected" % id)
	player_connected.emit(id)

func _on_server_peer_disconnected(id: int):
	if id in connected_clients:
		connected_clients.erase(id)
		GameEvents.log_info("WebSocket: Client %d disconnected" % id)
		player_disconnected.emit(id)

func _on_server_connection_failed():
	GameEvents.log_error("WebSocket: Server connection failed")
	connection_failed.emit("Server connection failed")

func _on_client_connection_succeeded():
	GameEvents.log_info("WebSocket: Successfully connected to server")
	# The client doesn't emit player_connected for itself - the server handles that

func _on_client_connection_failed():
	GameEvents.log_error("WebSocket: Failed to connect to server")
	is_client = false
	websocket_client = null
	connection_failed.emit("Failed to connect to server")

func _on_client_server_disconnected():
	GameEvents.log_info("WebSocket: Disconnected from server")
	is_client = false
	websocket_client = null
	player_disconnected.emit(1)  # Server disconnected

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _disconnect_client(client_id: int):
	if websocket_server and client_id in connected_clients:
		websocket_server.disconnect_peer(client_id)

func get_connection_count() -> int:
	if is_server:
		return connected_clients.size()
	elif is_client:
		return 1
	return 0

func is_server_running() -> bool:
	return is_server and websocket_server != null

func is_connected_to_server() -> bool:
	return is_client and websocket_client != null and websocket_client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func set_max_connections(count: int):
	max_connections = count
	GameEvents.log_info("WebSocket: Max connections set to %d" % count)

func get_network_stats() -> Dictionary:
	var stats = {
		"connected_players": get_connection_count(),
		"bytes_sent": bytes_sent,
		"bytes_received": bytes_received,
		"is_server": is_server,
		"is_client": is_client,
		"server_port": server_port if is_server else -1
	}
	
	# Add ping information
	if last_ping_time.size() > 0:
		var total_ping = 0
		for ping in last_ping_time.values():
			total_ping += ping
		stats["average_ping"] = total_ping / last_ping_time.size()
	else:
		stats["average_ping"] = 0
	
	return stats

# ============================================================================
# HEALTH CHECK (for Railway deployment)
# ============================================================================

func get_health_status() -> Dictionary:
	return {
		"status": "healthy" if (is_server_running() or is_connected_to_server()) else "disconnected",
		"uptime": Time.get_ticks_msec(),
		"connections": get_connection_count(),
		"max_connections": max_connections,
		"bytes_sent": bytes_sent,
		"bytes_received": bytes_received
	}

# ============================================================================
# DEBUG FUNCTIONS
# ============================================================================

func print_debug_info():
	GameEvents.log_debug("=== WEBSOCKET DEBUG INFO ===")
	GameEvents.log_debug("Is Server: %s" % is_server)
	GameEvents.log_debug("Is Client: %s" % is_client)
	GameEvents.log_debug("Connected Clients: %d" % connected_clients.size())
	GameEvents.log_debug("Bytes Sent: %d" % bytes_sent)
	GameEvents.log_debug("Bytes Received: %d" % bytes_received)
	
	if is_server:
		for client_id in connected_clients.keys():
			var ping = last_ping_time.get(client_id, 0)
			GameEvents.log_debug("Client %d ping: %d ms" % [client_id, ping])

# Test function for development
func send_test_message():
	var test_data = {
		"type": "chat_message",
		"message": "Test message from WebSocket",
		"timestamp": Time.get_ticks_msec()
	}
	send_data(test_data) 