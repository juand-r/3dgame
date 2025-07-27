# WebSocketManager.gd - WebSocket Networking Implementation
# Handles WebSocket server/client functionality for multiplayer networking
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
var client_id: int = -1  # For client connections, stores our assigned ID
var assigned_client_id: int = -1  # NEW: Stores server-assigned client ID
var connection_timeout: float = 30.0

# Statistics
var bytes_sent: int = 0
var bytes_received: int = 0
var last_ping_time: Dictionary = {}

# Connection state tracking
var _has_logged_connection: bool = false

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
		_check_multiplayer_packets()
	elif is_client and websocket_client:
		websocket_client.poll()
		_check_multiplayer_packets()
		_check_client_status()

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
	
	# Construct WebSocket URL - use wss:// for secure connections (Railway, etc.)
	var url: String
	if address.contains("railway.app") or address.contains("herokuapp.com") or port == 443:
		# Use secure WebSocket for cloud platforms (no port needed)
		url = "wss://%s" % address
		GameEvents.log_info("Using secure WebSocket: %s" % url)
	else:
		# Use regular WebSocket for local development
		url = "ws://%s:%d" % [address, port]
		GameEvents.log_info("Using WebSocket: %s" % url)
	
	# Connect to server
	var error = websocket_client.create_client(url)
	
	if error != OK:
		GameEvents.log_error("WebSocket: Failed to connect - Error %d" % error)
		websocket_client = null
		connection_failed.emit("Failed to connect to %s:%d" % [address, port])
		return false
	
	# Set up client
	is_client = true
	_has_logged_connection = false  # Reset connection logging flag
	
	# Connect signals (Note: WebSocketMultiplayerPeer uses different signals in Godot 4.4)
	# We'll monitor connection status via polling instead
	
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
	_has_logged_connection = false  # Reset connection logging flag

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
		GameEvents.log_debug("CLIENT: Attempting to send packet to server (size: %d bytes)" % packet.size())
		var result = websocket_client.put_packet(packet)
		if result == OK:
			bytes_sent += packet.size()
			GameEvents.log_debug("CLIENT: Packet sent successfully to server")
		else:
			GameEvents.log_error("CLIENT: Failed to send packet to server - Error: %d" % result)



# ============================================================================
# DATA RECEPTION - NEW MULTIPLAYER APPROACH
# ============================================================================

func _check_multiplayer_packets():
	"""Check for packets using Godot's multiplayer peer system"""
	var peer = websocket_server if is_server else websocket_client
	if not peer:
		return
	
	# Use the multiplayer peer's get_packet_count() method
	var packet_count = peer.get_available_packet_count()
	if packet_count > 0:
		GameEvents.log_debug("MULTIPLAYER: %d packets available" % packet_count)
		
		for i in range(packet_count):
			var packet = peer.get_packet()
			if packet.size() > 0:
				bytes_received += packet.size()
				GameEvents.log_debug("MULTIPLAYER: Processing packet (size: %d bytes)" % packet.size())
				
				# For server: packet came from a client, but we need to determine which one
				# For client: packet came from server (ID 1)
				var from_id = 1 if is_client else _get_sender_id_from_packet(packet)
				_process_received_packet(from_id, packet)

func _get_sender_id_from_packet(packet: PackedByteArray) -> int:
	"""Extract sender ID from packet for server-side processing"""
	# Parse the JSON to get the player_id or sender info
	var json_string = packet.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK and typeof(json.data) == TYPE_DICTIONARY:
		var data = json.data
		# Try to get player_id from the message content
		return data.get("player_id", -1)
	
	return -1  # Unknown sender

func _check_client_status():
	if not websocket_client:
		return
	
	# Check if connection is still valid (Godot 4.4 approach)
	var status = websocket_client.get_connection_status()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		if is_client:  # Only emit if we were connected
			GameEvents.log_error("WebSocket: Connection to server lost")
			connection_failed.emit("Connection to server lost")
			is_client = false
			websocket_client = null
			_has_logged_connection = false
	elif status == MultiplayerPeer.CONNECTION_CONNECTED and is_client:
		# Connection successful - only log once
		if not _has_logged_connection:
			GameEvents.log_info("WebSocket: Successfully connected to server")
			_has_logged_connection = true

