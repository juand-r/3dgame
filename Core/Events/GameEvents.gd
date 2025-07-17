# GameEvents.gd - Global Event Bus
# Handles communication between all game systems
extends Node

# ============================================================================
# NETWORK EVENTS
# ============================================================================

# Connection events
signal server_started(port: int)
signal server_stopped()
signal client_connected_to_server(address: String, port: int)
signal client_disconnected_from_server()

# Player events
signal player_joined(player_id: int, player_name: String)
signal player_left(player_id: int, player_name: String)
signal player_connected(player_data: Dictionary)
signal player_disconnected(player_id: int)
signal player_spawned(player_id: int, position: Vector3)

# Data events
signal network_data_received(from_id: int, data: Dictionary)
signal network_error(error_message: String)

# ============================================================================
# GAMEPLAY EVENTS
# ============================================================================

# Player movement events
signal player_position_updated(player_id: int, position: Vector3, rotation: Vector3, velocity: Vector3)
signal player_entered_vehicle(player_id: int, vehicle_id: int)
signal player_exited_vehicle(player_id: int, vehicle_id: int)

# Vehicle events
signal vehicle_spawned(vehicle_id: int, position: Vector3, rotation: Vector3)
signal vehicle_position_updated(vehicle_id: int, position: Vector3, rotation: Vector3, velocity: Vector3)
signal vehicle_destroyed(vehicle_id: int)

# World events
signal world_loaded()
signal world_unloaded()
signal game_state_changed(new_state: int)

# Inventory events
signal item_picked_up(player_id: int, item_id: String, item_data: Dictionary)
signal item_dropped(player_id: int, item_id: String, position: Vector3)

# ============================================================================
# UI EVENTS
# ============================================================================

signal ui_show_main_menu()
signal ui_show_connection_dialog()
signal ui_show_game_hud()
signal ui_hide_all()

# Connection UI events
signal ui_connection_status_changed(status: String, message: String)
signal ui_player_count_changed(count: int, max_count: int)
signal connection_status_updated(status_text: String)

# ============================================================================
# DEBUG EVENTS
# ============================================================================

signal debug_log(level: String, message: String)
signal debug_performance_update(fps: float, memory_mb: float, network_kb: float)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Emit debug events with automatic formatting
func log_debug(message: String):
    debug_log.emit("DEBUG", "[%s] %s" % [Time.get_datetime_string_from_system(), message])

func log_info(message: String):
    debug_log.emit("INFO", "[%s] %s" % [Time.get_datetime_string_from_system(), message])

func log_warning(message: String):
    debug_log.emit("WARNING", "[%s] %s" % [Time.get_datetime_string_from_system(), message])

func log_error(message: String):
    debug_log.emit("ERROR", "[%s] %s" % [Time.get_datetime_string_from_system(), message])

# Network helper functions
func emit_player_update(player_id: int, pos: Vector3, rot: Vector3, vel: Vector3):
    player_position_updated.emit(player_id, pos, rot, vel)

func emit_vehicle_update(vehicle_id: int, pos: Vector3, rot: Vector3, vel: Vector3):
    vehicle_position_updated.emit(vehicle_id, pos, rot, vel)

func emit_connection_status(status: String, message: String = ""):
    ui_connection_status_changed.emit(status, message)
    log_info("Connection status: %s - %s" % [status, message])

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
    log_info("GameEvents initialized - Event bus ready")
    
    # Connect to our own debug events for console logging
    debug_log.connect(_on_debug_log)

func _on_debug_log(level: String, message: String):
    match level:
        "DEBUG":
            print("[DEBUG] ", message)
        "INFO":
            print("[INFO] ", message)
        "WARNING":
            print_rich("[color=yellow][WARNING][/color] ", message)
        "ERROR":
            print_rich("[color=red][ERROR][/color] ", message)
        _:
            print(message)
