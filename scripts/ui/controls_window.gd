class_name ControlsWindow
extends PanelContainer
## Tuş atama penceresi (Ayarlar > Kontroller). Her aksiyon için bir klavye/fare ve bir gamepad
## tuşu gösterir. Butona tıklayıp yeni tuşa basınca atama değişir. Aynı tuş başka bir aksiyonda
## varsa oradan kaldırılır ve oyuncuya söylenir. Atamalar Controls servisi tarafından kaydedilir.

signal closed

## Bu süre içinde tuşa basılmazsa dinleme iptal olur (gamepad'de Esc yok)
const LISTEN_TIMEOUT := 5.0
## Dinlemeyi başlatan basış (gamepad A gibi) yeni tuş sayılmasın diye kısa bekleme
const LISTEN_DELAY := 0.15

## "aksiyon/yuva" -> Button
var _buttons := {}
var _status: Label
var _listening_action := ""
var _listening_slot := -1
var _listen_time := 0.0


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menus")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_CONTROLS"
	box.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(grid)
	for key: String in ["", "UI_KEYBOARD_MOUSE", "UI_GAMEPAD"]:
		var header := Label.new()
		header.text = key
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.modulate = Color(1, 1, 1, 0.7)
		grid.add_child(header)
	for action: String in Controls.REBINDABLE:
		var label := Label.new()
		label.text = action_name_key(action)
		label.custom_minimum_size = Vector2(92, 0)
		grid.add_child(label)
		for slot in Controls.SLOTS.size():
			var button := Button.new()
			button.custom_minimum_size = Vector2(84, 0)
			button.clip_text = true
			button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			button.pressed.connect(_start_listening.bind(action, slot))
			grid.add_child(button)
			_buttons["%s/%d" % [action, slot]] = button

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(264, 0)
	_status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	var reset := Button.new()
	reset.text = "UI_RESET_DEFAULTS"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void:
		_stop_listening()
		Controls.reset_to_defaults()
		_status.text = tr("UI_BINDINGS_RESET"))
	row.add_child(reset)
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	row.add_child(close_button)
	Controls.bindings_changed.connect(_refresh)
	Settings.changed.connect(_refresh)
	hide()


## Aksiyonun ayarlarda görünen adının çeviri anahtarı, ör. "skill_1" -> "ACTION_SKILL_1".
static func action_name_key(action: String) -> String:
	return "ACTION_" + action.to_upper()


func open() -> void:
	_stop_listening()
	_status.text = ""
	_refresh()
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func close() -> void:
	_stop_listening()
	hide()
	closed.emit()


func is_listening() -> bool:
	return not _listening_action.is_empty()


func _process(delta: float) -> void:
	if not is_listening():
		return
	_listen_time += delta
	if _listen_time > LISTEN_TIMEOUT:
		_stop_listening()
		_status.text = ""


func _input(event: InputEvent) -> void:
	if not visible or not is_listening():
		return
	if _listen_time < LISTEN_DELAY:
		# Dinlemeyi başlatan basış/bırakış yeni tuş sayılmasın; GUI'ye de gitmesin
		if not event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key and key.pressed and key.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_stop_listening()
		_status.text = ""
		return
	var code := Controls.event_to_code(event, _listening_slot)
	if code.is_empty():
		# Fare hareketi gibi atanamayan girdiler; tıklama ve tuşlar GUI'ye gitmesin
		if not event is InputEventMouseMotion:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	var action := _listening_action
	var slot := _listening_slot
	_stop_listening()
	var removed_from := Controls.set_binding(action, slot, code)
	if removed_from.is_empty():
		_status.text = ""
	else:
		_status.text = tr("UI_BINDING_MOVED") % [Controls.code_label(code), tr(action_name_key(removed_from))]
	# Odak bu butonda kalsın; gamepad ile gezinmeye devam edilebilsin
	(_buttons["%s/%d" % [action, slot]] as Button).grab_focus()


func _start_listening(action: String, slot: int) -> void:
	_stop_listening()
	_listening_action = action
	_listening_slot = slot
	_listen_time = 0.0
	Controls.capturing = true
	_status.text = tr("UI_PRESS_KEY_HINT")
	_refresh()


func _stop_listening() -> void:
	if not is_listening():
		return
	_listening_action = ""
	_listening_slot = -1
	_refresh()
	# Yakalanan tuşun "yeni basıldı" durumu bu kare boyunca sürer; oyun bir kare sonra dinlemeye döner
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_listening():
		Controls.capturing = false


func _refresh() -> void:
	for id: String in _buttons:
		var parts := id.split("/")
		var button: Button = _buttons[id]
		if parts[0] == _listening_action and int(parts[1]) == _listening_slot:
			button.text = tr("UI_PRESS_KEY")
		else:
			button.text = Controls.code_label(Controls.get_binding(parts[0], int(parts[1])))
