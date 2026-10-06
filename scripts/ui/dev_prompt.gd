class_name DevPrompt
extends Control
## Geliştirici komut çubuğu: oyun içinde (hiçbir pencere açık değilken) Enter ile açılan küçük metin çubuğu.
## Enter onaylar, Esc kapatır. "zort" yazılıp onaylanırsa o oturum için dev modu açılır
## (GameState.dev_mode; kayda yazılmaz) ve dev konsolu tuşu (DevConsole.TOGGLE_KEY) çalışır.
## Başka bir şey yazılırsa yalnızca çubuk kapanır. Açıkken oyun duraklar: yazarken basılan WASD vb.
## tuşlar oyunu yürütmesin diye (Input.is_action_pressed yazı kutusunun tuş tüketmesinden etkilenmez).
## Geliştirici aracı olduğu için metinler çeviri anahtarı değildir (bkz. decisions.md).

signal closed

const SECRET := "zort"

var _panel: PanelContainer
var _edit: LineEdit


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Çubuğun dışı fareyi yakalamaz (yalnızca panel yakalar)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("menus")
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"WindowPanel"
	add_child(_panel)
	_edit = LineEdit.new()
	_edit.custom_minimum_size = Vector2(180, 14)
	_edit.max_length = 32
	_edit.context_menu_enabled = false
	_edit.text_submitted.connect(_on_submitted)
	_panel.add_child(_edit)
	hide()


func open() -> void:
	_edit.clear()
	show()
	get_tree().paused = true
	_panel.reset_size()
	# Yatayda ortada, üstte (altta öğretici ipuçları ve yetenek çubuğu var)
	_panel.position = Vector2(roundf((size.x - _panel.size.x) / 2.0), 100.0)
	_edit.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	_edit.release_focus()
	hide()
	get_tree().paused = false
	closed.emit()


## Geri tuşu (Esc): çubuğu kapatır
func go_back() -> void:
	close()


func _on_submitted(text: String) -> void:
	var unlocked := text.strip_edges().to_lower() == SECRET
	close()
	if unlocked:
		GameState.dev_mode = true
		GameState.message.emit("Dev console unlocked (%s)" % OS.get_keycode_string(DevConsole.TOGGLE_KEY), Color(0.6, 1.0, 0.7))
