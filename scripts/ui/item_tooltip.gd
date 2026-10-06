class_name ItemTooltip
extends PanelContainer
## Eşya bilgi kutusu: imleç (ya da gamepad odağı) bir yuvanın üstündeyken yuvanın yanında çıkar.
## Pencereler büyümesin diye uzun açıklamalar burada gösterilir. Fareyi yakalamaz.

const WIDTH := 132
const GAP := 4

var _title: Label
var _body: Label


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	add_child(box)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(WIDTH, 0)
	_title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(WIDTH, 0)
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_body.modulate = Color(1, 1, 1, 0.85)
	box.add_child(_body)
	hide()


## anchor: üstüne gelinen yuva. Kutu yuvanın sağına, sığmazsa soluna konur; ekrandan taşmaz.
func show_for(anchor: Control, title: String, body: String, color: Color = Color.WHITE) -> void:
	_title.text = title
	# Parşömen zeminde okunsun diye nadirlik rengi koyulaştırılır; renksiz (sıradan) eşyada mürekkep rengi
	_title.add_theme_color_override("font_color", color.darkened(0.5) if color.s > 0.2 else Color(0.23, 0.13, 0.09))
	_body.text = body
	_body.visible = not body.is_empty()
	show()
	reset_size()
	var rect := anchor.get_global_rect()
	var screen := get_viewport_rect().size
	var target := Vector2(rect.end.x + GAP, rect.position.y)
	if target.x + size.x > screen.x:
		target.x = rect.position.x - GAP - size.x
	target.y = clampf(target.y, 0.0, maxf(0.0, screen.y - size.y))
	global_position = target.round()


func hide_for(_anchor: Control = null) -> void:
	hide()
