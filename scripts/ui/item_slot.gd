class_name ItemSlot
extends Button
## Çanta ve ekipman yuvası: çerçeve (eşyanın nadirliğine göre renkli), ikon, sağ altta adet.
## Tıklanınca / gamepad ile seçilince pressed; sağ tıkta secondary_pressed (hızlı eylem: kuşan, kullan, çıkar).
## Fare üstüne gelince ya da gamepad odağı gelince hovered, ayrılınca unhovered (bilgi kutusu için).

signal secondary_pressed
signal hovered
signal unhovered

const SIZE := Vector2(26, 26)
## Çerçevenin içi: ikon bu alana ortalanır (çerçeve kenarı 4 piksel)
const ICON_AREA := Rect2(4, 4, 18, 18)
const RARITY_FRAMES: Array[StringName] = [&"CommonSlot", &"UncommonSlot", &"RareSlot", &"LegendarySlot"]
const LOCK_ICON := preload("res://addons/pixel_ui_fantasy/icons/lock.png")

var _frame: PanelContainer
var _icon: TextureRect
var _count: Label
var _selected := false


func _init() -> void:
	custom_minimum_size = SIZE
	flat = true
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _ready() -> void:
	_frame = PanelContainer.new()
	_frame.theme_type_variation = &"InsetPanel"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_count = Label.new()
	_count.theme_type_variation = &"HudLabel"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -22
	_count.offset_top = -12
	_count.offset_right = 0
	_count.offset_bottom = 1
	add_child(_count)
	mouse_entered.connect(hovered.emit)
	focus_entered.connect(hovered.emit)
	mouse_exited.connect(unhovered.emit)
	focus_exited.connect(unhovered.emit)
	gui_input.connect(_on_gui_input)


## Yuvayı doldurur. icon null ise boş yuva; hint verilirse boş yuvada soluk olarak gösterilir
## (ör. kask yuvasında soluk kask). rarity -1: nadirlik çerçevesi yok.
func show_item(icon: Texture2D, count: int = 0, rarity: int = -1, hint: Texture2D = null) -> void:
	IconFit.place(_icon, icon if icon else hint, ICON_AREA)
	_icon.modulate = Color.WHITE if icon else Color(1, 1, 1, 0.22)
	_count.text = str(count) if count > 1 else ""
	_frame.theme_type_variation = RARITY_FRAMES[rarity] if rarity >= 0 and rarity < RARITY_FRAMES.size() else &"InsetPanel"
	_refresh_tint()


## Kilitli yuva (çift elli silah takılıyken ikinci el)
func show_locked() -> void:
	IconFit.place(_icon, LOCK_ICON, ICON_AREA)
	_icon.modulate = Color(1, 1, 1, 0.6)
	_count.text = ""
	_frame.theme_type_variation = &"InsetPanel"
	_refresh_tint()


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_tint()


func _refresh_tint() -> void:
	_frame.modulate = Color(1.35, 1.2, 0.75) if _selected else Color.WHITE


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		secondary_pressed.emit()
