extends Node
## Ana oyun sahnesi: haritaları yükler/değiştirir, oyuncuyu haritalar arasında taşır,
## oyunu otomatik kaydeder. Ana menü GameState'i önceden hazırlar (yeni oyun veya kayıt).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const RESPAWN_DELAY := 2.0
## Bu kadar saniyede bir otomatik kayıt
const AUTOSAVE_INTERVAL := 60.0

var current_map: Map
var player: Player
var _changing_map := false
var _autosave_timer := 0.0

@onready var world: Node2D = $World
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	player = PLAYER_SCENE.instantiate()
	GameState.map_change_requested.connect(_on_map_change_requested)
	GameState.player_died.connect(_on_player_died)
	Quests.quest_completed.connect(_save.unbind(1))
	Quests.quest_started.connect(_save.unbind(1))
	GameState.shards_changed.connect(_save.unbind(1))
	hud.save_requested.connect(_save)
	GameState.boss_ended.connect(_on_boss_ended)
	change_map(GameState.current_map, GameState.current_spawn, GameState.saved_position)


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_save()


func _notification(what: int) -> void:
	# Telefon arka plana alınınca veya kapatılınca kaydet
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	# Android geri tuşu: duraklatma menüsü
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.open_pause_menu()


func change_map(map_path: String, spawn_name: String, at_position: Variant = null) -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	if current_map:
		world.remove_child(current_map)
		current_map.queue_free()
	if not ResourceLoader.exists(map_path):
		map_path = GameState.START_MAP
	var scene := load(map_path) as PackedScene
	current_map = scene.instantiate() as Map
	world.add_child(current_map)
	current_map.add_player(player, spawn_name)
	if at_position is Vector2:
		player.global_position = at_position
	GameState.current_map = map_path
	GameState.current_spawn = spawn_name
	GameState.saved_position = null
	_changing_map = false
	hud.show_map_name(current_map.name_key)
	Audio.play_music(current_map.music)
	if not current_map.map_id.is_empty():
		Quests.notify("reach", current_map.map_id)
	_save()


func _save() -> void:
	_autosave_timer = 0.0
	if player == null or not player.is_inside_tree() or player.state == Player.State.DEAD:
		return
	GameState.save_game(player.global_position)


func _on_map_change_requested(map_path: String, spawn_name: String) -> void:
	# Çıkış alanı fizik adımında tetiklenir; harita değişimi o adım bitince yapılır
	if _changing_map:
		return
	_changing_map = true
	change_map.call_deferred(map_path, spawn_name)


func _on_boss_ended(boss: Node) -> void:
	# İkinci faz başlamıyorsa haritanın müziğine dön
	if boss is Boss and not (boss as Boss).next_boss_scene and current_map:
		Audio.play_music(current_map.music)


func _on_player_died() -> void:
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	GameState.restore_after_death()
	player.revive()
	change_map(GameState.START_MAP, GameState.START_SPAWN)
