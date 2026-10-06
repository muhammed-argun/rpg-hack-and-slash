class_name Player
extends CharacterBody2D
## Oyuncu karakteri (şimdilik Warrior): hareket, saldırı, alan yeteneği, blok/parry, yuvarlanma,
## iksirler ve NPC'lerle etkileşim.
## Girdi aksiyonları: move_left/right/up/down, attack, skill, block, dodge, use_potion, use_mana_potion
## (klavye ve sanal joystick/butonlar aynı aksiyonları tetikler).
## Yakında bir NPC varsa saldırı butonu "Konuş" olur.

signal interactable_changed(interactable: Interactable)

enum State { NORMAL, ATTACK, SKILL, BLOCK, DODGE, HURT, STAGGER, DEAD }

# Joystick'teki çok küçük yatay sapmalar karakteri döndürmesin diye
const TURN_THRESHOLD := 0.1
const NO_RESOURCE_MESSAGE_INTERVAL := 1.5
const SHIELD_ICON := preload("res://addons/pixel_ui_fantasy/icons/shield.png")

@export var move_speed: float = 120.0
## Saldırı animasyonunun kaçıncı karesinde hasar verileceği (0'dan başlar)
@export var attack_hit_frame: int = 2
## Saldırı alanının karakterin merkezinden uzaklığı (piksel)
@export var attack_reach: float = 16.0
## Her vuruşun düşmanın dengesine (poise) verdiği hasar katı
@export var poise_damage_multiplier: float = 1.0

@export_group("Yetenek: Yer Sarsıntısı")
## Kılıcı yere saplayıp çevresindeki tüm düşmanlara hasar verir
@export var skill_mana_cost: int = 20
@export var skill_cooldown: float = 2.0
@export var skill_radius: float = 44.0
## Normal saldırı hasarının katı
@export var skill_damage_multiplier: float = 1.6
## "special" animasyonunun kaçıncı karesinde vurulacağı (0'dan başlar)
@export var skill_hit_frame: int = 3

@export_group("Savunma")
## Blok tuşuna bu kadar saniye içinde basılırsa gelen saldırı parry'lenir
@export var parry_window: float = 0.2
@export var parry_stamina_cost: float = 5.0
## Bloklanan hasarın ne kadarı yine de geçer (0.2 = %20)
@export var block_damage_ratio: float = 0.2
## Bloklanan her hasar puanı için harcanan stamina (ağır saldırıda 2 katı)
@export var block_stamina_per_damage: float = 1.5
@export var block_move_speed_ratio: float = 0.35
## Savunma kırılınca veya ağır vuruş yiyince sersemleme süresi
@export var stagger_time: float = 0.6

@export_group("Yuvarlanma")
@export var dodge_stamina_cost: float = 22.0
@export var dodge_speed: float = 270.0
@export var dodge_time: float = 0.28
## Yuvarlanmanın başından itibaren dokunulmazlık süresi
@export var dodge_invulnerable_time: float = 0.22

var state: State = State.NORMAL
## Görselin baktığı yön: "right" ya da "left". Yalnızca yatay girdiyle değişir.
var facing: String = "right"
## Saldırının ve yuvarlanmanın yöneldiği yön: son hareket yönü (çapraz ve dikey dahil)
var aim_direction: Vector2 = Vector2.RIGHT
## Yeteneğin tekrar kullanılabilmesine kalan süre
var skill_cooldown_left: float = 0.0
## Yakındaki etkileşilebilir nesne (NPC vb.); yoksa null
var current_interactable: Interactable = null
var _hit_done := false
var _no_resource_timer := 0.0
var _shake_time := 0.0
var _shake_strength := 0.0
var _block_started_at := -10.0
var _state_timer := 0.0
var _invulnerable_time := 0.0
var _afterimage_timer := 0.0
var _shield_icon: Sprite2D
# Harita değişiminden sonra çarpışmanın kapalı kalacağı fizik karesi sayısı
var _spawn_guard := 0

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
	_shield_icon = Sprite2D.new()
	_shield_icon.texture = SHIELD_ICON
	_shield_icon.position = Vector2(0, -34)
	_shield_icon.visible = false
	add_child(_shield_icon)


