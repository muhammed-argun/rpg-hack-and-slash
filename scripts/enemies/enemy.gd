class_name Enemy
extends CharacterBody2D
## Yakın dövüş düşmanı: oyuncuyu görünce kovalar, menzile girince saldırır,
## oyuncu uzaklaşırsa başladığı noktaya döner.
## İsteğe bağlı bir özel saldırısı vardır ("special" animasyonu):
##   SLAM:   yerde uyarı alanı belirir, kısa bir hazırlıktan sonra alandaki oyuncuya vurur
##   CHARGE: hücum yolu gösterilir, sonra o yönde hızla atılır
## Saldırı türleri (Combat.Kind): normal saldırılar bloklanabilir; özel saldırı ağır (turuncu) veya
## engellenemez (kırmızı) olabilir. Parry'lenen ya da dengesi (poise) kırılan düşman sersemler.
## Yeni düşman türü için: mevcut bir düşman sahnesini kopyala, Sprite'ın sprite_folder'ını ve değerleri değiştir.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, RETURN, ATTACK, SPECIAL, CHARGING, HURT, STUNNED, DEAD }
enum Special { NONE, SLAM, CHARGE }

## Görevlerde kullanılan tür kimliği (ör. "orc"); data/quests.json'daki kill hedefleriyle eşleşir
@export var enemy_id: String = ""
## Ekranda gösterilen adın çeviri anahtarı
@export var name_key: String = ""
@export var max_hp: int = 40
## Öldürülünce oyuncuya verilen deneyim
@export var xp_reward: int = 10
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
@export var attack_kind: Combat.Kind = Combat.Kind.NORMAL

@export_group("Denge (Poise)")
## Bu kadar hasar birikince düşman sersemler; vuruş almadan poise_recover_delay geçerse sıfırlanır
@export var poise: float = 30.0
@export var poise_recover_delay: float = 2.5
@export var stun_time: float = 1.5
## Sersemlemiş düşmanın aldığı hasar katı
@export var stunned_damage_multiplier: float = 1.5

@export_group("Özel Saldırı")
@export var special: Special = Special.NONE
@export var special_kind: Combat.Kind = Combat.Kind.HEAVY
@export var special_damage: int = 16
@export var special_cooldown: float = 6.0
## Oyuncu bu mesafe aralığındayken özel saldırı denenir
@export var special_min_range: float = 0.0
@export var special_max_range: float = 50.0
## SLAM: vuruş alanının yarıçapı. CHARGE: hücum sırasında çarpma yarıçapı
@export var special_radius: float = 32.0
## SLAM: vuruş alanının merkezi düşmanın baktığı yöne bu kadar kayar
@export var special_offset: float = 0.0
## Uyarı alanı göründükten sonra vuruşa kadar beklenen ek süre (oyuncunun kaçma fırsatı)
@export var special_windup: float = 0.6
## "special" animasyonunun kaçıncı karesinde vurulacağı / hücumun başlayacağı (0'dan başlar)
@export var special_hit_frame: int = 3
@export var charge_speed: float = 260.0
@export var charge_distance: float = 110.0

var hp: int
var state: State = State.IDLE
## Görselin baktığı yön: "right" ya da "left"
var facing: String = "right"
var _home: Vector2
var _cooldown := 0.0
var _special_cooldown := 0.0
var _hit_done := false
var _knockback := Vector2.ZERO
var _player: Player
var _telegraph: AreaTelegraph
var _special_center := Vector2.ZERO
var _charge_direction := Vector2.ZERO
var _charge_time := 0.0
var _windup_held := false
var _poise_damage := 0.0
var _poise_timer := 0.0
var _stun_timer := 0.0
var _glow_tween: Tween
# Sahnede verilen renk tonu (yanıp sönme bitince geri dönülür)
var _base_modulate := Color.WHITE
var _agent: NavigationAgent2D
var _path_timer := 0.0

@onready var sprite: CharacterSprite = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var health_bar: HealthBar2D = $HealthBar


