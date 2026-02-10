extends Node3D

const SPEED := 40.0
const GRAVITY := 3.0
const LIFETIME := 10.0

var vel := Vector3.ZERO
var alive := true
var timer := 0.0

func fire() -> void:
	vel = -global_transform.basis.z * SPEED

func _physics_process(delta: float) -> void:
	if not alive:
		return
	timer += delta
	if timer > LIFETIME:
		queue_free()
		return

	vel.y -= GRAVITY * delta
	var from := global_position
	var to := from + vel * delta

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, 5)
	var result := space.intersect_ray(query)

	if result:
		alive = false
		global_position = result.position
		look_at(global_position + vel, Vector3.UP)
		global_position += -global_transform.basis.z * -0.02
		var body: Node = result.collider
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(1, result.position)
		var pos := global_position
		var rot := global_rotation
		get_parent().remove_child(self)
		body.add_child(self)
		global_position = pos
		global_rotation = rot
	else:
		global_position = to
		look_at(global_position + vel, Vector3.UP)
	
