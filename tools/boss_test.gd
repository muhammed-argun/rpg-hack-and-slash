extends Node
## Boss deneme aracı. Kurt İni arenasında istenen boss'u başlatır.
##
## Elle oynamak için (klavye: WASD, Space saldırı, L blok, Shift yuvarlanma, K yetenek):
##   godot --path . res://tools/boss_test.tscn -- --boss=morvane
## Bütün boss'ları otomatik dene (her biri birkaç saniye dövüşür, sonra öldürülür):
##   godot --path . res://tools/boss_test.tscn --quit-after 30000 -- --all
##
## Boss id'leri: fenris, morvane, asterion, gozcu, bjorn, velzara, surtr, corvin, azgoroth, aldric, malphas

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DEN_PATH := "res://scenes/maps/ashwood_den.tscn"
const ALL_BOSSES := ["fenris", "morvane", "asterion", "gozcu", "bjorn", "velzara", "surtr", "corvin", "azgoroth", "aldric"]
## Otomatik denemede her boss'un oyuncuyla dövüşeceği süre
const FIGHT_TIME := 7.0

var _main: Node
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = "user://save_boss_test.json"
	GameState.new_game()
	# Prologdaki giriş hikâye kartı oyunu duraklatmasın
	GameState.set_flag("intro_seen")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame
	var boss_id := "fenris"
	var run_all := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--boss="):
			boss_id = arg.get_slice("=", 1)
		elif arg == "--all":
			run_all = true
	if run_all:
		await _run_all()
	else:
		await _spawn(boss_id)


func _spawn(boss_id: String) -> Boss:
	GameState.flags.erase("boss_" + boss_id)
	_main.change_map(DEN_PATH, "from_wild")
	await get_tree().physics_frame
	var arena := _main.current_map.get_node("Entities/BossArena") as BossArena
	var old := arena.get_node_or_null("Fenris")
	if old:
		old.free()
	var path := "res://scenes/bosses/%s.tscn" % boss_id
	if not ResourceLoader.exists(path):
		push_error("Boss bulunamadı: " + path)
		return null
	var boss := (load(path) as PackedScene).instantiate() as Boss
	arena.add_child(boss)
	arena.set("_boss", boss)
	arena.set("_fight_started", false)
	return boss


func _run_all() -> void:
	for boss_id: String in ALL_BOSSES:
		var boss := await _spawn(boss_id)
		if boss == null:
			_failures.append(boss_id + ": sahne yok")
			continue
		var player: Player = _main.player
		player.global_position = boss.global_position + Vector2(0, 60)
		await _frames(5)
		if not boss.active:
			_failures.append(boss_id + ": uyanmadı")
		# Oyuncu yerinde durur, boss saldırılarını yapar (oyuncu sürekli iyileştirilir)
		var time := 0.0
		var hits := 0
		var last_hp := GameState.hp
		while time < FIGHT_TIME:
			if GameState.hp < last_hp:
				hits += 1
			GameState.hp = GameState.max_hp
			last_hp = GameState.hp
			if is_instance_valid(boss) and time > FIGHT_TIME * 0.5 and boss.phase == 1:
				# İkinci fazı da görmek için canını yarıya indir
				boss.take_damage(int(boss.max_hp * 0.55), false, player.global_position)
			await _frames(1)
			time += get_physics_process_delta_time()
		await _screenshot("boss_" + boss_id)
		print("%s: oyuncuya %d kez vurdu, faz %d" % [boss_id, hits, boss.phase if is_instance_valid(boss) else -1])
		if hits == 0:
			_failures.append(boss_id + ": hiç vuramadı")
		# Öldür
		var guard := 0
		while is_instance_valid(boss) and boss.state != Enemy.State.DEAD and guard < 200:
			boss.take_damage(100, false, player.global_position)
			await _frames(2)
			guard += 1
		await _wait(2.5)
		if boss_id == "aldric":
			# Kral ölünce Malphas aynı arenada başlamalı
			var malphas: Boss = null
			for node in get_tree().get_nodes_in_group("bosses"):
				if node is Boss and (node as Boss).boss_id == "malphas" and (node as Boss).state != Enemy.State.DEAD:
					malphas = node
			if malphas == null or not malphas.active:
				_failures.append("aldric: Malphas başlamadı")
			else:
				print("aldric: Malphas başladı")
				await _wait(3.0)
				await _screenshot("boss_malphas")
				while is_instance_valid(malphas) and malphas.state != Enemy.State.DEAD:
					malphas.take_damage(150, false, player.global_position)
					await _frames(2)
				await _wait(1.0)
				if not GameState.has_flag("game_completed") or GameState.shards.has("malphas"):
					_failures.append("malphas: oyun sonu tetiklenmedi ya da parça verdi")
				await _wait(9.0)
				await _screenshot("ending")
		elif not GameState.shards.has(boss_id):
			_failures.append(boss_id + ": parça vermedi")
		# Kalan çağrılmış yardımcıları temizle
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Enemy and not node is Boss:
				node.queue_free()
		await _frames(5)
		# Boss ölünce haritada takılı uyarı alanı kalmamalı
		await _wait(0.5)
		if _telegraph_count() > 0:
			_failures.append("%s: boss ölünce haritada %d uyarı alanı kaldı" % [boss_id, _telegraph_count()])
	await _test_area_cleanup()
	await _test_fenris_phases()
	print("Parçalar: %s" % str(GameState.shards))
	if _failures.is_empty():
		print("BOSS TESTİ BAŞARILI")
	else:
		print("BOSS TESTİ BAŞARISIZ:\n- " + "\n- ".join(_failures))
	get_tree().quit()


