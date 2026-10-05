class_name EnemyGroup
extends Node2D
## Bir düşman bölüğü. İçindeki tüm düşmanlar yenilince sandık düşürür.
## Kullanım: Haritanın Entities node'una "EnemyGroup" ekle, içine düşman sahnelerini
## (ör. scenes/enemies/goblin.tscn) çocuk olarak yerleştir.

const CHEST_SCENE := preload("res://scenes/objects/chest.tscn")

## Sandıktaki ganimetin seviyesi (eşya gücünü ve altın miktarını artırır)
@export var loot_level: int = 1

var _alive := 0


func _ready() -> void:
	y_sort_enabled = true
	for child in get_children():
		if child is Enemy:
			_alive += 1
			(child as Enemy).died.connect(_on_enemy_died)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	if _alive == 0:
		# Sandık, son düşmanın öldüğü yere düşer
		_spawn_chest.call_deferred(enemy.global_position)


func _spawn_chest(at: Vector2) -> void:
	var chest := CHEST_SCENE.instantiate() as Chest
	chest.loot_level = loot_level
	get_parent().add_child(chest)
	chest.global_position = at
