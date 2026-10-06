class_name Chest
extends Area2D
## Bölük yenilince düşen sandık. Oyuncu üstüne yürüyünce açılır ve ganimet verir.

const TEXTURE_CLOSED := "res://assets/objects/chest_closed.png"
const TEXTURE_OPEN := "res://assets/objects/chest_open.png"
# Sandık belirdikten sonra açılabilir hâle gelene kadar geçen süre
const ARM_DELAY := 0.6
# Her tür eşya düşebilir (boş liste = hepsi). Ekipman ikonları şimdilik yer tutucu.
const LOOT_TYPES: Array[ItemData.Type] = []

@export var loot_level: int = 1
## Seviye başına altın aralığı
@export var gold_min: int = 5
@export var gold_max: int = 15
@export_range(0.0, 1.0) var health_potion_chance: float = 0.35
@export_range(0.0, 1.0) var mana_potion_chance: float = 0.35
@export_range(0.0, 1.0) var item_chance: float = 0.5

var _opened := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_set_texture(TEXTURE_CLOSED)
	body_entered.connect(_on_body_entered)
	# Belirme animasyonu
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(ARM_DELAY).timeout
	monitoring = true


func _on_body_entered(body: Node2D) -> void:
	if not _opened and body is Player:
		_open()


func _open() -> void:
	_opened = true
	_set_texture(TEXTURE_OPEN)
	Audio.play_sfx("chest_open")
	GameState.add_gold(randi_range(gold_min, gold_max) * loot_level)
	if randf() < health_potion_chance:
		GameState.add_health_potions(1)
	if randf() < mana_potion_chance:
		GameState.add_mana_potions(1)
	if randf() < item_chance:
		GameState.add_item(ItemData.create_random(loot_level, LOOT_TYPES))
	set_deferred("monitoring", false)


func _set_texture(path: String) -> void:
	sprite.texture = load(path)
	# Alt kenarı node konumuna hizala (y-sort için)
	sprite.offset = Vector2(0, -floorf(sprite.texture.get_height() / 2.0))
