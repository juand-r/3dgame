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
	
	# Apply PBR textures first
	setup_real_textures()
	
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

func setup_real_textures():
	"""Apply real PBR textures to world surfaces"""
	print("[WORLD] 🎨 Applying real PBR textures...")
	
	# Apply desert texture to ground
	apply_real_desert_texture()
	
	# Apply fallback materials to other objects
	apply_fallback_building_materials()
	apply_real_wood_textures()

func apply_real_desert_texture():
	"""Apply downloaded PBR desert texture to the ground"""
	print("[WORLD] 🔍 Looking for ground node...")
	
	var ground_node = get_node_or_null("../Terrain/Ground")
	if not ground_node:
		print("[WORLD] ❌ Ground node not found")
		return
	
	print("[WORLD] 🔍 Ground node found:", ground_node)
	
	# Create desert PBR material
	var desert_material = create_desert_pbr_material()
	if desert_material:
		ground_node.material_override = desert_material
		print("[WORLD] ✅ Real desert PBR texture applied successfully!")
	else:
		print("[WORLD] ❌ Failed to create desert material")

func create_desert_pbr_material() -> StandardMaterial3D:
	"""Create PBR material with downloaded desert textures"""
	print("[WORLD] 🎨 Creating desert PBR material...")
	
	var material = StandardMaterial3D.new()
	
	# Base paths
	var texture_base = "res://Textures/Ground/ground_0041_2k_N0kbi3/"
	
	# Load each texture map
	var textures = {
		"color": texture_base + "ground_0041_color_2k.jpg",
		"normal_opengl": texture_base + "ground_0041_normal_opengl_2k.png", 
		"roughness": texture_base + "ground_0041_roughness_2k.jpg",
		"ao": texture_base + "ground_0041_ao_2k.jpg",
		"height": texture_base + "ground_0041_height_2k.png"
	}
	
	# Apply color/albedo
	if ResourceLoader.exists(textures.color):
		material.albedo_texture = load(textures.color)
		print("[WORLD] ✅ Applied desert albedo texture")
	
	# Apply normal map
	if ResourceLoader.exists(textures.normal_opengl):
		material.normal_enabled = true
		material.normal_texture = load(textures.normal_opengl)
		material.normal_scale = 1.0
		print("[WORLD] ✅ Applied desert normal map")
	
	# Apply roughness map
	if ResourceLoader.exists(textures.roughness):
		material.roughness_texture = load(textures.roughness)
		print("[WORLD] ✅ Applied desert roughness map")
	
	# Apply AO map
	if ResourceLoader.exists(textures.ao):
		material.ao_enabled = true
		material.ao_texture = load(textures.ao)
		material.ao_light_affect = 1.0
		print("[WORLD] ✅ Applied desert AO map")
	
	# Apply height/displacement map (disabled to reduce crisp detail at distance)
	# if ResourceLoader.exists(textures.height):
	#	material.heightmap_enabled = true
	#	material.heightmap_texture = load(textures.height)
	#	material.heightmap_scale = 0.1
	#	print("[WORLD] ✅ Applied desert height map")
	
	# Set up UV tiling for better coverage (moderate tiling for balanced detail)
	material.uv1_scale = Vector3(25.0, 25.0, 1.0)  # Balanced texture tiling
	
	return material

func apply_fallback_building_materials():
	"""Apply concrete PBR textures to buildings"""
	print("[WORLD] 🏢 Applying concrete PBR textures to buildings...")
	
	# Create concrete material
	var concrete_material = create_concrete_pbr_material()
	if not concrete_material:
		print("[WORLD] ❌ Failed to create concrete material for buildings")
		return
	
	# Apply to all buildings
	var buildings_count = 0
	for building in buildings:
		if building and not building.material_override:
			building.material_override = concrete_material
			buildings_count += 1
			print("[WORLD] ✅ Applied concrete texture to building:", building.name)
	
	print("[WORLD] ✅ Concrete textures applied to %d buildings!" % buildings_count)

func apply_real_wood_textures():
	"""Apply real PBR wood textures to barriers/obstacles"""
	print("[WORLD] 🌲 Applying wood PBR textures to barriers...")
	
	var obstacles_node = get_node_or_null("../Obstacles")
	if not obstacles_node:
		print("[WORLD] ❌ Obstacles node not found")
		return
	
	# Create wood PBR material
	var wood_material = create_wood_pbr_material()
	if not wood_material:
		print("[WORLD] ❌ Failed to create wood material")
		return
	
	# Apply to all barriers
	var barriers_count = 0
	for child in obstacles_node.get_children():
		if child is MeshInstance3D:
			child.material_override = wood_material
			barriers_count += 1
			print("[WORLD] ✅ Applied wood texture to:", child.name)
	
	print("[WORLD] ✅ Wood PBR textures applied to %d barriers!" % barriers_count)

