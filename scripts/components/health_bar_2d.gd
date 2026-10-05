class_name HealthBar2D
extends Node2D
## Düşmanların üstünde görünen küçük can barı. Yalnızca hasar alınınca görünür.

@export var width: float = 16.0
@export var height: float = 2.0

var _ratio := 1.0


func set_ratio(ratio: float) -> void:
	_ratio = clampf(ratio, 0.0, 1.0)
	visible = _ratio < 1.0
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-width / 2.0, 0.0, width, height)
	draw_rect(rect.grow(1.0), Color(0, 0, 0, 0.8))
	draw_rect(rect, Color(0.25, 0.05, 0.05))
	draw_rect(Rect2(rect.position, Vector2(width * _ratio, height)), Color(0.85, 0.15, 0.15))
