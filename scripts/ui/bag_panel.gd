class_name BagPanel
extends VBoxContainer
## Çanta paneli (envanter ve dükkân penceresinde ortak): 6x6 yuva, sürükle-bırak, bölme (split),
## imlece yapışan yığın ve eşya bilgi kutusu.
## - Tıkla: seç. Sağ tık: quick_action (envanterde kullan/kuşan, dükkânda sat).
## - Sürükle-bırak: yığının tamamı taşınır; aynı türse birleşir, farklıysa yer değiştirir.
## - Split: kaydırıcıyla adet seçilir, o kadarı imlece yapışır; bir yuvaya tıklayınca bırakılır
##   (boşsa yerleşir, aynı türse birleşir, farklı eşyaysa yer değiştirir ve o eşya imlece geçer).
## - Gamepad: odakla gez, A seç / bırak; imlece yapışan yığın odaktaki yuvanın üstünde görünür.
## Sahip pencere actions satırına kendi butonlarını ekler (Split butonu en sonda kalır).

signal selection_changed(index: int)
signal quick_action(index: int)
## Ekipman yuvasından çantaya sürükleyip bırakınca (InventoryWindow ele alır)
signal equipment_dropped(slot_name: String, index: int)

const COLUMNS := 6

## Seçili yuva (-1: yok)
var selected := -1
## Sahip pencerenin butonlarını eklediği satır
var actions: HBoxContainer
## Bilgi kutusunda satış fiyatı da yazsın (dükkân)
var show_prices := false
## Bilgi kutusu (sahip pencere verir; pencerenin en üstünde çizilsin diye)
var tooltip: ItemTooltip

var _slots: Array[ItemSlot] = []
var _count_label: Label
var _split_button: Button
var _split_popup: PanelContainer
var _split_slider: HSlider
var _split_label: Label
var _split_ok: Button
var _held: BagStack
var _held_origin := -1
var _held_view: Control
var _held_icon: TextureRect
var _held_count: Label


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	add_child(header)
	var label := Label.new()
	label.text = "UI_BAG"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	_count_label = Label.new()
	_count_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	header.add_child(_count_label)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 1)
	grid.add_theme_constant_override("v_separation", 1)
	add_child(grid)
	for i in GameState.BAG_SIZE:
		var slot := ItemSlot.new()
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.secondary_pressed.connect(func() -> void:
			if _held == null:
				quick_action.emit(i))
		slot.hovered.connect(_show_tooltip.bind(i))
		slot.unhovered.connect(_hide_tooltip)
		slot.set_drag_forwarding(_get_drag.bind(i), _can_drop.bind(i), _drop.bind(i))
		grid.add_child(slot)
		_slots.append(slot)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 2)
	add_child(actions)
	_split_button = Button.new()
	_split_button.text = "UI_SPLIT"
	_split_button.pressed.connect(_open_split)
	actions.add_child(_split_button)
	_build_split_popup()
	_build_held_view()
	GameState.inventory_changed.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	if _held == null:
		return
	# İmlece yapışan yığın: fareyle oynanıyorsa imlecin yanında, gamepad'de odaktaki yuvanın üstünde
	var focus := get_viewport().gui_get_focus_owner()
	if Controls.using_gamepad and focus is ItemSlot:
		_held_view.global_position = focus.global_position + Vector2(6, -8)
	else:
		_held_view.global_position = get_global_mouse_position() + Vector2(4, 4)


func refresh() -> void:
	if not is_node_ready():
		return
	if selected >= 0 and GameState.bag[selected] == null:
		selected = -1
	for i in _slots.size():
		var stack := GameState.bag[i]
		var slot := _slots[i]
		if stack:
			slot.show_item(stack.get_icon(), stack.count, stack.get_rarity())
		else:
			slot.show_item(null)
		slot.set_selected(i == selected)
	_count_label.text = "%d/%d" % [GameState.bag_used_slots(), GameState.BAG_SIZE]
	var stack := get_selected_stack()
	# Bölünebilecek kadar (en az 2) eşya varsa Split etkin
	_split_button.disabled = stack == null or stack.count < 2 or _held != null
	_refresh_held_view()


func get_selected_stack() -> BagStack:
	return GameState.bag[selected] if selected >= 0 else null


func select(index: int) -> void:
	selected = index if index >= 0 and GameState.bag[index] != null else -1
	refresh()
	selection_changed.emit(selected)


func get_slot(index: int) -> ItemSlot:
	return _slots[index]


func is_holding() -> bool:
	return _held != null


## İmlece yapışan yığını çantaya geri koyar (pencere kapanırken). Önce geldiği yuvaya.
func return_held() -> void:
	_split_popup.hide()
	if _held == null:
		return
	var stack := _held
	_held = null
	if _held_origin >= 0 and (GameState.bag[_held_origin] == null or GameState.bag[_held_origin].can_stack_with(stack)):
		GameState.place_in_slot(stack, _held_origin)
	elif GameState.add_to_bag(stack) > 0:
		# Hiç yer yoksa (olmamalı) eşya kaybolmasın: satılır
		GameState.gold += stack.unit_value() * stack.count
		GameState.gold_changed.emit(GameState.gold)
	_held_origin = -1
	refresh()


