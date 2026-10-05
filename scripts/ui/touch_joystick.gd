class_name TouchJoystick
extends Control
## Ekranın sol tarafında, dokunulan yerde beliren sanal joystick.
## Hareket aksiyonlarını (move_left/right/up/down) tetikler; oyuncu bunları
## klavye girdisiyle aynı şekilde okur.

@export var base_texture: Texture2D
@export var knob_texture: Texture2D
## Joystick kolunun merkezden gidebileceği en uzak mesafe (piksel)
@export var max_distance: float = 20.0
@export_range(0.0, 1.0) var dead_zone: float = 0.2
## Dokunulmadığında joystick'in sol alt köşeden uzaklığı
@export var idle_margin: Vector2 = Vector2(44, 44)

var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _touch_index == -1 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_center = touch.position - global_position
			_update_knob(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == _touch_index:
			_touch_index = -1
			_knob = Vector2.ZERO
			_apply(Vector2.ZERO)
			queue_redraw()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_update_knob(drag.position)


func _update_knob(screen_position: Vector2) -> void:
	_knob = (screen_position - global_position - _center).limit_length(max_distance)
	_apply(_knob / max_distance)
	queue_redraw()


func _apply(vector: Vector2) -> void:
	if vector.length() < dead_zone:
		vector = Vector2.ZERO
	_set_action("move_left", maxf(0.0, -vector.x))
	_set_action("move_right", maxf(0.0, vector.x))
	_set_action("move_up", maxf(0.0, -vector.y))
	_set_action("move_down", maxf(0.0, vector.y))


func _set_action(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	if base_texture == null or knob_texture == null:
		return
	var active := _touch_index != -1
	var center := _center if active else Vector2(idle_margin.x, size.y - idle_margin.y)
	var tint := Color(1, 1, 1, 0.8 if active else 0.35)
	draw_texture(base_texture, (center - base_texture.get_size() / 2.0).round(), tint)
	draw_texture(knob_texture, (center + _knob - knob_texture.get_size() / 2.0).round(), tint)
