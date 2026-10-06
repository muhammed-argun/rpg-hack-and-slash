class_name Boss
extends Enemy
## Boss altyapısı. Enemy'nin hareket/saldırı mekaniklerini kullanır, üstüne şunları ekler:
##   - attacks listesinden faza ve mesafeye göre ağırlıklı saldırı seçimi (BossAttack)
##   - 2. faz (canı phase2_threshold altına inince hızlanır, yeni saldırılar açılır)
##   - ekranın üstünde boss can barı (HUD, GameState.boss_started sinyaliyle)
##   - ölünce kristal parçası, büyük sandık, görev bildirimi ve kalıcı "yenildi" bayrağı
##   - next_boss_scene: Kral -> Malphas gibi art arda gelen dövüşler
## Boss, bir BossArena içinde durur ve arena tetiklenince activate() ile uyanır.

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)

const CHEST_SCENE := preload("res://scenes/objects/chest.tscn")

## Kayıt ve görevlerde kullanılan kimlik (ör. "fenris")
@export var boss_id: String = ""
## Ünvanın çeviri anahtarı (ör. "BOSS_FENRIS_TITLE")
@export var title_key: String = ""
@export var attacks: Array[BossAttack] = []
@export_range(0.1, 0.9) var phase2_threshold: float = 0.5
@export var phase2_speed_multiplier: float = 1.25
## Yenilince kristal parçası verir mi (Kral'ın 1. fazı vermez, Malphas'a geçer)
@export var gives_shard: bool = true
@export var loot_level: int = 3
## Doluysa bu boss ölünce bu sahne aynı yerde başlar (ikinci faz dövüşü)
@export var next_boss_scene: PackedScene

var phase := 1
var active := false
var _current_attack: BossAttack
var _combo_left := 0


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	# Boss'un canı ekranın üstündeki büyük barda gösterilir
	health_bar.modulate.a = 0.0
	detect_radius = 0.0


func get_display_name() -> String:
	return tr(name_key)


func activate() -> void:
	if active or state == State.DEAD:
		return
	active = true
	_cooldown = 1.0
	Audio.play_sfx("boss_roar", 0.0)
	Audio.play_music("final_boss" if boss_id in ["aldric", "malphas"] else "boss")
	GameState.boss_started.emit(self)
	health_changed.emit(hp, max_hp)


func _update_movement() -> void:
	if not active or _distance_to_player() == INF:
		state = State.IDLE
		velocity = Vector2.ZERO
		sprite.play_directional("idle", facing)
		return
	state = State.CHASE
	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if _cooldown <= 0.0:
		var attack := _pick_attack(distance)
		if attack:
			_face(to_player)
			_execute(attack)
			return
	if distance > attack_range * 0.9:
		velocity = to_player.normalized() * move_speed
		_face(to_player)
		sprite.play_directional("walk", facing)
	else:
		velocity = Vector2.ZERO
		_face(to_player)
		sprite.play_directional("idle", facing)


func _pick_attack(distance: float) -> BossAttack:
	var candidates: Array[BossAttack] = []
	var total := 0.0
	for attack in attacks:
		if attack.min_phase <= phase and distance >= attack.min_range and distance <= attack.max_range:
			candidates.append(attack)
			total += attack.weight
	if candidates.is_empty():
		return null
	var roll := randf() * total
	for attack in candidates:
		roll -= attack.weight
		if roll <= 0.0:
			return attack
	return candidates.back()


func _execute(attack: BossAttack) -> void:
	_current_attack = attack
	match attack.type:
		BossAttack.Type.MELEE:
			attack_kind = attack.kind
			damage = attack.damage
			attack_hit_frame = attack.hit_frame
			attack_range = maxf(attack.max_range, 20.0)
			_combo_left = attack.combo_hits - 1
			_start_attack()
		BossAttack.Type.SLAM, BossAttack.Type.RING:
			special = Special.SLAM
			special_kind = attack.kind
			special_damage = attack.damage
			special_radius = attack.radius
			special_offset = 0.0 if attack.type == BossAttack.Type.RING else attack.offset
			special_windup = attack.windup
			special_hit_frame = attack.hit_frame
			_start_special()
		BossAttack.Type.CHARGE:
			special = Special.CHARGE
			special_kind = attack.kind
			special_damage = attack.damage
			special_radius = attack.radius
			special_windup = attack.windup
			special_hit_frame = attack.hit_frame
			charge_speed = attack.charge_speed
			charge_distance = attack.charge_distance
			_start_special()
		BossAttack.Type.SUMMON:
			_start_summon(attack)
		BossAttack.Type.PROJECTILE:
			_start_cast(attack, _fire_projectiles.bind(attack))
		BossAttack.Type.TELEPORT:
			_start_teleport(attack)
		BossAttack.Type.BARRAGE:
			_start_barrage(attack)
		BossAttack.Type.LINE:
			_start_line(attack)
	_cooldown = attack.recovery + 0.6


