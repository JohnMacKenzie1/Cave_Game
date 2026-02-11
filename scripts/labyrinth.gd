extends Node3D

const ROOM_SIZE := 12.0
const ROOM_HEIGHT := 5.0
const WALL_THICK := 0.5
const SPACING := 22.0
const PASSAGE_WIDTH := 4.0
const PASSAGE_LENGTH := 10.0
const LONG_PASSAGE := 14.0
const LONG_WIDTH := 4.0
const LONG_PASSAGES: Array[int] = [1, 4, 8, 11, 14]

var cube_scene: PackedScene = preload("res://scenes/cube_enemy.tscn")
var torch_scene: PackedScene = preload("res://scenes/torch.tscn")
var pickup_scene: PackedScene = preload("res://scenes/crossbow_pickup.tscn")
var spear_scene: PackedScene = preload("res://scenes/spear.tscn")
var light_sphere_scene: PackedScene = preload("res://scenes/light_sphere.tscn")

var mats := {}
var mat_ceiling: StandardMaterial3D

var connections: Array = []
var astar := AStar3D.new()

func _ready() -> void:
	_create_materials()
	_define_connections()
	_build_astar()
	_build_rooms()
	_build_passages()
	_spawn_pickup()
	_spawn_spear_pickup()
	_spawn_light_spheres()
	_build_armory_sign()

func _room_id(row: int, col: int) -> int:
	return row * 4 + col

func _build_astar() -> void:
	for row in range(4):
		for col in range(4):
			var id := _room_id(row, col)
			astar.add_point(id, _room_center(row, col))
	for c in connections:
		var a: Vector2i = c[0]
		var b: Vector2i = c[1]
		astar.connect_points(_room_id(a.x, a.y), _room_id(b.x, b.y))

func _pos_to_room_id(pos: Vector3) -> int:
	var best_id := 0
	var best_dist := 99999.0
	for row in range(4):
		for col in range(4):
			var c := _room_center(row, col)
			var d := Vector2(pos.x - c.x, pos.z - c.z).length()
			if d < best_dist:
				best_dist = d
				best_id = _room_id(row, col)
	return best_id

func get_flee_path(from_pos: Vector3, player_pos: Vector3) -> Array[Vector3]:
	var from_id := _pos_to_room_id(from_pos)
	var player_id := _pos_to_room_id(player_pos)

	# Find farthest room from player
	var best_id := from_id
	var best_dist := -1.0
	for row in range(4):
		for col in range(4):
			var id := _room_id(row, col)
			if id == from_id:
				continue
			var c := _room_center(row, col)
			var d := Vector2(c.x - player_pos.x, c.z - player_pos.z).length()
			if d > best_dist:
				best_dist = d
				best_id = id

	var id_path := astar.get_id_path(from_id, best_id)
	var waypoints: Array[Vector3] = []
	for i in range(id_path.size()):
		var pt: Vector3 = astar.get_point_position(id_path[i])
		if i > 0:
			# Add doorway midpoint between consecutive rooms
			var prev: Vector3 = astar.get_point_position(id_path[i - 1])
			var mid := (prev + pt) / 2.0
			mid.y = 0.0
			waypoints.append(mid)
		pt.y = 0.0
		waypoints.append(pt)
	return waypoints

func _create_materials() -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.25, 0.2)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.3, 0.25)
	mats["nw"] = [floor_mat, wall_mat]
	mats["ne"] = [floor_mat, wall_mat]
	mats["sw"] = [floor_mat, wall_mat]
	mats["se"] = [floor_mat, wall_mat]

	mat_ceiling = StandardMaterial3D.new()
	mat_ceiling.albedo_color = Color(0.2, 0.17, 0.14)

func _define_connections() -> void:
	# Horizontal
	connections.append([Vector2i(0,0), Vector2i(0,1)])
	connections.append([Vector2i(0,2), Vector2i(0,3)])
	connections.append([Vector2i(1,0), Vector2i(1,1)])
	connections.append([Vector2i(1,1), Vector2i(1,2)])
	connections.append([Vector2i(2,0), Vector2i(2,1)])
	connections.append([Vector2i(2,1), Vector2i(2,2)])
	connections.append([Vector2i(2,2), Vector2i(2,3)])
	connections.append([Vector2i(3,0), Vector2i(3,1)])
	connections.append([Vector2i(3,1), Vector2i(3,2)])
	connections.append([Vector2i(3,2), Vector2i(3,3)])
	# Vertical
	connections.append([Vector2i(0,0), Vector2i(1,0)])
	connections.append([Vector2i(0,2), Vector2i(1,2)])
	connections.append([Vector2i(1,2), Vector2i(2,2)])
	connections.append([Vector2i(1,3), Vector2i(2,3)])
	connections.append([Vector2i(2,1), Vector2i(3,1)])
	# Loops
	connections.append([Vector2i(2,2), Vector2i(3,2)])
	connections.append([Vector2i(1,0), Vector2i(2,0)])

