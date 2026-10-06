class_name ShopWindow
extends PanelContainer
## Tüccar Kadir'in dükkânı: iksir satın alma ve çantadaki değerli eşyaları satma.
## Pencere açıkken oyun duraklar.

signal closed

var _buy_list: VBoxContainer
var _sell_list: VBoxContainer
var _sell_all: Button


func _ready() -> void:
	theme_type_variation = &"WindowPanel"
	custom_minimum_size = Vector2(250, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_SHOP"
	box.add_child(title)

	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 2)
	box.add_child(_buy_list)
	box.add_child(HSeparator.new())

	var sell_scroll := ScrollContainer.new()
	sell_scroll.custom_minimum_size = Vector2(0, 72)
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(sell_scroll)
	_sell_list = VBoxContainer.new()
	_sell_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_list.add_theme_constant_override("separation", 2)
	sell_scroll.add_child(_sell_list)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	box.add_child(row)
	_sell_all = Button.new()
	_sell_all.text = "UI_SELL_ALL"
	_sell_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_all.pressed.connect(_sell_everything)
	row.add_child(_sell_all)
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.icon = load("res://addons/pixel_ui_fantasy/icons/cross.png")
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.pressed.connect(close)
	row.add_child(close_button)

	GameState.inventory_changed.connect(_refresh)
	GameState.gold_changed.connect(_refresh.unbind(1))
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
	if _buy_list == null:
		return
	for child in _buy_list.get_children():
		child.queue_free()
	_buy_list.add_child(_row(load(GameState.HEALTH_POTION_ICON), tr("ITEM_HEALTH_POTION"), GameState.HEALTH_POTION_PRICE,
		"UI_BUY", GameState.gold >= GameState.HEALTH_POTION_PRICE, GameState.buy_health_potion))
	_buy_list.add_child(_row(load(GameState.MANA_POTION_ICON), tr("ITEM_MANA_POTION"), GameState.MANA_POTION_PRICE,
		"UI_BUY", GameState.gold >= GameState.MANA_POTION_PRICE, GameState.buy_mana_potion))
	for child in _sell_list.get_children():
		child.queue_free()
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = "UI_NOTHING_TO_SELL"
		_sell_list.add_child(empty)
	for item in GameState.inventory:
		var label_text := item.get_display_name()
		var color := item.get_color() if item.rarity != ItemData.Rarity.COMMON else Color.WHITE
		_sell_list.add_child(_row(item.get_icon(), label_text, item.value, "UI_SELL", true, _sell.bind(item), color))
	_sell_all.disabled = GameState.inventory.is_empty()


func _row(icon: Texture2D, item_name: String, price: int, button_key: String, enabled: bool, action: Callable, color: Color = Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var art := TextureRect.new()
	art.texture = icon
	art.custom_minimum_size = Vector2(24, 24)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if color != Color.WHITE:
		name_label.add_theme_color_override("font_color", color.darkened(0.45))
	row.add_child(name_label)
	var price_label := Label.new()
	price_label.text = tr("UI_PRICE") % price
	price_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(price_label)
	var button := Button.new()
	button.text = button_key
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(44, 0)
	button.pressed.connect(func() -> void: action.call())
	row.add_child(button)
	return row


func _sell(item: ItemData) -> void:
	var earned := GameState.sell_item(item)
	if earned > 0:
		GameState.message.emit(tr("MSG_SOLD") % earned, GameState.GOLD_COLOR)


func _sell_everything() -> void:
	var total := 0
	for item in GameState.inventory.duplicate():
		total += GameState.sell_item(item)
	if total > 0:
		GameState.message.emit(tr("MSG_SOLD") % total, GameState.GOLD_COLOR)