func _process(delta: float) -> void:
	# Kamera sarsıntısı
	if _shake_time > 0.0:
		_shake_time -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
	else:
		camera.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _spawn_guard > 0:
		_spawn_guard -= 1
		if _spawn_guard == 0 and state != State.DEAD:
			collision.disabled = false
	skill_cooldown_left = maxf(0.0, skill_cooldown_left - delta)
	_no_resource_timer = maxf(0.0, _no_resource_timer - delta)
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	_update_interactable()
	if state != State.DEAD:
		if Input.is_action_just_pressed("use_potion"):
			_use_health_potion()
		if Input.is_action_just_pressed("use_mana_potion"):
			_use_mana_potion()

	match state:
		State.NORMAL:
			_process_normal()
		State.BLOCK:
			_process_block()
		State.DODGE:
			_process_dodge(delta)
		State.STAGGER:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.NORMAL)
		_:
			velocity = Vector2.ZERO
	move_and_slide()


func _read_input() -> Vector2:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		aim_direction = input.normalized()
	# Sağ ya da sol girdisi varsa (yukarı/aşağı ile birlikte olsa bile) hemen o yöne dön
	if input.x > TURN_THRESHOLD:
		facing = "right"
	elif input.x < -TURN_THRESHOLD:
		facing = "left"
	return input


func _process_normal() -> void:
	var input := _read_input()

	if Input.is_action_just_pressed("dodge") and _try_start_dodge():
		return
	if Input.is_action_pressed("block"):
		_start_block()
		return
	if Input.is_action_just_pressed("skill") and _try_start_skill():
		return
	# Yakında NPC varsa saldırı tuşu konuşmayı başlatır
	if current_interactable and Input.is_action_just_pressed("attack"):
		velocity = Vector2.ZERO
		current_interactable.interact(self)
		return
	# Basılı tutulduğu sürece saldırmaya devam eder
	if Input.is_action_pressed("attack") and current_interactable == null:
		_start_attack()
		return

	velocity = input * move_speed
	sprite.play_directional("walk" if input != Vector2.ZERO else "idle", facing)


# --- Saldırı ----------------------------------------------------------------

func _start_attack() -> void:
	_set_state(State.ATTACK)
	_hit_done = false
	velocity = Vector2.ZERO
	attack_area.position = aim_direction * attack_reach + Vector2(0, -8)
	sprite.play_directional("attack", facing, true)
	Audio.play_sfx("swing")
	if not sprite.has_directional("attack"):
		# Saldırı görseli yoksa hasarı hemen ver
		_deal_attack_damage()
		_set_state(State.NORMAL)


func _deal_attack_damage() -> void:
	_hit_done = true
	for body in attack_area.get_overlapping_bodies():
		if body is Enemy:
			var hit: Dictionary = GameState.roll_damage()
			(body as Enemy).take_damage(hit["amount"], hit["crit"], global_position, 1.0, poise_damage_multiplier)
			Audio.play_sfx("crit" if hit["crit"] else "hit")


func _try_start_skill() -> bool:
	if skill_cooldown_left > 0.0:
		return false
	if not GameState.spend_mana(skill_mana_cost):
		_warn("MSG_NO_MANA", GameState.MANA_COLOR)
		return false
	_set_state(State.SKILL)
	_hit_done = false
	velocity = Vector2.ZERO
	skill_cooldown_left = skill_cooldown
	GameState.skill_cooldown_started.emit(skill_cooldown)
	sprite.play_directional("special", facing, true)
	if not sprite.has_directional("special"):
		_deal_skill_damage()
		_set_state(State.NORMAL)
	return true


