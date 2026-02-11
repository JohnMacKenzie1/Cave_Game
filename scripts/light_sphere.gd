extends RigidBody3D

var light: OmniLight3D
var _player_nearby := false

func _ready() -> void:
	add_to_group("light_sphere")
	freeze = false
	gravity_scale = 1.0
	continuous_cd = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.4
	physics_material_override.friction = 0.8
	contact_monitor = true
	max_contacts_reported = 1
	collision_layer = 1
	collision_mask = 1

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.15
	sphere_mesh.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.95, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.4)
	mat.emission_energy_multiplier = 2.0
	sphere_mesh.material = mat
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = sphere_mesh
	add_child(mesh_inst)

	var col_shape := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.15
	col_shape.shape = shape
	add_child(col_shape)

	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 5.0
	light.omni_range = 18.0
	light.omni_attenuation = 1.0
	add_child(light)

	# Pickup detection area
	var pickup_area := Area3D.new()
	pickup_area.collision_layer = 0
	pickup_area.collision_mask = 2
	var area_shape := CollisionShape3D.new()
	var area_sphere := SphereShape3D.new()
	area_sphere.radius = 1.0
	area_shape.shape = area_sphere
	pickup_area.add_child(area_shape)
	add_child(pickup_area)
	pickup_area.body_entered.connect(_on_body_entered)
	pickup_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = false

func can_pickup() -> bool:
	return _player_nearby

func throw(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	linear_velocity = direction.normalized() * 15.0
