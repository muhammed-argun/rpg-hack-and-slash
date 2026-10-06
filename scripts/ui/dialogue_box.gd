class_name DialogueBox
extends PanelContainer
## Ekranın altında beliren konuşma kutusu. Dialogue servisinin dialogue_started sinyalini dinler.
## Metin harf harf yazılır; dokunuş önce metni tamamlar, sonra sonraki satıra geçer.
## Konuşma sürerken oyun duraklar.

const CHARS_PER_SECOND := 45.0

var _lines: Array = []
var _index := 0
var _typing := false
# Konuşmayı başlatan dokunuş metni hemen geçmesin diye kısa bekleme
var _input_lock := 0.0

@onready var speaker_label: Label = %Speaker
@onready var text_label: Label = %Text
@onready var hint_label: Label = %Hint


func _ready() -> void:
	hide()
	Dialogue.dialogue_started.connect(_on_dialogue_started)
	gui_input.connect(_on_gui_input)


func _process(delta: float) -> void:
	if not visible:
		return
	_input_lock -= delta
	if _typing:
		text_label.visible_ratio = minf(1.0, text_label.visible_ratio + delta * CHARS_PER_SECOND / maxf(text_label.text.length(), 1.0))
		if text_label.visible_ratio >= 1.0:
			_typing = false
			hint_label.show()
	# Klavyeyle de ilerletilebilir (saldırı tuşu)
	if Input.is_action_just_pressed("attack") and _input_lock <= 0.0:
		_advance()


func _on_dialogue_started(_npc_id: String, _dialogue_id: String, lines: Array) -> void:
	_lines = lines
	_index = 0
	_input_lock = 0.2
	show()
	get_tree().paused = true
	_show_line()


func _show_line() -> void:
	var line: Array = _lines[_index]
	speaker_label.text = Dialogue.get_npc_name(str(line[0]))
	text_label.text = tr(str(line[1]))
	text_label.visible_ratio = 0.0
	_typing = true
	Audio.play_sfx("dialogue", 0.1)
	hint_label.hide()


func _advance() -> void:
	if _input_lock > 0.0:
		return
	if _typing:
		text_label.visible_ratio = 1.0
		_typing = false
		hint_label.show()
		return
	_index += 1
	if _index < _lines.size():
		_show_line()
		return
	hide()
	get_tree().paused = false
	# Basılı kalan saldırı tuşu konuşma biter bitmez saldırı başlatmasın
	Input.action_release("attack")
	Dialogue.finish()


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()
