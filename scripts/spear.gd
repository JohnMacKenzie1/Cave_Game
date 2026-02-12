extends RigidBody3D

const THROW_SPEED := 35.0
const THROW_GRAVITY := 3.0
const DAMAGE := 2

var is_held := false
var is_thrown := false
var _player_nearby := false
var vel := Vector3.ZERO

func _ready() -> void:
	add_to_group("spear")
	freeze = true
	gravity_scale = 0.0
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	$PickupArea.body_entered.connect(_on_pickup_enter)
	$PickupArea.body_exited.connect(_on_pickup_exit)
	visible = true
	set_floor_pose()

func _on_pickup_enter(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = true
		if not is_held:
			var p := get_tree().current_scene.get_node_or_null("HUD/SpearPrompt")
			if p:
				p.visible = true

func _on_pickup_exit(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = false
		var p := get_tree().current_scene.get_node_or_null("HUD/SpearPrompt")
		if p:
			p.visible = false

func _physics_process(delta: float) -> void:
	if not is_thrown:
		return

	vel.y -= THROW_GRAVITY * delta
	var from := global_position
	var to := from + vel * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 5)
	var result := space.intersect_ray(query)

	if result:
		is_thrown = false
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		look_at(global_position + vel, Vector3.UP)
		rotate_object_local(Vector3.RIGHT, deg_to_rad(140))
		# Position so tip is at hit point, pull back along flight direction
		global_position = result.position - vel.normalized() * 0.5
		var body: Node = result.collider
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(DAMAGE, result.position)
			var pos := global_position
			var rot := global_rotation
			get_parent().remove_child(self)
			body.add_child(self)
			global_position = pos
			global_rotation = rot
	else:
		global_position = to
		look_at(global_position + vel, Vector3.UP)
		rotate_object_local(Vector3.RIGHT, deg_to_rad(140))

func can_pickup() -> bool:
	return _player_nearby and not is_held and not is_thrown

func set_floor_pose() -> void:
	rotation_degrees = Vector3(220, 0, 0)

func set_hand_pose() -> void:
	position = Vector3(0.3, -0.35, -0.5)
	rotation_degrees = Vector3(140, 0, 0)

func pickup(player: Node3D) -> void:
	is_held = true
	is_thrown = false
	freeze = true
	collision_layer = 0
	collision_mask = 0
	var p := get_tree().current_scene.get_node_or_null("HUD/SpearPrompt")
	if p:
		p.visible = false
	var cam: Node3D = player.get_node("Head/Camera3D")
	var hand: Node3D = cam.get_node_or_null("Hand")
	if hand == null:
		hand = Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3.ZERO
		hand.scale = Vector3.ONE
		cam.add_child(hand)
	if get_parent() != null:
		get_parent().remove_child(self)
	hand.add_child(self)
	scale = Vector3.ONE
	set_hand_pose()
	visible = true

func throw_spear(origin: Vector3, direction: Vector3) -> void:
	is_held = false
	is_thrown = true
	var root := get_tree().current_scene
	if get_parent() != null:
		get_parent().remove_child(self)
	root.add_child(self)
	global_position = origin
	vel = direction.normalized() * THROW_SPEED
	look_at(origin + direction, Vector3.UP)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(140))
	freeze = true
	collision_layer = 0
	collision_mask = 0
	visible = true