func _deal_skill_damage() -> void:
	_hit_done = true
	var center := global_position + Vector2(0, -4)
	Shockwave.spawn(center, skill_radius)
	shake(2.0, 0.2)
	Audio.play_sfx("skill_slam")
	Settings.vibrate(30)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var e := enemy as Enemy
		if e and e.state != Enemy.State.DEAD and e.global_position.distance_to(center) <= skill_radius:
			var hit: Dictionary = GameState.roll_damage(skill_damage_multiplier)
			e.take_damage(hit["amount"], hit["crit"], center, 1.8, 2.0)


# --- Savunma: blok, parry, yuvarlanma ----------------------------------------

func _start_block() -> void:
	_set_state(State.BLOCK)
	_block_started_at = _now()
	_shield_icon.visible = true
	sprite.modulate = Color(0.75, 0.85, 1.0)
	sprite.play_directional("block" if sprite.has_directional("block") else "idle", facing)


func _process_block() -> void:
	var input := _read_input()
	if not Input.is_action_pressed("block"):
		_set_state(State.NORMAL)
		return
	if Input.is_action_just_pressed("dodge") and _try_start_dodge():
		return
	# Blok sırasında yavaşça hareket edilebilir
	velocity = input * move_speed * block_move_speed_ratio
	sprite.play_directional("block" if sprite.has_directional("block") else "idle", facing)


func _try_start_dodge() -> bool:
	if not GameState.spend_stamina(dodge_stamina_cost):
		_warn("MSG_NO_STAMINA", GameState.STAMINA_COLOR)
		return false
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := input.normalized() if input != Vector2.ZERO else (Vector2.RIGHT if facing == "right" else Vector2.LEFT)
	aim_direction = direction
	_set_state(State.DODGE)
	_state_timer = dodge_time
	_invulnerable_time = dodge_invulnerable_time
	velocity = direction * dodge_speed
	sprite.play_directional("walk", facing, true)
	Audio.play_sfx("dodge")
	sprite.speed_scale = 2.0
	return true


func _process_dodge(delta: float) -> void:
	_state_timer -= delta
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = 0.05
		Afterimage.spawn_from(sprite, get_parent())
	velocity = aim_direction * dodge_speed * clampf(_state_timer / dodge_time + 0.3, 0.3, 1.0)
	if _state_timer <= 0.0:
		_set_state(State.NORMAL)


func is_invulnerable() -> bool:
	return _invulnerable_time > 0.0 or state == State.DEAD


## Düşman saldırısı. source: saldıran (parry'lenince sersemletmek için), kind: Combat.Kind
## Dönüş: Combat.Result
func take_damage(amount: int, source: Node2D = null, kind: Combat.Kind = Combat.Kind.NORMAL) -> Combat.Result:
	if state == State.DEAD:
		return Combat.Result.DODGED
	if is_invulnerable():
		return Combat.Result.DODGED
	if state == State.BLOCK and kind != Combat.Kind.UNBLOCKABLE:
		# Doğru zamanlama: parry
		if _now() - _block_started_at <= parry_window and GameState.spend_stamina(parry_stamina_cost):
			_on_parry(source)
			return Combat.Result.PARRIED
		var cost := amount * block_stamina_per_damage * (2.0 if kind == Combat.Kind.HEAVY else 1.0)
		if GameState.spend_stamina(cost, true):
			var chip := roundi(amount * block_damage_ratio)
			if chip > 0:
				GameState.damage_player(chip + GameState.get_defense())
			_flash(Color(0.6, 0.75, 1.0))
			shake(1.0, 0.1)
			Audio.play_sfx("block")
			return Combat.Result.BLOCKED
		# Stamina bitti: savunma kırılır
		GameState.message.emit(tr("MSG_GUARD_BREAK"), Color(1, 0.5, 0.3))
		Audio.play_sfx("guard_break")
		_receive_hit(roundi(amount * 0.5))
		_stagger()
		return Combat.Result.GUARD_BROKEN
	if state == State.BLOCK and kind == Combat.Kind.UNBLOCKABLE:
		GameState.message.emit(tr("MSG_UNBLOCKABLE"), Combat.KIND_COLORS[Combat.Kind.UNBLOCKABLE])
	_receive_hit(amount)
	if GameState.hp > 0:
		if kind != Combat.Kind.NORMAL:
			_stagger()
		elif state == State.NORMAL and sprite.has_directional("hurt"):
			_set_state(State.HURT)
			sprite.play_directional("hurt", facing, true)
	return Combat.Result.HIT


