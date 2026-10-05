extends CanvasLayer
## Oyun arayüzü: can barı, altın, iksir sayısı ve olay mesajları.

const MESSAGE_LIFETIME := 2.5
const MAX_MESSAGES := 4

@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var gold_label: Label = %GoldLabel
@onready var potion_label: Label = %PotionLabel
@onready var messages: VBoxContainer = %Messages


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.potions_changed.connect(_on_potions_changed)
	GameState.message.connect(_on_message)
	_on_hp_changed(GameState.hp, GameState.max_hp)
	_on_gold_changed(GameState.gold)
	_on_potions_changed(GameState.potions)


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d/%d" % [current, maximum]


func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Altın: %d" % amount


func _on_potions_changed(amount: int) -> void:
	potion_label.text = str(amount)


func _on_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(MESSAGE_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