# Haritadaki (silinmeye ayrılmamış) uyarı alanı sayısı
func _telegraph_count() -> int:
	if Map.current == null:
		return 0
	var count := 0
	for effect in Map.current.ground_effects.get_children():
		if effect is AreaTelegraph and not effect.is_queued_for_deletion():
			count += 1
	return count


func _find_attack(boss: Boss, type: BossAttack.Type) -> BossAttack:
	for attack in boss.attacks:
		if attack.type == type:
			return attack
	return null


# 2. faz alan saldırıları ve uyarı alanı temizliği (Fenris üzerinde): alan uyarısı bitince hasar verir,
# çağırma uyarıları saldırı bölünürse / boss ölürse silinir, sahipsiz uyarı kendiliğinden kaybolur
func _test_area_cleanup() -> void:
	# Malphas'tan sonra oyun sonu ekranı oyunu duraklatmış olabilir
	get_tree().paused = false
	var boss := await _spawn("fenris")
	var player: Player = _main.player
	player.global_position = boss.global_position + Vector2(0, 30)
	await _frames(5)
	boss.take_damage(int(boss.max_hp * 0.55), false, player.global_position)
	if boss.phase != 2:
		_failures.append("alan testi: Fenris 2. faza geçmedi")
		return
	# 0) Atılma (dash) saldırısı: oyuncuya vurur ve yaklaşık 1 sn sersemletir
	var leap := _find_attack(boss, BossAttack.Type.CHARGE)
	if leap == null:
		_failures.append("alan testi: Fenris'te atılma saldırısı yok")
		return
	player.global_position = boss.global_position + Vector2(90, 0)
	await _frames(3)
	GameState.hp = GameState.max_hp
	var leap_hp := GameState.hp
	boss._execute(leap)
	var stun_seen := 0.0
	var waited := 0.0
	while waited < 3.5:
		await _frames(1)
		var step := get_physics_process_delta_time()
		waited += step
		if player.is_stunned():
			stun_seen += step
		elif stun_seen > 0.0:
			break
	if GameState.hp >= leap_hp:
		_failures.append("alan testi: Fenris atılma saldırısı hasar vermedi")
	if stun_seen < 0.9 or stun_seen > 1.4:
		_failures.append("alan testi: Fenris atılması ~1 sn sersemletmeli (%.2f sn)" % stun_seen)
	print("alan testi: Fenris atılması hasar verdi (%d -> %d), sersemleme %.2f sn" % [leap_hp, GameState.hp, stun_seen])
	boss._cancel_special()
	boss.state = Enemy.State.CHASE
	player.global_position = boss.global_position + Vector2(0, 30)
	await _frames(3)
	# Boss kendi başına saldırmasın; saldırıları elle başlatıyoruz
	boss.set_physics_process(false)
	var storm := _find_attack(boss, BossAttack.Type.RING)
	var howl := _find_attack(boss, BossAttack.Type.SUMMON)
	if storm == null or howl == null:
		_failures.append("alan testi: Fenris'te RING/SUMMON saldırısı yok")
		return
	# 1) Alan saldırısı: uyarı görünür, dolunca oyuncuya hasar verir, sonra uyarı silinir
	GameState.hp = GameState.max_hp
	var hp_before := GameState.hp
	boss._execute(storm)
	await _wait(0.3)
	if _telegraph_count() < 1:
		_failures.append("alan testi: alan saldırısında uyarı alanı görünmedi")
	await _wait(2.5)
	if GameState.hp >= hp_before:
		_failures.append("alan testi: 2. faz alan saldırısı uyarı bitince hasar vermedi")
	if _telegraph_count() > 0:
		_failures.append("alan testi: alan saldırısından sonra %d uyarı alanı kaldı" % _telegraph_count())
	print("alan testi: 2. faz alan saldırısı hasar verdi (%d -> %d)" % [hp_before, GameState.hp])
	# 2) Çağırma uyarıları saldırı sersemlemeyle bölününce silinmeli
	GameState.hp = GameState.max_hp
	boss._end_stun()
	boss.state = Enemy.State.CHASE
	boss._execute(howl)
	await _wait(0.2)
	var during := _telegraph_count()
	if during < howl.summon_count:
		_failures.append("alan testi: çağırma işaretleri görünmedi (%d)" % during)
	boss.stun()
	await _frames(3)
	if _telegraph_count() > 0:
		_failures.append("alan testi: sersemleyen boss'un çağırma işaretleri silinmedi (%d)" % _telegraph_count())
	await _wait(1.5)
	if _telegraph_count() > 0:
		_failures.append("alan testi: sersemlemeden sonra takılı uyarı kaldı (%d)" % _telegraph_count())
	print("alan testi: sersemleyen boss'un işaretleri temizlendi (önce %d, sonra %d)" % [during, _telegraph_count()])
	# 3) Çağırma sırasında boss ölürse uyarılar silinmeli
	boss._end_stun()
	boss.state = Enemy.State.CHASE
	boss._execute(howl)
	await _wait(0.2)
	boss.take_damage(boss.max_hp * 2, false, player.global_position)
	await _frames(3)
	if _telegraph_count() > 0:
		_failures.append("alan testi: ölen boss'un uyarı alanları silinmedi (%d)" % _telegraph_count())
	await _wait(2.0)
	if _telegraph_count() > 0:
		_failures.append("alan testi: boss öldükten sonra takılı uyarı kaldı (%d)" % _telegraph_count())
	# 4) Güvenlik ağı: sahibi olmayan uyarı süresi dolunca kendiliğinden silinir
	AreaTelegraph.circle(player.global_position + Vector2(80, 0), 10.0, 0.2, Combat.Kind.NORMAL)
	await _wait(0.2 + AreaTelegraph.OVERDUE_LIFETIME + 0.5)
	if _telegraph_count() > 0:
		_failures.append("alan testi: sahipsiz uyarı alanı kendiliğinden silinmedi")
	print("alan testi bitti")


