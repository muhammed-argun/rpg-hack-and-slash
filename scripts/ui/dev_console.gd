class_name DevConsole
extends Control
## Geliştirici konsolu penceresi. Yalnızca dev modu açıkken (komut çubuğuna "zort") TOGGLE_KEY ile açılır.
## Sekmeler: ışınlanma (harita giriş noktaları), god mode, düşman/boss çağırma, çantaya eşya ekleme.
## Açıkken oyun duraklar, Esc kapatır. Oyuncuya görünmeyen bir geliştirici aracı olduğu için
## metinler çeviri anahtarı değildir (bkz. decisions.md).

signal closed

## Konsolu açan tuş: oyunda hiçbir işlevi olmayan, ayarlarda görünmeyen bir tuş (Controls'a aksiyon eklenmedi)
const TOGGLE_KEY := KEY_F9
const MAPS := [
	"res://scenes/maps/prologue.tscn",
	"res://scenes/maps/town.tscn",
	"res://scenes/maps/wild.tscn",
	"res://scenes/maps/ashwood_den.tscn",
]
const ENEMIES := [
	["Goblin", "res://scenes/enemies/goblin.tscn"],
	["Orc", "res://scenes/enemies/orc.tscn"],
	["Demon", "res://scenes/enemies/demon.tscn"],
	["Blood Monster", "res://scenes/enemies/blood_monster.tscn"],
]
## Boss'lar da çağrılabilir; ölünce gerçek boss gibi ilerleme (kristal parçası, bayrak) verir
const BOSSES := ["fenris", "morvane", "asterion", "gozcu", "bjorn", "velzara", "surtr", "corvin", "azgoroth", "aldric", "malphas"]
## Çağrılan düşmanların oyuncunun çevresindeki halka yarıçapı
const SPAWN_RADIUS := 56.0

var _tabs: TabContainer
var _status: Label
var _god_check: CheckButton
var _teleport_list: ItemList
var _teleport_targets: Array[Array] = []
var _spawn_list: ItemList
var _spawn_paths: Array[String] = []
var _spawn_count: SpinBox
var _item_list: ItemList
var _item_entries: Array[Dictionary] = []
var _item_rarity: OptionButton
var _item_count: SpinBox
var _built := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("menus")
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	hide()


func open() -> void:
	if not _built:
		_build()
	_god_check.set_pressed_no_signal(GameState.god_mode)
	_status.text = "Esc: close"
	show()
	get_tree().paused = true
	_tabs.current_tab = 0
	_panel_center()


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = false
	closed.emit()


## Geri tuşu (Esc): konsolu kapatır
func go_back() -> void:
	close()


func _panel_center() -> void:
	# Panel boyutu içeriğe göre; ekranın ortasına elle yerleştirilir (PRESET_MODE_MINSIZE
	# custom_minimum_size'ı hesaba katmadığı için panel kayıyordu)
	var panel := get_node("Panel") as Control
	panel.reset_size()
	panel.position = ((size - panel.size) / 2.0).round()


# --- Arayüz ------------------------------------------------------------------------

func _build() -> void:
	_built = true
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.theme_type_variation = &"WindowPanel"
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	var title := Label.new()
	title.theme_type_variation = &"Title"
	title.text = "DEV CONSOLE"
	box.add_child(title)
	_tabs = TabContainer.new()
	box.add_child(_tabs)
	_build_teleport_tab()
	_build_god_tab()
	_build_spawn_tab()
	_build_items_tab()
	_status = Label.new()
	_status.theme_type_variation = &"HudLabel"
	box.add_child(_status)


func _new_page(tab_name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = tab_name
	page.add_theme_constant_override("separation", 3)
	_tabs.add_child(page)
	return page


func _new_list(page: Control) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 110)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.select_mode = ItemList.SELECT_SINGLE
	page.add_child(list)
	return list


func _new_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	return button


