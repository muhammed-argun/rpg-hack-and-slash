class_name Boss
extends Enemy
## Boss altyapısı. Enemy'nin hareket/saldırı mekaniklerini kullanır, üstüne şunları ekler:
##   - attacks listesinden faza ve mesafeye göre ağırlıklı saldırı seçimi (BossAttack)
##   - 2. faz (canı phase2_threshold altına inince hızlanır, yeni saldırılar açılır) ve isteğe bağlı
##     3. faz (phase3_threshold > 0). Faza özel saldırı: BossAttack.min_phase; faz açılışı: phase_opener
##   - saldırı bekleme süresi (BossAttack.cooldown); çağırma yardımcılar yaşarken de yapılır (en fazla MAX_MINIONS canlı)
##   - boss'lar yetenekle (Yer Sarsıntısı) sersemlemez; yalnızca parry sersemletir
##   - ekranın üstünde boss can barı (HUD, GameState.boss_started sinyaliyle)
##   - ölünce kristal parçası, büyük sandık, görev bildirimi ve kalıcı "yenildi" bayrağı
##   - next_boss_scene: Kral -> Malphas gibi art arda gelen dövüşler
## Boss, bir BossArena içinde durur ve arena tetiklenince activate() ile uyanır.

signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)

const CHEST_SCENE := preload("res://scenes/objects/chest.tscn")
## Yağmur vuruşlarının uyarı alanlarına yazılan sahip boss kimliği (meta anahtarı)
const OWNER_META := &"owner_boss"
## Çağırma işaretinin (yardımcının doğacağı yer) yarıçapı; patlama daireleri bunun 2 katıdır
const SUMMON_MARKER_RADIUS := 10.0
## Yardımcıların boss çevresinde doğduğu halkanın yarıçapı
const SUMMON_RING_RADIUS := 44.0
## Boss'a ait aynı anda en fazla bu kadar canlı yardımcı olabilir (çağırma sınırsız birikmesin)
const MAX_MINIONS := 8

## Kayıt ve görevlerde kullanılan kimlik (ör. "fenris")
@export var boss_id: String = ""
## Ünvanın çeviri anahtarı (ör. "BOSS_FENRIS_TITLE")
@export var title_key: String = ""
@export var attacks: Array[BossAttack] = []
@export_range(0.1, 0.9) var phase2_threshold: float = 0.5
## 0 = 3. faz yok; doluysa can bu orana inince 3. faz başlar (phase2_threshold'dan küçük olmalı)
@export_range(0.0, 0.9) var phase3_threshold: float = 0.0
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
## Bu boss'un hazırladığı ve henüz patlamamış uyarı alanları (çağırma işaretleri, çizgi uyarısı);
## saldırı bölünür ya da boss ölürse temizlenir
var _attack_telegraphs: Array[AreaTelegraph] = []
var _barrage_tweens: Array[Tween] = []
## Hazırlık süresi süren büyü/çağırma/ışınlanma sırasında true. Bu sırada State.SPECIAL'ı sprite
## olayları (kare/animasyon bitişi) yönetmez; yoksa "special" animasyonu bitince durum bozulur ve
## çağırma/büyü etkisi hiç gerçekleşmezdi.
var _casting := false
## Her büyü/çağırma başlangıcında artar; bölünen (iptal edilen) bir hazırlığın geciken çağrısı bunu kıyaslayıp çıkar
var _cast_id := 0
var _clock := 0.0
## Saldırı -> yeniden seçilebileceği an (_clock cinsinden)
var _attack_ready := {}
## Faz açılışında bir sonraki saldırı olarak zorlanan saldırı
var _forced_attack: BossAttack
## Çağırdığı yardımcılar (tekrar çağırma sınırı için canlı olanlar sayılır)
var _minions: Array[Enemy] = []


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	# Boss'un canı ekranın üstündeki büyük barda gösterilir
	health_bar.modulate.a = 0.0
	detect_radius = 0.0


func get_display_name() -> String:
	return tr(name_key)


