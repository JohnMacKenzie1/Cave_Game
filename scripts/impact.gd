extends Node3D

@onready var light: OmniLight3D = $Light

func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	get_tree().create_timer(3.0).timeout.connect(queue_free)
