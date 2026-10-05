extends Node
## Ana sahne: haritaları yükler/değiştirir, oyuncuyu haritalar arasında taşır.

const START_MAP := "res://scenes/maps/town.tscn"
const START_SPAWN := "start"
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const RESPAWN_DELAY := 2.0

var current_map: Map
var player: Player
var _changing_map := false

@onready var world: Node2D = $World


func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	GameState.map_change_requested.connect(_on_map_change_requested)
	GameState.player_died.connect(_on_player_died)
	change_map(START_MAP, START_SPAWN)


func change_map(map_path: String, spawn_name: String) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	if current_map:
		world.remove_child(current_map)
		current_map.queue_free()
	var scene := load(map_path) as PackedScene
	current_map = scene.instantiate() as Map
	world.add_child(current_map)
	current_map.add_player(player, spawn_name)
	_changing_map = false


func _on_map_change_requested(map_path: String, spawn_name: String) -> void:
	# Çıkış alanı fizik adımında tetiklenir; harita değişimi o adım bitince yapılır
	if _changing_map:
		return
	_changing_map = true
	change_map.call_deferred(map_path, spawn_name)


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	GameState.restore_after_death()
	player.revive()
	change_map(START_MAP, START_SPAWN)