func _physics_process(delta: float) -> void:
	_clock += delta
	super._physics_process(delta)


## Boss'lar Yer Sarsıntısı'ndan sersemlemez (parry hâlâ sersemletir: on_parried -> stun)
func can_be_staggered() -> bool:
	return false


## Çağırdığı ve hâlâ yaşayan yardımcıların sayısı
func alive_minion_count() -> int:
	var count := 0
	for minion in _minions:
		if is_instance_valid(minion) and minion.state != Enemy.State.DEAD:
			count += 1
	return count


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
	# Faz açılışı: yeni fazın imza saldırısı (çağırma, patlama daireleri) hemen yapılır
	if _forced_attack:
		var forced := _forced_attack
		_forced_attack = null
		if _attack_available(forced):
			return forced
	var candidates: Array[BossAttack] = []
	var total := 0.0
	for attack in attacks:
		if attack.min_phase <= phase and distance >= attack.min_range and distance <= attack.max_range \
				and _attack_available(attack):
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


# Bekleme süresi dolmuş mu; çağırma yardımcılar yaşıyor olsa da yapılır (bekleme süresi dolunca),
# ama taşmayı önlemek için aynı anda en fazla MAX_MINIONS yardımcı olabilir
func _attack_available(attack: BossAttack) -> bool:
	if _attack_ready.get(attack, 0.0) > _clock:
		return false
	if attack.type == BossAttack.Type.SUMMON and alive_minion_count() >= MAX_MINIONS:
		return false
	return true


func _execute(attack: BossAttack) -> void:
	_current_attack = attack
	if attack.cooldown > 0.0:
		_attack_ready[attack] = _clock + attack.cooldown
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
			# Boss hücumu bloklanamaz ve parry'lenemez (kırmızı uyarı); yalnızca yuvarlanma kurtarır
			special_kind = Combat.Kind.UNBLOCKABLE
			special_damage = attack.damage
			special_radius = attack.radius
			special_windup = attack.windup
			special_hit_frame = attack.hit_frame
			charge_speed = attack.charge_speed
			charge_distance = attack.charge_distance
			charge_stun_time = attack.stun_time
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
	_begin_cast()
	var id := _cast_id
	_start_glow(Color(0.8, 0.5, 1.0))
	sprite.play_directional("special" if sprite.has_directional("special") else "idle", facing, true)
	# Çağrılacak yerlerde küçük uyarılar
	var spots: Array[Vector2] = []
	var markers: Array[AreaTelegraph] = []
	for i in attack.summon_count:
		var angle := TAU * i / attack.summon_count + randf() * 0.5
		spots.append(global_position + Vector2(cos(angle), sin(angle)) * SUMMON_RING_RADIUS)
		var marker := AreaTelegraph.circle(spots[i], SUMMON_MARKER_RADIUS, attack.windup, Combat.Kind.NORMAL)
		markers.append(marker)
		_attack_telegraphs.append(marker)
	var tween := create_tween()
	tween.tween_interval(attack.windup)
	tween.tween_callback(_finish_summon.bind(attack, spots, markers, id))


func _finish_summon(attack: BossAttack, spots: Array[Vector2], markers: Array[AreaTelegraph], id: int) -> void:
	# Hazırlık iptal edildiyse (boss sersemledi, öldü, faz değişti) işaretleri iptal eden zaten sildi
	if id != _cast_id:
		return
	if state != State.SPECIAL:
		_clear_attack_telegraphs()
		return
	_casting = false
	_stop_glow()
	for marker in markers:
		if is_instance_valid(marker):
			marker.detonate()
	_attack_telegraphs.clear()
	# Hazırlık sırasında sınıra yaklaşıldıysa yalnızca kalan kadar doğar
	var room := MAX_MINIONS - alive_minion_count()
	for i in mini(spots.size(), maxi(room, 0)):
		var scene := _summon_scene_for(attack, i)
		if scene == null:
			continue
		var minion := scene.instantiate() as Node2D
		get_parent().add_child(minion)
		minion.global_position = spots[i]
		if minion is Enemy:
			var enemy := minion as Enemy
			# Çağrılan yardımcılar görev sayımına ve deneyime girmez (çağırma bekleme süresi dolunca
			# yenisi gelir; deneyim verseydi tekrar tekrar çağırtıp kasılabilirdi) ve hemen saldırır
			enemy.enemy_id = ""
			enemy.xp_reward = 0
			enemy.detect_radius = 400.0
			_minions.append(enemy)
	state = State.CHASE


