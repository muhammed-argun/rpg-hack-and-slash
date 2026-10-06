class_name SmithWindow
extends PanelContainer
## Demirci Borak: demir cevheri ve altınla silahı güçlendirme (+1 ... +10).
## Her seviye saldırı hasarını artırır. Pencere açıkken oyun duraklar.

signal closed

var _level_label: Label
var _damage_label: Label
var _cost_label: Label
var _upgrade: Button


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	theme_type_variation = &"WindowPanel"
	custom_minimum_size = Vector2(200, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_SMITH"
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"RareSlot"
	slot.custom_minimum_size = Vector2(42, 42)
	var icon := TextureRect.new()
	icon.texture = load("res://addons/pixel_ui_fantasy/icons/sword.png")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	slot.add_child(icon)
	row.add_child(slot)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	_level_label = _label(info)
	_damage_label = _label(info)

	_cost_label = _label(box)
	box.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	box.add_child(buttons)
	_upgrade = Button.new()
	_upgrade.text = "UI_UPGRADE"
	_upgrade.icon = load("res://addons/pixel_ui_fantasy/icons/check.png")
	_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade.pressed.connect(func() -> void:
		GameState.upgrade_weapon()
		_refresh())
	buttons.add_child(_upgrade)
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	buttons.add_child(close_button)
	GameState.inventory_changed.connect(_refresh)
	hide()


func open() -> void:
	_refresh()
	show()
	get_tree().paused = true
	await get_tree().process_frame
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func _refresh() -> void:
	if _level_label == null:
		return
	_level_label.text = tr("UI_WEAPON_LEVEL") % GameState.weapon_level
	_damage_label.text = tr("UI_WEAPON_DAMAGE") % GameState.get_attack_damage()
	if GameState.weapon_level >= GameState.MAX_WEAPON_LEVEL:
		_cost_label.text = tr("UI_MAX_LEVEL")
		_upgrade.disabled = true
		return
	var cost := GameState.weapon_upgrade_cost()
	var ore := int(cost["iron_ore"])
	var gold := int(cost["gold"])
	_cost_label.text = "%s: %d/%d %s, %s" % [tr("UI_RECIPE_NEEDS"), GameState.get_material("iron_ore"), ore,
		tr("MAT_IRON_ORE"), tr("UI_PRICE") % gold]
	_upgrade.disabled = GameState.get_material("iron_ore") < ore or GameState.gold < gold


func _label(parent: Control) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	parent.add_child(label)
	return label
