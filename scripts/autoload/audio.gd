extends Node
## Ses servisi. Ses adlarını data/audio.json'daki dosyalara eşler; dosya yoksa sessizce atlar.
## Autoload olarak "Audio" adıyla erişilir.
##   Audio.play_sfx("hit")         efekt (SFX bus'ı, hafif perde farkıyla)
##   Audio.play_music("town")      müzik (Music bus'ı, yumuşak geçişle, döngülü)

const DATA_PATH := "res://data/audio.json"
const SFX_PLAYERS := 10
const MUSIC_FADE := 1.0

var _sfx: Dictionary = {}
var _music: Dictionary = {}
var _cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_sfx = parsed.get("sfx", {})
		_music = parsed.get("music", {})
	for i in SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)


func play_sfx(sound_name: String, pitch_variation: float = 0.06) -> void:
	var files: Array = _sfx.get(sound_name, [])
	if files.is_empty():
		return
	var stream := _load(str(files.pick_random()))
	if stream == null:
		return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_PLAYERS
	player.stream = stream
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()


func play_music(music_name: String) -> void:
	if music_name == current_music:
		return
	current_music = music_name
	var stream := _load(str(_music.get(music_name, "")))
	var old := _music_players[_active_music]
	_active_music = 1 - _active_music
	var new := _music_players[_active_music]
	var tween := create_tween().set_parallel()
	tween.tween_property(old, "volume_db", -80.0, MUSIC_FADE)
	if stream:
		_set_loop(stream)
		new.stream = stream
		new.volume_db = -40.0
		new.play()
		tween.tween_property(new, "volume_db", 0.0, MUSIC_FADE)
	tween.chain().tween_callback(old.stop)


func stop_music() -> void:
	play_music("")


func _load(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_cache[path] = stream
	return stream


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
