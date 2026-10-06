class_name TutorialHints
extends PanelContainer
## İlk oyunda sırayla gösterilen öğretici ipuçları. Her ipucu, oyuncu o hareketi bir kez
## yapınca kaybolur ve "tutorial_<id>" bayrağıyla kaydedilir (bir daha gösterilmez).
## Metinlerdeki {aksiyon} yer tutucuları o aksiyonun güncel tuşuyla doldurulur (ör. {interact} → F).

# [id, metin anahtarı, gösterilme koşulu]
const HINTS := [
	["move", "HINT_MOVE", "always"],
	["talk", "HINT_TALK", "arrival_active"],
	["attack", "HINT_ATTACK", "outside_town"],
	["block", "HINT_BLOCK", "outside_town"],
	["dodge", "HINT_DODGE", "outside_town"],
	["skill", "HINT_SKILL", "outside_town"],
]

var _label: Label
var _current := ""
var _current_key := ""
var _start_position := Vector2.INF
var _check_timer := 0.0


func _ready() -> void:
	theme_type_variation = &"ParchmentPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.theme_type_variation = &"Ink"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(220, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(_label)
	Settings.changed.connect(_refresh_text)
	Controls.device_changed.connect(_refresh_text.unbind(1))
	Controls.bindings_changed.connect(_refresh_text)
	Dialogue.dialogue_finished.connect(func(_npc: String, _dialogue: String) -> void: _complete("talk"))
	hide()


func _process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.2
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or not player.is_inside_tree() or get_tree().paused:
		return
	if _current.is_empty():
		_pick_next()
		return
	# Tamamlanma koşulları
	match _current:
		"move":
			if _start_position == Vector2.INF:
				_start_position = player.global_position
			elif player.global_position.distance_to(_start_position) > 48.0:
				_complete("move")
		"attack":
			if player.state == Player.State.ATTACK:
				_complete("attack")
		"block":
			if player.state == Player.State.BLOCK:
				_complete("block")
		"dodge":
			if player.state == Player.State.DODGE:
				_complete("dodge")
		"skill":
			if player.state == Player.State.SKILL:
				_complete("skill")


func _pick_next() -> void:
	for hint: Array in HINTS:
		var id: String = hint[0]
		if GameState.has_flag("tutorial_" + id):
			continue
		if not _condition_met(hint[2]):
			return
		_show(id, hint[1])
		return


func _condition_met(condition: String) -> bool:
	match condition:
		"arrival_active":
			return Quests.get_state("q_main_arrival") == Quests.State.ACTIVE
		"outside_town":
			return Map.current != null and Map.current.map_id != "town"
	return true


func _show(id: String, key: String) -> void:
	_current = id
	_current_key = key
	_start_position = Vector2.INF
	_refresh_text()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	# İçeriğe göre boyutlan, ekranın alt ortasına yerleş
	reset_size()
	await get_tree().process_frame
	reset_size()
	position = Vector2((get_viewport_rect().size.x - size.x) / 2.0, get_viewport_rect().size.y - size.y - 46.0)


func _refresh_text() -> void:
	if not _current_key.is_empty():
		# Gamepad ile oynanıyorsa varsa gamepad'e özel metin (<ANAHTAR>_PAD)
		var key := _current_key
		if Controls.using_gamepad and tr(key + "_PAD") != key + "_PAD":
			key += "_PAD"
		_label.text = Controls.format_action_keys(tr(key))


func _complete(id: String) -> void:
	if GameState.has_flag("tutorial_" + id):
		return
	GameState.set_flag("tutorial_" + id)
	if _current != id:
		return
	_current = ""
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(hide)
	# Bir sonraki ipucu biraz beklesin
	_check_timer = 2.0
