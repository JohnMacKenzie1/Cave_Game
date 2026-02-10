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
	_build_shooting_range()
	_spawn_pickup()
	_spawn_spear_pickup()

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
			if row == 0 and col == 0:
				has_door = true

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
	if row != 0 or col != 0:
		return
	var half := ROOM_SIZE / 2.0
	var wall_offset := half - 0.25
	var spots: Array = []

	if not _has_connection(row, col, -1, 0):
		spots.append([Vector3(2, 2.5, -wall_offset), 0.0])
		spots.append([Vector3(-2, 2.5, -wall_offset), 0.0])
	if not _has_connection(row, col, 1, 0):
		spots.append([Vector3(2, 2.5, wall_offset), PI])
		spots.append([Vector3(-2, 2.5, wall_offset), PI])
	if not _has_connection(row, col, 0, 1):
		spots.append([Vector3(wall_offset, 2.5, 2), -PI / 2.0])
		spots.append([Vector3(wall_offset, 2.5, -2), -PI / 2.0])
	if not _has_connection(row, col, 0, -1):
		spots.append([Vector3(-wall_offset, 2.5, 2), PI / 2.0])
		spots.append([Vector3(-wall_offset, 2.5, -2), PI / 2.0])

	for spot in spots:
		var t := torch_scene.instantiate()
		t.position = spot[0]
		t.rotation.y = spot[1]
		room.add_child(t)

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

	
func _build_shooting_range() -> void:
	var quad := "nw"
	var floor_mat: StandardMaterial3D = mats[quad][0]
	var wall_mat: StandardMaterial3D = mats[quad][1]

	var range_length := ROOM_SIZE * 2.0
	var range_width := ROOM_SIZE
	var center := Vector3(-ROOM_SIZE / 2.0 - range_length / 2.0, 0.0, 0.0)

	var range_room := Node3D.new()
	range_room.name = "ShootingRange"
	range_room.position = center
	add_child(range_room)

	# Floor and ceiling
	_add_box(range_room, Vector3(0, -0.5, 0), Vector3(range_length, 1, range_width), floor_mat)
	_add_box(range_room, Vector3(0, 5.25, 0), Vector3(range_length, 0.5, range_width), mat_ceiling)

	# North wall
	var half_w := range_width / 2.0
	_add_box(range_room, Vector3(0, 2.5, -half_w), Vector3(range_length, 5, WALL_THICK), wall_mat)
	# South wall
	_add_box(range_room, Vector3(0, 2.5, half_w), Vector3(range_length, 5, WALL_THICK), wall_mat)
	# West wall (far end with targets)
	var half_l := range_length / 2.0
	_add_box(range_room, Vector3(-half_l, 2.5, 0), Vector3(WALL_THICK, 5, range_width), wall_mat)
	# East wall (opening toward spawn room) - doorway
	var side_len := (range_width - PASSAGE_WIDTH) / 2.0
	_add_box(range_room, Vector3(half_l, 2.5, -(half_w - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
	_add_box(range_room, Vector3(half_l, 2.5,  (half_w - side_len / 2.0)), Vector3(WALL_THICK, 5, side_len), wall_mat)
	_add_box(range_room, Vector3(half_l, 4.25, 0), Vector3(WALL_THICK, 1.5, PASSAGE_WIDTH), wall_mat)

	# Targets on west wall - all at same height (lower on wall = 1.5)
	var target_x := -half_l + 0.3
	_add_target(range_room, Vector3(target_x, 1.5, -3.0), 1.2)
	_add_target(range_room, Vector3(target_x, 1.5, 0.0), 0.8)
	_add_target(range_room, Vector3(target_x, 1.5, 3.0), 0.5)

	# Purple torches - 4 on each long wall
	var torch_color := Color(0.6, 0.1, 0.9)
	var wall_offset := half_w - 0.25
	var torch_positions: Array[Array] = [
		[Vector3(-9.0, 2.5, -wall_offset), 0.0],
		[Vector3(-3.0, 2.5, -wall_offset), 0.0],
		[Vector3(3.0, 2.5, -wall_offset), 0.0],
		[Vector3(9.0, 2.5, -wall_offset), 0.0],
		[Vector3(-9.0, 2.5, wall_offset), PI],
		[Vector3(-3.0, 2.5, wall_offset), PI],
		[Vector3(3.0, 2.5, wall_offset), PI],
		[Vector3(9.0, 2.5, wall_offset), PI],
	]
	for spot in torch_positions:
		var t := torch_scene.instantiate()
		t.position = spot[0]
		t.rotation.y = spot[1]
		range_room.add_child(t)
		# Override light color to purple after adding to tree
		var light: OmniLight3D = t.get_node("OmniLight3D")
		light.light_color = torch_color
		var flame: MeshInstance3D = t.get_node("Flame")
		var purple_mat := StandardMaterial3D.new()
		purple_mat.albedo_color = Color(0.7, 0.2, 1.0)
		purple_mat.emission_enabled = true
		purple_mat.emission = Color(0.6, 0.1, 0.9)
		purple_mat.emission_energy_multiplier = 3.0
		flame.material_override = purple_mat

func _add_target(parent: Node3D, pos: Vector3, size: float) -> void:
	# Outer ring - red
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = Color(0.8, 0.1, 0.1)
	var outer := CSGCylinder3D.new()
	outer.radius = size / 2.0
	outer.height = 0.05
	outer.sides = 32
	outer.rotation.z = deg_to_rad(90)
	outer.position = pos
	outer.use_collision = true
	outer.material = outer_mat
	parent.add_child(outer)

	# Middle ring - white
	var mid_mat := StandardMaterial3D.new()
	mid_mat.albedo_color = Color(0.9, 0.9, 0.9)
	var mid := CSGCylinder3D.new()
	mid.radius = size / 3.0
	mid.height = 0.06
	mid.sides = 32
	mid.rotation.z = deg_to_rad(90)
	mid.position = pos + Vector3(0.02, 0, 0)
	mid.material = mid_mat
	parent.add_child(mid)

	# Bullseye - red
	var bull_mat := StandardMaterial3D.new()
	bull_mat.albedo_color = Color(0.9, 0.05, 0.05)
	var bull := CSGCylinder3D.new()
	bull.radius = size / 6.0
	bull.height = 0.07
	bull.sides = 32
	bull.rotation.z = deg_to_rad(90)
	bull.position = pos + Vector3(0.04, 0, 0)
	bull.material = bull_mat
	parent.add_child(bull)

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
	var range_entrance_x := -ROOM_SIZE / 2.0
	pickup.position = Vector3(range_entrance_x - 1.5, 0.5, 1.5)
	add_child(pickup)

func _spawn_spear_pickup() -> void:
	var spear := spear_scene.instantiate()
	var range_entrance_x := -ROOM_SIZE / 2.0
	spear.position = Vector3(range_entrance_x - 1.5, 0.8, -1.5)
	add_child(spear)

func respawn_enemy(old_pos: Vector3) -> void:
	var rooms: Array[Vector3] = []
	for row in range(4):
		for col in range(4):
			var center := _room_center(row, col)
			if Vector2(center.x, center.z).distance_to(Vector2(old_pos.x, old_pos.z)) > 2.0:
				rooms.append(center)
	var new_room: Vector3 = rooms[randi() % rooms.size()]
	call_deferred("_spawn_cube_at", new_room)
