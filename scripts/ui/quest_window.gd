class_name QuestWindow
extends PanelContainer
## Görev günlüğü (J ya da HUD'daki "!" butonu): açık görevler ve hedefleri, ardından tamamlananlar.
## Bir göreve tıklanınca ayrıntısı görünür ve HUD'da takip edilir. Açıkken oyun duraklar.

signal closed

var _list: VBoxContainer
var _description: Label


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	theme_type_variation = &"WindowPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_QUESTS"
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)
	box.add_child(HSeparator.new())
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size = Vector2(260, 40)
	_description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_description)
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.icon = preload("res://addons/pixel_ui_fantasy/icons/cross.png")
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_refresh()
	_description.text = tr("UI_TAP_QUEST") if not Quests.get_open_quests().is_empty() else tr("UI_NO_QUESTS")
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for id in Quests.get_open_quests():
		_list.add_child(_quest_button(id))
	for id in Quests.get_completed_quests():
		var button := _quest_button(id)
		button.modulate = Color(1, 1, 1, 0.5)
		_list.add_child(button)


func _quest_button(id: String) -> Button:
	var button := Button.new()
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var state := Quests.get_state(id)
	var mark := "* " if bool(Quests.defs[id].get("main", false)) else ""
	var suffix := ""
	match state:
		Quests.State.READY:
			suffix = "  (" + tr("UI_QUEST_READY") + ")"
		Quests.State.DONE:
			suffix = "  (" + tr("UI_QUEST_DONE") + ")"
	button.text = mark + Quests.get_title(id) + suffix
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(_show_quest.bind(id))
	button.focus_entered.connect(_show_quest.bind(id, false))
	return button


## track: seçilen görev HUD'da takip edilsin mi (odakla gezerken değil, tıklayınca)
func _show_quest(id: String, track: bool = true) -> void:
	var lines: Array[String] = [Quests.get_description(id)]
	for i in Quests.get_objective_count(id):
		lines.append(("+ " if Quests.is_objective_done(id, i) else "» ") + Quests.get_objective_text(id, i))
	_description.text = "\n".join(lines)
	if track and Quests.get_state(id) != Quests.State.DONE:
		Quests.tracked = id
		Quests.tracked_changed.emit(id)