func _start_summon(attack: BossAttack) -> void:
	state = State.SPECIAL
	velocity = Vector2.ZERO
	_start_glow(Color(0.8, 0.5, 1.0))
	sprite.play_directional("special" if sprite.has_directional("special") else "idle", facing, true)
	# Çağrılacak yerlerde küçük uyarılar
	var spots: Array[Vector2] = []
	for i in attack.summon_count:
		var angle := TAU * i / attack.summon_count + randf() * 0.5
		spots.append(global_position + Vector2(cos(angle), sin(angle)) * 36.0)
		AreaTelegraph.circle(spots[i], 10.0, attack.windup, Combat.Kind.NORMAL)
	var tween := create_tween()
	tween.tween_interval(attack.windup)
	tween.tween_callback(_finish_summon.bind(attack, spots))


func _finish_summon(attack: BossAttack, spots: Array[Vector2]) -> void:
	if state != State.SPECIAL:
		return
	_stop_glow()
	for effect in Map.current.ground_effects.get_children() if Map.current else []:
		if effect is AreaTelegraph and spots.has(effect.position):
			(effect as AreaTelegraph).detonate()
	if attack.summon_scene:
		for spot in spots:
			var minion := attack.summon_scene.instantiate() as Node2D
			get_parent().add_child(minion)
			minion.global_position = spot
			if minion is Enemy:
				# Çağrılan yardımcılar görev sayımına girmez ve hemen saldırır
				(minion as Enemy).enemy_id = ""
				(minion as Enemy).detect_radius = 400.0
	state = State.CHASE


# --- Büyü türü saldırılar (hazırlık + etki) --------------------------------------

## Kısa bir hazırlıktan (parlama + animasyon) sonra effect çağrılır.
func _start_cast(attack: BossAttack, effect: Callable) -> void:
	state = State.SPECIAL
	velocity = Vector2.ZERO
	_start_glow(Combat.KIND_COLORS[attack.kind])
	var anim := attack.animation if sprite.has_directional(attack.animation) else "idle"
	sprite.play_directional(anim, facing, true)
	var tween := create_tween()
	tween.tween_interval(attack.windup)
	tween.tween_callback(func() -> void:
		if state != State.SPECIAL:
			return
		_stop_glow()
		effect.call()
		state = State.CHASE)


func _fire_projectiles(attack: BossAttack) -> void:
	if _distance_to_player() == INF:
		return
	var origin := global_position + Vector2(0, -14)
	var base := origin.direction_to(_player.global_position + Vector2(0, -8))
	for i in attack.count:
		var t := 0.0 if attack.count == 1 else float(i) / (attack.count - 1) - 0.5
		var direction := base.rotated(deg_to_rad(attack.spread) * t)
		Projectile.spawn(origin, direction, attack.projectile_speed, attack.damage, attack.kind, attack.projectile_color, attack.homing)


func _start_teleport(attack: BossAttack) -> void:
	state = State.SPECIAL
	velocity = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if state == State.DEAD or _distance_to_player() == INF:
			return
		var angle := randf() * TAU
		global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * attack.teleport_distance
		Shockwave.spawn(global_position + Vector2(0, -6), 20.0, Color(0.7, 0.5, 1.0)))
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func() -> void:
		if state == State.SPECIAL:
			state = State.CHASE
			# Işınlandıktan hemen sonra saldırabilsin
			_cooldown = minf(_cooldown, 0.3))


## Oyuncunun çevresine art arda düşen alan vuruşları (meteor, kemik kafes, kan yağmuru).
func _start_barrage(attack: BossAttack) -> void:
	_start_cast(attack, func() -> void: pass)
	if _distance_to_player() == INF:
		return
	var effects := Map.current.ground_effects if Map.current else null
	if effects == null:
		return
	for i in attack.count:
		var offset := Vector2.ZERO if i == 0 else Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.3, 1.0) * attack.spread
		# Gecikmeli vuruşlar haritaya bağlı çalışır; boss bu sırada ölse bile yağmur tamamlanır
		var tween := effects.create_tween()
		tween.tween_interval(i * 0.18)
		tween.tween_callback(Boss._barrage_strike.bind(get_tree(), attack, _player.global_position + offset))