func _process_received_packet(from_id: int, packet: PackedByteArray):
	# Convert packet to JSON
	var json_string = packet.get_string_from_utf8()
	GameEvents.log_debug("SERVER: Received JSON from client %d: %s" % [from_id, json_string.substr(0, 100) + "..." if json_string.length() > 100 else json_string])
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		GameEvents.log_error("WebSocket: Failed to parse JSON from client %d" % from_id)
		return
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		GameEvents.log_error("WebSocket: Received invalid data type from client %d" % from_id)
		return
	
	var message_type = data.get("type", "unknown")
	GameEvents.log_debug("SERVER: Message type from client %d: %s" % [from_id, message_type])
	
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
	print("PRINT DEBUG: _on_server_peer_connected called with id: ", id)
	GameEvents.log_debug("DEBUG: _on_server_peer_connected called with id: %d" % id)
	
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
	
	# NEW: Send client ID assignment message to the new client
	var id_assignment_data = {
		"type": "client_id_assignment",
		"your_client_id": id,
		"timestamp": Time.get_ticks_msec()
	}
	
	# Send the ID assignment directly to this client
	if websocket_server:
		var peer = websocket_server.get_peer(id)
		if peer:
			var json_string = JSON.stringify(id_assignment_data)
			var packet = json_string.to_utf8_buffer()
			peer.put_packet(packet)
			GameEvents.log_debug("Sent client ID assignment to client %d: %d" % [id, id])
	
	print("PRINT DEBUG: About to emit player_connected signal for id: ", id)
	GameEvents.log_debug("DEBUG: About to emit player_connected signal for id: %d" % id)
	player_connected.emit(id)
	print("PRINT DEBUG: player_connected.emit(", id, ") completed")
	GameEvents.log_debug("DEBUG: player_connected.emit(%d) completed" % id)

func _on_server_peer_disconnected(id: int):
	if id in connected_clients:
		connected_clients.erase(id)
		GameEvents.log_info("WebSocket: Client %d disconnected" % id)
		player_disconnected.emit(id)

# Note: Godot 4.4 WebSocketMultiplayerPeer doesn't have connection_failed, 
# connection_succeeded, or server_disconnected signals.
# We monitor connection status via polling in _process instead.

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
	if not is_client:
		return false
	if not websocket_client:
		return false
	
	var status = websocket_client.get_connection_status()
	var is_connected = status == MultiplayerPeer.CONNECTION_CONNECTED
	
	# Debug: Log connection status occasionally 
	if not is_connected:
		GameEvents.log_debug("Client connection check - status: %d (expected: %d)" % [status, MultiplayerPeer.CONNECTION_CONNECTED])
	
	return is_connected

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
func get_unique_id() -> int:
	if is_server:
		return 1  # Server is always ID 1
	elif is_client:
		# If we have a server-assigned ID, use that
		if assigned_client_id != -1:
			GameEvents.log_debug("Using server-assigned client ID: %d" % assigned_client_id)
			return assigned_client_id
		
		# Fallback to WebSocket method (but this usually doesn't work reliably)
		if websocket_client:
			var status = websocket_client.get_connection_status()
			var unique_id = websocket_client.get_unique_id()
			
			if status == MultiplayerPeer.CONNECTION_CONNECTED and unique_id > 0:
				GameEvents.log_debug("Using WebSocket assigned ID: %d" % unique_id)
				return unique_id
		
		# If we get here, we haven't received our ID assignment yet
		GameEvents.log_debug("Client ID not yet assigned by server")
		return -1
	
	GameEvents.log_warning("get_unique_id() returning -1 - no valid client state")
	return -1

func set_assigned_client_id(id: int):
	"""Store the server-assigned client ID"""
	assigned_client_id = id
	GameEvents.log_info("Client ID assigned by server: %d" % id)

func send_test_message():
	var test_data = {
		"type": "chat_message",
		"message": "Test message from WebSocket",
		"timestamp": Time.get_ticks_msec()
	}
	send_data(test_data) 
