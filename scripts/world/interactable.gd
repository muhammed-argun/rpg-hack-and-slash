class_name Interactable
extends Node2D
## Oyuncunun yaklaşıp saldırı butonuyla etkileşebildiği nesnelerin temeli (NPC, sunak, kapı...).
## Oyuncu interact_radius içine girince HUD'daki saldırı butonunun üstünde prompt_key metni görünür.

@export var interact_radius: float = 30.0
## Butonun üstünde gösterilecek metnin çeviri anahtarı
@export var prompt_key: String = "UI_TALK"


func _ready() -> void:
	add_to_group("interactables")


func can_interact() -> bool:
	return visible


func interact(_player: Player) -> void:
	pass
