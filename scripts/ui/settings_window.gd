class_name SettingsWindow
extends PanelContainer
## Ayarlar penceresi: dil, müzik ve efekt sesi, titreşim, kontroller (tuş atama). Değişiklikler
## anında uygulanır ve Settings/Controls servisleri tarafından kaydedilir. Hem ana menüde hem oyunda kullanılır.

signal closed

var _language: OptionButton
var _music: HSlider
var _sfx: HSlider
var _vibration: CheckBox
var _fullscreen: CheckBox
var _window_size: OptionButton
var _vsync: CheckBox
var _controls: ControlsWindow


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menus")
	custom_minimum_size = Vector2(220, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_SETTINGS"
	box.add_child(title)

	_language = OptionButton.new()
	_language.add_item("UI_LANG_TR")
	_language.add_item("UI_LANG_EN")
	_language.item_selected.connect(func(index: int) -> void:
		Settings.set_language(Settings.LANGUAGES[index]))
	box.add_child(_row("UI_LANGUAGE", _language))

	_music = _slider()
	_music.value_changed.connect(func(value: float) -> void:
		Settings.set_music_volume(value))
	box.add_child(_row("UI_MUSIC", _music))

	_sfx = _slider()
	_sfx.value_changed.connect(func(value: float) -> void:
		Settings.set_sfx_volume(value))
	box.add_child(_row("UI_SFX", _sfx))

	_vibration = CheckBox.new()
	_vibration.text = "UI_VIBRATION"
	_vibration.toggled.connect(func(on: bool) -> void:
		Settings.set_vibration(on))
	box.add_child(_vibration)

	_fullscreen = CheckBox.new()
	_fullscreen.text = "UI_FULLSCREEN"
	_fullscreen.toggled.connect(func(on: bool) -> void:
		Settings.set_fullscreen(on)
		_window_size.disabled = on)
	box.add_child(_fullscreen)
	# Pencere boyutu: temel çözünürlüğün tam katları (pixel art keskin kalsın)
	_window_size = OptionButton.new()
	_window_size.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_window_size.item_selected.connect(func(index: int) -> void:
		Settings.set_window_scale(_window_size.get_item_id(index)))
	box.add_child(_row("UI_WINDOW_SIZE", _window_size))
	_vsync = CheckBox.new()
	_vsync.text = "UI_VSYNC"
	_vsync.toggled.connect(func(on: bool) -> void:
		Settings.set_vsync(on))
	box.add_child(_vsync)
	var controls_button := Button.new()
	controls_button.text = "UI_CONTROLS"
	controls_button.pressed.connect(_open_controls)
	box.add_child(controls_button)
	# Kontroller penceresi bu pencerenin kardeşi: bu pencere gizlenince o görünür kalsın
	_controls = ControlsWindow.new()
	_controls.closed.connect(open)
	get_parent().add_child.call_deferred(_controls)

	box.add_child(HSeparator.new())
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()


func open() -> void:
	_language.select(maxi(0, Settings.LANGUAGES.find(Settings.language)))
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_vibration.set_pressed_no_signal(Settings.vibration)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_vsync.set_pressed_no_signal(Settings.vsync)
	_window_size.clear()
	var base := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	for scale in range(1, Settings.max_window_scale() + 1):
		_window_size.add_item("%dx%d" % [base.x * scale, base.y * scale], scale)
	_window_size.select(_window_size.get_item_index(clampi(Settings.window_scale, 1, Settings.max_window_scale())))
	_window_size.disabled = Settings.fullscreen
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


## Geri tuşu (Esc / gamepad B): Kontroller açıksa ayarlara, değilse bir üst menüye döner.
## Bu pencerelerden biri açıktıysa true döner.
func go_back() -> bool:
	if _controls.visible:
		if not _controls.is_listening():
			_controls.close()
		return true
	if visible:
		close()
		return true
	return false


## Kontroller dahil hepsini sinyal vermeden gizler (duraklatma menüsü yeniden açılırken).
func hide_all() -> void:
	if _controls.visible:
		_controls.close()
	hide()


func _open_controls() -> void:
	hide()
	_controls.open()


func close() -> void:
	hide()
	closed.emit()


func _row(label_key: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = label_key
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return row


func _slider() -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	return slider
