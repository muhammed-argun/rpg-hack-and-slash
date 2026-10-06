class_name CraftingWindow
extends PanelContainer
## Simya penceresi (Şifacı Mira). Tarifler data/recipes.json'dan okunur; yalnızca açılmış
## (koşulu sağlanan) tarifler gösterilir. Pencere açıkken oyun duraklar.

signal closed

const DATA_PATH := "res://data/recipes.json"

var recipes: Dictionary = {}
var _list: VBoxContainer


func _ready() -> void:
	# Gamepad ile açılınca ilk butonu odaklansın (Controls.focus_top_menu)
	add_to_group("menus")
	theme_type_variation = &"WindowPanel"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	recipes = parsed if parsed is Dictionary else {}
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "UI_ALCHEMY"
	box.add_child(title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	box.add_child(_list)
	box.add_child(HSeparator.new())
	var close_button := Button.new()
	close_button.text = "UI_CLOSE"
	close_button.icon = load("res://addons/pixel_ui_fantasy/icons/cross.png")
	close_button.pressed.connect(close)
	box.add_child(close_button)
	GameState.inventory_changed.connect(_refresh)
	GameState.gold_changed.connect(_refresh.unbind(1))
	hide()


func open() -> void:
	_refresh()
	show()
	# İçeriğe göre küçül ve ortala (satırlar bir sonraki karede yerleşir)
	await get_tree().process_frame
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	get_tree().paused = true


func close() -> void:
	hide()
	get_tree().paused = false
	closed.emit()


## Tarifi uygular: malzeme ve altın yeterliyse harcar, ürünü verir.
func craft(recipe_id: String) -> bool:
	var recipe: Dictionary = recipes.get(recipe_id, {})
	var cost: Dictionary = recipe.get("cost", {})
	var gold_cost: int = int(recipe.get("gold", 0))
	var gives: Dictionary = recipe.get("gives", {})
	# Ürün çantaya sığmıyorsa malzeme harcanmasın
	for key: String in ["health_potions", "mana_potions"]:
		if gives.has(key) and not GameState.bag_has_room_for(BagStack.of_id(key.trim_suffix("s"), 1)):
			GameState.message.emit(tr("MSG_BAG_FULL"), Color(1, 0.5, 0.4))
			return false
	if GameState.gold < gold_cost or not GameState.spend_materials(cost):
		GameState.message.emit(tr("MSG_NOT_ENOUGH"), Color(1, 0.5, 0.4))
		return false
	if gold_cost > 0:
		GameState.gold -= gold_cost
		GameState.gold_changed.emit(GameState.gold)
	if gives.has("health_potions"):
		GameState.add_health_potions(int(gives["health_potions"]), false)
	if gives.has("mana_potions"):
		GameState.add_mana_potions(int(gives["mana_potions"]), false)
	Audio.play_sfx("craft")
	GameState.message.emit(tr("MSG_CRAFTED") % tr(recipe.get("name", recipe_id)), GameState.HEAL_COLOR)
	Quests.notify("craft", recipe_id)
	return true


func _refresh() -> void:
	if _list == null:
		return
	for child in _list.get_children():
		child.queue_free()
	for recipe_id: String in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		if not GameConditions.evaluate(recipe.get("requires")):
			continue
		_list.add_child(_make_row(recipe_id, recipe))


func _make_row(recipe_id: String, recipe: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var slot := PanelContainer.new()
	slot.theme_type_variation = &"InsetPanel"
	slot.custom_minimum_size = Vector2(42, 42)
	var icon := TextureRect.new()
	icon.texture = load(recipe.get("icon", ""))
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	slot.add_child(icon)
	row.add_child(slot)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = tr(recipe.get("name", recipe_id))
	info.add_child(name_label)
	var parts: Array[String] = []
	var can_craft := true
	var cost: Dictionary = recipe.get("cost", {})
	for material_id: String in cost:
		var have := GameState.get_material(material_id)
		var need := int(cost[material_id])
		can_craft = can_craft and have >= need
		parts.append("%d/%d %s" % [have, need, tr(GameState.MATERIALS[material_id][0])])
	var gold_cost := int(recipe.get("gold", 0))
	if gold_cost > 0:
		can_craft = can_craft and GameState.gold >= gold_cost
		parts.append(tr("MSG_GOLD").trim_prefix("+") % gold_cost)
	var cost_label := Label.new()
	cost_label.text = ", ".join(parts)
	cost_label.modulate = Color(1, 1, 1, 0.85)
	info.add_child(cost_label)
	row.add_child(info)
	var button := Button.new()
	button.text = "UI_CRAFT"
	button.disabled = not can_craft
	button.custom_minimum_size = Vector2(56, 0)
	button.pressed.connect(func() -> void:
		craft(recipe_id))
	row.add_child(button)
	return row
