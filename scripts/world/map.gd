class_name Map
extends Node2D
## Bir harita sahnesinin kök scripti.
## Beklenen yapı:
##   Ground   (TileMapLayer) zemin
##   Entities (Node2D, y-sort açık) duvarlar, oyuncu, düşman bölükleri, sandıklar
##   Spawns   (Node2D) giriş noktaları (Marker2D, adı MapExit.target_spawn ile eşleşir)
##   Exits    (Node2D) çıkışlar (MapExit)
## Yer efektleri (uyarı alanları, şok dalgaları) zeminin üstüne, karakterlerin altına çizilir.

const TILE_SIZE := 32

## Haritanın kare cinsinden boyutu (kamera sınırlarını belirler)
@export var map_size: Vector2i = Vector2i(48, 32)

# Şu an oynanan harita (her an tek bir harita yüklüdür)
static var current: Map

var ground_effects: Node2D

@onready var entities: Node2D = $Entities
@onready var spawns: Node2D = $Spawns


func _ready() -> void:
	current = self
	ground_effects = Node2D.new()
	ground_effects.name = "GroundEffects"
	add_child(ground_effects)
	move_child(ground_effects, $Ground.get_index() + 1)


func _exit_tree() -> void:
	if current == self:
		current = null


## Zemin efektini şu anki haritaya ekler (harita yoksa efekt atılır).
static func add_ground_effect(effect: Node2D) -> void:
	if current and is_instance_valid(current.ground_effects):
		current.ground_effects.add_child(effect)
	else:
		effect.queue_free()


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