func _get_quadrant(row: int, col: int) -> String:
	if row <= 1 and col <= 1:
		return "nw"
	elif row <= 1:
		return "ne"
	elif col <= 1:
		return "sw"
	else:
		return "se"

func _get_light_color(quadrant: String) -> Color:
	match quadrant:
		"nw": return Color(1.0, 0.7, 0.3)
		"ne": return Color(0.4, 0.6, 0.9)
		"sw": return Color(0.3, 0.8, 0.4)
		"se": return Color(0.9, 0.3, 0.1)
	return Color(1.0, 0.7, 0.3)

func _room_center(row: int, col: int) -> Vector3:
	return Vector3(col * SPACING, 0.0, row * SPACING)

func _has_connection(row: int, col: int, dr: int, dc: int) -> bool:
	var a := Vector2i(row, col)
	var b := Vector2i(row + dr, col + dc)
	for c in connections:
		if (c[0] == a and c[1] == b) or (c[0] == b and c[1] == a):
			return true
	return false

func _add_box(parent: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var box := CSGBox3D.new()
	box.size = sz
	box.position = pos
	box.use_collision = true
	box.material = mat
	parent.add_child(box)

func _build_rooms() -> void:
	for row in range(4):
		for col in range(4):
			var center := _room_center(row, col)
			var quad := _get_quadrant(row, col)
			var floor_mat: StandardMaterial3D = mats[quad][0]
			var wall_mat: StandardMaterial3D = mats[quad][1]

			var room := Node3D.new()
			room.name = "Room_%d_%d" % [row, col]
			room.position = center
			add_child(room)

			_add_box(room, Vector3(0, -0.5, 0), Vector3(ROOM_SIZE, 1, ROOM_SIZE), floor_mat)
			_add_box(room, Vector3(0, 5.25, 0), Vector3(ROOM_SIZE, 0.5, ROOM_SIZE), mat_ceiling)

			_build_wall(room, wall_mat, row, col, "north")
			_build_wall(room, wall_mat, row, col, "south")
			_build_wall(room, wall_mat, row, col, "east")
			_build_wall(room, wall_mat, row, col, "west")

			_place_torches(room, row, col)

func _build_wall(room: Node3D, wall_mat: StandardMaterial3D, row: int, col: int, side: String) -> void:
	var half := ROOM_SIZE / 2.0
	var side_len := (ROOM_SIZE - PASSAGE_WIDTH) / 2.0

	var has_door := false
	match side:
		"north":
			has_door = _has_connection(row, col, -1, 0)
		"south":
			has_door = _has_connection(row, col, 1, 0)
		"east":
			has_door = _has_connection(row, col, 0, 1)
		"west":
			has_door = _has_connection(row, col, 0, -1)

	match side:
		"north":
			if has_door:
				_add_box(room, Vector3(-(half - side_len / 2.0), 2.5, -half), Vector3(side_len, 5, WALL_THICK), wall_mat)
				_add_box(room, Vector3( (half - side_len / 2.0), 2.5, -half), Vector3(side_len, 5, WALL_THICK), wall_mat)
				_add_box(room, Vector3(0, 4.25, -half), Vector3(PASSAGE_WIDTH, 1.5, WALL_THICK), wall_mat)
			else:
				_add_box(room, Vector3(0, 2.5, -half), Vector3(ROOM_SIZE, 5, WALL_THICK), wall_mat)
		"south":
			if has_door:
				_add_box(room, Vector3(-(half - side_len / 2.0), 2.5, half), Vector3(side_len, 5, WALL_THICK), wall_mat)
				_add_box(room, Vector3( (half - side_len / 2.0), 2.5, half), Vector3(side_len, 5, WALL_THICK), wall_mat)
				_add_box(room, Vector3(0, 4.25, half), Vector3(PASSAGE_WIDTH, 1.5, WALL_THICK), wall_mat)
			else:
				_add_box(room, Vector3(0, 2.5, half), Vector3(ROOM_SIZE, 5, WALL_THICK), wall_mat)
		"east":
			if has_door:
				_add_box(room, Vector3(half, 2.5, -(half - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
				_add_box(room, Vector3(half, 2.5,  (half - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
				_add_box(room, Vector3(half, 4.25, 0), Vector3(WALL_THICK, 1.5, PASSAGE_WIDTH), wall_mat)
			else:
				_add_box(room, Vector3(half, 2.5, 0), Vector3(WALL_THICK, 5, ROOM_SIZE), wall_mat)
		"west":
			if has_door:
				_add_box(room, Vector3(-half, 2.5, -(half - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
				_add_box(room, Vector3(-half, 2.5,  (half - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
				_add_box(room, Vector3(-half, 4.25, 0), Vector3(WALL_THICK, 1.5, PASSAGE_WIDTH), wall_mat)
			else:
				_add_box(room, Vector3(-half, 2.5, 0), Vector3(WALL_THICK, 5, ROOM_SIZE), wall_mat)

func _place_torches(room: Node3D, row: int, col: int) -> void:
	if not (row == 0 and col == 0) and not (row == 0 and col == 1):
		return
	var half := ROOM_SIZE / 2.0
	var corner := half - 0.5
	var spots: Array = []

	if row == 0 and col == 1:
		# Armory: 4 torches in corners
		spots.append([Vector3(-corner, 2.5, -corner), PI / 4.0])
		spots.append([Vector3(corner, 2.5, -corner), -PI / 4.0])
		spots.append([Vector3(-corner, 2.5, corner), 3.0 * PI / 4.0])
		spots.append([Vector3(corner, 2.5, corner), -3.0 * PI / 4.0])
	elif row == 0 and col == 0:
		# Spawn room: 2 torches in far corners (north wall)
		spots.append([Vector3(-corner, 2.5, -corner), PI / 4.0])
		spots.append([Vector3(corner, 2.5, -corner), -PI / 4.0])

	var rod_mat := StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.15, 0.15, 0.18)
	rod_mat.metallic = 0.8

	for spot in spots:
		var t := torch_scene.instantiate()
		t.position = spot[0]
		t.rotation.y = spot[1]
		room.add_child(t)

		# Rod from corner wall to torch
		var rod := MeshInstance3D.new()
		var rod_mesh := BoxMesh.new()
		rod_mesh.size = Vector3(0.06, 0.06, 0.8)
		rod.mesh = rod_mesh
		rod.material_override = rod_mat
		rod.position = Vector3(0, 0.0, -0.4)
		rod.rotation.y = 0.0
		t.add_child(rod)

func _build_passages() -> void:
	for idx in connections.size():
		var c: Array = connections[idx]
		var a: Vector2i = c[0]
		var b: Vector2i = c[1]
		var ca := _room_center(a.x, a.y)
		var cb := _room_center(b.x, b.y)
		var mid := (ca + cb) / 2.0

		var quad := _get_quadrant(a.x, a.y)
		var floor_mat: StandardMaterial3D = mats[quad][0]
		var wall_mat: StandardMaterial3D = mats[quad][1]

		var is_long := idx in LONG_PASSAGES
		var p_length := PASSAGE_LENGTH
		var p_width := LONG_WIDTH if is_long else PASSAGE_WIDTH

		var passage := Node3D.new()
		passage.name = "Passage_%d%d_%d%d" % [a.x, a.y, b.x, b.y]
		passage.position = mid
		add_child(passage)

		var is_horizontal := (a.x == b.x)
		var pw := p_width / 2.0 + WALL_THICK / 2.0

		if is_horizontal:
			_add_box(passage, Vector3(0, -0.5, 0), Vector3(p_length, 1, p_width), floor_mat)
			_add_box(passage, Vector3(0, 3.75, 0), Vector3(p_length, 0.5, p_width + 0.5), mat_ceiling)
			_add_box(passage, Vector3(0, 1.75, -pw), Vector3(p_length, 3.5, WALL_THICK), wall_mat)
			_add_box(passage, Vector3(0, 1.75,  pw), Vector3(p_length, 3.5, WALL_THICK), wall_mat)
		else:
			_add_box(passage, Vector3(0, -0.5, 0), Vector3(p_width, 1, p_length), floor_mat)
			_add_box(passage, Vector3(0, 3.75, 0), Vector3(p_width + 0.5, 0.5, p_length), mat_ceiling)
			_add_box(passage, Vector3(-pw, 1.75, 0), Vector3(WALL_THICK, 3.5, p_length), wall_mat)
			_add_box(passage, Vector3( pw, 1.75, 0), Vector3(WALL_THICK, 3.5, p_length), wall_mat)

	
func get_room_exits(pos: Vector3) -> Array[Vector3]:
	var best_row := 0
	var best_col := 0
	var best_dist := 99999.0
	for row in range(4):
		for col in range(4):
			var c := _room_center(row, col)
			var d := Vector2(pos.x - c.x, pos.z - c.z).length()
			if d < best_dist:
				best_dist = d
				best_row = row
				best_col = col
	var center := _room_center(best_row, best_col)
	var exits: Array[Vector3] = []
	var half := ROOM_SIZE / 2.0
	if _has_connection(best_row, best_col, -1, 0):
		exits.append(Vector3(center.x, 0, center.z - half))
	if _has_connection(best_row, best_col, 1, 0):
		exits.append(Vector3(center.x, 0, center.z + half))
	if _has_connection(best_row, best_col, 0, 1):
		exits.append(Vector3(center.x + half, 0, center.z))
	if _has_connection(best_row, best_col, 0, -1):
		exits.append(Vector3(center.x - half, 0, center.z))
	return exits

func _spawn_cube_at(room_pos: Vector3) -> void:
	var cube := cube_scene.instantiate()
	cube.position = Vector3(room_pos.x, 0.5, room_pos.z)
	add_child(cube)

func _spawn_pickup() -> void:
	var pickup := pickup_scene.instantiate()
	var room_center := _room_center(0, 1)
	var wall_x := room_center.x + ROOM_SIZE / 2.0 - 0.5
	pickup.position = Vector3(wall_x, 1.5, room_center.z + 1.5)
	pickup.rotation.y = deg_to_rad(-90)
	pickup.rotation.x = deg_to_rad(-270)
	add_child(pickup)

func _spawn_spear_pickup() -> void:
	var spear := spear_scene.instantiate()
	var room_center := _room_center(0, 1)
	var wall_x := room_center.x + ROOM_SIZE / 2.0 - 0.5
	spear.position = Vector3(wall_x, 1.5, room_center.z - 1.5)
	add_child(spear)

func _spawn_light_spheres() -> void:
	var room_center := _room_center(0, 1)
	# 3 spheres on a shelf on the north wall
	var wall_z := room_center.z - ROOM_SIZE / 2.0 + 0.5
	for i in 3:
		var sphere_pickup := Area3D.new()
		sphere_pickup.name = "SpherePickup_%d" % i
		sphere_pickup.collision_layer = 0
		sphere_pickup.collision_mask = 2
		sphere_pickup.position = Vector3(room_center.x - 0.5 + i * 0.5, 1.2, wall_z)
		sphere_pickup.add_to_group("sphere_pickup")
		sphere_pickup.add_to_group("light_sphere")

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.8
		col.shape = shape
		sphere_pickup.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 0.15
		sphere_mesh.height = 0.3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.95, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.4)
		mat.emission_energy_multiplier = 2.0
		sphere_mesh.material = mat
		mesh_inst.mesh = sphere_mesh
		sphere_pickup.add_child(mesh_inst)

		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.5)
		light.light_energy = 1.5
		light.omni_range = 4.0
		sphere_pickup.add_child(light)

		sphere_pickup.body_entered.connect(func(body: Node3D):
			if body.name == "Player":
				sphere_pickup.set_meta("player_nearby", true)
		)
		sphere_pickup.body_exited.connect(func(body: Node3D):
			if body.name == "Player":
				sphere_pickup.set_meta("player_nearby", false)
		)

		add_child(sphere_pickup)

func _build_armory_sign() -> void:
	var sign_pos := Vector3(ROOM_SIZE / 2.0 - 0.27, 4.25, 0.0)

	# Wooden plank behind the text
	var plank := CSGBox3D.new()
	plank.size = Vector3(0.1, 0.6, 2.8)
	plank.position = sign_pos
	plank.use_collision = false
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.3, 0.18, 0.08)
	plank.material = wood_mat
	add_child(plank)

	# Text on the plank
	var label := Label3D.new()
	label.text = "A R M O R Y"
	label.font_size = 96
	label.pixel_size = 0.005
	label.position = sign_pos + Vector3(-0.06, 0.0, 0.0)
	label.rotation.y = deg_to_rad(-90)
	label.modulate = Color(0.05, 0.05, 0.05)
	label.no_depth_test = false
	label.double_sided = false
	add_child(label)

func respawn_enemy(old_pos: Vector3) -> void:
	var rooms: Array[Vector3] = []
	for row in range(4):
		for col in range(4):
			var center := _room_center(row, col)
			if Vector2(center.x, center.z).distance_to(Vector2(old_pos.x, old_pos.z)) > 2.0:
				rooms.append(center)
	var new_room: Vector3 = rooms[randi() % rooms.size()]
	call_deferred("_spawn_cube_at", new_room)
