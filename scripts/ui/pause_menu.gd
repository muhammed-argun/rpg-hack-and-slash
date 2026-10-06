class_name PauseMenu
extends Control
## Oyun içi duraklatma menüsü: Devam, Ayarlar, Ana Menü, Çıkış.
## Ana menüye dönerken ve çıkarken oyun kaydedilir.

signal resumed
signal save_requested

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var _panel: PanelContainer
var _settings: SettingsWindow
var _confirm: ConfirmDialog
var _pending := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Arkadaki oyunu karart
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WindowPanel"
	_panel.custom_minimum_size = Vector2(150, 0)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_PAUSED"
	box.add_child(title)
	for entry in [["UI_RESUME", resume], ["UI_SETTINGS", _open_settings], ["UI_MAIN_MENU", _ask_main_menu], ["UI_QUIT", _ask_quit]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		box.add_child(button)

	_settings = SettingsWindow.new()
	add_child(_settings)
	_settings.closed.connect(func() -> void: _panel.show())
	_confirm = ConfirmDialog.new()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(func() -> void: _panel.show())
	hide()


func open() -> void:
	show()
	_panel.show()
	_settings.hide()
	_confirm.hide()
	_panel.reset_size()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	get_tree().paused = true


func resume() -> void:
	hide()
	get_tree().paused = false
	resumed.emit()


func _open_settings() -> void:
	_panel.hide()
	_settings.open()


func _ask_main_menu() -> void:
	_pending = "menu"
	_panel.hide()
	_confirm.ask("UI_MAIN_MENU_CONFIRM")


func _ask_quit() -> void:
	_pending = "quit"
	_panel.hide()
	_confirm.ask("UI_QUIT_CONFIRM")


func _on_confirmed() -> void:
	save_requested.emit()
	get_tree().paused = false
	if _pending == "quit":
		get_tree().quit()
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
