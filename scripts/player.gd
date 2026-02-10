extends CharacterBody3D

const SPEED = 5.0
const SPRINT_SPEED = 8.5
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.0015
const SHOOT_COOLDOWN = 0.8
const MAX_AMMO = 20

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var crossbow: Node3D = $Head/Camera3D/WeaponOffset/Crossbow
@onready var ammo_label: Label = get_node("../HUD/AmmoCounter")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var impact_scene: PackedScene = preload("res://scenes/impact.tscn")
var bolt_scene: PackedScene = preload("res://scenes/bolt.tscn")
var has_crossbow := false
var has_spear := false
var spear_ref: Node = null
var can_shoot := true
var ammo := MAX_AMMO
var torch_light: OmniLight3D
var torch_time := 0.0
var is_ads := false
var ads_lerp := 0.0
const ADS_SPEED := 10.0
const ADS_FOV := 55.0
const HIP_FOV := 75.0
const ADS_POS := Vector3(0.0, -0.16, -0.34)
const ADS_ROT_DEG := Vector3(4.0, 0.0, 0.0)
const HIP_POS := Vector3(0.3, -0.25, -0.45)
const HIP_ROT_DEG := Vector3(-1.0, -4.0, 0.75)

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	update_ammo_display()
	_setup_torch()
	# Hide crossbow until picked up
	var weapon_offset := get_node("Head/Camera3D/WeaponOffset")
	weapon_offset.visible = false
	ammo_label.visible = false

func equip_crossbow() -> void:
	var weapon_offset := get_node("Head/Camera3D/WeaponOffset")
	weapon_offset.visible = true
	ammo_label.visible = true

func equip_spear() -> void:
	pass

func _try_pickup_spear() -> void:
	if has_spear:
		return
	var spears := get_tree().get_nodes_in_group("spear")
	for s in spears:
		if s.has_method("can_pickup") and s.can_pickup():
			s.pickup(self)
			has_spear = true
			spear_ref = s
			return

func throw_spear() -> void:
	if not has_spear or spear_ref == null:
		return
	has_spear = false
	var origin := camera.global_position + camera.global_basis * Vector3(0, -0.05, -0.8)
	var direction := -camera.global_basis.z
	spear_ref.throw_spear(origin, direction)
	spear_ref = null

func _setup_torch() -> void:
	var torch_pivot := Node3D.new()
	torch_pivot.name = "TorchPivot"
	torch_pivot.position = Vector3(-0.3, -0.2, -0.45)
	camera.add_child(torch_pivot)

	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.03, 0.18, 0.03)
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0, -0.12, 0)
	var shaft_mat := StandardMaterial3D.new()
	shaft_mat.albedo_color = Color(0.4, 0.25, 0.1)
	shaft.material_override = shaft_mat
	torch_pivot.add_child(shaft)

	var flame := MeshInstance3D.new()
	var flame_mesh := BoxMesh.new()
	flame_mesh.size = Vector3(0.04, 0.06, 0.04)
	flame.mesh = flame_mesh
	flame.position = Vector3(0, 0.0, 0)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.8, 0.3)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.15)
	flame_mat.emission_energy_multiplier = 2.0
	flame.material_override = flame_mat
	torch_pivot.add_child(flame)

	torch_light = OmniLight3D.new()
	torch_light.position = Vector3(0, 0.03, 0)
	torch_light.light_color = Color(1.0, 0.7, 0.3)
	torch_light.light_energy = 2.5
	torch_light.omni_range = 14.0
	torch_light.omni_attenuation = 1.0
	torch_pivot.add_child(torch_light)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_ads = event.pressed and has_crossbow

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif has_spear and not has_crossbow:
			throw_spear()
		elif has_crossbow and can_shoot and ammo > 0:
			shoot()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if has_spear:
			throw_spear()

	if event.is_action_pressed("interact"):
		_try_pickup_spear()

func _process(delta: float) -> void:
	torch_time += delta
	var flicker := 2.5 + 0.15 * sin(torch_time * 3.3) + 0.1 * sin(torch_time * 7.1)
	torch_light.light_energy = clampf(flicker, 2.2, 2.8)

	# Spear pickup prompt
	if not has_spear:
		var spears := get_tree().get_nodes_in_group("spear")
		var near_spear := false
		for s in spears:
			if s.has_method("can_pickup") and s.can_pickup():
				near_spear = true
				break
		for s in spears:
			if s.has_method("show_prompt"):
				s.show_prompt(near_spear)

	# ADS interpolation
	var target_ads := 1.0 if is_ads else 0.0
	ads_lerp = lerp(ads_lerp, target_ads, ADS_SPEED * delta)
	var weapon_offset := get_node("Head/Camera3D/WeaponOffset")
	weapon_offset.position = HIP_POS.lerp(ADS_POS, ads_lerp)
	var hip_rot := Vector3(deg_to_rad(HIP_ROT_DEG.x), deg_to_rad(HIP_ROT_DEG.y), deg_to_rad(HIP_ROT_DEG.z))
	var ads_rot := Vector3(deg_to_rad(ADS_ROT_DEG.x), deg_to_rad(ADS_ROT_DEG.y), deg_to_rad(ADS_ROT_DEG.z))
	weapon_offset.rotation = hip_rot.lerp(ads_rot, ads_lerp)
	camera.fov = lerp(HIP_FOV, ADS_FOV, ads_lerp)

func _physics_process(delta: float) -> void:
	# Gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump.`
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Sprint.
	var current_speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED

	# Movement.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor():
		if direction:
			velocity.x = direction.x * current_speed
			velocity.z = direction.z * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)
			velocity.z = move_toward(velocity.z, 0, current_speed)
	else:
		velocity.x = lerp(velocity.x, direction.x * current_speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * current_speed, delta * 3.0)

	move_and_slide()

func shoot() -> void:
	can_shoot = false
	ammo -= 1
	update_ammo_display()
	crossbow.shoot()

	# Spawn bolt projectile
	var bolt := bolt_scene.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_transform = Transform3D.IDENTITY
	bolt.global_position = camera.global_position + camera.global_basis * Vector3(0, -0.05, -0.6)
	bolt.global_rotation = camera.global_rotation
	bolt.scale = Vector3.ONE
	bolt.fire()


	get_tree().create_timer(SHOOT_COOLDOWN).timeout.connect(func(): can_shoot = true)

func update_ammo_display() -> void:
	ammo_label.text = "BOLTS: %d" % ammo
	if ammo == 0:
		ammo_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2, 0.85))
	else:
		ammo_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
