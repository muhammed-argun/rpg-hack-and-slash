class_name Player
extends CharacterBody2D
## Oyuncu karakteri (şimdilik Warrior): hareket, saldırı, hasar alma, iksir.
## Girdi aksiyonları: move_left/right/up/down, attack, use_potion
## (klavye ve sanal joystick/butonlar aynı aksiyonları tetikler).

enum State { NORMAL, ATTACK, HURT, DEAD }

const FACING_VECTORS := {
	"down": Vector2.DOWN,
	"up": Vector2.UP,
	"right": Vector2.RIGHT,
	"left": Vector2.LEFT,
}

@export var move_speed: float = 120.0
## Saldırı animasyonunun kaçıncı karesinde hasar verileceği (0'dan başlar)
@export var attack_hit_frame: int = 2
## Saldırı alanının karakterin merkezinden uzaklığı (piksel)
@export var attack_reach: float = 16.0

var state: State = State.NORMAL
var facing: String = "down"
var _hit_done := false

@onready var sprite: CharacterSprite = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	GameState.player_died.connect(_on_player_died)
	sprite.play_directional("idle", facing)


func _physics_process(_delta: float) -> void:
	if state != State.DEAD and Input.is_action_just_pressed("use_potion"):
		_use_potion()

	if state == State.NORMAL:
		_process_normal()
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _process_normal() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = _direction_name(input)

	# Basılı tutulduğu sürece saldırmaya devam eder
	if Input.is_action_pressed("attack"):
		_start_attack()
		return

	velocity = input * move_speed
	sprite.play_directional("walk" if input != Vector2.ZERO else "idle", facing)


func _start_attack() -> void:
	state = State.ATTACK
	_hit_done = false
	velocity = Vector2.ZERO
	attack_area.position = FACING_VECTORS[facing] * attack_reach + Vector2(0, -8)
	sprite.play_directional("attack", facing, true)
	if not sprite.has_directional("attack"):
		# Saldırı görseli yoksa hasarı hemen ver
		_deal_attack_damage()
		state = State.NORMAL


func _deal_attack_damage() -> void:
	_hit_done = true
	for body in attack_area.get_overlapping_bodies():
		if body is Enemy:
			var hit: Dictionary = GameState.roll_damage()
			(body as Enemy).take_damage(hit["amount"], hit["crit"], global_position)


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	var dealt := GameState.damage_player(amount)
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), str(dealt), Color(1, 0.35, 0.35))
	_flash()
	# Saldırı sırasında hasar almak saldırıyı bölmez
	if GameState.hp > 0 and state == State.NORMAL and sprite.has_directional("hurt"):
		state = State.HURT
		sprite.play_directional("hurt", facing, true)


## Ölümden sonra yeniden doğarken Main tarafından çağrılır.
func revive() -> void:
	state = State.NORMAL
	modulate = Color.WHITE
	collision.set_deferred("disabled", false)
	sprite.play_directional("idle", facing, true)


func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
	camera.reset_smoothing()


func _use_potion() -> void:
	var healed := GameState.use_potion()
	if healed > 0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), "+%d" % healed, GameState.HEAL_COLOR)


func _on_player_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	sprite.play_directional("death", facing, true)


func _on_sprite_frame_changed() -> void:
	if state != State.ATTACK or _hit_done:
		return
	if sprite.frame >= mini(attack_hit_frame, sprite.get_current_frame_count() - 1):
		_deal_attack_damage()


func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK:
			if not _hit_done:
				_deal_attack_damage()
			state = State.NORMAL
		State.HURT:
			state = State.NORMAL


func _flash() -> void:
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"
