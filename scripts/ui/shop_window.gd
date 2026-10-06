class_name ShopWindow
extends PanelContainer
## Tüccar Kadir'in dükkânı. Sol: oyuncunun çantası (BagPanel; seç + Sat, sağ tıkla hızlı sat,
## Split ile yığını bölüp bir kısmını sat). Sağ: satın alınabilecek eşyalar ve "Değerlileri Sat".
## Fiyatlar eşya bilgi kutusunda yazar. Pencere açıkken oyun duraklar.

signal closed

var bag: BagPanel
var tooltip: ItemTooltip
var _buy_list: VBoxContainer
var _sell_button: Button
var _sell_all: Button


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	theme_type_variation = &"WindowPanel"
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	add_child(root)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_SHOP"
	root.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	root.add_child(columns)

	tooltip = ItemTooltip.new()
	bag = BagPanel.new()
	bag.tooltip = tooltip
	bag.show_prices = true
	columns.add_child(bag)
	_sell_button = Button.new()
	_sell_button.text = "UI_SELL"
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.pressed.connect(func() -> void: _sell(bag.selected))
	bag.actions.add_child(_sell_button)
	bag.actions.move_child(_sell_button, 0)
	bag.quick_action.connect(_sell)
	bag.selection_changed.connect(_refresh.unbind(1))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.custom_minimum_size = Vector2(190, 0)
	columns.add_child(right)
	var buy_title := Label.new()
	buy_title.text = "UI_SHOP_BUY"
	right.add_child(buy_title)
	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 2)
	_buy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_buy_list)
	_sell_all = Button.new()
	_sell_all.text = "UI_SELL_ALL"
	_sell_all.pressed.connect(_sell_everything)
	right.add_child(_sell_all)
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.icon = load("res://addons/pixel_ui_fantasy/icons/cross.png")
	close_button.pressed.connect(close)
	right.add_child(close_button)
	add_child(tooltip)

	GameState.inventory_changed.connect(_refresh)
	GameState.gold_changed.connect(_refresh.unbind(1))
	hide()


func open() -> void:
	bag.select(-1)
	_refresh()
	show()
	get_tree().paused = true
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func close() -> void:
	bag.return_held()
	tooltip.hide()
	hide()
	get_tree().paused = false
	closed.emit()


## Geri tuşu: önce split penceresi kapanır, sonra dükkân.
func go_back() -> void:
	if bag.is_split_open():
		bag.close_split()
	else:
		close()


## Çantadaki yuvayı (tamamını) satar.
func _sell(index: int) -> void:
	if index < 0 or GameState.bag[index] == null:
		return
	var earned := GameState.sell_slot(index)
	if earned > 0:
		GameState.message.emit(tr("MSG_SOLD") % earned, GameState.GOLD_COLOR)
	else:
		GameState.message.emit(tr("UI_CANNOT_SELL"), Color(1, 0.6, 0.4))


func _refresh() -> void:
	if _buy_list == null:
		return
	for child in _buy_list.get_children():
		child.queue_free()
	_buy_list.add_child(_row(load(GameState.HEALTH_POTION_ICON), tr("ITEM_HEALTH_POTION"), GameState.HEALTH_POTION_PRICE,
		GameState.gold >= GameState.HEALTH_POTION_PRICE, GameState.buy_health_potion))
	_buy_list.add_child(_row(load(GameState.MANA_POTION_ICON), tr("ITEM_MANA_POTION"), GameState.MANA_POTION_PRICE,
		GameState.gold >= GameState.MANA_POTION_PRICE, GameState.buy_mana_potion))
	var stack := bag.get_selected_stack()
	_sell_button.disabled = stack == null or stack.unit_value() <= 0
	_sell_all.disabled = not _has_valuables()


func _row(icon: Texture2D, item_name: String, price: int, enabled: bool, action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(20, 20)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(20, 20)
	holder.add_child(art)
	IconFit.place(art, icon, Rect2(0, 0, 20, 20))
	row.add_child(holder)
	var name_label := Label.new()
	name_label.text = item_name
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var price_label := Label.new()
	price_label.text = tr("UI_PRICE") % price
	price_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	row.add_child(price_label)
	var button := Button.new()
	button.text = "UI_BUY"
	button.disabled = not enabled
	button.custom_minimum_size = Vector2(40, 0)
	button.pressed.connect(func() -> void: action.call())
	row.add_child(button)
	return row


func _has_valuables() -> bool:
	for stack in GameState.bag:
		if stack and stack.item and stack.item.type == ItemData.Type.VALUABLE:
			return true
	return false


# Yalnızca değerli eşyaları satar; ekipman (yedek silah, zırh) tek tek satılır, yanlışlıkla gitmesin
func _sell_everything() -> void:
	var total := 0
	for i in GameState.bag.size():
		var stack := GameState.bag[i]
		if stack and stack.item and stack.item.type == ItemData.Type.VALUABLE:
			total += GameState.sell_slot(i)
	if total > 0:
		GameState.message.emit(tr("MSG_SOLD") % total, GameState.GOLD_COLOR)
