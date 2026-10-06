extends Node
## Kontroller: varsayılan tuş atamaları, oyuncunun değiştirdiği atamalar (user://settings.cfg,
## [controls] bölümü), tuş adları ve son kullanılan cihaz (klavye/fare ya da gamepad).
## Autoload olarak "Controls" adıyla erişilir.
##
## Input Map buradan kurulur; project.godot'ta aksiyon tanımı yok. Her aksiyonun iki yuvası var:
## "kb" (klavye tuşu ya da fare butonu) ve "pad" (gamepad butonu ya da çubuk/tetik yönü).
## Oyun kodu yalnızca aksiyon adlarını okur (Input.is_action_pressed("attack") gibi).

## Son kullanılan cihaz değişince (klavye/fare <-> gamepad); ipuçları tuş adını yeniler
signal device_changed(using_gamepad: bool)
## Bir atama değişince
signal bindings_changed

const PATH := "user://settings.cfg"
const SECTION := "controls"
const SLOTS := ["kb", "pad"]
const DEADZONE := 0.2
## Gamepad çubuğu/tetiği bu kadar itilince "basıldı" sayılır (atama yaparken ve cihaz algılarken)
const AXIS_PRESS := 0.6

## Ayarlar ekranında gösterilen, değiştirilebilen aksiyonlar (sırasıyla)
const REBINDABLE := [
	"move_up", "move_down", "move_left", "move_right",
	"attack", "block", "dodge", "interact",
	"skill_1", "skill_2", "skill_3",
	"quick_slot_1", "quick_slot_2",
	"swap_weapons", "toggle_inventory", "toggle_character", "toggle_quests", "pause",
	"menu_move", "menu_split",
]

## Varsayılan atamalar: [klavye/fare, gamepad]. Kodlar: "key:<fiziksel tuş>", "mouse:<buton>",
## "joy:<buton>", "axis:<eksen>:<+1/-1>". Gamepad düzeni Xbox / Steam Deck adlarıyla.
## Fiziksel tuş: klavye düzeninden bağımsız konum (ör. Q klavyede WASD'nin yeri hep aynı).
const DEFAULTS := {
	"move_up": ["key:%d" % KEY_W, "axis:%d:-1" % JOY_AXIS_LEFT_Y],
	"move_down": ["key:%d" % KEY_S, "axis:%d:1" % JOY_AXIS_LEFT_Y],
	"move_left": ["key:%d" % KEY_A, "axis:%d:-1" % JOY_AXIS_LEFT_X],
	"move_right": ["key:%d" % KEY_D, "axis:%d:1" % JOY_AXIS_LEFT_X],
	"attack": ["mouse:%d" % MOUSE_BUTTON_LEFT, "joy:%d" % JOY_BUTTON_X],
	"block": ["mouse:%d" % MOUSE_BUTTON_RIGHT, "axis:%d:1" % JOY_AXIS_TRIGGER_LEFT],
	"dodge": ["key:%d" % KEY_SPACE, "joy:%d" % JOY_BUTTON_A],
	"interact": ["key:%d" % KEY_F, "joy:%d" % JOY_BUTTON_Y],
	"skill_1": ["key:%d" % KEY_E, "joy:%d" % JOY_BUTTON_RIGHT_SHOULDER],
	"skill_2": ["key:%d" % KEY_R, "axis:%d:1" % JOY_AXIS_TRIGGER_RIGHT],
	"skill_3": ["key:%d" % KEY_T, "joy:%d" % JOY_BUTTON_B],
	"quick_slot_1": ["key:%d" % KEY_1, "joy:%d" % JOY_BUTTON_DPAD_LEFT],
	"quick_slot_2": ["key:%d" % KEY_2, "joy:%d" % JOY_BUTTON_DPAD_RIGHT],
	"toggle_inventory": ["key:%d" % KEY_I, "joy:%d" % JOY_BUTTON_BACK],
	"toggle_character": ["key:%d" % KEY_C, "joy:%d" % JOY_BUTTON_DPAD_UP],
	"toggle_quests": ["key:%d" % KEY_J, "joy:%d" % JOY_BUTTON_DPAD_DOWN],
	"swap_weapons": ["key:%d" % KEY_Q, "joy:%d" % JOY_BUTTON_LEFT_SHOULDER],
	"pause": ["key:%d" % KEY_ESCAPE, "joy:%d" % JOY_BUTTON_START],
	# Çanta menüsü (envanter / dükkân): yalnızca pencere açıkken anlamlı; oyun içi aksiyonlarla aynı
	# tuşu paylaşabilir çünkü pencere açıkken oyun duraklıyor
	"menu_move": ["key:%d" % KEY_X, "joy:%d" % JOY_BUTTON_X],
	"menu_split": ["key:%d" % KEY_V, "joy:%d" % JOY_BUTTON_Y],
	# Nişan (sağ çubuk); ayarlarda gösterilmez
	"aim_up": ["", "axis:%d:-1" % JOY_AXIS_RIGHT_Y],
	"aim_down": ["", "axis:%d:1" % JOY_AXIS_RIGHT_Y],
	"aim_left": ["", "axis:%d:-1" % JOY_AXIS_RIGHT_X],
	"aim_right": ["", "axis:%d:1" % JOY_AXIS_RIGHT_X],
}

