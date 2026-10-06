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
	print("Parçalar: %s" % str(GameState.shards))
	if _failures.is_empty():
		print("BOSS TESTİ BAŞARILI")
	else:
		print("BOSS TESTİ BAŞARISIZ:\n- " + "\n- ".join(_failures))
	get_tree().quit()


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