func _summon_scene_for(attack: BossAttack, index: int) -> PackedScene:
	if not attack.summon_scenes.is_empty():
		return attack.summon_scenes[index % attack.summon_scenes.size()]
	return attack.summon_scene


# Büyü/çağırma/ışınlanma hazırlığı başlar: boss SPECIAL durumuna girer, sprite olayları durumu bozmaz
func _begin_cast() -> void:
	state = State.SPECIAL
	_casting = true
	_cast_id += 1
	velocity = Vector2.ZERO


# --- Büyü türü saldırılar (hazırlık + etki) --------------------------------------

## Kısa bir hazırlıktan (parlama + animasyon) sonra effect çağrılır.
func _start_cast(attack: BossAttack, effect: Callable) -> void:
	_begin_cast()
	var id := _cast_id
	_start_glow(Combat.KIND_COLORS[attack.kind])
	var anim := attack.animation if sprite.has_directional(attack.animation) else "idle"
	sprite.play_directional(anim, facing, true)
	var tween := create_tween()
	tween.tween_interval(attack.windup)
	tween.tween_callback(func() -> void:
		if id != _cast_id or state != State.SPECIAL:
			return
		_casting = false
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
	_begin_cast()
	var id := _cast_id
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		if id != _cast_id or state == State.DEAD or _distance_to_player() == INF:
			return
		var angle := randf() * TAU
		global_position = _player.global_position + Vector2(cos(angle), sin(angle)) * attack.teleport_distance
		Shockwave.spawn(global_position + Vector2(0, -6), 20.0, Color(0.7, 0.5, 1.0)))
	tween.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func() -> void:
		if id == _cast_id and state == State.SPECIAL:
			_casting = false
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
		# Gecikmeli vuruşlar boss'a değil haritaya bağlı çalışır (boss ölüm animasyonundan sonra silinse
		# de çağrı kaybolmaz); boss ölürse _clear_barrage ile iptal edilir
		var tween := effects.create_tween()
		tween.tween_interval(i * 0.18)
		tween.tween_callback(Boss._barrage_strike.bind(get_tree(), attack, _player.global_position + offset, get_instance_id()))
		_barrage_tweens.append(tween)


static func _barrage_strike(tree: SceneTree, attack: BossAttack, spot: Vector2, owner_id: int) -> void:
	if Map.current == null:
		return
	var telegraph := AreaTelegraph.circle(spot, attack.radius, attack.windup, attack.kind)
	telegraph.blink = attack.blink
	telegraph.set_meta(OWNER_META, owner_id)
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
	_attack_telegraphs.append(telegraph)
	_start_cast(attack, func() -> void:
		_attack_telegraphs.erase(telegraph)
		if is_instance_valid(telegraph):
			telegraph.detonate()
		var player := get_tree().get_first_node_in_group("player") as Player
		if player == null or not player.is_inside_tree():
			return
		var closest := Geometry2D.get_closest_point_to_segment(player.global_position, origin, end)
		if closest.distance_to(player.global_position) <= attack.radius:
			player.take_damage(attack.damage, null, attack.kind)
			player.shake(2.0, 0.2))


