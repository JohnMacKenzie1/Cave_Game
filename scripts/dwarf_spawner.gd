extends Node3D

const SPAWN_MIN_DIST_FROM_PLAYER := 15.0
const RESPAWN_DELAY_MIN := 1.0
const RESPAWN_DELAY_MAX := 3.0
const SPACING := 22.0

var cube_scene: PackedScene = preload("res://scenes/cube_enemy.tscn")
var spawn_points: Array[Marker3D] = []
var active_dwarf: CharacterBody3D = null

func _ready() -> void:
	_create_spawn_points()
	_spawn_dwarf()

func _create_spawn_points() -> void:
	for row in range(4):
		for col in range(4):
			var marker := Marker3D.new()
			marker.position = Vector3(col * SPACING, 0.0, row * SPACING)
			marker.name = "SpawnPoint_%d_%d" % [row, col]
			add_child(marker)
			spawn_points.append(marker)

func _spawn_dwarf() -> void:

	var player := get_tree().current_scene.get_node_or_null("Player")
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO

	var valid_points: Array[Marker3D] = []
	for point in spawn_points:
		var dist := Vector2(point.global_position.x - player_pos.x, point.global_position.z - player_pos.z).length()
		if dist > SPAWN_MIN_DIST_FROM_PLAYER:
			valid_points.append(point)

	if valid_points.is_empty():
		valid_points = spawn_points.duplicate()

	var chosen: Marker3D = valid_points[randi() % valid_points.size()]
	var spawn_position := Vector3(chosen.global_position.x, 0.5, chosen.global_position.z)

	var dwarf := cube_scene.instantiate()
	dwarf.position = spawn_position
	get_tree().current_scene.get_node("Labyrinth").add_child(dwarf)

	active_dwarf = dwarf
	dwarf.dwarf_died.connect(_on_dwarf_died)

	print("New dwarf spawned at ", spawn_position)

func _on_dwarf_died() -> void:
	active_dwarf = null
	var delay := randf_range(RESPAWN_DELAY_MIN, RESPAWN_DELAY_MAX)
	get_tree().create_timer(delay).timeout.connect(_spawn_dwarf)
