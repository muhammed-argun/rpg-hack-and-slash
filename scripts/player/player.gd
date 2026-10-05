class_name Player
extends CharacterBody2D
## Oyuncu karakteri (şimdilik Warrior): hareket, saldırı, alan yeteneği, hasar alma, iksirler.
## Girdi aksiyonları: move_left/right/up/down, attack, skill, use_potion, use_mana_potion
## (klavye ve sanal joystick/butonlar aynı aksiyonları tetikler).

enum State { NORMAL, ATTACK, SKILL, HURT, DEAD }

# Joystick'teki çok küçük yatay sapmalar karakteri döndürmesin diye
const TURN_THRESHOLD := 0.1
const NO_MANA_MESSAGE_INTERVAL := 1.5

@export var move_speed: float = 120.0
## Saldırı animasyonunun kaçıncı karesinde hasar verileceği (0'dan başlar)
@export var attack_hit_frame: int = 2
## Saldırı alanının karakterin merkezinden uzaklığı (piksel)
@export var attack_reach: float = 16.0

@export_group("Yetenek: Yer Sarsıntısı")
## Kılıcı yere saplayıp çevresindeki tüm düşmanlara hasar verir
@export var skill_mana_cost: int = 20
@export var skill_cooldown: float = 2.0
@export var skill_radius: float = 44.0
## Normal saldırı hasarının katı
@export var skill_damage_multiplier: float = 1.6
## "special" animasyonunun kaçıncı karesinde vurulacağı (0'dan başlar)
@export var skill_hit_frame: int = 3

var state: State = State.NORMAL
## Görselin baktığı yön: "right" ya da "left". Yalnızca yatay girdiyle değişir.
var facing: String = "right"
## Saldırının yöneldiği yön: son hareket yönü (çapraz ve dikey dahil)
var aim_direction: Vector2 = Vector2.RIGHT
## Yeteneğin tekrar kullanılabilmesine kalan süre
var skill_cooldown_left: float = 0.0
var _hit_done := false
var _no_mana_timer := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0

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


func _process(delta: float) -> void:
	# Kamera sarsıntısı
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	skill_cooldown_left = maxf(0.0, skill_cooldown_left - delta)
	_no_mana_timer = maxf(0.0, _no_mana_timer - delta)
	if state != State.DEAD:
		if Input.is_action_just_pressed("use_potion"):
			_use_health_potion()
		if Input.is_action_just_pressed("use_mana_potion"):
			_use_mana_potion()

	if state == State.NORMAL:
		_process_normal()
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _process_normal() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		aim_direction = input.normalized()
	# Sağ ya da sol girdisi varsa (yukarı/aşağı ile birlikte olsa bile) hemen o yöne dön
	if input.x > TURN_THRESHOLD:
		facing = "right"
	elif input.x < -TURN_THRESHOLD:
		facing = "left"

	if Input.is_action_just_pressed("skill") and _try_start_skill():
		return
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
	attack_area.position = aim_direction * attack_reach + Vector2(0, -8)
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


func _try_start_skill() -> bool:
	if skill_cooldown_left > 0.0:
		return false
	if not GameState.spend_mana(skill_mana_cost):
		if _no_mana_timer <= 0.0:
			GameState.message.emit("Yeterli mana yok", GameState.MANA_COLOR)
			_no_mana_timer = NO_MANA_MESSAGE_INTERVAL
		return false
	state = State.SKILL
	_hit_done = false
	velocity = Vector2.ZERO
	skill_cooldown_left = skill_cooldown
	GameState.skill_cooldown_started.emit(skill_cooldown)
	sprite.play_directional("special", facing, true)
	if not sprite.has_directional("special"):
		_deal_skill_damage()
		state = State.NORMAL
	return true


func _deal_skill_damage() -> void:
	_hit_done = true
	var center := global_position + Vector2(0, -4)
	Shockwave.spawn(center, skill_radius)
	shake(2.0, 0.2)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as Enemy
		if e and e.state != Enemy.State.DEAD and e.global_position.distance_to(center) <= skill_radius:
			var hit: Dictionary = GameState.roll_damage(skill_damage_multiplier)
			e.take_damage(hit["amount"], hit["crit"], center, 1.8)


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return
	var dealt := GameState.damage_player(amount)
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), str(dealt), Color(1, 0.35, 0.35))
	_flash()
	# Saldırı veya yetenek sırasında hasar almak hareketi bölmez
	if GameState.hp > 0 and state == State.NORMAL and sprite.has_directional("hurt"):
		state = State.HURT
		sprite.play_directional("hurt", facing, true)


## Kamerayı kısa süre sarsar (vuruş hissi için).
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength if _shake_time > 0.0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)


## Ölümden sonra yeniden doğarken Main tarafından çağrılır.
func revive() -> void:
	state = State.NORMAL
	modulate = Color.WHITE
	skill_cooldown_left = 0.0
	collision.set_deferred("disabled", false)
	sprite.play_directional("idle", facing, true)


func set_camera_limits(bounds: Rect2i) -> void:
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
	camera.reset_smoothing()


func _use_health_potion() -> void:
	var healed := GameState.use_health_potion()
	if healed > 0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), "+%d" % healed, GameState.HEAL_COLOR)


func _use_mana_potion() -> void:
	var restored := GameState.use_mana_potion()
	if restored > 0:
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), "+%d" % restored, GameState.MANA_COLOR)


func _on_player_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	sprite.play_directional("death", facing, true)


func _on_sprite_frame_changed() -> void:
	if _hit_done:
		return
	match state:
		State.ATTACK:
			if sprite.frame >= mini(attack_hit_frame, sprite.get_current_frame_count() - 1):
				_deal_attack_damage()
		State.SKILL:
			if sprite.frame >= mini(skill_hit_frame, sprite.get_current_frame_count() - 1):
				_deal_skill_damage()


func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK:
			if not _hit_done:
				_deal_attack_damage()
			state = State.NORMAL
		State.SKILL:
			if not _hit_done:
				_deal_skill_damage()
			state = State.NORMAL
		State.HURT:
			state = State.NORMAL


func _flash() -> void:
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)
