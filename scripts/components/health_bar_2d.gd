class_name HealthBar2D
extends Node2D
## Düşmanların üstünde görünen küçük can barı (Pixel Bars "thin" bar, ahşap çerçeve).
## Yalnızca hasar alınınca görünür.

@export var width: float = 20.0

var _bar: PixelBar


func _ready() -> void:
	_bar = PixelBar.new()
	_bar.shape = PixelBar.Shape.THIN
	_bar.style = "wood"
	_bar.fill = "health"
	_bar.trail_hold = 0.25
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(width, 7)
	_bar.size = Vector2(width, 7)
	_bar.position = Vector2(-roundf(width / 2.0), 0)
	add_child(_bar)
	_bar.settle()


func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	visible = ratio < 1.0
	if _bar:
		_bar.value = ratio * _bar.max_value
