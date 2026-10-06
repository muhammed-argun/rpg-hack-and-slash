class_name InventoryWindow
extends PanelContainer
## Birleşik envanter + karakter penceresi (I ve C aynı pencereyi açar). Açıkken oyun duraklar.
## Sol: çanta (BagPanel: 36 yuva, sürükle-bırak, split) ve Kullan/Kuşan/Çıkar, 1/2 hızlı kullanım butonları.
## Sağ: seviye, can/mana, XP barı (üstüne gelince "350/1000" yazar), ekipman yuvaları, iki silah seti,
## sadak (3 mühimmat yuvası), özellikler (STR/AGI/INT/VIT) ve dağıtılacak puanlar.
## Eşya bilgisi imlecin yanındaki kutuda (ItemTooltip) çıkar; pencere metne göre büyümez.
## Fare: tıkla = seç, sağ tık = hızlı eylem, sürükle = taşı (çanta <-> ekipman). Gamepad: odakla gez, A = seç.

signal closed

const PREVIEW_FRAME := "res://assets/characters/soldier/idle_right_01.png"
# Ekipman yuvalarının yerleşimi: karakterin solu ve sağı
const LEFT_SLOTS := ["helmet", "armor", "gloves", "boots"]
const RIGHT_SLOTS := ["amulet", "cloak", "ring", "belt"]
const QUIVER_SLOTS := ["ammo_1", "ammo_2", "ammo_3"]
# Boş ekipman yuvasında soluk gösterilen ikonun türü
const SLOT_HINT_TYPES := {
	"helmet": ItemData.Type.HELMET, "armor": ItemData.Type.ARMOR, "gloves": ItemData.Type.GLOVES,
	"boots": ItemData.Type.BOOTS, "amulet": ItemData.Type.AMULET, "cloak": ItemData.Type.CLOAK,
	"ring": ItemData.Type.RING, "belt": ItemData.Type.BELT,
	"main_1": ItemData.Type.WEAPON, "main_2": ItemData.Type.WEAPON,
	"off_1": ItemData.Type.OFFHAND, "off_2": ItemData.Type.OFFHAND,
	"ammo_1": ItemData.Type.AMMO, "ammo_2": ItemData.Type.AMMO, "ammo_3": ItemData.Type.AMMO,
}

var bag: BagPanel
var tooltip: ItemTooltip
var _equip_slots := {}
# Seçili ekipman yuvası ("" = çantada seçim var ya da hiç yok)
var _selected_equip := ""

var _primary: Button
var _quick_buttons: Array[Button] = []
var _level_label: Label
var _stats_label: Label
var _combat_label: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _set_buttons: Array[Button] = []
var _attribute_labels := {}
var _attribute_buttons := {}
var _points_label: Label


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	theme_type_variation = &"WindowPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_CHARACTER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.icon = preload("res://addons/pixel_ui_fantasy/icons/cross.png")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	title_row.add_child(close_button)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)
	tooltip = ItemTooltip.new()
	bag = BagPanel.new()
	bag.tooltip = tooltip
	columns.add_child(bag)
	_build_bag_actions()
	columns.add_child(_build_character())
	# Bilgi kutusu en son eklenir: her şeyin üstünde çizilsin
	add_child(tooltip)

	bag.selection_changed.connect(_on_bag_selection_changed)
	bag.quick_action.connect(_quick_action_bag)
	bag.equipment_dropped.connect(_on_equipment_dropped)
	GameState.inventory_changed.connect(_refresh)
	GameState.equipment_changed.connect(_refresh)
	GameState.attributes_changed.connect(_refresh)
	GameState.hotbar_changed.connect(_refresh)
	GameState.xp_changed.connect(_refresh.unbind(3))
	Settings.changed.connect(_refresh)
	Controls.bindings_changed.connect(_refresh)
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	_selected_equip = ""
	bag.select(-1)
	_refresh()
	show()
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	get_tree().paused = true


func close() -> void:
	bag.return_held()
	tooltip.hide()
	hide()
	get_tree().paused = false
	closed.emit()


## Geri tuşu: önce split penceresi / elde tutulan eşya iptal edilir, sonra pencerenin kendisi kapanır.
func go_back() -> void:
	if not bag.handle_back():
		close()