## Özel imleç (Pixel UI Fantasy). İmleç ekran ölçeğiyle büyümediği için pencere ölçeğine uygun kopya seçilir.
const CURSORS := [
	"res://addons/pixel_ui_fantasy/cursor.png",
	"res://addons/pixel_ui_fantasy/cursor_2x.png",
	"res://addons/pixel_ui_fantasy/cursor_3x.png",
	"res://addons/pixel_ui_fantasy/cursor_4x.png",
]

const PAD_BUTTON_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_START: "Start", JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "PAD_DPAD_UP", JOY_BUTTON_DPAD_DOWN: "PAD_DPAD_DOWN",
	JOY_BUTTON_DPAD_LEFT: "PAD_DPAD_LEFT", JOY_BUTTON_DPAD_RIGHT: "PAD_DPAD_RIGHT",
}

## Testler kendi dosyalarını kullanır (oyuncunun ayarlarına dokunmasınlar)
var config_path := PATH
## Oyuncunun atamaları: aksiyon -> [kb kodu, pad kodu]
var bindings := {}
## Son girdi gamepad'den mi geldi
var using_gamepad := false
## Tuş atama ekranı yeni tuş beklerken true. Bu sırada basılan tuşlar oyunda aksiyon sayılmamalı
## (ör. Esc duraklatma menüsünü kapatmasın); HUD bunu kontrol eder.
var capturing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bindings = _copy_defaults()
	load_bindings()
	apply()
	get_tree().root.size_changed.connect(_update_cursor)
	_update_cursor()


func _exit_tree() -> void:
	# Oyun kapanırken imleç dokusunu bırak (yoksa çıkışta sızıntı uyarısı verir)
	Input.set_custom_mouse_cursor(null)


func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > AXIS_PRESS)
	var desktop: bool = event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length() > 2.0)
	if pad and not using_gamepad:
		_set_using_gamepad(true)
	elif desktop and using_gamepad:
		_set_using_gamepad(false)


func _process(_delta: float) -> void:
	# Gamepad ile menüde gezilirken odakta bir şey yoksa açık menünün ilk butonunu seç
	if using_gamepad and get_viewport().gui_get_focus_owner() == null:
		focus_top_menu()


func _set_using_gamepad(value: bool) -> void:
	using_gamepad = value
	# Gamepad ile oynarken fare imleci gizlenir (Steam Deck); fare oynayınca geri gelir
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_VISIBLE
	device_changed.emit(value)


# Pencere boyutuna göre imleç kopyası: 480x270 temel çözünürlüğün kaç katıysa o
func _update_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window_size := get_tree().root.size
	var base := Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var scale := clampi(mini(window_size.x / base.x, window_size.y / base.y), 1, CURSORS.size())
	Input.set_custom_mouse_cursor(load(CURSORS[scale - 1]), Input.CURSOR_ARROW, Vector2.ZERO)


# --- Atamalar -------------------------------------------------------------------

func get_binding(action: String, slot: int) -> String:
	return bindings.get(action, ["", ""])[slot]


## Bir aksiyonun yuvasına yeni kod atar. Aynı kod başka bir aksiyonda varsa oradan kaldırılır;
## kaldırılan aksiyonun adı döner (yoksa "").
func set_binding(action: String, slot: int, code: String) -> String:
	var removed_from := ""
	if not code.is_empty():
		for other: String in bindings:
			if other != action and bindings[other][slot] == code:
				bindings[other][slot] = ""
				removed_from = other
	bindings[action][slot] = code
	apply()
	save_bindings()
	return removed_from


func reset_to_defaults() -> void:
	bindings = _copy_defaults()
	apply()
	save_bindings()


## Atamaları Input Map'e uygular (aksiyonlar yoksa oluşturur).
func apply() -> void:
	for action: String in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		InputMap.action_erase_events(action)
		for code: String in bindings[action]:
			var event := code_to_event(code)
			if event:
				InputMap.action_add_event(action, event)
	bindings_changed.emit()


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK or not config.has_section(SECTION):
		return
	for action: String in bindings:
		# Yeni eklenen aksiyonlar eski ayar dosyasında yoktur; varsayılan verilmezse Godot hata yazar
		var saved: Variant = config.get_value(SECTION, action, [])
		if saved is Array and saved.size() == 2:
			bindings[action] = [str(saved[0]), str(saved[1])]


func save_bindings() -> void:
	# Aynı dosyada başka ayarlar da var: önce oku, sadece kendi bölümünü değiştir
	var config := ConfigFile.new()
	config.load(config_path)
	for action: String in bindings:
		config.set_value(SECTION, action, bindings[action])
	config.save(config_path)


