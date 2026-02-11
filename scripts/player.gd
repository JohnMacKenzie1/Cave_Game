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
var light_spheres := 0
var light_sphere_scene: PackedScene = preload("res://scenes/light_sphere.tscn")
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

var active_weapon := 0
var weapon_slots: Array[String] = []
var weapon_ui_slots: Array[Control] = []

func _try_pickup_spear() -> void:
	if has_spear:
		return
	var spears := get_tree().get_nodes_in_group("spear")
	for s in spears:
		if s.has_method("can_pickup") and s.can_pickup():
			s.pickup(self)
			has_spear = true
			spear_ref = s
			if "spear" not in weapon_slots:
				weapon_slots.append("spear")
			_switch_weapon(weapon_slots.find("spear") + 1)
			return

func _switch_weapon(slot: int) -> void:
	if slot < 1 or slot > weapon_slots.size():
		return
	active_weapon = slot
	var weapon_name: String = weapon_slots[slot - 1]
	var weapon_offset := get_node("Head/Camera3D/WeaponOffset")
	weapon_offset.visible = (weapon_name == "crossbow")
	ammo_label.visible = (weapon_name == "crossbow")
	if spear_ref != null:
		spear_ref.visible = (weapon_name == "spear")
	is_ads = false
	_update_weapon_ui()
	_update_sphere_ui()

func _update_weapon_ui() -> void:
	for ui in weapon_ui_slots:
		if is_instance_valid(ui):
			ui.queue_free()
	weapon_ui_slots.clear()

	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud == null:
		return

	for i in weapon_slots.size():
		var slot_num := i + 1
		var wname: String = weapon_slots[i]
		var is_active := (slot_num == active_weapon)

		var panel := PanelContainer.new()
		panel.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		panel.anchor_left = 1.0
		panel.anchor_top = 1.0
		panel.anchor_right = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = -220 + i * 70
		panel.offset_top = -120
		panel.offset_right = -155 + i * 70
		panel.offset_bottom = -65
		panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5) if is_active else Color(0, 0, 0, 0.25)
		style.border_color = Color(1, 1, 1, 0.8) if is_active else Color(1, 1, 1, 0.3)
		style.set_border_width_all(2 if is_active else 1)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)

		# Weapon icon drawn with simple lines
		var icon_label := Label.new()
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 16)
		icon_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9) if is_active else Color(1, 1, 1, 0.4))
		if wname == "crossbow":
			icon_label.text = "[+>"
		elif wname == "spear":
			icon_label.text = "---|>"
		elif wname == "spheres":
			icon_label.text = "( * )"
		vbox.add_child(icon_label)

		# Slot number
		var num_label := Label.new()
		num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_label.add_theme_font_size_override("font_size", 12)
		num_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7) if is_active else Color(1, 1, 1, 0.3))
		num_label.text = str(slot_num)
		vbox.add_child(num_label)

		hud.add_child(panel)
		weapon_ui_slots.append(panel)

func _try_pickup_spheres() -> void:
	# Pick up wall-spawned sphere pickups
	var wall_pickups := get_tree().get_nodes_in_group("sphere_pickup")
	for p in wall_pickups:
		if p.has_meta("player_nearby") and p.get_meta("player_nearby"):
			for pp in wall_pickups:
				pp.queue_free()
			light_spheres += 3
			if "spheres" not in weapon_slots:
				weapon_slots.append("spheres")
			_switch_weapon(weapon_slots.find("spheres") + 1)
			_update_sphere_ui()
			return
	# Pick up thrown spheres on the ground
	var spheres := get_tree().get_nodes_in_group("light_sphere")
	for s in spheres:
		if s.is_in_group("sphere_pickup"):
			continue
		if s.has_method("can_pickup") and s.can_pickup():
			light_spheres += 1
			_update_sphere_ui()
			s.queue_free()
			return

func throw_light_sphere() -> void:
	if light_spheres <= 0:
		return
	light_spheres -= 1
	_update_sphere_ui()
	var sphere := light_sphere_scene.instantiate()
	get_tree().current_scene.add_child(sphere)
	var origin := camera.global_position + camera.global_basis * Vector3(0, -0.1, -0.6)
	var direction := -camera.global_basis.z
	sphere.throw(origin, direction)

func _update_sphere_ui() -> void:
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud == null:
		return
	var existing := hud.get_node_or_null("SphereCounter")
	if light_spheres > 0:
		if existing == null:
			existing = Label.new()
			existing.name = "SphereCounter"
			existing.anchors_preset = Control.PRESET_BOTTOM_RIGHT
			existing.anchor_left = 1.0
			existing.anchor_top = 1.0
			existing.anchor_right = 1.0
			existing.anchor_bottom = 1.0
			existing.offset_left = -220
			existing.offset_top = -150
			existing.offset_right = -30
			existing.offset_bottom = -125
			existing.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			existing.grow_vertical = Control.GROW_DIRECTION_BEGIN
			existing.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			existing.add_theme_font_size_override("font_size", 20)
			existing.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 0.85))
			hud.add_child(existing)
		existing.text = "SPHERES: %d" % light_spheres
	elif existing != null:
		existing.queue_free()

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

	var active_name := weapon_slots[active_weapon - 1] if active_weapon >= 1 and active_weapon <= weapon_slots.size() else ""

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_ads = event.pressed and active_name == "crossbow"

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif active_name == "spear" and has_spear:
			throw_spear()
		elif active_name == "crossbow" and has_crossbow and can_shoot and ammo > 0:
			shoot()
		elif active_name == "spheres" and light_spheres > 0:
			throw_light_sphere()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		if has_spear:
			throw_spear()

	if event.is_action_pressed("interact"):
		_try_pickup_spear()
		_try_pickup_spheres()

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			_switch_weapon(1)
		elif event.keycode == KEY_2:
			_switch_weapon(2)
		elif event.keycode == KEY_3:
			_switch_weapon(3)

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

	# Sphere pickup prompt
	var sphere_prompt := get_tree().current_scene.get_node_or_null("HUD/SpherePrompt")
	if sphere_prompt:
		var near_wall := false
		var near_ground := false
		for p in get_tree().get_nodes_in_group("sphere_pickup"):
			if p.has_meta("player_nearby") and p.get_meta("player_nearby"):
				near_wall = true
				break
		if not near_wall:
			for s in get_tree().get_nodes_in_group("light_sphere"):
				if s.is_in_group("sphere_pickup"):
					continue
				if s.has_method("can_pickup") and s.can_pickup():
					near_ground = true
					break
		if near_wall:
			sphere_prompt.text = "Press E to pick up light spheres"
			sphere_prompt.visible = true
		elif near_ground:
			sphere_prompt.text = "Press E to pick up light sphere"
			sphere_prompt.visible = true
		else:
			sphere_prompt.visible = false

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
