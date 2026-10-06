extends Node
## Oyuncu ayarları: dil, ses düzeyleri, titreşim. user://settings.cfg dosyasında saklanır.
## Autoload olarak "Settings" adıyla erişilir.

signal changed

const PATH := "user://settings.cfg"
const LANGUAGES := ["tr", "en"]

var language: String = "tr"
## 0..1 arası
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var vibration: bool = true


func _ready() -> void:
	# İlk açılışta telefonun diline göre seç (Türkçe değilse İngilizce)
	language = "tr" if OS.get_locale_language() == "tr" else "en"
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	language = config.get_value("game", "language", language)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	vibration = config.get_value("game", "vibration", vibration)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "language", language)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("game", "vibration", vibration)
	config.save(PATH)


func apply() -> void:
	if not language in LANGUAGES:
		language = "en"
	TranslationServer.set_locale(language)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	changed.emit()


func set_language(value: String) -> void:
	language = value
	apply()
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_vibration(value: bool) -> void:
	vibration = value
	save_settings()


## Telefonu kısa süre titreştirir (ayarlarda kapalıysa hiçbir şey yapmaz).
func vibrate(duration_ms: int = 40) -> void:
	if vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.001)
