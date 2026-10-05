class_name Shockwave
extends Node2D
## Yere vurma yeteneklerinde yerde genişleyen halka efekti.

var radius := 40.0
var color := Color(1.0, 0.95, 0.8)
var duration := 0.35
var _t := 0.0


static func spawn(at: Vector2, max_radius: float, ring_color: Color = Color(1.0, 0.95, 0.8)) -> void:
	var wave := Shockwave.new()
	wave.position = at
	wave.radius = max_radius
	wave.color = ring_color
	Map.add_ground_effect(wave)


func _process(delta: float) -> void:
	_t += delta / duration
	if _t >= 1.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var r := radius * (1.0 - pow(1.0 - _t, 3.0))
	var alpha := 1.0 - _t
	draw_circle(Vector2.ZERO, r, Color(color, 0.15 * alpha))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.9 * alpha), 2.0)
	draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 32, Color(color, 0.4 * alpha), 1.0)
