class_name Map
extends Node2D
## Bir harita sahnesinin kök scripti.
## Beklenen yapı:
##   Ground   (TileMapLayer) zemin
##   Entities (Node2D, y-sort açık) duvarlar, oyuncu, düşman bölükleri, sandıklar
##   Spawns   (Node2D) giriş noktaları (Marker2D, adı MapExit.target_spawn ile eşleşir)
##   Exits    (Node2D) çıkışlar (MapExit)

const TILE_SIZE := 32

## Haritanın kare cinsinden boyutu (kamera sınırlarını belirler)
@export var map_size: Vector2i = Vector2i(48, 32)

@onready var entities: Node2D = $Entities
@onready var spawns: Node2D = $Spawns


func add_player(player: Player, spawn_name: String) -> void:
	entities.add_child(player)
	player.global_position = get_spawn_position(spawn_name)
	player.set_camera_limits(Rect2i(Vector2i.ZERO, map_size * TILE_SIZE))


func get_spawn_position(spawn_name: String) -> Vector2:
	if not spawn_name.is_empty():
		var marker := spawns.get_node_or_null(spawn_name) as Node2D
		if marker:
			return marker.global_position
	push_warning("Map: '%s' giriş noktası bulunamadı, ilk giriş noktası kullanılıyor." % spawn_name)
	if spawns.get_child_count() > 0:
		return (spawns.get_child(0) as Node2D).global_position
	return Vector2(map_size * TILE_SIZE) / 2.0
