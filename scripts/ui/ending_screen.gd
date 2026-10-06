class_name EndingScreen
extends Control
## Oyun sonu: Malphas yenilince ("game_completed" bayrağı) ekran kararır, hikâyenin son
## cümleleri tek tek belirir, ardından teşekkür ve ana menüye dönüş butonu gelir.

const LINES := ["ENDING_1", "ENDING_2", "ENDING_3", "ENDING_4", "ENDING_5"]
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var _box: VBoxContainer
var _button: Button


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.03)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 8)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 40
	_box.offset_right = -40
	add_child(_box)
	for key: String in LINES:
		_box.add_child(_line(key, Color(0.95, 0.88, 0.8)))
	var thanks := _line("ENDING_THANKS", Color(1.0, 0.8, 0.45))
	_box.add_child(thanks)
	_button = Button.new()
	_button.text = "UI_MAIN_MENU"
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.modulate.a = 0.0
	_button.pressed.connect(_to_main_menu)
	_box.add_child(_button)
	hide()


func play() -> void:
	show()
	Audio.play_music("ending")
	modulate.a = 0.0
	get_tree().paused = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.5)
	for child in _box.get_children():
		tween.tween_interval(0.6)
		tween.tween_property(child, "modulate:a", 1.0, 1.2)


func _line(key: String, color: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = &"HudLabel"
	label.text = key
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate.a = 0.0
	return label


func _to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