func _ready() -> void:
	hp = max_hp
	_base_modulate = sprite.modulate
	_agent = NavigationAgent2D.new()
	_agent.path_desired_distance = 6.0
	_agent.target_desired_distance = 8.0
	_agent.radius = 7.0
	add_child(_agent)
	_home = global_position
	# Bölükteki düşmanlar özel saldırıyı aynı anda yapmasın
	_special_cooldown = randf_range(1.5, special_cooldown)
	add_to_group("enemies")
	sprite.frame_changed.connect(_on_sprite_frame_changed)
	sprite.animation_finished.connect(_on_sprite_animation_finished)
	sprite.play_directional("idle", facing)
	health_bar.set_ratio(1.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	_poise_timer -= delta
	if _poise_timer <= 0.0:
		_poise_damage = 0.0
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player

	match state:
		State.IDLE, State.CHASE, State.RETURN:
			_update_movement()
		State.CHARGING:
			_update_charge(delta)
		State.STUNNED:
			velocity = Vector2.ZERO
			_stun_timer -= delta
			if _stun_timer <= 0.0:
				_end_stun()
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
		var to_player := _player.global_position - global_position
		if _can_use_special(distance):
			_face(to_player)
			_start_special()
			return
		if distance <= attack_range:
			velocity = Vector2.ZERO
			_face(to_player)
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

	var direction := _direction_towards(target)
	velocity = direction * move_speed
	_face(direction)
	sprite.play_directional("walk", facing)


# Hedefe giden yolun bir sonraki noktasına doğru yön (engellerin etrafından dolaşır).
# Navigasyon hazır değilse ya da yol bulunamazsa doğrudan hedefe yönelir.
func _direction_towards(target: Vector2) -> Vector2:
	_path_timer -= get_physics_process_delta_time()
	if _path_timer <= 0.0 or _agent.target_position.distance_to(target) > 24.0:
		_agent.target_position = target
		_path_timer = 0.25
	if NavigationServer2D.map_get_iteration_id(_agent.get_navigation_map()) == 0 or _agent.is_navigation_finished():
		return global_position.direction_to(target)
	var next := _agent.get_next_path_position()
	if next.distance_to(global_position) < 0.5:
		return global_position.direction_to(target)
	return global_position.direction_to(next)


func take_damage(amount: int, crit: bool, from_position: Vector2, knockback_scale: float = 1.0, poise_scale: float = 1.0) -> void:
	if state == State.DEAD:
		return
	if state == State.STUNNED:
		amount = roundi(amount * stunned_damage_multiplier)
	hp -= amount
	health_bar.set_ratio(float(hp) / max_hp)
	var text := str(amount) + ("!" if crit else "")
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -28), text, Color(1, 0.85, 0.2) if crit else Color.WHITE)
	_flash()
	if hp <= 0:
		_die()
		return
	if state == State.STUNNED:
		return
	# Denge: yeterince hasar birikince sersemler (özel saldırı sırasında bile)
	_poise_damage += amount * poise_scale
	_poise_timer = poise_recover_delay
	if _poise_damage >= poise:
		stun()
		return
	# Özel saldırı sırasında düşman sendelemez ve geri savrulmaz
	if state == State.SPECIAL or state == State.CHARGING:
		return
	_knockback = from_position.direction_to(global_position) * knockback_force * knockback_scale
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
		_player.take_damage(damage, self, attack_kind)


# --- Özel saldırı ----------------------------------------------------------

func _can_use_special(distance: float) -> bool:
	return special != Special.NONE and _special_cooldown <= 0.0 \
		and distance >= special_min_range and distance <= special_max_range


func _start_special() -> void:
	state = State.SPECIAL
	_hit_done = false
	_windup_held = false
	_special_cooldown = special_cooldown
	velocity = Vector2.ZERO
	var forward := Vector2.RIGHT if facing == "right" else Vector2.LEFT
	var warn_time := special_windup + _time_until_hit_frame()
	match special:
		Special.SLAM:
			_special_center = global_position + forward * special_offset + Vector2(0, -2)
			_telegraph = AreaTelegraph.circle(_special_center, special_radius, warn_time, special_kind)
		Special.CHARGE:
			_charge_direction = global_position.direction_to(_player.global_position)
			_face(_charge_direction)
			var end := global_position + _charge_direction * charge_distance
			_telegraph = AreaTelegraph.line(global_position, end, special_radius * 2.0, warn_time, special_kind)
	_start_glow(Combat.KIND_COLORS[special_kind])
	Audio.play_sfx("telegraph")
	sprite.play_directional("special", facing, true)
	if not sprite.has_directional("special"):
		# Görsel yoksa yalnızca hazırlık süresi kadar bekle
		_hold_windup()


# Animasyonun vuruş karesine gelmesine kalan süre (uyarı alanının dolma süresi için)
func _time_until_hit_frame() -> float:
	var anim_name := "special_right"
	if not sprite.sprite_frames.has_animation(anim_name):
		return 0.0
	var fps := sprite.sprite_frames.get_animation_speed(anim_name)
	return special_hit_frame / fps if fps > 0.0 else 0.0


