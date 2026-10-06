class_name AimMarker
extends Node2D
## Oyuncunun ayağının çevresinde nişan yönünü gösteren küçük ok. Yalnızca gamepad ile
## oynarken görünür (fareyle oynarken imleç zaten nişanı gösteriyor).

const DISTANCE := 13.0
const CENTER := Vector2(0, -2)
const COLOR := Color(1.0, 0.95, 0.8, 0.75)


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var player := get_parent() as Player
	visible = player != null and Controls.using_gamepad and player.state != Player.State.DEAD
	if not visible:
		return
	var direction := player.get_aim_direction()
	rotation = direction.angle()
	position = CENTER + direction * DISTANCE


func _draw() -> void:
	# Sağa bakan küçük üçgen; yön rotation ile verilir
	draw_colored_polygon(PackedVector2Array([Vector2(3, 0), Vector2(-2, -3), Vector2(-2, 3)]), COLOR)
