class_name Hotbar
extends HBoxContainer
## Ekranın alt ortasındaki çubuk: 3 yetenek yuvası (E/R/T) ve 2 hızlı kullanım yuvası (1/2).
## Her yuvanın üstünde atanmış tuş yazar (ayarlardan değişince ve gamepad'e geçince güncellenir).
## Yetenek yuvasında mana bedeli ve bekleme süresi, hızlı kullanım yuvasında eşya adedi görünür.

const GAP := 10

var skill_slots: Array[HotbarSlot] = []
var quick_slots: Array[HotbarSlot] = []
var _key_labels := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 5)
	for i in GameState.SKILL_SLOT_COUNT:
		skill_slots.append(_add_slot("skill_%d" % (i + 1)))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(GAP, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gap)
	for i in GameState.QUICK_SLOT_COUNT:
		quick_slots.append(_add_slot("quick_slot_%d" % (i + 1)))
	GameState.hotbar_changed.connect(refresh)
	GameState.health_potions_changed.connect(refresh.unbind(1))
	GameState.mana_potions_changed.connect(refresh.unbind(1))
	GameState.skill_cooldown_started.connect(_on_skill_cooldown_started)
	Controls.device_changed.connect(_refresh_keys.unbind(1))
	Controls.bindings_changed.connect(_refresh_keys)
	Settings.changed.connect(_refresh_keys)
	refresh()
	_refresh_keys()
	# Ekranın alt ortasına yerleş
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 3)


func _process(_delta: float) -> void:
	# Mana yetmeyen ya da bekleyen yetenek soluk görünsün
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	for i in skill_slots.size():
		var id: String = GameState.skill_slots[i]
		if not id.is_empty():
			skill_slots[i].set_dimmed(GameState.mana < player.get_skill_mana_cost(id))


func refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	for i in skill_slots.size():
		var id: String = GameState.skill_slots[i]
		var slot := skill_slots[i]
		slot.set_icon(GameState.skill_icon(id))
		var cost := player.get_skill_mana_cost(id) if player and not id.is_empty() else 0
		slot.set_count(str(cost) if cost > 0 else "", GameState.MANA_COLOR)
		if player and not id.is_empty():
			# Yuva değişince bekleme süresi kaldığı yerden görünsün
			slot.start_cooldown(player.get_skill_cooldown_duration(id), player.get_skill_cooldown(id))
	for i in quick_slots.size():
		var id: String = GameState.quick_slots[i]
		var slot := quick_slots[i]
		slot.set_icon(GameState.consumable_icon(id))
		var count := GameState.consumable_count(id)
		slot.set_count(str(count) if not id.is_empty() else "")
		slot.set_dimmed(count == 0)


func _add_slot(action: String) -> HotbarSlot:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", -1)
	add_child(column)
	var key := Label.new()
	key.theme_type_variation = &"HudLabel"
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(key)
	_key_labels[action] = key
	var slot := HotbarSlot.new()
	column.add_child(slot)
	return slot


func _refresh_keys() -> void:
	for action: String in _key_labels:
		(_key_labels[action] as Label).text = Controls.get_action_label(action, true)


func _on_skill_cooldown_started(skill_id: String, duration: float) -> void:
	var index := GameState.skill_slots.find(skill_id)
	if index >= 0:
		skill_slots[index].start_cooldown(duration)
