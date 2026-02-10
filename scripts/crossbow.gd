extends Node3D

var recoil := 0.0
var default_pos: Vector3

func _ready() -> void:
	default_pos = position

func _process(delta: float) -> void:
	recoil = move_toward(recoil, 0.0, delta * 3.0)
	position = default_pos + Vector3(0, recoil * 0.015, recoil * 0.06)

func shoot() -> void:
	recoil = 1.0
