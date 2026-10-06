class_name ActionButton
extends Control
## Dokunmatik aksiyon butonu: çerçeve + ikon + isteğe bağlı sayı + bekleme süresi göstergesi.
## Basıldığında Input Map'teki `action` aksiyonunu tetikler (klavye kısayoluyla aynı).
## Dokunma için TouchScreenButton kullanılır; böylece joystick tutulurken de basılabilir
## (normal Button yalnızca ilk parmağı algılar).

signal pressed

@export var action: String = ""
@export var icon: Texture2D:
	set(value):
		icon = value
		if is_node_ready():
			_layout()
## İkonun tam sayı büyütme katı (16 px ikon için 2 = 32 px); pikseller keskin kalır
@export_range(1, 4) var icon_scale: int = 1
## Çerçevenin tema varyasyonu: SkillSlot, InsetPanel, CommonSlot...
@export var frame_variation: StringName = &"InsetPanel"
## Sağ altta sayı (iksir adedi, mana bedeli) gösterilsin mi
@export var show_count: bool = false
@export var count_color: Color = Color.WHITE

var _cooldown_ratio := 0.0
var _cooldown_tween: Tween

@onready var frame: Panel = $Frame
@onready var icon_rect: TextureRect = $Icon
@onready var count_label: Label = $Count
@onready var cooldown_overlay: Control = $CooldownOverlay
@onready var touch: TouchScreenButton = $Touch


func _ready() -> void:
	frame.theme_type_variation = frame_variation
	count_label.visible = show_count
	count_label.modulate = count_color
	touch.action = action
	touch.pressed.connect(_on_pressed)
	touch.released.connect(_on_released)
	cooldown_overlay.draw.connect(_draw_cooldown)
	resized.connect(_layout)
	_layout()


func set_count(value: int) -> void:
	count_label.text = str(value)


## İkonu soluk gösterir (ör. iksir kalmadığında, mana yetmediğinde).
func set_dimmed(dimmed: bool) -> void:
	icon_rect.modulate = Color(1, 1, 1, 0.35) if dimmed else Color.WHITE


## Saat yönünde kaybolan karartma ile bekleme süresini gösterir.
func start_cooldown(duration: float) -> void:
	if _cooldown_tween:
		_cooldown_tween.kill()
	_cooldown_ratio = 1.0
	_cooldown_tween = create_tween()
	_cooldown_tween.tween_method(_set_cooldown_ratio, 1.0, 0.0, duration)


func _set_cooldown_ratio(ratio: float) -> void:
	_cooldown_ratio = ratio
	cooldown_overlay.queue_redraw()


func _layout() -> void:
	if not is_node_ready():
		return
	if icon:
		var icon_size := icon.get_size() * icon_scale
		icon_rect.texture = icon
		icon_rect.size = icon_size
		icon_rect.position = ((size - icon_size) / 2.0).round()
	var shape := touch.shape as RectangleShape2D
	if shape:
		shape.size = size
	touch.position = size / 2.0
	cooldown_overlay.queue_redraw()


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
		cooldown_overlay.draw_colored_polygon(polygon, Color(0, 0, 0, 0.55))


func _on_pressed() -> void:
	modulate = Color(0.75, 0.75, 0.75)
	pressed.emit()


func _on_released() -> void:
	modulate = Color.WHITE
