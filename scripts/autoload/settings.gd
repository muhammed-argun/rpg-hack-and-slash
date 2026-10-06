extends Node
## Oyuncu ayarları: dil, ses düzeyleri, titreşim, ekran (tam ekran, pencere boyutu, V-Sync).
## user://settings.cfg dosyasında saklanır (tuş atamaları da aynı dosyada, Controls autoload'u).
## Autoload olarak "Settings" adıyla erişilir.

signal changed

const PATH := "user://settings.cfg"
const LANGUAGES := ["tr", "en"]

## Testler kendi dosyalarını kullanır (oyuncunun ayarlarına dokunmasınlar)
var config_path := PATH

var language: String = "tr"
## 0..1 arası
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var vibration: bool = true
var fullscreen: bool = false
## Pencere modunda boyut: temel çözünürlüğün (480x270) kaç katı. Pixel art keskin kalsın diye tam sayı.
var window_scale: int = 3
var vsync: bool = true


func _ready() -> void:
	# İlk açılışta telefonun diline göre seç (Türkçe değilse İngilizce)
	language = "tr" if OS.get_locale_language() == "tr" else "en"
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	language = config.get_value("game", "language", language)
	music_volume = config.get_value("audio", "music", music_volume)
	sfx_volume = config.get_value("audio", "sfx", sfx_volume)
	vibration = config.get_value("game", "vibration", vibration)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	window_scale = config.get_value("display", "window_scale", window_scale)
	vsync = config.get_value("display", "vsync", vsync)


func save_settings() -> void:
	# Aynı dosyada tuş atamaları da var (Controls): önce oku, sadece kendi değerlerini değiştir
	var config := ConfigFile.new()
	config.load(config_path)
	config.set_value("game", "language", language)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("game", "vibration", vibration)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "window_scale", window_scale)
	config.set_value("display", "vsync", vsync)
	config.save(config_path)


func apply() -> void:
	if not language in LANGUAGES:
		language = "en"
	TranslationServer.set_locale(language)
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	apply_display()
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


## Kısa titreşim: gamepad ile oynanıyorsa gamepad'i, telefonda telefonu titreştirir
## (ayarlarda kapalıysa hiçbir şey yapmaz).
func vibrate(duration_ms: int = 40) -> void:
	if not vibration:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
	elif Controls.using_gamepad:
		for device in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.4, 0.6, duration_ms / 1000.0)


# --- Ekran ----------------------------------------------------------------------

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply_display()
	save_settings()


func set_window_scale(value: int) -> void:
	window_scale = clampi(value, 1, max_window_scale())
	apply_display()
	save_settings()


func set_vsync(value: bool) -> void:
	vsync = value
	apply_display()
	save_settings()


## Ekrana sığan en büyük pencere katı (ör. 1920x1080 ekranda 4 = 1920x1080; görev çubuğu için 1 eksik).
func max_window_scale() -> int:
	if _headless():
		return 4
	var screen := DisplayServer.screen_get_usable_rect().size
	var base := _base_size()
	return maxi(1, mini(screen.x / base.x, screen.y / base.y))


## Tam ekran / pencere ve V-Sync ayarlarını uygular.
func apply_display() -> void:
	if _headless():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var window := get_window()
	if fullscreen:
		if window.mode != Window.MODE_FULLSCREEN:
			window.mode = Window.MODE_FULLSCREEN
		return
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window_scale = clampi(window_scale, 1, max_window_scale())
	var target := _base_size() * window_scale
	if window.size != target:
		window.size = target
		# Ekranın ortasına al
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		window.position = screen.position + (screen.size - target) / 2


func _base_size() -> Vector2i:
	return Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.001)
