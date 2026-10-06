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
## Görevlerdeki "reach" hedefleriyle eşleşen kimlik (ör. "ashwood_den")
@export var map_id: String = ""
## Haritaya girince gösterilen adın çeviri anahtarı
@export var name_key: String = ""
## Bölgenin renk tonu (ör. kaleye yaklaştıkça renksizleşen bölgeler için). Beyaz = değişiklik yok
@export var tint: Color = Color.WHITE
## Haritanın müziği (data/audio.json'daki ad, ör. "town")
@export var music: String = ""

# Şu an oynanan harita (her an tek bir harita yüklüdür)
static var current: Map

var ground_effects: Node2D
## Engellerden (duvar, ağaç, su) çıkarılan yürünebilir alan; düşmanlar bununla yol bulur
var navigation: NavigationRegion2D

@onready var entities: Node2D = $Entities
@onready var spawns: Node2D = $Spawns


func _ready() -> void:
	current = self
	ground_effects = Node2D.new()
	ground_effects.name = "GroundEffects"
	add_child(ground_effects)
	move_child(ground_effects, $Ground.get_index() + 1)
	_bake_navigation()
	if tint != Color.WHITE:
		var modulate_node := CanvasModulate.new()
		modulate_node.color = tint
		add_child(modulate_node)


# Haritanın sınırları içinde, Walls katmanındaki çarpışma şekillerini delik olarak alan bir
# navigasyon alanı oluşturur. Pişirme ayrı iş parçacığında yapılır; bitene kadar düşmanlar düz yürür.
func _bake_navigation() -> void:
	var walls := get_node_or_null("Entities/Walls")
	if walls:
		walls.add_to_group("navigation_source")
	var polygon := NavigationPolygon.new()
	var bounds := Rect2(Vector2.ZERO, Vector2(map_size * TILE_SIZE))
	polygon.add_outline(PackedVector2Array([bounds.position, Vector2(bounds.end.x, 0), bounds.end, Vector2(0, bounds.end.y)]))
	polygon.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	polygon.parsed_collision_mask = 1
	polygon.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	polygon.source_geometry_group_name = &"navigation_source"
	polygon.agent_radius = 7.0
	navigation = NavigationRegion2D.new()
	navigation.name = "Navigation"
	navigation.navigation_polygon = polygon
	add_child(navigation)
	navigation.bake_navigation_polygon(true)


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
	# Konum eklemeden önce verilir; yoksa oyuncu bir an eski haritadaki konumunda durur ve
	# oradaki alanları (ör. boss arenası) yanlışlıkla tetikleyebilir
	player.prepare_for_map_change()
	player.position = entities.to_local(get_spawn_position(spawn_name))
	entities.add_child(player)
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
