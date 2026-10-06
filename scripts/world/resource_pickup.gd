class_name ResourcePickup
extends Area2D
## Yerden toplanan malzeme (ot, cevher, görev eşyası). Oyuncu üstüne yürüyünce toplanır.
## Haritaya her girişte yeniden belirir (düşmanlar gibi).

## GameState.MATERIALS içindeki malzeme id'si
@export var material_id: String = "bloodweed"
@export var amount: int = 1
## Doluysa yalnızca bu görev aktifken görünür (ör. Pip'in kolyesi)
@export var required_quest: String = ""

var _collected := false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	sprite.texture = GameState.material_icon(material_id)
	if sprite.texture:
		sprite.offset = Vector2(0, -floorf(sprite.texture.get_height() / 2.0) + 2)
	body_entered.connect(_on_body_entered)
	if not required_quest.is_empty():
		_update_visibility()
		Quests.quest_started.connect(_update_visibility.unbind(1))
		Quests.quest_completed.connect(_update_visibility.unbind(1))
	# Hafif bir parıltı: toplanabilir olduğu belli olsun
	var tween := sprite.create_tween().set_loops()
	tween.tween_property(sprite, "modulate", Color(1.25, 1.25, 1.25), 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _update_visibility() -> void:
	var active := Quests.get_state(required_quest) == Quests.State.ACTIVE
	visible = active and not _collected
	set_deferred("monitoring", visible)


func _on_body_entered(body: Node2D) -> void:
	if _collected or not visible or not body is Player:
		return
	# Çanta doluysa toplanmaz; oyuncu yer açıp tekrar gelebilir
	if not GameState.bag_has_room_for(BagStack.of_id(material_id, amount)):
		GameState.message.emit(tr("MSG_BAG_FULL"), Color(1, 0.6, 0.4))
		return
	_collected = true
	set_deferred("monitoring", false)
	GameState.add_material(material_id, amount)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 12, 0.25).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
