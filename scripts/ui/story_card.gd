class_name StoryCard
extends Control
## Siyah ekranda satır satır beliren kısa anlatı (prolog girişi gibi). Ekrana dokununca ya da
## saldırı tuşuna basınca geçilir. Bittiğinde finished sinyali gelir.

signal finished

var _box: VBoxContainer
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 50
	_box.offset_right = -50
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	gui_input.connect(_on_gui_input)
	hide()


## Satırları (çeviri anahtarları) sırayla gösterir.
func play(line_keys: Array) -> void:
	for child in _box.get_children():
		child.queue_free()
	_done = false
	show()
	get_tree().paused = true
	var tween := create_tween()
	for key: Variant in line_keys:
		var label := Label.new()
		label.theme_type_variation = &"HudLabel"
		label.text = str(key)
		label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.78))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate.a = 0.0
		_box.add_child(label)
		tween.tween_property(label, "modulate:a", 1.0, 1.0)
		tween.tween_interval(1.2)
	var hint := Label.new()
	hint.theme_type_variation = &"HudLabel"
	hint.text = "UI_TAP_TO_CONTINUE"
	hint.modulate = Color(1, 1, 1, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)
	tween.tween_property(hint, "modulate:a", 0.6, 0.5)


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("attack"):
		_finish()


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		hide()
		modulate.a = 1.0
		get_tree().paused = false
		Input.action_release("attack")
		finished.emit())