func _non_boss_enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and not node is Boss and (node as Enemy).state != Enemy.State.DEAD and not node.is_queued_for_deletion():
			list.append(node)
	return list


func _clear_minions() -> void:
	for enemy in _non_boss_enemies():
		enemy.free()


# Çağırma/patlama seçimi: verilen mesafede n kez saldırı seçip hangi türlerin çıktığını döndürür
func _picked_types(boss: Boss, distance: float, tries: int = 300) -> Array[int]:
	var types: Array[int] = []
	for i in tries:
		var attack := boss._pick_attack(distance)
		if attack and not types.has(attack.type):
			types.append(attack.type)
	return types


# Fenris 3 faz: 1. faz yakın dövüş + alan + atılma; 2. faz (%60) 2 Demon + 2 Blood Monster çağırır (canlı yardımcı varken
# tekrar çağırmaz); 3. faz (%30) çağırmaya ek olarak kırmızı yanıp sönen patlama daireleri (yalnızca oyuncuya hasar);
# hazırlık sırasında faz değişirse/boss ölürse bekleyen etkiler temizlenir; boss hücumu bloklanamaz
func _test_fenris_phases() -> void:
	get_tree().paused = false
	# Malphas'tan kalan oyun sonu ekranı sonraki ekran görüntülerini örtmesin
	_main.get_node("HUD")._ending.hide()
	_clear_minions()
	var boss := await _spawn("fenris")
	var player: Player = _main.player
	player.global_position = boss.global_position + Vector2(0, 40)
	await _frames(5)
	var f := "faz testi: "
	GameState.hp = GameState.max_hp
	# --- 1. faz: yalnızca MELEE, RING (alan), CHARGE (atılma) ---
	_check_phase(boss.phase == 1, f + "Fenris 1. fazda başlamalı")
	boss.set_physics_process(false)
	var phase1_types := _picked_types(boss, 20.0) + _picked_types(boss, 100.0)
	var allowed: Array[int] = [BossAttack.Type.MELEE, BossAttack.Type.RING, BossAttack.Type.CHARGE]
	var only_basic := true
	for t in phase1_types:
		if not allowed.has(t):
			only_basic = false
	_check_phase(only_basic and phase1_types.has(BossAttack.Type.RING) and phase1_types.has(BossAttack.Type.CHARGE) and phase1_types.has(BossAttack.Type.MELEE), f + "1. fazda yalnızca kılıç, alan ve atılma saldırıları olmalı (%s)" % str(phase1_types))
	# Boss hücumu bloklanamaz: blok basılı da olsa isabet eder, stun verir
	var leap := _find_attack(boss, BossAttack.Type.CHARGE)
	player.global_position = boss.global_position + Vector2(90, 0)
	await _frames(3)
	GameState.hp = GameState.max_hp
	GameState.stamina = GameState.max_stamina
	var hp_before_leap := GameState.hp
	boss.set_physics_process(true)
	boss._execute(leap)
	_check_phase(boss.special_kind == Combat.Kind.UNBLOCKABLE, f + "Boss hücumu bloklanamaz (kırmızı uyarı) olmalı")
	var blocked := false
	var stunned := false
	var waited := 0.0
	while waited < 3.0:
		await _frames(1)
		waited += get_physics_process_delta_time()
		if not blocked and boss.state == Enemy.State.CHARGING and boss.global_position.distance_to(player.global_position) < 45.0:
			Input.action_press("block")
			blocked = true
		if player.is_stunned():
			stunned = true
	Input.action_release("block")
	_check_phase(blocked and stunned and GameState.hp < hp_before_leap, f + "Boss hücumuna blok/parry işe yaramamalı (hasar ve stun)")
	await _wait(1.2)
	# --- 2. faz: 4 yardımcı (2 Demon + 2 Blood Monster) ---
	boss._cancel_special()
	boss.state = Enemy.State.CHASE
	boss._cooldown = 0.0
	player.global_position = boss.global_position + Vector2(0, 40)
	GameState.hp = GameState.max_hp
	await _frames(3)
	boss.take_damage(int(boss.max_hp * 0.45), false, player.global_position)
	_check_phase(boss.phase == 2, f + "Canı %60'ın altına inince 2. faz başlamalı")
	var minions: Array[Enemy] = []
	waited = 0.0
	while waited < 6.0 and minions.size() < 4:
		GameState.hp = GameState.max_hp
		await _frames(2)
		waited += get_physics_process_delta_time() * 2.0
		minions = _non_boss_enemies()
	var demons := 0
	var monsters := 0
	for m in minions:
		if m.name_key == "ENEMY_DEMON":
			demons += 1
		elif m.name_key == "ENEMY_BLOOD_MONSTER":
			monsters += 1
	_check_phase(minions.size() == 4 and demons == 2 and monsters == 2, f + "2. fazda 2 Demon + 2 Blood Monster doğmalı (demon %d, blood monster %d, toplam %d)" % [demons, monsters, minions.size()])
	await _screenshot("fenris_phase2_minions")
	# Çağırma bekleme süresi 20 sn: dolmadan (yardımcılar yaşıyor ya da ölmüş olsun) seçilmez; dolunca yardımcılar
	# yaşarken de yeniden çağrılır (mob'ları öldürmeden çağırtmama exploit'i yok); üst sınır 8 canlı yardımcı
	boss.set_physics_process(false)
	GameState.god_mode = true
	var howl := _find_attack(boss, BossAttack.Type.SUMMON)
	var ready_at: float = boss._attack_ready.get(howl, 0.0)
	_check_phase(is_equal_approx(howl.cooldown, 20.0) and ready_at > boss._clock and ready_at - boss._clock <= 20.0, f + "Çağırma bekleme süresi 20 sn olmalı")
	_check_phase(boss.alive_minion_count() == 4 and not _picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "20 sn dolmadan (yardımcılar yaşarken) çağırma seçilmemeli")
	boss._clock = ready_at - 0.5
	_check_phase(not _picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "20 sn dolmasına 0,5 sn kala çağırma seçilmemeli")
	boss._clock = ready_at + 0.1
	_check_phase(boss.alive_minion_count() == 4 and _picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "20 sn dolunca yardımcılar yaşıyor olsa da çağırma seçilebilmeli")
	boss.state = Enemy.State.CHASE
	boss._cooldown = 0.0
	boss._execute(howl)
	await _wait(howl.windup + 0.6)
	var after_second := _non_boss_enemies().size()
	_check_phase(after_second == 8, f + "Yeniden çağırma eskilere ek 4 yardımcı doğurmalı (4+4 = 8, şimdi %d)" % after_second)
	boss._clock = boss._attack_ready.get(howl, 0.0) + 0.1
	_check_phase(boss.alive_minion_count() == Boss.MAX_MINIONS and not _picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "8 yardımcı varken (üst sınır) çağırma seçilmemeli")
	# Sınıra 2 kala çağırma yalnızca kalan kadar (2) doğurur
	var killed := 0
	for m in _non_boss_enemies():
		if killed < 2:
			m.free()
			killed += 1
	await _frames(2)
	_check_phase(boss.alive_minion_count() == 6 and _picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "6 yardımcı varken çağırma yeniden seçilebilmeli")
	boss.state = Enemy.State.CHASE
	boss._cooldown = 0.0
	boss._execute(howl)
	await _wait(howl.windup + 0.6)
	_check_phase(_non_boss_enemies().size() == Boss.MAX_MINIONS, f + "Sınıra yakınken çağırma yalnızca kalan kadar doğurmalı (toplam %d, sınır %d)" % [_non_boss_enemies().size(), Boss.MAX_MINIONS])
	GameState.god_mode = false
	_clear_minions()
	await _frames(2)
	_check_phase(boss.alive_minion_count() == 0, f + "Yardımcılar temizlendi")
	boss._clock += 30.0
	_check_phase(_picked_types(boss, 100.0).has(BossAttack.Type.SUMMON), f + "Bekleme süresi dolunca çağırma yeniden seçilebilmeli")
	# --- Çağırma hazırlığı sırasında faz değişirse bekleyen işaretler silinir, yardımcı doğmaz ---
	boss.state = Enemy.State.CHASE
	boss._cooldown = 0.0
	boss.set_physics_process(true)
	boss._execute(_find_attack(boss, BossAttack.Type.SUMMON))
	await _wait(0.2)
	var summon_markers := _telegraph_count()
	boss.set_physics_process(false)
	boss.take_damage(int(boss.max_hp * 0.30), false, player.global_position)
	_check_phase(boss.phase == 3, f + "Canı %%30'un altına inince 3. faz başlamalı (can %d/%d)" % [boss.hp, boss.max_hp])
	await _frames(3)
	_check_phase(summon_markers >= 4 and _telegraph_count() == 0, f + "Faz değişince bekleyen çağırma işaretleri silinmeli (önce %d, sonra %d)" % [summon_markers, _telegraph_count()])
	await _wait(1.2)
	_check_phase(_non_boss_enemies().is_empty(), f + "Faz değişince iptal edilen çağırma yardımcı doğurmamalı")
	var blast := _find_attack(boss, BossAttack.Type.BARRAGE)
	_check_phase(boss._forced_attack == blast and blast.blink and is_equal_approx(blast.radius, Boss.SUMMON_MARKER_RADIUS * 2.0) and is_equal_approx(blast.windup, 1.5), f + "3. faz açılışı: çağırma işaretinin 2 katı büyüklükte, 1,5 sn uyarılı yanıp sönen patlama")
	boss._clock += 30.0
	var types3 := _picked_types(boss, 100.0)
	_check_phase(not _picked_types(boss, 100.0).is_empty() and types3.has(BossAttack.Type.BARRAGE) and types3.has(BossAttack.Type.SUMMON), f + "3. fazda patlama ve çağırma da seçilebilmeli (%s)" % str(types3))
	# --- Patlama daireleri: yalnızca oyuncuya hasar ---
	boss._forced_attack = null
	boss.state = Enemy.State.CHASE
	boss._cancel_special()
	player.global_position = boss.global_position + Vector2(0, 70)
	GameState.hp = GameState.max_hp
	await _frames(3)
	# Patlama dairesinin içine koyduğumuz yardımcı ve boss hasar almamalı
	var dummy := (load("res://scenes/enemies/blood_monster.tscn") as PackedScene).instantiate() as Enemy
	_main.current_map.get_node("Entities").add_child(dummy)
	dummy.global_position = player.global_position + Vector2(2, 0)
	dummy.detect_radius = 0.0
	dummy.set_physics_process(false)
	var boss_hp := boss.hp
	var dummy_hp := dummy.hp
	boss._attack_ready.clear()
	boss._execute(blast)
	await _wait(1.0)
	var circles := 0
	var blinking := true
	for effect in Map.current.ground_effects.get_children():
		if effect is AreaTelegraph and not effect.is_queued_for_deletion():
			circles += 1
			var t := effect as AreaTelegraph
			if not t.blink or not is_equal_approx(t.radius, 20.0) or t.fill_color != Combat.telegraph_color(Combat.Kind.UNBLOCKABLE):
				blinking = false
	_check_phase(circles == blast.count and blinking, f + "Patlama daireleri (%d) kırmızı, yanıp sönen ve 2 kat büyük olmalı (%d daire)" % [blast.count, circles])
	await _screenshot("fenris_phase3_blast")
	var hp_before_blast := GameState.hp
	await _wait(1.2)
	_check_phase(GameState.hp < hp_before_blast and hp_before_blast - GameState.hp >= 1, f + "Patlama oyuncuya hasar vermeli (%d -> %d)" % [hp_before_blast, GameState.hp])
	_check_phase(boss.hp == boss_hp and dummy.hp == dummy_hp, f + "Patlama boss'a ve diğer düşmanlara hasar vermemeli (boss %d/%d, düşman %d/%d)" % [boss.hp, boss_hp, dummy.hp, dummy_hp])
	await _wait(0.5)
	_check_phase(_telegraph_count() == 0, f + "Patlayan daireler haritadan kalkmalı (%d)" % _telegraph_count())
	dummy.free()
	# --- Boss patlama hazırlığında ölürse bekleyen daireler ve vuruşlar iptal olur ---
	boss.state = Enemy.State.CHASE
	boss._attack_ready.clear()
	GameState.hp = GameState.max_hp
	player.global_position = boss.global_position + Vector2(0, 70)
	boss._execute(blast)
	await _wait(0.5)
	var pending := _telegraph_count()
	boss.take_damage(boss.max_hp * 2, false, player.global_position)
	await _frames(3)
	_check_phase(pending >= 2 and _telegraph_count() == 0, f + "Boss ölünce bekleyen patlama daireleri silinmeli (önce %d, sonra %d)" % [pending, _telegraph_count()])
	var hp_after_death := GameState.hp
	await _wait(2.5)
	_check_phase(GameState.hp == hp_after_death and _telegraph_count() == 0, f + "Boss öldükten sonra patlama gerçekleşmemeli (can %d -> %d)" % [hp_after_death, GameState.hp])
	_clear_minions()
	print("faz testi bitti")


func _check_phase(condition: bool, description: String) -> void:
	print(("[OK] " if condition else "[HATA] ") + description)
	if not condition:
		_failures.append(description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


func _screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("user://%s.png" % file_name)
