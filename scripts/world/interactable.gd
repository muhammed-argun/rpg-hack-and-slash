class_name Interactable
extends Node2D
## Oyuncunun yaklaşıp etkileşim tuşuyla (interact, varsayılan F) kullanabildiği nesnelerin temeli (NPC, sunak, kapı...).
## Oyuncu interact_radius içine girince nesnenin üstünde "[F] <prompt_key>" ipucu görünür (HUD çizer).

@export var interact_radius: float = 30.0
## İpucunda tuştan sonra gösterilecek metnin çeviri anahtarı
@export var prompt_key: String = "UI_TALK"


func _ready() -> void:
	add_to_group("interactables")


func can_interact() -> bool:
	return visible


func interact(_player: Player) -> void:
	pass
