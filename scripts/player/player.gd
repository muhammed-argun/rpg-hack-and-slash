class_name Player
extends CharacterBody2D
## Oyuncu karakteri (şimdilik Warrior): hareket, saldırı, alan yeteneği, blok/parry, yuvarlanma,
## iksirler ve NPC'lerle etkileşim.
## Girdi aksiyonları: move_left/right/up/down, attack, interact, skill_1, block, dodge, quick_slot_1,
## quick_slot_2 (klavye ve gamepad aynı aksiyonları tetikler; atamalar Controls autoload'unda).
## Yakında bir NPC varsa etkileşim tuşu (interact) konuşmayı başlatır.

signal interactable_changed(interactable: Interactable)

enum State { NORMAL, ATTACK, SKILL, BLOCK, DODGE, HURT, STAGGER, DEAD }

# Joystick'teki çok küçük yatay sapmalar karakteri döndürmesin diye
const TURN_THRESHOLD := 0.1
const NO_RESOURCE_MESSAGE_INTERVAL := 1.5
## Sağ çubuk bu kadar itilince nişan çubuktan alınır
const AIM_STICK_THRESHOLD := 0.35
## Düşman çarpışma katmanı (3. katman). Dash sırasında maskeden çıkarılır: düşmanların içinden geçilir.
const ENEMY_LAYER := 4
## Dash bir düşmanın içinde biterse en fazla bu kadar saniye daha kayarak dışarı çıkar
const DASH_EXIT_TIME := 0.25
## Nişanın ölçüldüğü nokta: karakterin gövdesi (ayak değil)
const AIM_ORIGIN_OFFSET := Vector2(0, -8)
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
## Son nişan yönü (saldırı, ileride ok ve büyüler). Güncel değer için get_aim_direction() kullan.
var aim_direction: Vector2 = Vector2.RIGHT
## Son hareket yönü; yuvarlanma bu yöne gider (Hades'teki gibi)
var move_direction: Vector2 = Vector2.RIGHT
## Yeteneklerin tekrar kullanılabilmesine kalan süre: yetenek id'si -> saniye
var skill_cooldowns := {}
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
var _dash_exit_time := 0.0
var _shield_icon: Sprite2D
var _aim_marker: AimMarker
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
	_aim_marker = AimMarker.new()
	add_child(_aim_marker)


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
	for id: String in skill_cooldowns:
		skill_cooldowns[id] = maxf(0.0, skill_cooldowns[id] - delta)
	_no_resource_timer = maxf(0.0, _no_resource_timer - delta)
	_invulnerable_time = maxf(0.0, _invulnerable_time - delta)
	_update_interactable()
	if state != State.DEAD:
		if Input.is_action_just_pressed("swap_weapons"):
			GameState.swap_weapon_set()
		for i in GameState.QUICK_SLOT_COUNT:
			if Input.is_action_just_pressed("quick_slot_%d" % (i + 1)):
				_use_consumable(GameState.quick_slots[i])

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
		move_direction = input.normalized()
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
	for i in GameState.SKILL_SLOT_COUNT:
		if Input.is_action_just_pressed("skill_%d" % (i + 1)) and _try_use_skill(GameState.skill_slots[i]):
			return
	# Yakında NPC varsa etkileşim tuşu konuşmayı başlatır
	if current_interactable and Input.is_action_just_pressed("interact"):
		velocity = Vector2.ZERO
		current_interactable.interact(self)
		return
	# Basılı tutulduğu sürece saldırmaya devam eder (fare bir arayüz butonunun üstündeyse saldırmaz)
	if Input.is_action_pressed("attack") and not _pointer_over_ui():
		_start_attack()
		return

	velocity = input * move_speed
	sprite.play_directional("walk" if input != Vector2.ZERO else "idle", facing)


# --- Nişan ------------------------------------------------------------------

