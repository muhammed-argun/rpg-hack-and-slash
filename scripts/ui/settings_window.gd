class_name SettingsWindow
extends PanelContainer
## Ayarlar penceresi: dil, müzik ve efekt sesi, titreşim. Değişiklikler anında uygulanır
## ve Settings servisi tarafından kaydedilir. Hem ana menüde hem oyunda kullanılır.

signal closed

var _language: OptionButton
var _music: HSlider
var _sfx: HSlider
var _vibration: CheckBox


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


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