# --- Kurulum -------------------------------------------------------------------

func _build_bag_actions() -> void:
	_primary = Button.new()
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.pressed.connect(_on_primary_pressed)
	bag.actions.add_child(_primary)
	bag.actions.move_child(_primary, 0)
	for i in GameState.QUICK_SLOT_COUNT:
		var button := Button.new()
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.custom_minimum_size = Vector2(22, 0)
		button.pressed.connect(_assign_quick_slot.bind(i))
		bag.actions.add_child(button)
		bag.actions.move_child(button, i + 1)
		_quick_buttons.append(button)


func _build_character() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	box.add_child(header)
	_level_label = Label.new()
	_level_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(_level_label)
	_stats_label = Label.new()
	_stats_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_stats_label)
	# XP barı: fare üstüne gelince "350/1000" yazar
	_xp_bar = ProgressBar.new()
	_xp_bar.theme_type_variation = &"GoldBar"
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 8)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_xp_bar)
	_xp_text = Label.new()
	_xp_text.theme_type_variation = &"HudLabel"
	_xp_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_xp_text.offset_top = -3
	_xp_text.offset_bottom = 3
	_xp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_text.hide()
	_xp_bar.add_child(_xp_text)
	_xp_bar.mouse_entered.connect(_xp_text.show)
	_xp_bar.mouse_exited.connect(_xp_text.hide)

	# Ekipman: solda 4, ortada karakter, sağda 4 yuva
	var gear := HBoxContainer.new()
	gear.add_theme_constant_override("separation", 4)
	box.add_child(gear)
	gear.add_child(_slot_column(LEFT_SLOTS))
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	gear.add_child(center)
	var preview := TextureRect.new()
	preview.texture = load(PREVIEW_FRAME) if ResourceLoader.exists(PREVIEW_FRAME) else null
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(84, 62)
	center.add_child(preview)
	_combat_label = Label.new()
	_combat_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_combat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_combat_label)
	gear.add_child(_slot_column(RIGHT_SLOTS))

	# Silah setleri ve sadak (3 mühimmat yuvası; boşken soluk ok ikonu)
	var weapons := HBoxContainer.new()
	weapons.add_theme_constant_override("separation", 2)
	box.add_child(weapons)
	for set_number in [1, 2]:
		var set_button := Button.new()
		set_button.text = "I" if set_number == 1 else "II"
		set_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		set_button.toggle_mode = true
		set_button.custom_minimum_size = Vector2(18, 0)
		set_button.pressed.connect(_on_set_pressed.bind(set_number))
		weapons.add_child(set_button)
		_set_buttons.append(set_button)
		weapons.add_child(_equip_slot("main_%d" % set_number))
		weapons.add_child(_equip_slot("off_%d" % set_number))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(3, 0)
		weapons.add_child(gap)
	for slot_name: String in QUIVER_SLOTS:
		weapons.add_child(_equip_slot(slot_name))

	# Özellikler: 2x2, puan varsa "+" butonu
	var attributes := GridContainer.new()
	attributes.columns = 2
	attributes.add_theme_constant_override("h_separation", 8)
	attributes.add_theme_constant_override("v_separation", 1)
	box.add_child(attributes)
	for attribute: String in GameState.ATTRIBUTES:
		# Her hücre: ad + değer, puan varsa yanında "+" (gizlenince hücre yerinde kalır)
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(108, 0)
		attributes.add_child(cell)
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.tooltip_text = "ATTR_%s_DESC" % attribute.to_upper()
		cell.add_child(label)
		_attribute_labels[attribute] = label
		var plus := Button.new()
		plus.text = "+"
		plus.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		plus.custom_minimum_size = Vector2(16, 0)
		plus.pressed.connect(_on_attribute_plus.bind(attribute))
		cell.add_child(plus)
		_attribute_buttons[attribute] = plus
	_points_label = Label.new()
	_points_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_points_label)
	return box


func _slot_column(slot_names: Array) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	for slot_name: String in slot_names:
		column.add_child(_equip_slot(slot_name))
	return column


