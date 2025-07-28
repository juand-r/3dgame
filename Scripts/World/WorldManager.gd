extends Node3D
class_name WorldManager

## World Manager - Handles dynamic world elements and atmosphere
## Adds life and ambiance to the static world structures

# Dynamic elements
@export var enable_ambient_effects: bool = true
@export var building_light_interval: float = 3.0
@export var atmosphere_cycle_time: float = 60.0

# Building references for dynamic effects
var buildings: Array[MeshInstance3D] = []
var building_lights: Array[OmniLight3D] = []

# Atmosphere
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var time_of_day: float = 0.5  # 0.0 = night, 1.0 = day

signal world_ready

func _ready():
	print("[WORLD] WorldManager initializing...")
	
	# Find world components
	find_world_components()
	
	# Set up dynamic elements
	if enable_ambient_effects:
		setup_building_lights()
		setup_atmosphere_cycle()
	
	print("[WORLD] Enhanced world ready with dynamic elements")
	world_ready.emit()

func find_world_components():
	"""Find and cache references to world elements"""
	
	# Find buildings
	var buildings_node = get_node_or_null("../Buildings")
	if buildings_node:
		for child in buildings_node.get_children():
			if child is MeshInstance3D:
				buildings.append(child)
				print("[WORLD] Found building: ", child.name)
	
	# Find environment components
	world_environment = get_node_or_null("../Environment/WorldEnvironment")
	directional_light = get_node_or_null("../Environment/DirectionalLight3D")
	
	print("[WORLD] Found %d buildings, environment: %s, light: %s" % [
		buildings.size(),
		"yes" if world_environment else "no",
		"yes" if directional_light else "no"
	])

func setup_building_lights():
	"""Add dynamic lighting to buildings"""
	
	for building in buildings:
		# Create ambient light for each building
		var light = OmniLight3D.new()
		light.light_energy = 0.5
		light.light_color = Color(1.0, 0.9, 0.7)  # Warm light
		light.omni_range = 25.0
		light.position = Vector3(0, 15, 0)  # Top of building
		
		building.add_child(light)
		building_lights.append(light)
		
		# Add subtle animation
		var tween = create_tween()
		tween.set_loops()
		tween.tween_method(
			func(value): light.light_energy = value,
			0.3, 0.7, building_light_interval + randf() * 2.0
		)
		tween.tween_method(
			func(value): light.light_energy = value,
			0.7, 0.3, building_light_interval + randf() * 2.0
		)
	
	print("[WORLD] Added dynamic lights to %d buildings" % building_lights.size())

func setup_atmosphere_cycle():
	"""Set up subtle day/night atmosphere changes"""
	
	if not world_environment or not directional_light:
		return
	
	# Create atmosphere cycle
	var tween = create_tween()
	tween.set_loops()
	
	# Day to evening
	tween.tween_method(update_atmosphere, 0.0, 1.0, atmosphere_cycle_time / 2)
	# Evening to day  
	tween.tween_method(update_atmosphere, 1.0, 0.0, atmosphere_cycle_time / 2)
	
	print("[WORLD] Atmosphere cycle started (%d second cycles)" % atmosphere_cycle_time)

func update_atmosphere(time_value: float):
	"""Update atmosphere based on time of day"""
	
	time_of_day = time_value
	
	if not world_environment or not directional_light:
		return
	
	var env = world_environment.environment
	if not env:
		return
	
	# Adjust ambient light based on time
	var ambient_energy = lerp(0.2, 0.4, time_value)  # Darker at night
	env.ambient_light_energy = ambient_energy
	
	# Adjust background color (blue during day, darker at evening)
	var bg_color = Color(
		lerp(0.3, 0.5, time_value),  # Red
		lerp(0.4, 0.7, time_value),  # Green  
		lerp(0.6, 1.0, time_value)   # Blue
	)
	env.background_color = bg_color
	
	# Adjust directional light
	directional_light.light_energy = lerp(0.7, 1.2, time_value)

func get_world_info() -> Dictionary:
	"""Return information about the current world state"""
	
	return {
		"buildings_count": buildings.size(),
		"lights_count": building_lights.size(),
		"time_of_day": time_of_day,
		"atmosphere_enabled": enable_ambient_effects,
		"world_size": Vector2(200, 200)  # Our enhanced world size
	}

func get_random_spawn_position() -> Vector3:
	"""Get a random safe spawn position in the world"""
	
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		var x = randf_range(-90, 90)  # Stay within world bounds
		var z = randf_range(-90, 90)
		var pos = Vector3(x, 5, z)  # Start elevated to check for ground
		
		# Simple check - avoid building areas (very basic)
		var too_close_to_building = false
		for building in buildings:
			if building.global_position.distance_to(pos) < 20:
				too_close_to_building = true
				break
		
		if not too_close_to_building:
			return Vector3(x, 2, z)  # Return at ground level
		
		attempts += 1
	
	# Fallback to center if no good position found
	return Vector3(0, 2, 0)

func _input(event):
	"""Debug controls for world testing"""
	
	if event.is_action_pressed("ui_accept"):  # Space key
		print("[WORLD] World Info: ", get_world_info())
	
	if event.is_action_pressed("ui_select"):  # Enter key
		var random_pos = get_random_spawn_position()
		print("[WORLD] Random spawn position: ", random_pos) 