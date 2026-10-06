@tool
class_name ArenaGate
extends StaticBody2D
## Boss dövüşü sırasında arenanın çıkışını kapatan kızıl enerji duvarı.
## Ayrıca Kül Kalkanı gibi kalıcı engeller için de kullanılabilir.

@export var size: Vector2 = Vector2(32, 96):
	set(value):
		size = value
		_update_shape()
		queue_redraw()
@export var color: Color = Color(0.9, 0.15, 0.1)

var _closed := true
var _time := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	_shape = CollisionShape2D.new()
	add_child(_shape)
	_update_shape()


func set_closed(closed: bool) -> void:
	_closed = closed
	if _shape:
		_shape.set_deferred("disabled", not closed)
	queue_redraw()


func _process(delta: float) -> void:
	if _closed:
		_time += delta
		queue_redraw()


func _update_shape() -> void:
	if _shape == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = size
	_shape.shape = rect


func _draw() -> void:
	if not _closed and not Engine.is_editor_hint():
		return
	var rect := Rect2(-size / 2.0, size)
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_rect(rect, Color(color, 0.18 + 0.1 * pulse))
	# Dikey enerji çizgileri
	var step := 6.0
	var x := rect.position.x + fmod(_time * 12.0, step)
	while x < rect.end.x:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(color.lightened(0.3), 0.35 + 0.3 * pulse), 1.0)
		x += step
	draw_rect(rect, Color(color.lightened(0.4), 0.8), false, 1.0)