func create_wood_pbr_material() -> StandardMaterial3D:
	"""Create PBR material with downloaded wood textures"""
	print("[WORLD] 🎨 Creating wood PBR material...")
	
	var material = StandardMaterial3D.new()
	
	# Base paths
	var texture_base = "res://Textures/Barriers/wood_0046_2k_YXviLg/"
	
	# Load each texture map
	var textures = {
		"color": texture_base + "wood_0046_color_2k.jpg",
		"normal_opengl": texture_base + "wood_0046_normal_opengl_2k.png", 
		"roughness": texture_base + "wood_0046_roughness_2k.jpg",
		"ao": texture_base + "wood_0046_ambient_occlusion_2k.jpg",
		"height": texture_base + "wood_0046_height_2k.png"
	}
	
	# Apply color/albedo
	if ResourceLoader.exists(textures.color):
		material.albedo_texture = load(textures.color)
		print("[WORLD] ✅ Applied wood albedo texture")
	
	# Apply normal map
	if ResourceLoader.exists(textures.normal_opengl):
		material.normal_enabled = true
		material.normal_texture = load(textures.normal_opengl)
		material.normal_scale = 1.0
		print("[WORLD] ✅ Applied wood normal map")
	
	# Apply roughness map
	if ResourceLoader.exists(textures.roughness):
		material.roughness_texture = load(textures.roughness)
		print("[WORLD] ✅ Applied wood roughness map")
	
	# Apply AO map
	if ResourceLoader.exists(textures.ao):
		material.ao_enabled = true
		material.ao_texture = load(textures.ao)
		material.ao_light_affect = 1.0
		print("[WORLD] ✅ Applied wood AO map")
	
	# Apply height/displacement map
	if ResourceLoader.exists(textures.height):
		material.heightmap_enabled = true
		material.heightmap_texture = load(textures.height)
		material.heightmap_scale = 0.05  # Subtle displacement for wood
		print("[WORLD] ✅ Applied wood height map")
	
	# Set up UV tiling appropriate for wood planks
	material.uv1_scale = Vector3(2.0, 2.0, 1.0)  # Less tiling than ground
	
	return material

func create_concrete_pbr_material() -> StandardMaterial3D:
	"""Create PBR material with downloaded concrete textures"""
	print("[WORLD] 🏭 Creating concrete PBR material...")
	
	var material = StandardMaterial3D.new()
	
	# Base paths
	var texture_base = "res://Textures/Buildings/concrete_0018_2k_nJJC53/"
	
	# Load each texture map
	var textures = {
		"color": texture_base + "concrete_0018_color_2k.jpg",
		"normal_opengl": texture_base + "concrete_0018_normal_opengl_2k.png", 
		"roughness": texture_base + "concrete_0018_roughness_2k.jpg",
		"ao": texture_base + "concrete_0018_ao_2k.jpg",
		"height": texture_base + "concrete_0018_height_2k.png"
	}
	
	# Apply color/albedo
	if ResourceLoader.exists(textures.color):
		material.albedo_texture = load(textures.color)
		print("[WORLD] ✅ Applied concrete albedo texture")
	
	# Apply normal map
	if ResourceLoader.exists(textures.normal_opengl):
		material.normal_enabled = true
		material.normal_texture = load(textures.normal_opengl)
		material.normal_scale = 1.0
		print("[WORLD] ✅ Applied concrete normal map")
	
	# Apply roughness map
	if ResourceLoader.exists(textures.roughness):
		material.roughness_texture = load(textures.roughness)
		print("[WORLD] ✅ Applied concrete roughness map")
	
	# Apply AO map
	if ResourceLoader.exists(textures.ao):
		material.ao_enabled = true
		material.ao_texture = load(textures.ao)
		material.ao_light_affect = 1.0
		print("[WORLD] ✅ Applied concrete AO map")
	
	# Apply height/displacement map
	if ResourceLoader.exists(textures.height):
		material.heightmap_enabled = true
		material.heightmap_texture = load(textures.height)
		material.heightmap_scale = 0.05  # Subtle displacement for concrete
		print("[WORLD] ✅ Applied concrete height map")
	
	# Set up UV tiling appropriate for building concrete
	material.uv1_scale = Vector3(4.0, 4.0, 1.0)  # More tiling for building scale
	
	return material

func _input(event):
	"""Debug controls for world testing"""
	
	if event.is_action_pressed("ui_accept"):  # Space key
		print("[WORLD] World Info: ", get_world_info())
	
	if event.is_action_pressed("ui_select"):  # Enter key
		var random_pos = get_random_spawn_position()
		print("[WORLD] Random spawn position: ", random_pos) 