@tool
class_name MapExit
extends Area2D
## Haritadan çıkış noktası. Oyuncu girince hedef harita yüklenir.

## Yüklenecek harita sahnesi
@export_file("*.tscn") var target_map: String = ""
## Hedef haritadaki giriş noktasının (Spawns altındaki Marker2D) adı
@export var target_spawn: String = ""
## Çıkış alanının boyutu (piksel)
@export var exit_size: Vector2 = Vector2(32, 128):
	set(value):
		exit_size = value
		_update_shape()


func _ready() -> void:
	_update_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not target_map.is_empty():
		GameState.map_change_requested.emit(target_map, target_spawn)


func _update_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	# Her çıkışın kendi boyutu olabilmesi için şekil paylaşılmaz
	var rect := RectangleShape2D.new()
	rect.size = exit_size
	shape_node.shape = rect
