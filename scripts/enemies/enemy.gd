class_name Enemy
extends CharacterBody2D
## Basit yakın dövüş düşmanı: oyuncuyu görünce kovalar, menzile girince saldırır,
## oyuncu uzaklaşırsa başladığı noktaya döner.
## Yeni düşman türü için: goblin.tscn'yi kopyala, Sprite'ın sprite_folder'ını ve değerleri değiştir.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, RETURN, ATTACK, HURT, DEAD }

@export var max_hp: int = 40
@export var damage: int = 8
@export var move_speed: float = 60.0
## Oyuncuyu fark etme mesafesi (piksel)
@export var detect_radius: float = 110.0
## Oyuncu bu mesafeyi aşarsa düşman kovalamayı bırakır
@export var lose_radius: float = 200.0
@export var attack_range: float = 20.0
@export var attack_cooldown: float = 1.2
## Saldırı animasyonunun kaçıncı karesinde hasar verileceği (0'dan başlar)
@export var attack_hit_frame: int = 2
@export var knockback_force: float = 120.0

var hp: int
var state: State = State.IDLE
## Görselin baktığı yön: "right" ya da "left"
var facing: String = "right"
var _home: Vector2
var _cooldown := 0.0
var _hit_done := false
var _knockback := Vector2.ZERO
var _player: Player

@onready var sprite: CharacterSprite = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var health_bar: HealthBar2D = $HealthBar


func _ready() -> void:
	hp = max_hp
	_home = global_position
	add_to_group("enemies")
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.play_directional("idle", facing)
	health_bar.set_ratio(1.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player

	match state:
		State.IDLE, State.CHASE, State.RETURN:
			_update_movement()
		_:
			velocity = Vector2.ZERO

	velocity += _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_force * 8.0 * delta)
	move_and_slide()


func _update_movement() -> void:
	var target := _home
	var distance := _distance_to_player()
	var can_chase := distance <= detect_radius or (state == State.CHASE and distance <= lose_radius)

	if can_chase:
		state = State.CHASE
		if distance <= attack_range:
			velocity = Vector2.ZERO
			_face(_player.global_position - global_position)
			if _cooldown <= 0.0:
				_start_attack()
			else:
				sprite.play_directional("idle", facing)
			return
		target = _player.global_position
	elif state == State.CHASE:
		state = State.RETURN

	if state == State.RETURN and global_position.distance_to(_home) < 4.0:
		state = State.IDLE
	if state == State.IDLE:
		velocity = Vector2.ZERO
		sprite.play_directional("idle", facing)
		return

	var direction := global_position.direction_to(target)
	velocity = direction * move_speed
	_face(direction)
	sprite.play_directional("walk", facing)


func take_damage(amount: int, crit: bool, from_position: Vector2) -> void:
	if state == State.DEAD:
		return
	hp -= amount
	health_bar.set_ratio(float(hp) / max_hp)
	var text := str(amount) + ("!" if crit else "")
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), text, Color(1, 0.85, 0.2) if crit else Color.WHITE)
	_flash()
	_knockback = from_position.direction_to(global_position) * knockback_force
	if hp <= 0:
		_die()
		return
	# Vurulan düşman her zaman oyuncuya saldırmaya başlar
	state = State.CHASE
	if sprite.has_directional("hurt"):
		state = State.HURT
		sprite.play_directional("hurt", facing, true)


func _start_attack() -> void:
	state = State.ATTACK
	_hit_done = false
	_cooldown = attack_cooldown
	sprite.play_directional("attack", facing, true)
	if not sprite.has_directional("attack"):
		_try_hit_player()
		state = State.CHASE


func _try_hit_player() -> void:
	_hit_done = true
	if _distance_to_player() <= attack_range * 1.5:
		_player.take_damage(damage)


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	health_bar.hide()
	died.emit(self)
	if sprite.has_directional("death"):
		sprite.play_directional("death", facing, true)
	else:
		_fade_out()


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _distance_to_player() -> float:
	if _player == null or not _player.is_inside_tree() or _player.state == Player.State.DEAD:
		return INF
	return global_position.distance_to(_player.global_position)


# Yalnızca yatay bileşene göre döner; tam dikey harekette son yönünü korur
func _face(direction: Vector2) -> void:
	if direction.x > 0.01:
		facing = "right"
	elif direction.x < -0.01:
		facing = "left"


func _flash() -> void:
	modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func _on_sprite_frame_changed() -> void:
	if state != State.ATTACK or _hit_done:
		return
	if sprite.frame >= mini(attack_hit_frame, sprite.get_current_frame_count() - 1):
		_try_hit_player()


func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK:
			if not _hit_done:
				_try_hit_player()
			state = State.CHASE
		State.HURT:
			state = State.CHASE
		State.DEAD:
			_fade_out()