func _copy_defaults() -> Dictionary:
	var copy := {}
	for action: String in DEFAULTS:
		copy[action] = DEFAULTS[action].duplicate()
	return copy


# --- Kod <-> InputEvent ----------------------------------------------------------

func code_to_event(code: String) -> InputEvent:
	var parts := code.split(":")
	match parts[0]:
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(parts[1]) as MouseButton
			return mouse
		"joy":
			var button := InputEventJoypadButton.new()
			button.button_index = int(parts[1]) as JoyButton
			button.device = -1
			return button
		"axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(parts[1]) as JoyAxis
			motion.axis_value = signf(float(parts[2]))
			motion.device = -1
			return motion
	return null


## Basılan bir girdiyi koda çevirir; atanamayacak bir girdiyse "" döner.
## slot: 0 = klavye/fare, 1 = gamepad.
func event_to_code(event: InputEvent, slot: int) -> String:
	if slot == 0:
		var key := event as InputEventKey
		if key and key.pressed and not key.echo:
			var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return "key:%d" % physical
		var mouse := event as InputEventMouseButton
		if mouse and mouse.pressed:
			return "mouse:%d" % mouse.button_index
	else:
		var button := event as InputEventJoypadButton
		if button and button.pressed:
			return "joy:%d" % button.button_index
		var motion := event as InputEventJoypadMotion
		if motion and absf(motion.axis_value) > AXIS_PRESS:
			return "axis:%d:%d" % [motion.axis, 1 if motion.axis_value > 0.0 else -1]
	return ""


# --- Tuş adları --------------------------------------------------------------------

## Bir kodun oyuncuya gösterilecek adı (ör. "F", "Sol Tık", "RB", "LS Yukarı").
## short: dar yerler (yetenek çubuğu) için kısa ad.
func code_label(code: String, short: bool = false) -> String:
	if code.is_empty():
		return "-"
	var parts := code.split(":")
	match parts[0]:
		"key":
			# Fiziksel tuşu oyuncunun klavye düzenindeki harfe çevir
			var keycode := DisplayServer.keyboard_get_keycode_from_physical(int(parts[1]) as Key)
			if keycode == KEY_NONE:
				keycode = int(parts[1]) as Key
			return OS.get_keycode_string(keycode)
		"mouse":
			match int(parts[1]):
				MOUSE_BUTTON_LEFT: return tr("KEY_MOUSE_LEFT")
				MOUSE_BUTTON_RIGHT: return tr("KEY_MOUSE_RIGHT")
				MOUSE_BUTTON_MIDDLE: return tr("KEY_MOUSE_MIDDLE")
			return tr("KEY_MOUSE_N") % int(parts[1])
		"joy":
			var name_key: String = PAD_BUTTON_NAMES.get(int(parts[1]), str(int(parts[1])))
			if short and name_key.begins_with("PAD_"):
				name_key += "_SHORT"
			return tr(name_key)
		"axis":
			var axis := int(parts[1])
			var positive := int(parts[2]) > 0
			match axis:
				JOY_AXIS_TRIGGER_LEFT: return "LT"
				JOY_AXIS_TRIGGER_RIGHT: return "RT"
			var stick := "LS" if axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "RS"
			var vertical := axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]
			var direction := ("PAD_DOWN" if positive else "PAD_UP") if vertical else ("PAD_RIGHT" if positive else "PAD_LEFT")
			return "%s %s" % [stick, tr(direction)]
	return "?"


## Aksiyonun şu an kullanılan cihazdaki tuş adı. Gamepad ataması yoksa klavyeninki gösterilir.
func get_action_label(action: String, short: bool = false) -> String:
	if not bindings.has(action):
		return "?"
	var code: String = bindings[action][1 if using_gamepad else 0]
	if code.is_empty():
		code = bindings[action][0]
	return code_label(code, short)


## Metindeki {aksiyon} yer tutucularını tuş adlarıyla doldurur, ör. "{interact} ile konuş" → "F ile konuş".
func format_action_keys(text: String) -> String:
	var keys := {}
	for action: String in bindings:
		if text.contains("{%s}" % action):
			keys[action] = get_action_label(action)
	return text.format(keys)


# --- Gamepad ile menü odağı -------------------------------------------------------

## Görünür menülerin ("menus" grubu) en sonuncusunda ilk odaklanabilir kontrolü seçer.
func focus_top_menu() -> void:
	var menus := get_tree().get_nodes_in_group("menus")
	for i in range(menus.size() - 1, -1, -1):
		var menu := menus[i] as Control
		if menu and menu.is_visible_in_tree():
			var target := _first_focusable(menu)
			if target:
				target.grab_focus()
			return


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		if control.focus_mode == Control.FOCUS_ALL and not (control is BaseButton and (control as BaseButton).disabled):
			return control
		var found := _first_focusable(control)
		if found:
			return found
	return null
