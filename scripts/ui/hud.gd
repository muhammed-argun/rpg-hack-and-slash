extends CanvasLayer
## Oyun arayüzü: can/mana/stamina barları (Pixel Bars), görev takibi, boss barı, altın kesesi,
## menü butonları, etkileşim ipucu, olay mesajları, harita adı ve pencereler (envanter, simya,
## diyalog, duraklatma). Bir pencere açıkken oyun duraklar.
## Dokunmatik kontroller (TouchJoystick, ActionButton) PC sürümünde kullanılmıyor; mobil port için saklanıyor.

signal save_requested

const MESSAGE_LIFETIME := 2.5
const MAX_MESSAGES := 4
const HELD_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "interact", "skill_1", "skill_2", "skill_3", "block", "dodge"]
## Etkileşim ipucunun nesnenin kökünden yukarı uzaklığı (NPC adı ve görev işaretinin üstü)
const PROMPT_OFFSET_Y := -76.0

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
@onready var purse: PanelContainer = %Purse
@onready var messages: VBoxContainer = %Messages
@onready var map_name: Label = %MapName
@onready var interact_prompt: Label = %InteractPrompt
@onready var pause_button: Button = %PauseButton
@onready var bag_button: Button = %BagButton
@onready var quest_button: Button = %QuestButton
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
var _windows_open := false
var _prompt_target: Interactable
var _hotbar: Hotbar
var _quests: QuestWindow
var _dev_prompt: DevPrompt
var _dev_console: DevConsole


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.mana_changed.connect(_on_mana_changed)
	GameState.stamina_changed.connect(_on_stamina_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.message.connect(_on_message)
	GameState.boss_started.connect(_on_boss_started)
	GameState.boss_ended.connect(_on_boss_ended)
	GameState.player_died.connect(_on_player_died_hide_boss_bar)
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.level_up.connect(_on_level_up)
	Quests.tracked_changed.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_updated.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_ready.connect(_refresh_quest_tracker.unbind(1))
	Quests.quest_completed.connect(_refresh_quest_tracker.unbind(1))
	Settings.changed.connect(_refresh_quest_tracker)
	Settings.changed.connect(_refresh_interact_prompt)
	Controls.device_changed.connect(_refresh_interact_prompt.unbind(1))
	Controls.bindings_changed.connect(_refresh_interact_prompt)
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
	bag_button.pressed.connect(_toggle_inventory)
	pause_button.pressed.connect(open_pause_menu)
	GameState.flag_changed.connect(_on_flag_changed)
	_ending = EndingScreen.new()
	$Root.add_child(_ending)
	_story = StoryCard.new()
	$Root.add_child(_story)
	_story.finished.connect(_on_window_closed)
	_quests = QuestWindow.new()
	$Root.add_child(_quests)
	$Root.move_child(_quests, inventory.get_index() + 1)
	_quests.closed.connect(_on_window_closed)
	# Geliştirici araçları (komut çubuğu + konsol); pencereler gibi duraklatır
	_dev_prompt = DevPrompt.new()
	$Root.add_child(_dev_prompt)
	_dev_prompt.closed.connect(_on_window_closed)
	_dev_console = DevConsole.new()
	$Root.add_child(_dev_console)
	_dev_console.closed.connect(_on_window_closed)
	_hotbar = Hotbar.new()
	$Root.add_child(_hotbar)
	$Root.move_child(_hotbar, interact_prompt.get_index())
	var hints := TutorialHints.new()
	$Root.add_child(hints)
	$Root.move_child(hints, interact_prompt.get_index())
	_on_hp_changed(GameState.hp, GameState.max_hp)
	_on_mana_changed(int(GameState.mana), GameState.max_mana)
	_on_stamina_changed(int(GameState.stamina), GameState.max_stamina)
	_on_gold_changed(GameState.gold)
	_on_xp_changed(GameState.xp, GameState.xp_to_next(), GameState.level)
	_refresh_quest_tracker()
	for bar: PixelBar in [hp_bar, mp_bar, stamina_bar]:
		bar.settle()
	_fit_purse()


func _process(_delta: float) -> void:
	_connect_player()
	_update_interact_prompt()
	if Controls.capturing:
		return
	if Input.is_action_just_pressed("toggle_inventory") or Input.is_action_just_pressed("toggle_character"):
		_toggle_inventory()
	if Input.is_action_just_pressed("toggle_quests"):
		_toggle_quests()
	# Esc hem "pause" hem "ui_cancel"; gamepad'de Start "pause", B "ui_cancel"
	var pause := Input.is_action_just_pressed("pause")
	var back := Input.is_action_just_pressed("ui_cancel")
	if (pause or back) and not dialogue_box.visible:
		if pause_menu.visible:
			pause_menu.go_back()
		elif back and _close_top_window():
			pass
		elif pause and not _is_busy_except(pause_menu):
			open_pause_menu()


# Altın kesesi duraklat butonuyla aynı yükseklikte olsun (24 px): panelin iç boşluğu küçültülür,
# yoksa kese uzayıp alttaki görev butonunun üstüne biniyor
func _fit_purse() -> void:
	var style := purse.get_theme_stylebox("panel").duplicate() as StyleBox
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 5
	style.content_margin_right = 6
	purse.add_theme_stylebox_override("panel", style)


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


# Geliştirici tuşları: Enter komut çubuğunu açar ("zort" yazılırsa dev modu açılır); dev modu açıkken
# DevConsole.TOGGLE_KEY konsolu açar/kapatır. Yalnızca arayüz tuşu tüketmediyse ve hiçbir pencere
# açık değilken çalışır (Enter menülerde onay tuşu olduğu için çakışmasın).
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or Controls.capturing:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		if open_dev_prompt():
			get_viewport().set_input_as_handled()
	elif key.physical_keycode == DevConsole.TOGGLE_KEY or key.keycode == DevConsole.TOGGLE_KEY:
		if toggle_dev_console():
			get_viewport().set_input_as_handled()


## Komut çubuğunu açar; pencere/diyalog açıksa ya da oyun duraklıysa açmaz. Açıldıysa true.
func open_dev_prompt() -> bool:
	if get_tree().paused or _is_busy_except(null):
		return false
	_on_window_opened()
	_dev_prompt.open()
	return true


## Dev konsolunu açar/kapatır (yalnızca GameState.dev_mode açıkken). İşlem yapıldıysa true.
func toggle_dev_console() -> bool:
	if not GameState.dev_mode:
		return false
	if _dev_console.visible:
		_dev_console.close()
		return true
	if get_tree().paused or _is_busy_except(null):
		return false
	_on_window_opened()
	_dev_console.open()
	return true


func _is_busy_except(window: Control) -> bool:
	for other: Control in [inventory, _quests, crafting, shop, smith, dialogue_box, pause_menu, _dev_prompt, _dev_console]:
		if other != window and other.visible:
			return true
	return false


# Açık olan oyun penceresini kapatır (geri tuşu). Bir pencere kapandıysa true döner.
func _close_top_window() -> bool:
	for window: Control in [smith, shop, crafting, inventory, _quests, _dev_prompt, _dev_console]:
		if window.visible:
			# Envanter ve dükkânda önce split penceresi kapanır
			window.call("go_back" if window.has_method("go_back") else "close")
			return true
	return false


func _toggle_inventory() -> void:
	if _is_busy_except(inventory):
		return
	if inventory.visible:
		inventory.close()
	else:
		_on_window_opened()
		inventory.open()


func _open_quests() -> void:
	if _is_busy_except(null):
		return
	_on_window_opened()
	_quests.open()


func _toggle_quests() -> void:
	if _is_busy_except(_quests):
		return
	if _quests.visible:
		_quests.close()
	else:
		_on_window_opened()
		_quests.open()


func _on_window_requested(window_name: String) -> void:
	var windows := {"crafting": crafting, "shop": shop, "smith": smith}
	if not windows.has(window_name):
		push_warning("HUD: bilinmeyen pencere %s" % window_name)
		return
	# Diyalog kapanırken oyunun duraklaması kalkar; pencere bir sonraki karede açılır
	await get_tree().process_frame
	_on_window_opened()
	windows[window_name].open()


# Bir pencere açılınca: etkileşim ipucunu gizle, basılı kalan aksiyonları bırak
func _on_window_opened() -> void:
	if not _windows_open:
		Audio.play_sfx("ui_open", 0.0)
	_windows_open = true
	for action: String in HELD_ACTIONS:
		Input.action_release(action)


func _on_window_closed() -> void:
	if _is_busy_except(null):
		return
	Audio.play_sfx("ui_close", 0.0)
	_windows_open = false


func _connect_player() -> void:
	if _player_connected:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		player.interactable_changed.connect(_on_interactable_changed)
		_player_connected = true
		_hotbar.refresh()


func _on_interactable_changed(interactable: Interactable) -> void:
	_prompt_target = interactable
	_refresh_interact_prompt()


# İpucu metni: etkileşim tuşu + eylem adı, ör. "[F] Konuş"
func _refresh_interact_prompt() -> void:
	if _prompt_target == null:
		return
	interact_prompt.text = "[%s] %s" % [Controls.get_action_label("interact"), tr(_prompt_target.prompt_key)]
	interact_prompt.reset_size()


# İpucunu etkileşilecek nesnenin üstünde, ekran koordinatlarında tutar
func _update_interact_prompt() -> void:
	var target := _prompt_target
	var show_prompt := is_instance_valid(target) and target.is_inside_tree() and not _windows_open
	interact_prompt.visible = show_prompt
	if not show_prompt:
		return
	var screen_position := target.get_global_transform_with_canvas().origin
	interact_prompt.position = (screen_position + Vector2(-interact_prompt.size.x / 2.0, PROMPT_OFFSET_Y)).round()


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


# Oyuncu ölünce boss barı hemen kalkar. Boss'un durumuna dokunulmaz (oyuncu geri gelip arenaya girince
# harita yeniden yüklenir, boss canı dolu başlar ve boss_started bar'ı yeniden gösterir)
func _on_player_died_hide_boss_bar() -> void:
	if is_instance_valid(_boss) and _boss.health_changed.is_connected(_on_boss_health_changed):
		_boss.health_changed.disconnect(_on_boss_health_changed)
	_boss = null
	quest_tracker.modulate.a = 1.0
	boss_bar.hide()


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