## Nişan yönü; saldırı (ve ileride ok, büyü) bunu kullanır. Fareyle oynanıyorsa karakterden imlece.
## Gamepad'de sağ çubuğun yönü; çubuk bırakılmışsa hareket yönü, o da yoksa son nişan yönü.
func get_aim_direction() -> Vector2:
	if Controls.using_gamepad:
		var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if stick.length() > AIM_STICK_THRESHOLD:
			aim_direction = stick.normalized()
		else:
			var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if move != Vector2.ZERO:
				aim_direction = move.normalized()
	else:
		var to_mouse := get_global_mouse_position() - (global_position + AIM_ORIGIN_OFFSET)
		if to_mouse.length() > 2.0:
			aim_direction = to_mouse.normalized()
	return aim_direction


## Görseli nişanın olduğu yana çevirir (yalnızca sağ/sol görsel var)
func _face(direction: Vector2) -> void:
	if direction.x > TURN_THRESHOLD:
		facing = "right"
	elif direction.x < -TURN_THRESHOLD:
		facing = "left"


# Fare bir arayüz öğesinin (ör. çanta butonu) üstündeyse sol tık saldırı sayılmaz
func _pointer_over_ui() -> bool:
	return not Controls.using_gamepad and get_viewport().gui_get_hovered_control() != null


# --- Saldırı ----------------------------------------------------------------

func _start_attack() -> void:
	_set_state(State.ATTACK)
	_hit_done = false
	velocity = Vector2.ZERO
	var aim := get_aim_direction()
	_face(aim)
	attack_area.position = aim * attack_reach + AIM_ORIGIN_OFFSET
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


## Yeteneğin mana bedeli (HUD'daki yetenek çubuğu da gösterir).
func get_skill_mana_cost(id: String) -> int:
	match id:
		"ground_slam":
			return skill_mana_cost
	return 0


## Yeteneğin toplam bekleme süresi.
func get_skill_cooldown_duration(id: String) -> float:
	match id:
		"ground_slam":
			return skill_cooldown
	return 0.0


## Yeteneğin tekrar kullanılabilmesine kalan süre.
func get_skill_cooldown(id: String) -> float:
	return skill_cooldowns.get(id, 0.0)


# Yuvadaki yeteneği kullanmayı dener (boş yuva ya da bekleme süresi dolmamışsa false)
func _try_use_skill(id: String) -> bool:
	if id.is_empty() or get_skill_cooldown(id) > 0.0:
		return false
	match id:
		"ground_slam":
			return _try_start_ground_slam()
	push_warning("Player: bilinmeyen yetenek %s" % id)
	return false


func _start_skill_cooldown(id: String, duration: float) -> void:
	skill_cooldowns[id] = duration
	GameState.skill_cooldown_started.emit(id, duration)


# Yer Sarsıntısı: kılıcı yere saplayıp çevredeki bütün düşmanlara vurur
func _try_start_ground_slam() -> bool:
	if not GameState.spend_mana(skill_mana_cost):
		_warn("MSG_NO_MANA", GameState.MANA_COLOR)
		return false
	_set_state(State.SKILL)
	_hit_done = false
	velocity = Vector2.ZERO
	_start_skill_cooldown("ground_slam", skill_cooldown)
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
	_face(get_aim_direction())
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
	move_direction = direction
	_set_state(State.DODGE)
	# Dash/yuvarlanma sırasında düşmanların (boss'lar dahil) içinden geçilir; duvarlardan geçilmez
	collision_mask &= ~ENEMY_LAYER
	_dash_exit_time = 0.0
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
	velocity = move_direction * dodge_speed * clampf(_state_timer / dodge_time + 0.3, 0.3, 1.0)
	if _state_timer <= 0.0:
		# Bir düşmanın içinde bittiyse biraz daha kayarak arkasına çık
		if _dash_exit_time < DASH_EXIT_TIME and _overlapping_enemy():
			_dash_exit_time += delta
			velocity = move_direction * dodge_speed * 0.5
			return
		_set_state(State.NORMAL)


# Oyuncunun gövdesi şu an bir düşmanın gövdesiyle iç içe mi
func _overlapping_enemy() -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision.shape
	query.transform = collision.global_transform
	query.collision_mask = ENEMY_LAYER
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


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
	skill_cooldowns.clear()
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
		collision_mask |= ENEMY_LAYER
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


# Hızlı kullanım yuvasındaki eşyayı kullanır
func _use_consumable(id: String) -> void:
	match id:
		"health_potion":
			_use_health_potion()
		"mana_potion":
			_use_mana_potion()


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