static func _barrage_strike(tree: SceneTree, attack: BossAttack, spot: Vector2) -> void:
	if Map.current == null:
		return
	var telegraph := AreaTelegraph.circle(spot, attack.radius, attack.windup, attack.kind)
	var tween := telegraph.create_tween()
	tween.tween_interval(attack.windup)
	tween.tween_callback(func() -> void:
		telegraph.detonate()
		Shockwave.spawn(spot, attack.radius, Combat.KIND_COLORS[attack.kind])
		var player := tree.get_first_node_in_group("player") as Player
		if player and player.is_inside_tree() and player.global_position.distance_to(spot) <= attack.radius:
			player.take_damage(attack.damage, null, attack.kind))

## Boss'tan oyuncuya doğru çizgi: önce uyarı, sonra çizgi boyunca vuruş (ışın, yer yarığı).
func _start_line(attack: BossAttack) -> void:
	if _distance_to_player() == INF:
		return
	var origin := global_position
	var direction := origin.direction_to(_player.global_position)
	var end := origin + direction * attack.length
	var telegraph := AreaTelegraph.line(origin, end, attack.radius * 2.0, attack.windup, attack.kind)
	_start_cast(attack, func() -> void:
		if is_instance_valid(telegraph):
			telegraph.detonate()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player == null or not player.is_inside_tree():
			return
		var closest := Geometry2D.get_closest_point_to_segment(player.global_position, origin, end)
		if closest.distance_to(player.global_position) <= attack.radius:
			player.take_damage(attack.damage, null, attack.kind)
			player.shake(2.0, 0.2))


func take_damage(amount: int, crit: bool, from_position: Vector2, knockback_scale: float = 1.0, poise_scale: float = 1.0) -> void:
	if not active or state == State.DEAD:
		return
	# Boss'lar geri savrulmaz
	super.take_damage(amount, crit, from_position, 0.0, poise_scale)
	health_changed.emit(maxi(hp, 0), max_hp)
	if phase == 1 and hp > 0 and hp <= max_hp * phase2_threshold:
		_enter_phase(2)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	move_speed *= phase2_speed_multiplier
	sprite.speed_scale = 1.15
	Shockwave.spawn(global_position + Vector2(0, -6), 50.0, Color(1.0, 0.4, 0.3))
	if _player:
		_player.shake(3.0, 0.3)
	phase_changed.emit(phase)


func _on_sprite_animation_finished() -> void:
	# Kombo: aynı saldırıyı birkaç kez arka arkaya yap
	if state == State.ATTACK and _combo_left > 0:
		if not _hit_done:
			_try_hit_player()
		_combo_left -= 1
		_hit_done = false
		sprite.play_directional("attack", facing, true)
		return
	super._on_sprite_animation_finished()


func _die() -> void:
	super._die()
	active = false
	if next_boss_scene:
		# İkinci faz dövüşü (ör. Kral -> Malphas). Bu boss ölüm animasyonundan sonra silineceği için
		# başlatma ona bağlı olmayan statik bir fonksiyonla yapılır.
		GameState.boss_ended.emit(self)
		var tween := get_tree().create_tween()
		tween.tween_interval(1.8)
		tween.tween_callback(Boss._spawn_next.bind(next_boss_scene, get_parent(), global_position))
		return
	GameState.set_flag("boss_" + boss_id)
	if boss_id == "malphas":
		# Son boss: oyun sonu (HUD bu bayrağı dinleyip bitiş ekranını gösterir)
		GameState.set_flag("game_completed")
	if gives_shard:
		GameState.add_shard(boss_id)
	Quests.notify("boss", boss_id)
	GameState.message.emit(tr("MSG_BOSS_DEFEATED") % get_display_name(), Color(1.0, 0.85, 0.4))
	var chest := CHEST_SCENE.instantiate() as Chest
	chest.loot_level = loot_level
	get_parent().add_child.call_deferred(chest)
	chest.set_deferred("global_position", global_position)
	GameState.boss_ended.emit(self)


static func _spawn_next(scene: PackedScene, parent: Node, at: Vector2) -> void:
	if not is_instance_valid(parent):
		return
	var next := scene.instantiate() as Boss
	parent.add_child(next)
	next.global_position = at
	Shockwave.spawn(at + Vector2(0, -6), 70.0, Color(1.0, 0.3, 0.2))
	next.activate()
