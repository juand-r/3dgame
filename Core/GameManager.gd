extends Node

func _ready():
	print("GameManager initialized")

func start_server(port: int = 8080) -> bool:
	print("Server start requested on port: ", port)
	print("(NetworkManager temporarily disabled for testing)")
	return true

func connect_to_server(address: String, port: int = 8080) -> bool:
	print("Client connect requested to: ", address, ":", port)
	print("(NetworkManager temporarily disabled for testing)")
	return true

func stop_server():
	print("Server stop requested")

func disconnect_from_server():
	print("Client disconnect requested")

func print_debug_info():
	print("=== GAME MANAGER DEBUG ===")
	print("Minimal version active (no NetworkManager)")
