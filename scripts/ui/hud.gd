extends CanvasLayer
## Oyun arayüzü: can/mana/stamina barları (Pixel Bars), görev takibi, boss barı, altın kesesi,
## aksiyon butonları, olay mesajları, harita adı ve pencereler (envanter, simya, diyalog,
## duraklatma). Bir pencere açıkken oyun duraklar ve dokunmatik kontroller gizlenir.

signal save_requested

const MESSAGE_LIFETIME := 2.5
const MAX_MESSAGES := 4
const HELD_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "skill", "block", "dodge"]

@onready var hp_bar: PixelBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var mp_bar: PixelBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var stamina_bar: PixelBar = %StaminaBar
@onready var level_label: Label = %LevelLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var quest_tracker: Control = %QuestTracker
@onready var quest_title: Label = %QuestTitle
@onready var quest_objective: Label = %QuestObjective
@onready var boss_bar: Control = %BossBar
@onready var boss_health: PixelBar = %BossHealth
@onready var boss_name: Label = %BossName
@onready var gold_label: Label = %GoldLabel
@onready var messages: VBoxContainer = %Messages
@onready var map_name: Label = %MapName
@onready var joystick: TouchJoystick = %TouchJoystick
@onready var action_buttons: Control = %ActionButtons
@onready var interact_prompt: Label = %InteractPrompt
@onready var skill_button: ActionButton = %SkillButton
@onready var health_potion_button: ActionButton = %HealthPotionButton
@onready var mana_potion_button: ActionButton = %ManaPotionButton
@onready var quest_button: ActionButton = %QuestButton
@onready var inventory: InventoryWindow = %InventoryWindow
@onready var crafting: CraftingWindow = %CraftingWindow
@onready var shop: ShopWindow = %ShopWindow
@onready var smith: SmithWindow = %SmithWindow
@onready var dialogue_box: DialogueBox = %DialogueBox
@onready var pause_menu: PauseMenu = %PauseMenu