func _equip_slot(slot_name: String) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.pressed.connect(_select_equip.bind(slot_name))
	slot.secondary_pressed.connect(_quick_action_equip.bind(slot_name))
	slot.hovered.connect(_show_equip_tooltip.bind(slot_name))
	slot.unhovered.connect(_hide_tooltip)
	slot.set_drag_forwarding(_get_equip_drag.bind(slot_name), _can_drop_equip.bind(slot_name), _drop_equip.bind(slot_name))
	_equip_slots[slot_name] = slot
	return slot


func _hide_tooltip() -> void:
	tooltip.hide()


# --- Yenileme ------------------------------------------------------------------

func _refresh() -> void:
	if not is_node_ready():
		return
	for slot_name: String in _equip_slots:
		var slot: ItemSlot = _equip_slots[slot_name]
		var item := GameState.get_equipped(slot_name)
		if item:
			slot.show_item(item.get_icon(), 0, item.rarity)
		elif slot_name.begins_with("off_") and _offhand_locked(slot_name):
			slot.show_locked()
		else:
			slot.show_item(null, 0, -1, _hint_icon(slot_name))
		slot.set_selected(_selected_equip == slot_name)
	for i in _set_buttons.size():
		var active := GameState.active_weapon_set == i + 1
		_set_buttons[i].set_pressed_no_signal(active)
		# Kullanılmayan set soluk görünsün
		for slot_name: String in ["main_%d" % (i + 1), "off_%d" % (i + 1)]:
			(_equip_slots[slot_name] as ItemSlot).modulate = Color.WHITE if active else Color(1, 1, 1, 0.5)
	_refresh_character()
	_refresh_actions()


func _refresh_character() -> void:
	_level_label.text = tr("UI_LEVEL_SHORT") % GameState.level
	_stats_label.text = tr("UI_HP_MP") % [GameState.max_hp, GameState.max_mana]
	_combat_label.text = tr("UI_DAMAGE_DEFENSE") % [GameState.get_attack_damage(), GameState.get_defense()]
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	_xp_text.text = "%d/%d" % [GameState.xp, GameState.xp_to_next()]
	for attribute: String in GameState.ATTRIBUTES:
		(_attribute_labels[attribute] as Label).text = "%s  %d" % [tr("ATTR_" + attribute.to_upper()), GameState.get_attribute(attribute)]
		(_attribute_buttons[attribute] as Button).visible = GameState.attribute_points > 0
	_points_label.text = tr("UI_ATTRIBUTE_POINTS") % GameState.attribute_points
	_points_label.modulate = Color(1.0, 0.85, 0.3) if GameState.attribute_points > 0 else Color(1, 1, 1, 0.6)


func _hint_icon(slot_name: String) -> Texture2D:
	var path: String = ItemData.TYPE_ICONS.get(SLOT_HINT_TYPES.get(slot_name, -1), "")
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


func _offhand_locked(slot_name: String) -> bool:
	var main := GameState.get_equipped("main_" + slot_name.right(1))
	return main != null and main.two_handed


# --- Seçim, bilgi, eylemler ----------------------------------------------------

func _on_bag_selection_changed(index: int) -> void:
	if index >= 0:
		_selected_equip = ""
	_refresh()


func _select_equip(slot_name: String) -> void:
	_selected_equip = slot_name
	bag.select(-1)
	_refresh()


func _show_equip_tooltip(slot_name: String) -> void:
	var item := GameState.get_equipped(slot_name)
	var slot: ItemSlot = _equip_slots[slot_name]
	if item:
		tooltip.show_for(slot, item.get_display_name(), item.get_details(), item.get_color())
	else:
		var locked := slot_name.begins_with("off_") and _offhand_locked(slot_name)
		tooltip.show_for(slot, tr(GameState.SLOT_KEYS[slot_name]), tr("MSG_OFFHAND_LOCKED") if locked else tr("UI_EMPTY_SLOT"))


