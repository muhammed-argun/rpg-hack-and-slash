class_name HotbarSlot
extends Control
## Yetenek çubuğundaki tek yuva: çerçeve + ikon + sağ altta sayı (iksir adedi / mana bedeli)
## + saat yönünde kaybolan bekleme süresi karartması. Fareyi yakalamaz (üstündeyken saldırı engellenmesin).

const SIZE := Vector2(26, 26)
## Çerçevenin içi: ikon bu alana ortalanır
const ICON_AREA := Rect2(3, 3, 20, 20)

var _cooldown_ratio := 0.0
var _cooldown_tween: Tween
var _frame: PanelContainer
var _icon: TextureRect
var _count: Label
var _overlay: Control


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_frame = PanelContainer.new()
	_frame.theme_type_variation = &"SkillSlot"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_cooldown)
	add_child(_overlay)
	_count = Label.new()
	_count.theme_type_variation = &"HudLabel"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -24
	_count.offset_top = -12
	_count.offset_right = 0
	_count.offset_bottom = 1
	add_child(_count)


## icon null ise yuva boş görünür.
func set_icon(texture: Texture2D) -> void:
	IconFit.place(_icon, texture, ICON_AREA)
	_frame.modulate = Color.WHITE if texture else Color(1, 1, 1, 0.55)


func set_count(text: String, color: Color = Color.WHITE) -> void:
	_count.text = text
	_count.modulate = color


func has_icon() -> bool:
	return _icon.texture != null


## İkonu soluk gösterir (iksir kalmadı, mana yetmiyor).
func set_dimmed(dimmed: bool) -> void:
	_icon.modulate = Color(1, 1, 1, 0.35) if dimmed else Color.WHITE


## Bekleme süresini gösterir. remaining verilirse karartma o orandan başlar.
func start_cooldown(duration: float, remaining: float = -1.0) -> void:
	if _cooldown_tween:
		_cooldown_tween.kill()
	if remaining < 0.0:
		remaining = duration
	if duration <= 0.0 or remaining <= 0.0:
		_set_cooldown_ratio(0.0)
		return
	_cooldown_tween = create_tween()
	_cooldown_tween.tween_method(_set_cooldown_ratio, remaining / duration, 0.0, remaining)


func get_cooldown_ratio() -> float:
	return _cooldown_ratio


func _set_cooldown_ratio(ratio: float) -> void:
	_cooldown_ratio = ratio
	_overlay.queue_redraw()


func _draw_cooldown() -> void:
	if _cooldown_ratio <= 0.0:
		return
	var center := size / 2.0
	var radius := size.length() / 2.0
	var points := PackedVector2Array([center])
	var steps := 24
	# Saat 12 yönünden başlayıp saat yönünde kalan süre kadar dilim
	for i in steps + 1:
		var angle := -PI / 2.0 + TAU * _cooldown_ratio * i / steps
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	var inset := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var clipped := Geometry2D.intersect_polygons(points, PackedVector2Array([
		inset.position, Vector2(inset.end.x, inset.position.y), inset.end, Vector2(inset.position.x, inset.end.y)]))
	for polygon in clipped:
		_overlay.draw_colored_polygon(polygon, Color(0, 0, 0, 0.6))