func _new_count(max_count: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = max_count
	spin.value = 1
	return spin


func _build_teleport_tab() -> void:
	var page := _new_page("Teleport")
	_teleport_list = _new_list(page)
	# Haritaların Spawns altındaki giriş noktaları (sahne dosyasından okunur)
	for path: String in MAPS:
		var state := (load(path) as PackedScene).get_state()
		for i in state.get_node_count():
			# Düğümün ebeveyn yolu "./Spawns" ise bir giriş noktasıdır
			if str(state.get_node_path(i, true)) == "./Spawns":
				var spawn_name := str(state.get_node_name(i))
				_teleport_targets.append([path, spawn_name])
				_teleport_list.add_item("%s : %s" % [path.get_file().get_basename(), spawn_name])
	_teleport_list.item_activated.connect(_teleport.unbind(1))
	page.add_child(_new_button("Teleport", _teleport))


func _build_god_tab() -> void:
	var page := _new_page("God")
	_god_check = CheckButton.new()
	_god_check.text = "God mode (no damage)"
	_god_check.toggled.connect(_on_god_toggled)
	page.add_child(_god_check)
	page.add_child(_new_button("Restore HP / MP / Stamina", _restore_resources))


func _build_spawn_tab() -> void:
	var page := _new_page("Spawn")
	_spawn_list = _new_list(page)
	for entry: Array in ENEMIES:
		_spawn_paths.append(entry[1])
		_spawn_list.add_item(entry[0])
	for boss_id: String in BOSSES:
		_spawn_paths.append("res://scenes/bosses/%s.tscn" % boss_id)
		_spawn_list.add_item("BOSS: %s (gives progress)" % boss_id)
	_spawn_list.item_activated.connect(_spawn_selected.unbind(1))
	var row := HBoxContainer.new()
	_spawn_count = _new_count(20)
	row.add_child(_spawn_count)
	row.add_child(_new_button("Spawn", _spawn_selected))
	page.add_child(row)


func _build_items_tab() -> void:
	var page := _new_page("Items")
	_item_list = _new_list(page)
	_item_entries.append({"label": tr("ITEM_HEALTH_POTION"), "kind": "health_potion"})
	_item_entries.append({"label": tr("ITEM_MANA_POTION"), "kind": "mana_potion"})
	for id: String in GameState.MATERIALS:
		_item_entries.append({"label": tr(GameState.MATERIALS[id][0]), "kind": "material", "id": id})
	for valuable: Array in ItemData.VALUABLES:
		_item_entries.append({"label": tr(valuable[0]), "kind": "valuable", "name_key": valuable[0], "icon": valuable[1]})
	for weapon: Array in ItemData.WEAPONS:
		_item_entries.append({"label": tr(weapon[0]), "kind": "gear", "type": ItemData.Type.WEAPON, "name_key": weapon[0], "two_handed": weapon[1], "ranged": weapon[2]})
	for type: ItemData.Type in ItemData.GEAR_KEYS:
		for name_key: String in ItemData.GEAR_KEYS[type]:
			_item_entries.append({"label": tr(name_key), "kind": "gear", "type": type, "name_key": name_key})
	for type: ItemData.Type in ItemData.JEWELRY_KEYS:
		for name_key: String in ItemData.JEWELRY_KEYS[type]:
			_item_entries.append({"label": tr(name_key), "kind": "gear", "type": type, "name_key": name_key})
	for name_key: String in ItemData.AMMO_KEYS:
		_item_entries.append({"label": tr(name_key), "kind": "gear", "type": ItemData.Type.AMMO, "name_key": name_key})
	for entry in _item_entries:
		_item_list.add_item(entry["label"])
	_item_list.item_activated.connect(_add_selected_item.unbind(1))
	var row := HBoxContainer.new()
	_item_rarity = OptionButton.new()
	for key: String in ItemData.RARITY_KEYS:
		_item_rarity.add_item(tr(key))
	row.add_child(_item_rarity)
	_item_count = _new_count(99)
	row.add_child(_item_count)
	row.add_child(_new_button("Add to bag", _add_selected_item))
	page.add_child(row)


# --- Eylemler ----------------------------------------------------------------------

func _teleport() -> void:
	var selected := _teleport_list.get_selected_items()
	if selected.is_empty():
		_status.text = "Select a destination"
		return
	var target: Array = _teleport_targets[selected[0]]
	close()
	# Main bu isteği dinler ve haritayı değiştirir (oyuncu yeni haritaya taşınır)
	GameState.map_change_requested.emit(target[0], target[1])


func _on_god_toggled(enabled: bool) -> void:
	GameState.god_mode = enabled
	_status.text = "God mode %s" % ("ON" if enabled else "OFF")


func _restore_resources() -> void:
	if GameState.hp <= 0:
		return
	GameState.hp = GameState.max_hp
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)
	GameState.mana = GameState.max_mana
	GameState.mana_changed.emit(int(GameState.mana), GameState.max_mana)
	GameState.stamina = GameState.max_stamina
	GameState.stamina_changed.emit(int(GameState.stamina), GameState.max_stamina)
	_status.text = "Restored"