func take_damage(amount: int, crit: bool, from_position: Vector2, knockback_scale: float = 1.0, stagger: bool = false) -> void:
	if not active or state == State.DEAD:
		return
	# Boss'lar geri savrulmaz ve yetenekle sersemlemez
	super.take_damage(amount, crit, from_position, 0.0, false)
	health_changed.emit(maxi(hp, 0), max_hp)
	if phase == 1 and hp > 0 and hp <= max_hp * phase2_threshold:
		_enter_phase(2)
	if phase == 2 and hp > 0 and phase3_threshold > 0.0 and hp <= max_hp * phase3_threshold:
		_enter_phase(3)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	if new_phase == 2:
		move_speed *= phase2_speed_multiplier
	sprite.speed_scale = 1.15 if new_phase == 2 else 1.3
	# Hazırlığı süren büyü/çağırma/patlama (henüz etki etmemiş) yeni faza taşmasın; sürmekte olan
	# yakın dövüş/alan/hücum saldırısı bölünmez (bölünürse animasyon uyarısız vurur)
	_abort_cast()
	Shockwave.spawn(global_position + Vector2(0, -6), 50.0, Color(1.0, 0.4, 0.3))
	if _player:
		_player.shake(3.0, 0.3)
	GameState.message.emit(tr("MSG_BOSS_PHASE_%d" % new_phase) % get_display_name(), Color(1.0, 0.5, 0.35))
	# Faz açılışı saldırısı (ör. Fenris: 2. fazda çağırma, 3. fazda patlama daireleri) hemen gelir
	for attack in attacks:
		if attack.phase_opener and attack.min_phase == new_phase:
			_forced_attack = attack
			_cooldown = minf(_cooldown, 0.5)
			break
	phase_changed.emit(phase)


# Hazırlık aşamasındaki büyü/çağırma/ışınlanmayı iptal eder; havadaki yağmur/patlama vuruşları ve çağırma
# işaretleri de silinir. Yakın dövüş, alan ve hücum saldırıları (SPECIAL ama _casting değil) dokunulmaz.
func _abort_cast() -> void:
	if not _casting:
		return
	_cast_id += 1
	_casting = false
	_stop_glow()
	_clear_attack_telegraphs()
	_clear_barrage()
	if state == State.SPECIAL:
		state = State.CHASE
		sprite.modulate = _base_modulate


func _on_sprite_frame_changed() -> void:
	# Büyü/çağırma hazırlığında kare olayları (alan vuruşu mantığı) çalışmaz
	if _casting:
		return
	super._on_sprite_frame_changed()


func _on_sprite_animation_finished() -> void:
	# Büyü/çağırma hazırlığı sürerken animasyon bitişi durumu bozmaz (kendi zamanlayıcısı bitirir)
	if _casting and state == State.SPECIAL:
		return
	# Kombo: aynı saldırıyı birkaç kez arka arkaya yap
	if state == State.ATTACK and _combo_left > 0:
		if not _hit_done:
			_try_hit_player()
		_combo_left -= 1
		_hit_done = false
		sprite.play_directional("attack", facing, true)
		return
	super._on_sprite_animation_finished()


func _exit_tree() -> void:
	super._exit_tree()
	_clear_attack_telegraphs()


# Saldırı bölününce (sersemleme, ölüm) boss'un patlamamış uyarı alanları da kalkar
func _cancel_special() -> void:
	super._cancel_special()
	# Bölünen hazırlığın geciken çağrısı etki etmesin
	_cast_id += 1
	_casting = false
	_clear_attack_telegraphs()


func _clear_attack_telegraphs() -> void:
	for telegraph in _attack_telegraphs:
		if is_instance_valid(telegraph):
			telegraph.queue_free()
	_attack_telegraphs.clear()


## Boss ölünce sırada bekleyen ve havada olan yağmur (barrage) vuruşları da iptal edilir;
## yoksa ölü boss'un uyarı alanları haritada patlamaya devam eder.
func _clear_barrage() -> void:
	for tween in _barrage_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_barrage_tweens.clear()
	if Map.current == null or not is_instance_valid(Map.current.ground_effects):
		return
	for effect in Map.current.ground_effects.get_children():
		if effect is AreaTelegraph and effect.get_meta(OWNER_META, 0) == get_instance_id():
			effect.queue_free()


func _die() -> void:
	super._die()
	_clear_attack_telegraphs()
	_clear_barrage()
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