func _receive_hit(amount: int) -> void:
	var dealt := GameState.damage_player(amount)
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), str(dealt), Color(1, 0.35, 0.35))
	_flash()
	Settings.vibrate(25)
	Audio.play_sfx("player_hurt")


func _on_parry(source: Node2D) -> void:
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -34), tr("MSG_PARRY"), Color(1.0, 0.95, 0.5))
	Shockwave.spawn(global_position + Vector2(0, -8), 18.0, Color(1.0, 0.95, 0.6))
	shake(2.5, 0.15)
	Settings.vibrate(50)
	Audio.play_sfx("parry", 0.02)
	Combat.hit_stop(get_tree(), 0.08)
	if source and source.has_method("on_parried"):
		source.on_parried()


func _stagger() -> void:
	_set_state(State.STAGGER)
	_state_timer = stagger_time
	sprite.play_directional("hurt" if sprite.has_directional("hurt") else "idle", facing, true)


# --- Diğer ------------------------------------------------------------------

## Kamerayı kısa süre sarsar (vuruş hissi için).
func shake(strength: float, duration: float) -> void:
	_shake_strength = maxf(_shake_strength if _shake_time > 0.0 else 0.0, strength)
	_shake_time = maxf(_shake_time, duration)


## Yeni haritaya eklenmeden hemen önce çağrılır. Fizik motoru oyuncuyu bir kare boyunca eski
## haritadaki konumunda görebildiği için çarpışma kısa süre kapatılır; böylece yeni haritada o
## konuma denk gelen alanlar (çıkış, boss arenası, eşya) yanlışlıkla tetiklenmez.
func prepare_for_map_change() -> void:
	var shape := get_node("CollisionShape2D") as CollisionShape2D
	shape.disabled = true
	_spawn_guard = 2


## Ölümden sonra yeniden doğarken Main tarafından çağrılır.
func revive() -> void:
	_set_state(State.NORMAL)
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


func _set_state(new_state: State) -> void:
	if state == State.BLOCK and new_state != State.BLOCK:
		_shield_icon.visible = false
		sprite.modulate = Color.WHITE
	if state == State.DODGE and new_state != State.DODGE:
		sprite.speed_scale = 1.0
	state = new_state


func _update_interactable() -> void:
	var best: Interactable = null
	var best_distance := INF
	if state != State.DEAD:
		for node in get_tree().get_nodes_in_group("interactables"):
			var interactable := node as Interactable
			if interactable == null or not interactable.can_interact():
				continue
			var distance := global_position.distance_to(interactable.global_position)
			if distance <= interactable.interact_radius and distance < best_distance:
				best = interactable
				best_distance = distance
	if best != current_interactable:
		current_interactable = best
		interactable_changed.emit(best)


func _warn(key: String, color: Color) -> void:
	if _no_resource_timer <= 0.0:
		GameState.message.emit(tr(key), color)
		_no_resource_timer = NO_RESOURCE_MESSAGE_INTERVAL


func _use_health_potion() -> void:
	var healed := GameState.use_health_potion()
	if healed > 0:
		Audio.play_sfx("drink")
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), "+%d" % healed, GameState.HEAL_COLOR)


func _use_mana_potion() -> void:
	var restored := GameState.use_mana_potion()
	if restored > 0:
		Audio.play_sfx("drink")
		FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), "+%d" % restored, GameState.MANA_COLOR)


func _on_player_died() -> void:
	_set_state(State.DEAD)
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
			_set_state(State.NORMAL)
		State.SKILL:
			if not _hit_done:
				_deal_skill_damage()
			_set_state(State.NORMAL)
		State.HURT:
			_set_state(State.NORMAL)


func _flash(color: Color = Color(1, 0.4, 0.4)) -> void:
	modulate = color
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.2)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
