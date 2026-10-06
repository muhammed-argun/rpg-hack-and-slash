class_name NPC
extends Interactable
## Konuşulabilen karakter. Ne söyleyeceği data/dialogue.json'daki kurallarla belirlenir.
## Üstünde görev işareti gösterir: "!" yeni görev, "?" teslim edilecek görev.

## data/dialogue.json'daki NPC id'si (ör. "ezra")
@export var npc_id: String = ""
## Görsellerin klasörü (CharacterSprite isimlendirme kuralı)
@export_dir var sprite_folder: String = "res://assets/characters/soldier":
	set(value):
		sprite_folder = value
		if is_node_ready():
			sprite.sprite_folder = value
			sprite.reload()
## Görsel renk tonu (aynı görselden farklı NPC'ler yapmak için)
@export var tint: Color = Color.WHITE
@export var sprite_scale: float = 1.0
@export var face_left: bool = false

@onready var sprite: CharacterSprite = $Sprite
@onready var name_label: Label = $NameLabel
@onready var marker: Label = $Marker


func _ready() -> void:
	super._ready()
	if sprite.sprite_folder != sprite_folder:
		sprite.sprite_folder = sprite_folder
		sprite.reload()
	sprite.modulate = tint
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.play_directional("idle", "left" if face_left else "right")
	name_label.text = Dialogue.get_npc_name(npc_id)
	Quests.quest_started.connect(_refresh_marker.unbind(1))
	Quests.quest_ready.connect(_refresh_marker.unbind(1))
	Quests.quest_completed.connect(_refresh_marker.unbind(1))
	GameState.flag_changed.connect(_refresh_marker.unbind(2))
	Settings.changed.connect(_on_settings_changed)
	_refresh_marker()
	# İşaret hafifçe zıplasın
	var tween := marker.create_tween().set_loops()
	tween.tween_property(marker, "position:y", marker.position.y - 2, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(marker, "position:y", marker.position.y, 0.4).set_trans(Tween.TRANS_SINE)


func interact(player: Player) -> void:
	# Oyuncuya dön
	var face := "left" if player.global_position.x < global_position.x else "right"
	sprite.play_directional("idle", face)
	Dialogue.talk_to(npc_id)


func _refresh_marker() -> void:
	var symbol := Dialogue.get_marker(npc_id)
	marker.text = symbol
	marker.modulate = Color(1.0, 0.85, 0.3) if symbol == "!" else Color(0.6, 0.9, 1.0)


func _on_settings_changed() -> void:
	name_label.text = Dialogue.get_npc_name(npc_id)