# Vuruştan hemen önceki karede animasyonu durdurup hazırlık süresi kadar bekletir
func _hold_windup() -> void:
	_windup_held = true
	sprite.pause()
	var tween := create_tween()
	tween.tween_interval(special_windup)
	tween.tween_callback(_release_windup)


func _release_windup() -> void:
	if state != State.SPECIAL:
		return
	if sprite.has_directional("special"):
		sprite.play()
	else:
		_special_hit()


func _special_hit() -> void:
	_hit_done = true
	_stop_glow()
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.detonate()
		_telegraph = null
	match special:
		Special.SLAM:
			Shockwave.spawn(_special_center, special_radius, Color(1.0, 0.45, 0.35))
			Audio.play_sfx("enemy_slam")
			if _player and _player.state != Player.State.DEAD and _player.is_inside_tree() \
					and _player.global_position.distance_to(_special_center) <= special_radius:
				if _player.take_damage(special_damage, self, special_kind) == Combat.Result.HIT:
					_player.shake(2.0, 0.2)
			if not sprite.has_directional("special"):
				state = State.CHASE
		Special.CHARGE:
			state = State.CHARGING
			_charge_time = charge_distance / charge_speed


func _update_charge(delta: float) -> void:
	velocity = _charge_direction * charge_speed
	_charge_time -= delta
	# Hücum sırasında oyuncuya bir kez çarpabilir
	if not _hit_done and _distance_to_player() <= special_radius:
		_hit_done = true
		if _player.take_damage(special_damage, self, special_kind) == Combat.Result.HIT:
			_player.shake(1.5, 0.15)
	if _charge_time <= 0.0:
		velocity = Vector2.ZERO
		state = State.CHASE


func _cancel_special() -> void:
	_stop_glow()
	if _telegraph and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


# --- Parry ve sersemleme -----------------------------------------------------

## Oyuncu bu düşmanın saldırısını parry'leyince çağrılır.
func on_parried() -> void:
	if state != State.DEAD:
		stun()


## Düşmanı stun_time saniye sersemletir; bu sürede daha fazla hasar alır.
func stun() -> void:
	if state == State.DEAD:
		return
	_cancel_special()
	state = State.STUNNED
	_stun_timer = stun_time
	_poise_damage = 0.0
	velocity = Vector2.ZERO
	FloatingText.spawn(get_parent(), global_position + Vector2(0, -38), tr("MSG_STAGGER"), Color(1.0, 0.85, 0.3))
	sprite.play_directional("hurt" if sprite.has_directional("hurt") else "idle", facing, true)
	# Sersemlemiş düşman sarımsı yanıp söner
	_start_glow(Color(1.0, 0.95, 0.4), 0.25)


func _end_stun() -> void:
	_stop_glow()
	state = State.CHASE


# Özel saldırı hazırlığında ya da sersemlemede düşman renkli yanıp söner
func _start_glow(color: Color, period: float = 0.15) -> void:
	_stop_glow()
	_glow_tween = sprite.create_tween().set_loops()
	_glow_tween.tween_property(sprite, "modulate", color.lightened(0.3), period)
	_glow_tween.tween_property(sprite, "modulate", _base_modulate, period)


func _stop_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null
	sprite.modulate = _base_modulate


# --- Ölüm ve yardımcılar ---------------------------------------------------

func _die() -> void:
	_cancel_special()
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	health_bar.hide()
	died.emit(self)
	Audio.play_sfx("enemy_death")
	GameState.add_xp(xp_reward)
	if not enemy_id.is_empty():
		Quests.notify("kill", enemy_id)
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
	match state:
		State.ATTACK:
			if not _hit_done and sprite.frame >= mini(attack_hit_frame, sprite.get_current_frame_count() - 1):
				_try_hit_player()
		State.SPECIAL:
			var hit_frame := mini(special_hit_frame, sprite.get_current_frame_count() - 1)
			if not _windup_held and sprite.frame >= hit_frame - 1:
				_hold_windup()
			elif _windup_held and not _hit_done and sprite.frame >= hit_frame:
				_special_hit()


func _on_sprite_animation_finished() -> void:
	match state:
		State.ATTACK:
			if not _hit_done:
				_try_hit_player()
			state = State.CHASE
		State.SPECIAL:
			if not _hit_done:
				_special_hit()
			if state == State.SPECIAL:
				state = State.CHASE
		State.HURT:
			state = State.CHASE
		State.DEAD:
			_fade_out()
