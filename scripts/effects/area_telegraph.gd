class_name AreaTelegraph
extends Node2D
## Düşmanın özel saldırısından önce yerde beliren uyarı alanı.
## Kırmızı alan zamanla dolar; saldırı anında detonate() ile parlayıp kaybolur.
## Oyuncunun kaçabilmesi için mobilde okunaklı olması önemli.

enum Shape { CIRCLE, LINE }


var shape: Shape = Shape.CIRCLE
var radius := 32.0
## LINE için: başlangıçtan (node konumu) bitişe vektör
var line_vector := Vector2.ZERO
var duration := 0.6
## Renkler saldırı türüne göre: turuncu = ağır, kırmızı = engellenemez
var fill_color := Combat.telegraph_color(Combat.Kind.HEAVY)
var edge_color := Combat.edge_color(Combat.Kind.HEAVY)
var _progress := 0.0
var _flash := 0.0


## Yerde daire şeklinde uyarı.
static func circle(at: Vector2, circle_radius: float, warn_time: float, kind: Combat.Kind = Combat.Kind.HEAVY) -> AreaTelegraph:
	var telegraph := AreaTelegraph.new()
	telegraph._set_kind(kind)
	telegraph.shape = Shape.CIRCLE
	telegraph.radius = circle_radius
	telegraph.duration = warn_time
	telegraph.position = at
	Map.add_ground_effect(telegraph)
	return telegraph


## Yerde çizgi (hücum yolu) şeklinde uyarı; width çizginin kalınlığı.
static func line(from: Vector2, to: Vector2, width: float, warn_time: float, kind: Combat.Kind = Combat.Kind.HEAVY) -> AreaTelegraph:
	var telegraph := AreaTelegraph.new()
	telegraph._set_kind(kind)
	telegraph.shape = Shape.LINE
	telegraph.radius = width / 2.0
	telegraph.line_vector = to - from
	telegraph.duration = warn_time
	telegraph.position = from
	Map.add_ground_effect(telegraph)
	return telegraph


func _set_kind(kind: Combat.Kind) -> void:
	fill_color = Combat.telegraph_color(kind)
	edge_color = Combat.edge_color(kind)


## Saldırı anı: kısa bir parlamadan sonra kaybolur.
func detonate() -> void:
	_progress = 1.0
	_flash = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_flash", 0.0, 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)


func _process(delta: float) -> void:
	if _flash <= 0.0:
		_progress = minf(1.0, _progress + delta / maxf(duration, 0.01))
	queue_redraw()


func _draw() -> void:
	var fill := fill_color.lerp(Color(1, 0.9, 0.8, 0.6), _flash)
	match shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, radius * _progress, fill)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, edge_color, 1.0)
		Shape.LINE:
			var side := line_vector.orthogonal().normalized() * radius
			var tip := line_vector * _progress
			draw_colored_polygon(PackedVector2Array([side, tip + side, tip - side, -side]), fill)
			var edge := PackedVector2Array([side, line_vector + side, line_vector - side, -side, side])
			draw_polyline(edge, edge_color, 1.0)