# Seçime göre ana buton: Kullan / Kuşan / Çıkar; tüketilebilirse 1 ve 2 yuvasına koyma butonları
func _refresh_actions() -> void:
	_primary.text = "UI_USE"
	_primary.disabled = true
	var consumable := ""
	var stack := bag.get_selected_stack()
	if stack:
		if stack.is_consumable():
			_primary.disabled = false
			consumable = stack.id
		elif stack.item and stack.item.is_equippable():
			_primary.text = "UI_EQUIP"
			_primary.disabled = false
	elif not _selected_equip.is_empty():
		_primary.text = "UI_UNEQUIP"
		_primary.disabled = GameState.get_equipped(_selected_equip) == null
	for i in _quick_buttons.size():
		var button := _quick_buttons[i]
		button.text = Controls.get_action_label("quick_slot_%d" % (i + 1), true)
		button.disabled = consumable.is_empty()
		button.tooltip_text = tr("UI_ASSIGN_QUICK_SLOT") % button.text
		# Bu eşya zaten o yuvadaysa butonu vurgula
		button.modulate = Color(1.0, 0.85, 0.4) if not consumable.is_empty() and GameState.quick_slots[i] == consumable else Color.WHITE


func _on_primary_pressed() -> void:
	if bag.selected >= 0:
		_quick_action_bag(bag.selected)
	elif not _selected_equip.is_empty():
		_quick_action_equip(_selected_equip)


# Çantadaki yuva için hızlı eylem: iksiri iç, eşyayı kuşan
func _quick_action_bag(index: int) -> void:
	var stack := GameState.bag[index]
	if stack == null:
		return
	if stack.is_consumable():
		var used := GameState.use_health_potion() if stack.id == "health_potion" else GameState.use_mana_potion()
		if used == 0:
			GameState.message.emit(tr("MSG_HP_FULL" if stack.id == "health_potion" else "MSG_MP_FULL"), Color.WHITE)
	elif stack.item and stack.item.is_equippable():
		GameState.equip(stack.item)
	bag.refresh()
	_refresh()


func _quick_action_equip(slot_name: String) -> void:
	if GameState.unequip(slot_name):
		_selected_equip = ""
	_refresh()


func _assign_quick_slot(index: int) -> void:
	var stack := bag.get_selected_stack()
	if stack and stack.is_consumable():
		GameState.set_quick_slot(index, stack.id)


func _on_set_pressed(set_number: int) -> void:
	if GameState.active_weapon_set != set_number:
		GameState.swap_weapon_set()
	_refresh()


func _on_attribute_plus(attribute: String) -> void:
	GameState.add_attribute_point(attribute)


# --- Ekipman sürükle-bırak ----------------------------------------------------------

func _get_equip_drag(_at: Vector2, slot_name: String) -> Variant:
	var item := GameState.get_equipped(slot_name)
	if item == null or bag.is_holding():
		return null
	var preview := TextureRect.new()
	IconFit.place(preview, item.get_icon(), Rect2(-ItemSlot.ICON_AREA.size / 2.0, ItemSlot.ICON_AREA.size))
	var holder := Control.new()
	holder.add_child(preview)
	(_equip_slots[slot_name] as ItemSlot).set_drag_preview(holder)
	tooltip.hide()
	return {"source": "equip", "slot": slot_name}


# Çantadan gelen eşya bu yuvaya takılabiliyorsa kabul et
func _can_drop_equip(_at: Vector2, data: Variant, slot_name: String) -> bool:
	if not data is Dictionary or data.get("source") != "bag":
		return false
	var stack := GameState.bag[int(data["index"])]
	return stack != null and stack.item != null and slot_name in stack.item.get_slots()


func _drop_equip(_at: Vector2, data: Variant, slot_name: String) -> void:
	var stack := GameState.bag[int(data["index"])]
	if stack and stack.item:
		GameState.equip_to(stack.item, slot_name)
	_refresh()


# Ekipman yuvasından çantaya bırakıldı: boş yuvaya çıkar; dolu yuvadaki eşya oraya takılabiliyorsa yer değiştir
func _on_equipment_dropped(slot_name: String, index: int) -> void:
	var target := GameState.bag[index]
	if target == null:
		GameState.unequip(slot_name, index)
	elif target.item and slot_name in target.item.get_slots():
		GameState.equip_to(target.item, slot_name)
	else:
		GameState.unequip(slot_name)
	_refresh()
