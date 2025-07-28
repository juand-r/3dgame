extends CharacterBody3D
class_name PlayerController

# Player settings
@export var move_speed: float = 5.0
@export var jump_velocity: float = 8.0
@export var mouse_sensitivity: float = 0.002

# Player state
var player_id: int = -1
var is_local_player: bool = false

# Camera references
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

# Character model reference
@onready var character_model: Node3D = $Mage

# Movement state
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Networking state
var last_sent_position: Vector3 = Vector3.ZERO
var last_sent_rotation: Vector3 = Vector3.ZERO
var position_send_threshold: float = 0.05  # Send more frequently for better sync
var last_send_time: int = 0
var send_interval_ms: int = 50  # Send at most every 50ms (20 fps)

# Remote player interpolation targets
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO

func _ready():
    print("[DEBUG] Player ready - ID: ", player_id, " Local: ", is_local_player)
    
    if is_local_player:
        setup_local_player()
    else:
        setup_remote_player()

func setup_local_player():
    """Setup for the local player (the one controlled by this client)"""
    print("[DEBUG] Setting up local player")
    
    # Enable camera for local player
    camera.current = true
    
    # Capture mouse for camera control
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    
    # Connect to game events
    if GameEvents:
        GameEvents.log_info("Local player setup complete")

func setup_remote_player():
    """Setup for remote players (controlled by other clients)"""
    print("[DEBUG] Setting up remote player")
    
    # Disable camera for remote players
    camera.current = false

func _physics_process(delta):
    # Apply gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    # Only handle input for local player
    if is_local_player:
        handle_movement_input(delta)
        # Sync position to network after movement
        sync_position_to_network()
    else:
        # For remote players, interpolate to target position
        if target_position != Vector3.ZERO:
            var interpolation_speed = 15.0  # How fast to interpolate
            global_position = global_position.lerp(target_position, interpolation_speed * delta)
            rotation = rotation.lerp(target_rotation, interpolation_speed * delta)
    
    # Move the character
    move_and_slide()

func handle_movement_input(delta):
    """Handle WASD movement input"""
    # Get input direction
    var input_dir = Vector2.ZERO
    
    if Input.is_action_pressed("move_left"):
        input_dir.x -= 1
    if Input.is_action_pressed("move_right"):
        input_dir.x += 1
    if Input.is_action_pressed("move_forward"):
        input_dir.y -= 1
    if Input.is_action_pressed("move_backward"):
        input_dir.y += 1
    
    # Calculate movement direction relative to camera
    var direction = Vector3.ZERO
    if input_dir != Vector2.ZERO:
        direction = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    # Movement-based rotation (like real games) - but don't rotate when moving backward
    if character_model and direction != Vector3.ZERO:
        # Only rotate if NOT moving primarily backward (S key)
        if input_dir.y <= 0:  # Forward or sideways movement, but not backward
            var target_rotation = atan2(direction.x, direction.z)
            character_model.rotation.y = lerp_angle(character_model.rotation.y, target_rotation, 10.0 * delta)
    
    # Apply movement
    if direction:
        velocity.x = direction.x * move_speed
        velocity.z = direction.z * move_speed
    else:
        velocity.x = move_toward(velocity.x, 0, move_speed * delta * 3.0)
        velocity.z = move_toward(velocity.z, 0, move_speed * delta * 3.0)
    
    # Handle jumping
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = jump_velocity

func _input(event):
    # Only handle input for local player
    if not is_local_player:
        return
    
    # Handle ESC to toggle mouse capture
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            toggle_mouse_capture()
    
    # Handle mouse click to recapture when mouse is visible
    if event is InputEventMouseButton and event.pressed:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            GameEvents.log_info("Mouse recaptured (click)")
    
    # Handle mouse look
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        handle_mouse_look(event.relative)

func handle_mouse_look(mouse_delta: Vector2):
    """Handle mouse look camera control"""
    # Horizontal rotation (Y-axis)
    camera_pivot.rotate_y(-mouse_delta.x * mouse_sensitivity)
    
    # Vertical rotation (X-axis) with limits
    var x_rotation = camera_pivot.rotation.x - mouse_delta.y * mouse_sensitivity
    x_rotation = clamp(x_rotation, -PI/3, PI/3)  # Limit vertical look range
    camera_pivot.rotation.x = x_rotation

func toggle_mouse_capture():
    """Toggle between captured and visible mouse modes"""
    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        GameEvents.log_info("Mouse released (ESC)")
    else:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        GameEvents.log_info("Mouse captured (click to focus)")

func sync_position_to_network():
    """Send position updates to network for local player"""
    if not is_local_player:
        return
    
    var current_time = Time.get_ticks_msec()
    
    # Rate limiting: don't send more than every 50ms
    if current_time - last_send_time < send_interval_ms:
        return
    
    # Only send if position changed significantly OR enough time has passed
    var position_changed = global_position.distance_to(last_sent_position) >= position_send_threshold
    var rotation_changed = abs(rotation.y - last_sent_rotation.y) >= 0.1  # 0.1 radian threshold
    
    if not (position_changed or rotation_changed):
        return
    
    # Debug: Log local player position with context
    GameEvents.log_debug("LOCAL Player %d at position %s (camera looking from here)" % [player_id, global_position])
    
    # Create position update message (matching NetworkManager expected format)
    var position_data = {
        "type": "player_position",
        "player_id": player_id,
        "pos_x": global_position.x,
        "pos_y": global_position.y,
        "pos_z": global_position.z,
        "rot_x": rotation.x,
        "rot_y": rotation.y,
        "rot_z": rotation.z,
        "vel_x": velocity.x,
        "vel_y": velocity.y,
        "vel_z": velocity.z,
        "timestamp": Time.get_ticks_msec(),
        "is_grounded": is_on_floor()
    }
    
    # Send via NetworkManager (only if properly connected)
    if NetworkManager and NetworkManager.is_game_connected():
        NetworkManager.send_data(position_data)
        GameEvents.log_debug("Position sent: %s" % [global_position])
    else:
        # Debug: Log why we can't send
        var nm_exists = NetworkManager != null
        var connected = NetworkManager.is_game_connected() if NetworkManager else false
        GameEvents.log_debug("Skipping position send - NetworkManager: %s, Connected: %s" % [nm_exists, connected])
    
    # Update last sent data
    last_sent_position = global_position
    last_sent_rotation = rotation
    last_send_time = current_time

func apply_remote_position_update(new_position: Vector3, new_rotation: Vector3, new_velocity: Vector3):
    """Apply position update from network for remote players"""
    if is_local_player:
        return  # Don't apply updates to local player
    
    # Set targets for smooth interpolation (actual interpolation happens in _physics_process)
    target_position = new_position
    target_rotation = new_rotation
    target_velocity = new_velocity
    
    GameEvents.log_debug("REMOTE Player %d target updated to: %s (distance from my camera: %.2f)" % [player_id, new_position, global_position.distance_to(new_position)])

func set_player_data(id: int, local: bool):
    """Initialize player with ID and local status"""
    player_id = id
    is_local_player = local
    print("[DEBUG] Player data set - ID: ", player_id, " Local: ", is_local_player) 