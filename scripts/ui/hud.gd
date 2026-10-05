extends CanvasLayer
## Oyun arayüzü: can ve mana barları (Pixel Bars), altın kesesi, aksiyon butonları,
## olay mesajları ve envanter penceresi. Envanter açıkken oyun duraklar, HUD çalışmaya devam eder.

const MESSAGE_LIFETIME := 2.5
const MAX_MESSAGES := 4
const MOVEMENT_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "skill"]

@onready var hp_bar: PixelBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var mp_bar: PixelBar = %MPBar
@onready var mp_label: Label = %MPLabel
@onready var gold_label: Label = %GoldLabel
@onready var messages: VBoxContainer = %Messages
@onready var joystick: TouchJoystick = %TouchJoystick
@onready var action_buttons: Control = %ActionButtons
@onready var skill_button: ActionButton = %SkillButton
@onready var health_potion_button: ActionButton = %HealthPotionButton
@onready var mana_potion_button: ActionButton = %ManaPotionButton
@onready var inventory: InventoryWindow = %InventoryWindow


func _ready() -> void:
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.mana_changed.connect(_on_mana_changed)
	GameState.gold_changed.connect(_on_gold_changed)
	GameState.health_potions_changed.connect(_on_health_potions_changed)
	GameState.mana_potions_changed.connect(_on_mana_potions_changed)
	GameState.skill_cooldown_started.connect(skill_button.start_cooldown)
	GameState.message.connect(_on_message)
	inventory.closed.connect(_on_inventory_closed)
	_on_hp_changed(GameState.hp, GameState.max_hp)
	_on_mana_changed(int(GameState.mana), GameState.max_mana)
	_on_gold_changed(GameState.gold)
	_on_health_potions_changed(GameState.health_potions)
	_on_mana_potions_changed(GameState.mana_potions)
	hp_bar.settle()
	mp_bar.settle()


func _process(_delta: float) -> void:
	_update_skill_button()
	if Input.is_action_just_pressed("toggle_inventory"):
		if inventory.visible:
			inventory.close()
		else:
			_open_inventory()


func _open_inventory() -> void:
	# Pencerenin altında kalan dokunmatik kontrolleri gizle, basılı kalan aksiyonları bırak
	joystick.hide()
	action_buttons.hide()
	for action: String in MOVEMENT_ACTIONS:
		Input.action_release(action)
	inventory.open()


func _on_inventory_closed() -> void:
	joystick.show()
	action_buttons.show()


func _on_hp_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d/%d" % [current, maximum]


func _on_mana_changed(current: int, maximum: int) -> void:
	mp_bar.max_value = maximum
	mp_bar.value = current
	mp_label.text = "%d/%d" % [current, maximum]


# Yeteneğin mana bedeli ve manası yetmiyorsa soluk görünmesi
func _update_skill_button() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	skill_button.set_count(player.skill_mana_cost)
	skill_button.set_dimmed(GameState.mana < player.skill_mana_cost)


func _on_gold_changed(amount: int) -> void:
	gold_label.text = str(amount)


func _on_health_potions_changed(amount: int) -> void:
	health_potion_button.set_count(amount)
	health_potion_button.set_dimmed(amount == 0)


func _on_mana_potions_changed(amount: int) -> void:
	mana_potion_button.set_count(amount)
	mana_potion_button.set_dimmed(amount == 0)


func _on_message(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"HudLabel"
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	messages.add_child(label)
	if messages.get_child_count() > MAX_MESSAGES:
		messages.get_child(0).queue_free()
	var tween := label.create_tween()
	tween.tween_interval(MESSAGE_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
