class_name InventoryWindow
extends PanelContainer
## Envanter penceresi (Pixel UI Fantasy parşömen teması).
## Çanta: iksirler, malzemeler ve değerli eşyalar; kutuya dokunup "Kullan" ile iksir içilir.
## Görevler: açık görevler ve hedefleri, ardından tamamlananlar.
## Ekipman sekmesi silah/zırh görselleri gelince doldurulacak. Pencere açıkken oyun duraklar.

signal closed

const TAB_BAG := 0
const TAB_GEAR := 1
const TAB_QUESTS := 2
const SLOT_COUNT := 12
const SLOT_SIZE := Vector2(42, 42)

# Kutudaki kayıt: {"kind": "health"/"mana"/"material"/"item", "icon": Texture2D, "name": String,
#                  "count": int, "description": String}
var _entries: Array[Dictionary] = []
var _slots: Array[PanelContainer] = []
var _selected := -1

@onready var tabs: TabContainer = %Tabs
@onready var bag_grid: GridContainer = %BagGrid
@onready var quest_list: VBoxContainer = %QuestList
@onready var description: Label = %Description
@onready var use_button: Button = %UseButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	_set_tab_titles()
	tabs.set_tab_disabled(TAB_GEAR, true)
	for i in SLOT_COUNT:
		var slot := PanelContainer.new()
		slot.theme_type_variation = &"InsetPanel"
		slot.custom_minimum_size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_slot_input.bind(i))
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var count := Label.new()
		count.name = "Count"
		count.theme_type_variation = &"HudLabel"
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		slot.add_child(count)
		bag_grid.add_child(slot)
		_slots.append(slot)
	tabs.tab_changed.connect(_on_tab_changed)
	use_button.pressed.connect(_on_use_pressed)
	close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_refresh)
	Settings.changed.connect(_set_tab_titles)
	description.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open(tab: int = TAB_BAG) -> void:
	_selected = -1
	tabs.current_tab = tab
	_refresh()
	_refresh_quests()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


func _set_tab_titles() -> void:
	tabs.set_tab_title(TAB_BAG, tr("UI_BAG"))
	tabs.set_tab_title(TAB_GEAR, tr("UI_GEAR"))
	tabs.set_tab_title(TAB_QUESTS, tr("UI_QUESTS"))


func _on_tab_changed(tab: int) -> void:
	use_button.visible = tab == TAB_BAG
	if tab == TAB_QUESTS:
		_refresh_quests()
		description.text = tr("UI_TAP_QUEST") if not Quests.get_open_quests().is_empty() else tr("UI_NO_QUESTS")
	else:
		_update_details()


# --- Çanta -------------------------------------------------------------------

func _refresh() -> void:
	_build_entries()
	if _selected >= _entries.size():
		_selected = -1
	for i in _slots.size():
		var slot := _slots[i]
		var icon := slot.get_node("Icon") as TextureRect
		var count := slot.get_node("Count") as Label
		if i < _entries.size():
			var entry := _entries[i]
			icon.texture = entry["icon"]
			count.text = str(entry["count"]) if entry["count"] > 1 else ""
		else:
			icon.texture = null
			count.text = ""
		slot.theme_type_variation = &"RareSlot" if i == _selected else &"InsetPanel"
	if tabs.current_tab == TAB_BAG:
		_update_details()


func _build_entries() -> void:
	_entries.clear()
	if GameState.health_potions > 0:
		_entries.append({
			"kind": "health", "icon": load(GameState.HEALTH_POTION_ICON), "name": tr("ITEM_HEALTH_POTION"),
			"count": GameState.health_potions,
			"description": tr("ITEM_HEALTH_POTION_DESC") % roundi(GameState.HEALTH_POTION_RATIO * 100),
		})
	if GameState.mana_potions > 0:
		_entries.append({
			"kind": "mana", "icon": load(GameState.MANA_POTION_ICON), "name": tr("ITEM_MANA_POTION"),
			"count": GameState.mana_potions,
			"description": tr("ITEM_MANA_POTION_DESC") % roundi(GameState.MANA_POTION_RATIO * 100),
		})
	for material_id: String in GameState.materials:
		var amount := GameState.get_material(material_id)
		if amount <= 0 or not GameState.MATERIALS.has(material_id):
			continue
		var info: Array = GameState.MATERIALS[material_id]
		_entries.append({
			"kind": "material", "icon": GameState.material_icon(material_id), "name": tr(info[0]),
			"count": amount, "description": tr(info[1]),
		})
	# Aynı ad ve nadirlikteki değerli eşyalar tek kutuda üst üste durur
	var stacks := {}
	for item in GameState.inventory:
		var key := "%s|%d" % [item.name_key, item.rarity]
		if stacks.has(key):
			stacks[key]["count"] += 1
			continue
		var entry := {
			"kind": "item", "icon": item.get_icon(), "name": item.get_display_name(),
			"count": 1, "description": tr("ITEM_VALUE_DESC") % item.value,
		}
		stacks[key] = entry
		_entries.append(entry)


func _update_details() -> void:
	if _selected < 0 or _selected >= _entries.size():
		description.text = tr("UI_TAP_ITEM")
		use_button.disabled = true
		return
	var entry := _entries[_selected]
	description.text = "%s: %s" % [entry["name"], entry["description"]]
	use_button.disabled = not (entry["kind"] == "health" or entry["kind"] == "mana")


func _on_slot_input(event: InputEvent, index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		_selected = index if index < _entries.size() else -1
		_refresh()


func _on_use_pressed() -> void:
	if _selected < 0:
		return
	match _entries[_selected]["kind"]:
		"health":
			if GameState.use_health_potion() == 0:
				GameState.message.emit(tr("MSG_HP_FULL"), Color.WHITE)
		"mana":
			if GameState.use_mana_potion() == 0:
				GameState.message.emit(tr("MSG_MP_FULL"), Color.WHITE)
	_refresh()


# --- Görevler ----------------------------------------------------------------

func _refresh_quests() -> void:
	for child in quest_list.get_children():
		child.queue_free()
	for id in Quests.get_open_quests():
		quest_list.add_child(_quest_button(id))
	for id in Quests.get_completed_quests():
		var button := _quest_button(id)
		button.modulate = Color(1, 1, 1, 0.5)
		quest_list.add_child(button)


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
	return button


func _show_quest(id: String) -> void:
	var lines: Array[String] = [Quests.get_description(id)]
	for i in Quests.get_objective_count(id):
		lines.append(("+ " if Quests.is_objective_done(id, i) else "» ") + Quests.get_objective_text(id, i))
	description.text = "\n".join(lines)
	# Seçilen görev HUD'da takip edilir
	if Quests.get_state(id) != Quests.State.DONE:
		Quests.tracked = id
		Quests.tracked_changed.emit(id)