func _spawn_selected() -> void:
	var selected := _spawn_list.get_selected_items()
	if selected.is_empty():
		_status.text = "Select an enemy"
		return
	var spawned := spawn_enemies(_spawn_paths[selected[0]], int(_spawn_count.value))
	_status.text = "Spawned %d x %s" % [spawned, _spawn_list.get_item_text(selected[0])]


## Düşman sahnesinden count adet oyuncunun çevresinde (halka üzerinde) doğurur; doğan sayıyı döndürür.
## Boss'lar hemen uyanır (arena tetiği olmadan).
func spawn_enemies(scene_path: String, count: int) -> int:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.is_inside_tree() or not ResourceLoader.exists(scene_path):
		return 0
	var scene := load(scene_path) as PackedScene
	var parent := player.get_parent()
	var spawned := 0
	for i in count:
		var enemy := scene.instantiate() as Node2D
		var angle := TAU * i / maxi(count, 1) + randf() * 0.5
		var offset := Vector2.from_angle(angle) * (SPAWN_RADIUS + 6.0 * (i / 8))
		# Konum eklemeden önce verilir: düşmanın "ev" noktası doğduğu yer olsun
		enemy.position = parent.to_local(player.global_position + offset)
		parent.add_child(enemy)
		if enemy is Boss:
			(enemy as Boss).activate()
		elif enemy is Enemy:
			# Hemen saldırsın
			(enemy as Enemy).detect_radius = 400.0
		spawned += 1
	return spawned


func _add_selected_item() -> void:
	var selected := _item_list.get_selected_items()
	if selected.is_empty():
		_status.text = "Select an item"
		return
	var entry := _item_entries[selected[0]]
	var added := add_to_bag(entry, int(_item_count.value), _item_rarity.selected as ItemData.Rarity)
	_status.text = "Added %d x %s" % [added, entry["label"]]


## Havuz girdisinden count adet çantaya ekler (eşyalar çantaya girer, otomatik kuşanılmaz); eklenen adedi döndürür.
## rarity yalnızca ekipman ve değerli eşyalarda anlamlıdır.
func add_to_bag(entry: Dictionary, count: int, rarity: ItemData.Rarity = ItemData.Rarity.COMMON) -> int:
	match entry["kind"]:
		"health_potion":
			return GameState.add_health_potions(count)
		"mana_potion":
			return GameState.add_mana_potions(count)
		"material":
			return GameState.add_material(entry["id"], count)
		"valuable":
			var valuable := _make_item(entry, rarity)
			var left := GameState.add_to_bag(BagStack.of_item(valuable, count))
			return count - left
		"gear":
			# Ekipman yığılmaz: her biri ayrı yuvaya, ayrı eşya olarak
			var added := 0
			for i in count:
				if GameState.add_to_bag(BagStack.of_item(_make_item(entry, rarity))) > 0:
					break
				added += 1
			return added
	return 0


# Seviyeye ve nadirliğe göre ItemData.create_random ile aynı ölçekte bir eşya üretir
func _make_item(entry: Dictionary, rarity: ItemData.Rarity) -> ItemData:
	var item := ItemData.new()
	item.name_key = entry["name_key"]
	item.rarity = rarity
	item.type = entry.get("type", ItemData.Type.VALUABLE)
	item.two_handed = entry.get("two_handed", false)
	item.ranged = entry.get("ranged", false)
	item.icon_path = entry.get("icon", ItemData.BOW_ICON if item.ranged else "")
	var power: float = GameState.level * ItemData.RARITY_MULTIPLIERS[rarity]
	match item.type:
		ItemData.Type.WEAPON:
			item.damage_bonus = roundi(3.5 * power * (1.5 if item.two_handed else 1.0))
		ItemData.Type.RING, ItemData.Type.AMULET, ItemData.Type.AMMO:
			item.damage_bonus = roundi(1.5 * power)
		ItemData.Type.VALUABLE:
			pass
		_:
			var big := item.type == ItemData.Type.ARMOR or item.type == ItemData.Type.OFFHAND
			item.defense_bonus = roundi(2.0 * power * (1.0 if big else 0.5))
	item.value = roundi(11.0 * power * (2.0 if item.type == ItemData.Type.VALUABLE else 1.0))
	return item
