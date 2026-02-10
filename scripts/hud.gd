extends Control

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := size / 2.0
	var gap := 8.0
	var length := 14.0
	var thick := 2.0
	var color := Color(1.0, 1.0, 1.0, 0.75)

	# Left
	draw_rect(Rect2(center.x - gap - length, center.y - thick / 2.0, length, thick), color)
	# Right
	draw_rect(Rect2(center.x + gap, center.y - thick / 2.0, length, thick), color)
	# Up
	draw_rect(Rect2(center.x - thick / 2.0, center.y - gap - length, thick, length), color)
	# Down
	draw_rect(Rect2(center.x - thick / 2.0, center.y + gap, thick, length), color)
	# Center dot
	draw_circle(center, 1.5, color)
