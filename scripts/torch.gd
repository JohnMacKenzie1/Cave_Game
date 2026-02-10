extends Node3D

@onready var light: OmniLight3D = $OmniLight3D
var time := 0.0

func _process(delta: float) -> void:
	time += delta
	var flicker := 2.0 + 0.3 * sin(time * 3.7) + 0.15 * sin(time * 7.3) + 0.1 * sin(time * 13.1)
	light.light_energy = clamp(flicker, 1.5, 2.5)
