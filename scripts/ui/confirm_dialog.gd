class_name ConfirmDialog
extends PanelContainer
## Basit "Emin misin?" penceresi. ask() ile açılır, sonuç confirmed / cancelled sinyaliyle gelir.

signal confirmed
signal cancelled

var _label: Label


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "GAME_TITLE"
	box.add_child(title)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(200, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var yes := Button.new()
	yes.text = "UI_YES"
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(_answer.bind(true))
	row.add_child(yes)
	var no := Button.new()
	no.text = "UI_NO"
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(_answer.bind(false))
	row.add_child(no)
	hide()


func ask(message_key: String) -> void:
	_label.text = message_key
	show()
	# Ekranın ortasına yerleş
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _answer(yes: bool) -> void:
	hide()
	if yes:
		confirmed.emit()
	else:
		cancelled.emit()
