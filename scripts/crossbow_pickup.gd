extends Area3D

var player_inside := false
var prompt: Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt = get_tree().current_scene.get_node_or_null("HUD/PickupPrompt")

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		player_inside = true
		if prompt:
			prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		player_inside = false
		if prompt:
			prompt.visible = false

func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact"):
		var player := get_tree().current_scene.get_node_or_null("Player")
		if player and not player.has_crossbow:
			player.has_crossbow = true
			player.equip_crossbow()
			if prompt:
				prompt.visible = false
			queue_free()