var _boss: Boss
var _ending: EndingScreen
var _story: StoryCard
var _player_connected := false


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.mana_changed.connect(_on_mana_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.health_potions_changed.connect(_on_health_potions_changed)
	GameState.mana_potions_changed.connect(_on_mana_potions_changed)
	GameState.skill_cooldown_started.connect(skill_button.start_cooldown)
	GameState.message.connect(_on_message)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_ended.connect(_on_boss_ended)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_up.connect(_on_level_up)
	Quests.tracked_changed.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_updated.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_ready.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_completed.connect(_refresh_quest_tracker.unbind(1))
	Settings.changed.connect(_refresh_quest_tracker)
	Dialogue.dialogue_started.connect(_on_window_opened.unbind(3))
	Dialogue.dialogue_finished.connect(_on_window_closed.unbind(2))
	Dialogue.window_requested.connect(_on_window_requested)
	inventory.closed.connect(_on_window_closed)
	crafting.closed.connect(_on_window_closed)
	shop.closed.connect(_on_window_closed)
	smith.closed.connect(_on_window_closed)
	pause_menu.resumed.connect(_on_window_closed)
	pause_menu.save_requested.connect(save_requested.emit)
	quest_button.pressed.connect(_open_quests)
	GameState.flag_changed.connect(_on_flag_changed)
	_ending = EndingScreen.new()
	$Root.add_child(_ending)
	_story = StoryCard.new()
	$Root.add_child(_story)
	_story.finished.connect(_on_window_closed)
	var hints := TutorialHints.new()
	$Root.add_child(hints)
	$Root.move_child(hints, action_buttons.get_index())
	_on_hp_changed(GameState.hp, GameState.max_hp)
	_on_mana_changed(int(GameState.mana), GameState.max_mana)
	_on_stamina_changed(int(GameState.stamina), GameState.max_stamina)
	_on_gold_changed(GameState.gold)
	_on_xp_changed(GameState.xp, GameState.xp_to_next(), GameState.level)
	_on_health_potions_changed(GameState.health_potions)
	_on_mana_potions_changed(GameState.mana_potions)
	_refresh_quest_tracker()
	for bar: PixelBar in [hp_bar, mp_bar, stamina_bar]:
		bar.settle()


func _process(_delta: float) -> void:
	_connect_player()
	_update_skill_button()
	if Input.is_action_just_pressed("toggle_inventory") and not _is_busy_except(inventory):
		if inventory.visible:
			inventory.close()
		else:
			_on_window_opened()
			inventory.open()
	if Input.is_action_just_pressed("pause") and not dialogue_box.visible:
		if pause_menu.visible:
			pause_menu.resume()
		elif not _is_busy_except(pause_menu):
			open_pause_menu()


func open_pause_menu() -> void:
	if pause_menu.visible or dialogue_box.visible:
		return
	_on_window_opened()
	pause_menu.open()


## Haritaya girince adını ekranın ortasında kısa süre gösterir.
func show_map_name(key: String) -> void:
	if key.is_empty():
		return
	# Prologa ilk girişte hikâyenin girişi anlatılır
	if key == "MAP_PROLOGUE" and not GameState.has_flag("intro_seen"):
		GameState.set_flag("intro_seen")
		_on_window_opened()
		_story.play(["INTRO_1", "INTRO_2", "INTRO_3", "INTRO_4"])
	map_name.text = key
	var tween := map_name.create_tween()
	tween.tween_property(map_name, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.8)
	tween.tween_property(map_name, "modulate:a", 0.0, 0.8)


func _is_busy_except(window: Control) -> bool:
	for other: Control in [inventory, crafting, shop, smith, dialogue_box, pause_menu]:
		if other != window and other.visible:
			return true
	return false


func _open_quests() -> void:
	if _is_busy_except(null):
		return
	_on_window_opened()
	inventory.open(InventoryWindow.TAB_QUESTS)


func _on_window_requested(window_name: String) -> void:
	var windows := {"crafting": crafting, "shop": shop, "smith": smith}
	if not windows.has(window_name):
		push_warning("HUD: bilinmeyen pencere %s" % window_name)
		return
	# Diyalog kapanırken oyunun duraklaması kalkar; pencere bir sonraki karede açılır
	await get_tree().process_frame
	_on_window_opened()
	windows[window_name].open()


# Bir pencere açılınca: dokunmatik kontrolleri gizle, basılı kalan aksiyonları bırak
func _on_window_opened() -> void:
	if action_buttons.visible:
		Audio.play_sfx("ui_open", 0.0)
	joystick.hide()
	action_buttons.hide()
	for action: String in HELD_ACTIONS:
		Input.action_release(action)


func _on_window_closed() -> void:
	if _is_busy_except(null):
		return
	Audio.play_sfx("ui_close", 0.0)
	joystick.show()
	action_buttons.show()


func _connect_player() -> void:
	if _player_connected:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.interactable_changed.connect(_on_interactable_changed)
		_player_connected = true


func _on_interactable_changed(interactable: Interactable) -> void:
	interact_prompt.visible = interactable != null
	if interactable:
		interact_prompt.text = interactable.prompt_key


# Yeteneğin mana bedeli ve manası yetmiyorsa soluk görünmesi
func _update_skill_button() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	skill_button.set_count(player.skill_mana_cost)
	skill_button.set_dimmed(GameState.mana < player.skill_mana_cost)


func _refresh_quest_tracker() -> void:
	var id := Quests.tracked
	if id.is_empty() or Quests.get_state(id) == Quests.State.DONE or Quests.get_state(id) == Quests.State.NONE:
		quest_tracker.hide()
		return
	quest_tracker.show()
	quest_title.text = Quests.get_title(id)
	if Quests.get_state(id) == Quests.State.READY:
		quest_objective.text = "» " + tr("UI_QUEST_READY") + ": " + Dialogue.get_npc_name(Quests.get_turn_in_npc(id))
		return
	for i in Quests.get_objective_count(id):
		if not Quests.is_objective_done(id, i):
			quest_objective.text = "» " + Quests.get_objective_text(id, i)
			return
	quest_objective.text = ""


func _on_flag_changed(flag_name: String, _value: Variant) -> void:
	if flag_name != "game_completed":
		return
	save_requested.emit()
	await get_tree().create_timer(3.0).timeout
	_on_window_opened()
	_ending.play()


func _on_boss_started(boss: Node) -> void:
	_boss = boss as Boss
	if _boss == null:
		return
	boss_name.text = "%s, %s" % [_boss.get_display_name(), tr(_boss.title_key)] if not _boss.title_key.is_empty() else _boss.get_display_name()
	boss_health.max_value = _boss.max_hp
	boss_health.value = _boss.hp
	boss_health.settle()
	_boss.health_changed.connect(_on_boss_health_changed)
	boss_bar.show()
	quest_tracker.modulate.a = 0.4


func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_health.max_value = maximum
	boss_health.value = current


func _on_boss_ended(boss: Node) -> void:
	if boss != _boss:
		return
	_boss = null
	quest_tracker.modulate.a = 1.0
	var tween := boss_bar.create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(boss_bar.hide)


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d/%d" % [current, maximum]


func _on_mana_changed(current: int, maximum: int) -> void:
	mp_bar.max_value = maximum
	mp_bar.value = current
	mp_label.text = "%d/%d" % [current, maximum]


func _on_stamina_changed(current: int, maximum: int) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_xp_changed(current: int, needed: int, level: int) -> void:
	level_label.text = tr("UI_LEVEL_SHORT") % level
	xp_bar.max_value = needed
	xp_bar.value = current


func _on_level_up(_level: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		Shockwave.spawn(player.global_position + Vector2(0, -6), 40.0, Color(1.0, 0.9, 0.4))
		FloatingText.spawn(player.get_parent(), player.global_position + Vector2(0, -40), tr("UI_LEVEL_SHORT") % _level, Color(1.0, 0.9, 0.4))


func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)


func _on_health_potions_changed(amount: int) -> void:
	health_potion_button.set_count(amount)
	health_potion_button.set_dimmed(amount == 0)


func _on_mana_potions_changed(amount: int) -> void:
	mana_potion_button.set_count(amount)
	mana_potion_button.set_dimmed(amount == 0)


func _on_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HudLabel"
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(MESSAGE_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
