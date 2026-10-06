extends Control
## Ana menü: Devam Et, Yeni Oyun, Ayarlar, Emeği Geçenler, Çıkış.
## Oyun sahnesine geçmeden önce GameState yeni oyun veya kayıttan yükleme olarak hazırlanır.

const GAME_SCENE := "res://scenes/main.tscn"
const VERSION := "0.2"
const CREDITS := """Kül Prensi / Prince of Ash

Tiny RPG Character Asset Pack - Zerie
Pixel Bars Free by heyheythere - CC BY 4.0
Pixel UI Fantasy Free by heyheythere - CC BY 4.0
Free 30 Pixel Item Icons - Woshi Studio
Godot Engine - godotengine.org"""

var _buttons: VBoxContainer
var _continue: Button
var _settings: SettingsWindow
var _confirm: ConfirmDialog
var _credits: PanelContainer
var _pending := ""


func _ready() -> void:
	get_tree().paused = false
	theme = load("res://assets/ui/game_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_continue.disabled = not GameState.has_save()
	Audio.play_music("menu")


func _build() -> void:
	# Arka plan: kül renginden koyu kırmızıya geçiş
	var background := TextureRect.new()
	var gradient := GradientTexture2D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.set_color(0, Color(0.08, 0.06, 0.08))
	gradient.gradient.set_color(1, Color(0.28, 0.06, 0.05))
	gradient.fill_from = Vector2(0.5, 0.0)
	gradient.fill_to = Vector2(0.5, 1.0)
	background.texture = gradient
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_add_embers()

	var title := Label.new()
	title.theme_type_variation = &"HudLabel"
	title.text = "GAME_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.scale = Vector2(3, 3)
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(get_viewport_rect().size.x / 2.0 - title.size.x * 1.5, 24)
	var subtitle := Label.new()
	subtitle.theme_type_variation = &"HudLabel"
	subtitle.text = "GAME_SUBTITLE"
	subtitle.modulate = Color(1.0, 0.75, 0.6)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 70
	subtitle.offset_bottom = 84
	subtitle.offset_left = -120
	subtitle.offset_right = 120
	add_child(subtitle)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	add_child(panel)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 4)
	panel.add_child(_buttons)
	_continue = _button("UI_CONTINUE", _on_continue)
	_button("UI_NEW_GAME", _on_new_game)
	_button("UI_SETTINGS", _on_settings)
	_button("UI_CREDITS", _on_credits)
	_button("UI_QUIT", _on_quit)
	panel.reset_size()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.position.y += 30

	var version := Label.new()
	version.theme_type_variation = &"HudLabel"
	version.text = tr("UI_VERSION") % VERSION
	version.modulate = Color(1, 1, 1, 0.5)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	add_child(version)

	_settings = SettingsWindow.new()
	add_child(_settings)
	_settings.closed.connect(_buttons.get_parent().show)
	_confirm = ConfirmDialog.new()
	add_child(_confirm)
	_confirm.confirmed.connect(_on_confirmed)
	_confirm.cancelled.connect(_buttons.get_parent().show)
	_credits = _make_credits()
	add_child(_credits)


func _button(key: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = key
	button.pressed.connect(callback)
	_buttons.add_child(button)
	return button


func _add_embers() -> void:
	# Yukarı süzülen kor parçacıkları (atmosfer)
	var embers := CPUParticles2D.new()
	embers.amount = 40
	embers.lifetime = 6.0
	embers.preprocess = 6.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(260, 4)
	embers.position = Vector2(240, 280)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 22.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.0
	embers.color = Color(1.0, 0.45, 0.2, 0.8)
	add_child(embers)


func _make_credits() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"WindowPanel"
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_CREDITS"
	box.add_child(title)
	var text := Label.new()
	text.text = CREDITS
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(text)
	var close := Button.new()
	close.text = "UI_CLOSE"
	close.pressed.connect(func() -> void:
		panel.hide()
		_buttons.get_parent().show())
	box.add_child(close)
	panel.hide()
	return panel


func _on_continue() -> void:
	if GameState.load_game():
		get_tree().change_scene_to_file(GAME_SCENE)


func _on_new_game() -> void:
	if GameState.has_save():
		_pending = "new"
		_buttons.get_parent().hide()
		_confirm.ask("UI_NEW_GAME_CONFIRM")
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameState.new_game()
	Quests.start("q_main_arrival")
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings() -> void:
	_buttons.get_parent().hide()
	_settings.open()


func _on_credits() -> void:
	_buttons.get_parent().hide()
	_credits.show()
	_credits.reset_size()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _on_quit() -> void:
	_pending = "quit"
	_buttons.get_parent().hide()
	_confirm.ask("UI_QUIT_CONFIRM")


func _on_confirmed() -> void:
	match _pending:
		"new":
			_start_new_game()
		"quit":
			get_tree().quit()
