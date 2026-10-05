class_name InventoryWindow
extends PanelContainer
## Envanter penceresi (Pixel UI Fantasy parşömen teması).
## Çanta sekmesinde iksirler ve değerli eşyalar kutularda gösterilir; bir kutuya dokunup
## "Kullan" ile iksir içilir. Pencere açıkken oyun duraklatılır.
## Ekipman sekmesi silah/zırh görselleri gelince doldurulacak.

signal closed

const SLOT_COUNT := 12
const SLOT_SIZE := Vector2(42, 42)
const EMPTY_TEXT := "Bir eşyaya dokun."

# Kutudaki kayıt: {"kind": "health"/"mana"/"item", "icon": Texture2D, "name": String,
#                  "count": int, "description": String, "color": Color}
var _entries: Array[Dictionary] = []
var _slots: Array[PanelContainer] = []
var _selected := -1

@onready var tabs: TabContainer = %Tabs
@onready var bag_grid: GridContainer = %BagGrid
@onready var description: Label = %Description
@onready var use_button: Button = %UseButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	tabs.set_tab_title(0, "Çanta")
	tabs.set_tab_title(1, "Ekipman")
	tabs.set_tab_disabled(1, true)
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
		slot.add_child(count)
		bag_grid.add_child(slot)
		_slots.append(slot)
	use_button.pressed.connect(_on_use_pressed)
	close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_refresh)
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_selected = -1
	_refresh()
	show()
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


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
	_update_details()


func _build_entries() -> void:
	_entries.clear()
	if GameState.health_potions > 0:
		_entries.append({
			"kind": "health", "icon": load(GameState.HEALTH_POTION_ICON), "name": "Can İksiri",
			"count": GameState.health_potions, "color": GameState.HEAL_COLOR,
			"description": "Canın %%%d kadarını doldurur." % roundi(GameState.HEALTH_POTION_RATIO * 100),
		})
	if GameState.mana_potions > 0:
		_entries.append({
			"kind": "mana", "icon": load(GameState.MANA_POTION_ICON), "name": "Mana İksiri",
			"count": GameState.mana_potions, "color": GameState.MANA_COLOR,
			"description": "Mananın %%%d kadarını doldurur." % roundi(GameState.MANA_POTION_RATIO * 100),
		})
	# Aynı ad ve nadirlikteki değerli eşyalar tek kutuda üst üste durur
	var stacks := {}
	for item in GameState.inventory:
		var key := "%s|%d" % [item.item_name, item.rarity]
		if stacks.has(key):
			stacks[key]["count"] += 1
			continue
		var entry := {
			"kind": "item", "icon": item.get_icon(), "name": item.get_display_name(),
			"count": 1, "color": item.get_color(),
			"description": "Değer: %d altın. Dükkânda satılabilir." % item.value,
		}
		stacks[key] = entry
		_entries.append(entry)


func _update_details() -> void:
	if _selected < 0:
		description.text = EMPTY_TEXT
		use_button.disabled = true
		return
	var entry := _entries[_selected]
	description.text = "%s: %s" % [entry["name"], entry["description"]]
	use_button.disabled = entry["kind"] == "item"


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
				GameState.message.emit("Canın zaten dolu", Color.WHITE)
		"mana":
			if GameState.use_mana_potion() == 0:
				GameState.message.emit("Manan zaten dolu", Color.WHITE)
	_refresh()