func _on_slot_pressed(index: int) -> void:
	if _held:
		_held = GameState.place_in_slot(_held, index)
		# Yer değiştiren eşya imlece geçti; kapanırsa bu yuvaya dönmesin, boş yer arasın
		_held_origin = -1
		select(index)
		return
	select(index)


# --- Sürükle-bırak -----------------------------------------------------------------

func _get_drag(_at: Vector2, index: int) -> Variant:
	if _held or GameState.bag[index] == null:
		return null
	var preview := TextureRect.new()
	IconFit.place(preview, GameState.bag[index].get_icon(), Rect2(Vector2.ZERO, ItemSlot.ICON_AREA.size))
	var holder := Control.new()
	holder.add_child(preview)
	preview.position -= ItemSlot.ICON_AREA.size / 2.0
	_slots[index].set_drag_preview(holder)
	_hide_tooltip()
	return {"source": "bag", "index": index}


func _can_drop(_at: Vector2, data: Variant, _index: int) -> bool:
	return data is Dictionary and data.get("source") in ["bag", "equip"]


func _drop(_at: Vector2, data: Variant, index: int) -> void:
	match data["source"]:
		"bag":
			GameState.move_slot(int(data["index"]), index)
			select(index)
		"equip":
			equipment_dropped.emit(str(data["slot"]), index)


# --- Bölme (split) ----------------------------------------------------------------

func _build_split_popup() -> void:
	_split_popup = PanelContainer.new()
	_split_popup.theme_type_variation = &"WindowPanel"
	_split_popup.top_level = true
	_split_popup.add_to_group("menus")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_split_popup.add_child(box)
	var title := Label.new()
	title.text = "UI_SPLIT_TITLE"
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	_split_slider = HSlider.new()
	_split_slider.min_value = 1
	_split_slider.step = 1
	_split_slider.custom_minimum_size = Vector2(90, 0)
	_split_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_split_slider.value_changed.connect(func(value: float) -> void:
		_split_label.text = "%d / %d" % [int(value), int(_split_slider.max_value)])
	row.add_child(_split_slider)
	_split_label = Label.new()
	_split_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_split_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(_split_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	box.add_child(buttons)
	_split_ok = Button.new()
	_split_ok.text = "UI_OK"
	_split_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_ok.pressed.connect(_confirm_split)
	buttons.add_child(_split_ok)
	var cancel := Button.new()
	cancel.text = "UI_CANCEL"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_split_popup.hide)
	buttons.add_child(cancel)
	_split_popup.hide()
	add_child(_split_popup)


func _open_split() -> void:
	var stack := get_selected_stack()
	if stack == null or stack.count < 2:
		return
	_hide_tooltip()
	_split_slider.max_value = stack.count
	_split_slider.value = maxi(1, stack.count / 2)
	_split_label.text = "%d / %d" % [int(_split_slider.value), stack.count]
	_split_popup.show()
	_split_popup.reset_size()
	# Seçili yuvanın yanında aç; ekrandan taşmasın
	var rect := _slots[selected].get_global_rect()
	var screen := get_viewport_rect().size
	var target := Vector2(rect.end.x + 4, rect.position.y)
	target.x = minf(target.x, screen.x - _split_popup.size.x)
	target.y = minf(target.y, screen.y - _split_popup.size.y)
	_split_popup.global_position = target.round()
	_split_slider.grab_focus()


## Split penceresi açık mı (geri tuşu önce onu kapatsın)
func is_split_open() -> bool:
	return _split_popup.visible


func close_split() -> void:
	_split_popup.hide()


func _confirm_split() -> void:
	_split_popup.hide()
	if selected < 0:
		return
	_held_origin = selected
	_held = GameState.take_from_slot(selected, int(_split_slider.value))
	selected = -1
	refresh()
	if Controls.using_gamepad:
		_slots[_held_origin].grab_focus()


func _build_held_view() -> void:
	_held_view = Control.new()
	_held_view.top_level = true
	_held_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_view.z_index = 10
	_held_icon = TextureRect.new()
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_view.add_child(_held_icon)
	_held_count = Label.new()
	_held_count.theme_type_variation = &"HudLabel"
	_held_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_held_count.position = Vector2(10, 8)
	_held_view.add_child(_held_count)
	_held_view.hide()
	add_child(_held_view)


func _refresh_held_view() -> void:
	_held_view.visible = _held != null
	if _held:
		IconFit.place(_held_icon, _held.get_icon(), Rect2(Vector2.ZERO, ItemSlot.ICON_AREA.size))
		_held_count.text = str(_held.count) if _held.count > 1 else ""


# --- Bilgi kutusu ------------------------------------------------------------------

func _show_tooltip(index: int) -> void:
	var stack := GameState.bag[index]
	if tooltip == null or stack == null or _split_popup.visible:
		_hide_tooltip()
		return
	var body := stack.get_details()
	if show_prices:
		var value := stack.unit_value()
		body += "\n" + (tr("UI_SELL_PRICE") % (value * stack.count) if value > 0 else tr("UI_CANNOT_SELL"))
	tooltip.show_for(_slots[index], stack.get_display_name(), body, stack.get_color())


func _hide_tooltip() -> void:
	if tooltip:
		tooltip.hide()
