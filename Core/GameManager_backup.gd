# Backup of GameManager.gd - copy for safety
extends Node

func _ready():
	print("Minimal GameManager loaded")

func start_server(port: int = 8080) -> bool:
	print("Server start requested")
	return true

func connect_to_server(address: String, port: int = 8080) -> bool:
	print("Client connect requested")
	return true

func stop_server():
	print("Server stop requested")

func disconnect_from_server():
	print("Client disconnect requested") 