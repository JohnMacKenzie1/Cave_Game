extends CharacterBody3D

signal dwarf_died

const SPEED := 4.5
const PANIC_SPEED := 7.5
const WAYPOINT_RADIUS := 1.5
const TURN_SPEED := 8.0
const FALL_SPEED := 2.0
const PANIC_DURATION := 4.0

var dead := false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var time := 0.0
var hp := 2
var hit_cooldown := 0.0
var panic_timer := 0.0
var path: Array[Vector3] = []
var path_idx := 0
var last_room_id := -1
var bleeding := false
var bleed_timer := 0.0
var drip_timer := 0.0

@onready var left_arm: MeshInstance3D = $LeftArm
@onready var right_arm: MeshInstance3D = $RightArm

func _ready() -> void:
	add_to_group("enemy")
	_pick_destination()

func _pick_destination() -> void:
	var labyrinth := get_tree().current_scene.get_node_or_null("Labyrinth")
	if labyrinth == null:
		return
	var from_id: int = labyrinth._pos_to_room_id(global_position)
	var neighbors: PackedInt64Array = labyrinth.astar.get_point_connections(from_id)
	if neighbors.is_empty():
		return
	# Avoid going back the way we came, unless it's a dead end
	var choices: Array[int] = []
	for n in neighbors:
		if int(n) != last_room_id:
			choices.append(int(n))
	if choices.is_empty():
		choices.append(int(neighbors[0]))
	var target_id: int = choices[randi() % choices.size()]
	last_room_id = from_id
	var from_pos: Vector3 = labyrinth.astar.get_point_position(from_id)
	var to_pos: Vector3 = labyrinth.astar.get_point_position(target_id)
	var mid := (from_pos + to_pos) / 2.0
	mid.y = 0.0
	to_pos.y = 0.0
	path = [mid, to_pos]
	path_idx = 0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	time += delta
	hit_cooldown = maxf(hit_cooldown - delta, 0.0)
	var current_speed := PANIC_SPEED if bleeding else SPEED

	if path.is_empty() or path_idx >= path.size():
		_pick_destination()

	if path_idx < path.size():
		var target: Vector3 = path[path_idx]
		var to_target: Vector3 = target - global_position
		to_target.y = 0
		if to_target.length() < WAYPOINT_RADIUS:
			path_idx += 1
			if path_idx >= path.size():
				_pick_destination()
				if path_idx < path.size():
					target = path[path_idx]
					to_target = target - global_position
					to_target.y = 0

		if path_idx < path.size():
			var dir := (path[path_idx] - global_position)
			dir.y = 0
			if dir.length() > 0.01:
				dir = dir.normalized()
				velocity.x = dir.x * current_speed
				velocity.z = dir.z * current_speed
				var ta := atan2(dir.x, dir.z)
				rotation.y = lerp_angle(rotation.y, ta, minf(TURN_SPEED * delta, 1.0))
	else:
		velocity.x = 0
		velocity.z = 0

	# Blood drip trail when wounded
	if bleeding and not dead:
		drip_timer -= delta
		if drip_timer <= 0.0:
			drip_timer = randf_range(1.5, 3.0)
			_spawn_drip()

	var sw := sin(time * 10.0) * 0.5
	left_arm.rotation.x = sw
	right_arm.rotation.x = -sw

	move_and_slide()

func take_damage(amount: int, hit_pos: Vector3) -> void:
	if dead or hit_cooldown > 0.0:
		return
	# Only body/head hits count - reject arm shots
	var local_hit := global_transform.affine_inverse() * hit_pos
	var left_arm_pos := left_arm.position
	var right_arm_pos := right_arm.position
	var dist_left := Vector2(local_hit.x - left_arm_pos.x, local_hit.z - left_arm_pos.z).length()
	var dist_right := Vector2(local_hit.x - right_arm_pos.x, local_hit.z - right_arm_pos.z).length()
	if dist_left < 0.1 or dist_right < 0.1:
		_spawn_blood(hit_pos)
		return
	hp -= amount
	hit_cooldown = 0.5
	panic_timer = PANIC_DURATION
	last_hit_pos = hit_pos
	bleeding = true
	_spawn_blood(hit_pos)
	if hp <= 0:
		_die()

func die() -> void:
	take_damage(1, global_position + Vector3(0, 0.5, 0))

func _spawn_blood(pos: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.6, 0.02, 0.02, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.0, 0.0)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	mesh.material = mat
	var proc := ParticleProcessMaterial.new()
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 45.0
	proc.initial_velocity_min = 2.0
	proc.initial_velocity_max = 4.0
	proc.gravity = Vector3(0, -6, 0)
	proc.scale_min = 0.5
	proc.scale_max = 1.5
	proc.color = Color(0.6, 0.02, 0.02, 0.9)
	var blood := GPUParticles3D.new()
	blood.amount = 20
	blood.lifetime = 0.6
	blood.one_shot = true
	blood.explosiveness = 1.0
	blood.draw_pass_1 = mesh
	blood.process_material = proc
	blood.emitting = true
	get_tree().current_scene.add_child(blood)
	blood.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(blood.queue_free)

var last_hit_pos := Vector3.ZERO

func _die() -> void:
	dead = true
	velocity = Vector3.ZERO
	path.clear()
	set_physics_process(false)
	# Face away from hit, then fall in that direction
	var away := global_position - last_hit_pos
	away.y = 0
	if away.length() > 0.01:
		rotation.y = atan2(away.x, away.z)
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", deg_to_rad(90), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", 0.1, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_spawn_blood_puddle)
	tween.tween_callback(_on_death_finished)

func _spawn_drip() -> void:
	var drip := CSGCylinder3D.new()
	drip.radius = randf_range(0.03, 0.08)
	drip.height = 0.01
	drip.sides = 8
	var offset := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
	drip.position = Vector3(global_position.x + offset.x, 0.01, global_position.z + offset.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.02, 0.02)
	drip.material = mat
	get_tree().current_scene.add_child(drip)

func _spawn_blood_puddle() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.02, 0.02)
	var parent := Node3D.new()
	parent.position = Vector3(global_position.x, 0.01, global_position.z)
	get_tree().current_scene.add_child(parent)
	# Several overlapping blobs for irregular shape
	for i in 5:
		var blob := CSGCylinder3D.new()
		blob.radius = 0.03
		blob.height = 0.02
		blob.sides = 16
		var offset := Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
		blob.position = offset
		blob.material = mat
		parent.add_child(blob)
		var target_radius := randf_range(0.5, 0.9)
		var grow_time := randf_range(21.0, 36.0)
		var tw := get_tree().create_tween()
		tw.tween_property(blob, "radius", target_radius, grow_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_death_finished() -> void:
	dwarf_died.emit()
