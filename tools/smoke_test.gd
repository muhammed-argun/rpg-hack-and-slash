extends Node
## Otomatik duman testi: yeni oyun başlatır ve oyunun ana sistemlerini sırayla dener:
## yön, NPC diyaloğu ve görevler, dil değiştirme, savaş ve özel saldırılar, blok/parry/yuvarlanma,
## ot toplama ve simya, yetenek, boss dövüşü ve kristal parçası, envanter, kayıt/yükleme.
## Ekran görüntülerini user:// klasörüne kaydeder, sonuçları konsola yazar.
##
## Çalıştırma (proje klasöründe):
##   godot --path . res://tools/smoke_test.tscn --quit-after 20000

const MAIN_SCENE := preload("res://scenes/main.tscn")
const DEN_PATH := "res://scenes/maps/ashwood_den.tscn"
const WILD_PATH := "res://scenes/maps/wild.tscn"

var _main: Node
var _hud: Node
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = "user://save_smoke_test.json"
	Settings.set_language("tr")
	GameState.new_game()
	Quests.start("q_main_arrival")
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_hud = _main.get_node("HUD")
	await _frames(20)
	var player: Player = _main.player
	_check(_main.current_map.name == "Prologue", "Yeni oyun prologda (Varneth Yolu) başlamalı")
	_check(_hud._story.visible, "Prologa girince hikâye kartı gösterilmeli")
	await _wait(3.0)
	await _screenshot("00_intro")
	_hud._story._finish()
	await _wait(1.0)
	_check(not get_tree().paused, "Hikâye kartı geçilince oyun başlamalı")
	var hints: TutorialHints = _hud.get_node("Root").get_children().filter(func(n: Node) -> bool: return n is TutorialHints)[0]
	_check(hints.visible and hints._label.text.contains("W A S D"), "İlk ipucu yürüme tuşlarını (W A S D) göstermeli (yazı: %s)" % hints._label.text)
	await _screenshot("00_prologue")
	await _go_to_map("res://scenes/maps/town.tscn", "from_prologue")
	_check(_main.current_map.name == "Town", "Prologun sonundaki kapı şehre götürmeli")
	_check(Quests.get_state("q_main_arrival") == Quests.State.ACTIVE and Quests.is_objective_done("q_main_arrival", 0), "Şehre ulaşınca ilk hedef tamamlanmalı")
	await _screenshot("01_town")

	await _test_direction(player)
	await _test_dialogue(player)
	await _test_language()
	await _test_defense(player)
	await _test_combat(player)
	await _test_herbs_and_crafting(player)
	await _test_skill(player)
	await _test_boss(player)
	await _test_progression(player)
	await _test_inventory_and_save(player)

	print("Altın: %d, can iksiri: %d, mana iksiri: %d, parça: %d, çanta: %d eşya" % [
		GameState.gold, GameState.health_potions, GameState.mana_potions, GameState.shards.size(), GameState.inventory.size()])
	if _failures.is_empty():
		print("DUMAN TESTİ BAŞARILI")
	else:
		print("DUMAN TESTİ BAŞARISIZ:\n- " + "\n- ".join(_failures))
	get_tree().quit()


# --- Testler -------------------------------------------------------------------

func _test_direction(player: Player) -> void:
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _frames(5)
	_check(player.facing == "right" and not player.sprite.flip_h, "Sağ+yukarıda karakter sağa bakmalı")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(5)
	_check(player.facing == "left" and player.sprite.flip_h, "Yukarı basılıyken sola geçince karakter sola dönmeli")
	Input.action_release("move_left")
	Input.action_release("move_up")


func _test_dialogue(player: Player) -> void:
	var ezra := _find_npc("ezra")
	_check(ezra != null, "Şehirde Rahip Ezra olmalı")
	if ezra == null:
		return
	player.global_position = ezra.global_position + Vector2(0, 16)
	await _frames(3)
	_check(player.current_interactable == ezra, "Ezra'ya yaklaşınca etkileşim açılmalı")
	_check(_hud.interact_prompt.visible and _hud.interact_prompt.text == "[F] Konuş", "Ezra'nın üstünde '[F] Konuş' görünmeli (yazı: %s)" % _hud.interact_prompt.text)
	_check(not _hud.has_node("Root/TouchJoystick") and not _hud.has_node("Root/ActionButtons"), "PC'de dokunmatik joystick ve aksiyon butonları olmamalı")
	_check(not ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), "Fare dokunmayı taklit etmemeli")
	await _screenshot("02_talk_prompt")
	await _tap_action("interact")
	_check(Dialogue.is_active() and _hud.dialogue_box.visible, "Etkileşim tuşu (F) Ezra ile konuşmayı başlatmalı")
	_check(get_tree().paused, "Konuşma sırasında oyun durmalı")
	await _wait(0.6)
	await _screenshot("02_dialogue")
	await _finish_dialogue()
	_check(not get_tree().paused, "Konuşma bitince oyun devam etmeli")
	_check(Quests.get_state("q_main_arrival") == Quests.State.DONE, "Ezra ile konuşunca ilk görev tamamlanmalı")
	_check(Quests.get_state("q_main_shards") == Quests.State.ACTIVE, "Dokuz Parça görevi başlamalı")
	_check(Quests.get_state("q_main_fenris") == Quests.State.ACTIVE, "Kül Kurdu görevi başlamalı")
	_check(Dialogue.get_marker("mira") == "!", "Mira'nın üstünde yeni görev işareti (!) olmalı")
	_check(_hud.quest_tracker.visible, "HUD'da görev takibi görünmeli")


func _test_language() -> void:
	Settings.set_language("en")
	await _frames(2)
	_check(tr("UI_BAG") == "Bag" and Quests.get_title("q_main_shards") == "The Nine Shards", "İngilizceye geçince metinler İngilizce olmalı")
	await _screenshot("03_english")
	Settings.set_language("tr")
	await _frames(2)
	_check(tr("UI_BAG") == "Çanta", "Türkçeye dönünce metinler Türkçe olmalı")


func _test_defense(player: Player) -> void:
	await _go_to_map(WILD_PATH, "from_town")
	_heal()
	# Navigasyon: engellerden yürünebilir alan çıkarılmış olmalı
	await _wait(1.0)
	var nav := Map.current.navigation
	_check(nav != null and nav.navigation_polygon.get_polygon_count() > 0, "Vahşi bölgede navigasyon alanı oluşmalı")
	var path := NavigationServer2D.map_get_path(nav.get_navigation_map(), Vector2(60, 20) * 32, Vector2(10, 30) * 32, true)
	_check(path.size() > 2, "Uzak iki nokta arasında engellerden dolaşan bir yol bulunmalı (%d nokta)" % path.size())
	var orc := (_main.current_map.get_node("Entities/EnemyGroup4") as EnemyGroup).get_child(0) as Enemy
	# Parry: blok tuşuna basar basmaz gelen saldırı
	Input.action_press("block")
	await _frames(2)
	_check(player.state == Player.State.BLOCK, "Blok tuşu blok duruşuna geçirmeli")
	var result := player.take_damage(10, orc, Combat.Kind.NORMAL)
	await _frames(1)
	_check(result == Combat.Result.PARRIED, "Doğru zamanlamada saldırı parry'lenmeli")
	_check(orc.state == Enemy.State.STUNNED, "Parry'lenen düşman sersemlemeli")
	await _wait(0.4)
	var hp_before := GameState.hp
	result = player.take_damage(10, orc, Combat.Kind.NORMAL)
	_check(result == Combat.Result.BLOCKED and GameState.hp > hp_before - 10, "Geç blokta hasar büyük oranda engellenmeli")
	result = player.take_damage(10, orc, Combat.Kind.UNBLOCKABLE)
	_check(result == Combat.Result.HIT, "Engellenemez saldırı bloklanamamalı")
	Input.action_release("block")
	await _wait(0.7)
	_heal()
	# Yuvarlanma: dokunulmazlık
	GameState.stamina = GameState.max_stamina
	await _tap_action("dodge", 1)
	_check(player.state == Player.State.DODGE and player.is_invulnerable(), "Yuvarlanma sırasında dokunulmazlık olmalı")
	result = player.take_damage(30, orc, Combat.Kind.UNBLOCKABLE)
	_check(result == Combat.Result.DODGED, "Yuvarlanırken saldırı boşa gitmeli")
	_check(GameState.stamina < GameState.max_stamina, "Yuvarlanma stamina harcamalı")
	await _wait(0.5)


func _test_combat(player: Player) -> void:
	_heal()
	Quests.start("q_seren_orcs")
	var group := _main.current_map.get_node("Entities/EnemyGroup1") as EnemyGroup
	for child in group.get_children():
		child.set("_special_cooldown", 0.0)
	player.global_position = group.global_position + Vector2(0, 40)
	var gold_before := GameState.gold
	var saw_telegraph := false
	Input.action_press("attack")
	var waited := 0
	while _alive_enemies(group) > 0 and waited < 900:
		var target := _nearest_enemy(group, player)
		if target:
			var to_target := target.global_position - player.global_position
			player.aim_direction = to_target.normalized()
			player.facing = "right" if to_target.x >= 0 else "left"
			if player.global_position.distance_to(target.global_position) > 18.0:
				player.global_position = player.global_position.move_toward(target.global_position, 2.0)
		if not saw_telegraph and _has_ground_effect(AreaTelegraph):
			saw_telegraph = true
			await _screenshot("04_orc_special")
		if GameState.hp < 40:
			_heal()
		await _frames(1)
		waited += 1
	Input.action_release("attack")
	_check(_alive_enemies(group) == 0, "Ork bölüğü yenilmeli")
	_check(saw_telegraph, "Ork özel saldırısı uyarı alanı göstermeli")
	_check(Quests._states["q_seren_orcs"]["progress"][0] >= 2, "Öldürülen orklar Seren'in görevine sayılmalı")
	await _frames(40)
	var chest: Chest = null
	for child in _main.current_map.get_node("Entities").get_children():
		if child is Chest:
			chest = child
	_check(chest != null, "Bölük yenilince sandık düşmeli")
	if chest:
		player.global_position = chest.global_position + Vector2(0, 30)
		await _frames(50)
		player.global_position = chest.global_position
		await _frames(20)
		_check(GameState.gold > gold_before, "Sandık altın vermeli")


func _test_herbs_and_crafting(player: Player) -> void:
	Quests.start("q_mira_herbs")
	Quests.start("q_pip_necklace")
	await _frames(2)
	var collected := 0
	for child in _main.current_map.get_node("Entities").get_children():
		if child is ResourcePickup and child.material_id == "bloodweed" and collected < 5:
			player.global_position = child.global_position
			await _frames(4)
			collected += 1
	_check(GameState.get_material("bloodweed") >= 5, "Yerden Kanotu toplanabilmeli")
	_check(Quests.get_state("q_mira_herbs") == Quests.State.READY, "5 Kanotu toplanınca Mira'nın görevi teslim edilebilir olmalı")
	var necklace: ResourcePickup = null
	for child in _main.current_map.get_node("Entities").get_children():
		if child is ResourcePickup and child.material_id == "pip_necklace":
			necklace = child
	_check(necklace != null and necklace.visible, "Pip'in görevi alınınca kolye görünmeli")
	await _go_to_map("res://scenes/maps/town.tscn", "from_wild")
	var mira := _find_npc("mira")
	player.global_position = mira.global_position + Vector2(0, 16)
	await _frames(3)
	await _tap_action("interact")
	await _finish_dialogue()
	_check(Quests.get_state("q_mira_herbs") == Quests.State.DONE, "Mira'ya teslim edince görev tamamlanmalı")
	_check(GameState.has_flag("recipe_health_potion"), "Can iksiri tarifi açılmalı")
	_check(GameState.get_material("bloodweed") == collected - 5, "Teslimde Kanotu harcanmalı")
	# Mira'nın ikinci görevi otomatik teklif edilir; önce onu konuşarak al, sonra simya
	player.global_position = mira.global_position + Vector2(0, 16)
	await _frames(3)
	await _tap_action("interact")
	await _finish_dialogue()
	_check(Quests.get_state("q_mira_lotus") == Quests.State.ACTIVE, "Mira'nın ikinci görevi (Ay Nilüferi) alınmalı")
	GameState.add_material("bloodweed", 3, false)
	GameState.gold += 10
	var potions_before := GameState.health_potions
	await _frames(3)
	await _tap_action("interact")
	await _finish_dialogue()
	await _frames(3)
	_check(_hud.crafting.visible, "Mira ile konuşunca simya penceresi açılmalı")
	await _screenshot("05_crafting")
	_check(_hud.crafting.craft("health_potion"), "Malzeme varken iksir yapılabilmeli")
	_check(GameState.health_potions == potions_before + 1, "Simya can iksiri vermeli")
	_hud.crafting.close()
	await _frames(2)


func _test_skill(player: Player) -> void:
	await _go_to_map(WILD_PATH, "from_town")
	_heal()
	var demons := _main.current_map.get_node("Entities/EnemyGroup3") as EnemyGroup
	for child in demons.get_children():
		child.set("_special_cooldown", 99.0)
	player.global_position = demons.global_position + Vector2(0, 6)
	await _frames(5)
	GameState.mana = GameState.max_mana
	var mana_before := GameState.mana
	await _tap_action("skill", 2)
	await _frames(20)
	await _screenshot("06_skill")
	var damaged := 0
	for child in demons.get_children():
		var demon := child as Enemy
		if demon and demon.hp < demon.max_hp:
			damaged += 1
	_check(GameState.mana <= mana_before - player.skill_mana_cost + 1.0, "Yetenek mana harcamalı")
	_check(damaged >= 2, "Yetenek çevredeki tüm iblislere vurmalı (%d vuruldu)" % damaged)
	await _wait(1.0)


func _test_boss(player: Player) -> void:
	_heal()
	await _go_to_map(DEN_PATH, "from_wild")
	_check(Quests._states["q_main_fenris"]["progress"][0] == 1, "Kurt İni'ne girince görev hedefi ilerlemeli")
	var boss := _main.current_map.get_node("Entities/BossArena/Fenris") as Boss
	_check(boss != null and not boss.active, "Fenris arenada uyuyor olmalı")
	if boss == null:
		return
	player.global_position = boss.global_position + Vector2(0, 80)
	await _frames(5)
	_check(boss.active, "Arenaya girince Fenris uyanmalı")
	_check(_hud.boss_bar.visible, "Ekranın üstünde boss barı görünmeli")
	await _wait(2.0)
	await _screenshot("07_boss")
	# Hızlandırmak için boss'a doğrudan hasar ver
	_heal()
	while boss.hp > boss.max_hp * 0.45:
		boss.take_damage(30, false, player.global_position)
		await _frames(2)
	_check(boss.phase == 2, "Canı yarıya inince Fenris 2. faza geçmeli")
	await _wait(2.5)
	await _screenshot("08_boss_phase2")
	_heal()
	while is_instance_valid(boss) and boss.state != Enemy.State.DEAD:
		boss.take_damage(40, false, player.global_position)
		await _frames(2)
	await _wait(1.0)
	_check(GameState.shards.has("fenris"), "Fenris ölünce kristal parçası alınmalı")
	_check(Quests.get_state("q_main_fenris") == Quests.State.DONE, "Kül Kurdu görevi tamamlanmalı")
	_check(GameState.has_flag("boss_fenris"), "Fenris yenildi olarak kaydedilmeli")
	_check(Quests._states["q_main_shards"]["progress"][0] == 1, "Dokuz Parça görevi 1/9 olmalı")
	await _wait(1.5)
	_check(not _hud.boss_bar.visible, "Boss ölünce boss barı kapanmalı")
	await _screenshot("09_boss_defeated")


func _test_progression(player: Player) -> void:
	_check(GameState.level >= 2, "Düşman ve boss öldürmek seviye atlatmalı (seviye %d)" % GameState.level)
	_check(GameState.max_hp > GameState.BASE_MAX_HP, "Seviye atlayınca azami can artmalı")
	await _go_to_map("res://scenes/maps/town.tscn", "from_wild")
	# Dükkân: Kadir ile konuş, değerli eşyaları sat, iksir al
	GameState.add_item(ItemData.create_random(1, [ItemData.Type.VALUABLE]))
	var kadir := _find_npc("kadir")
	player.global_position = kadir.global_position + Vector2(0, 16)
	await _frames(3)
	await _tap_action("interact")
	await _finish_dialogue()
	await _frames(3)
	_check(_hud.shop.visible, "Kadir ile konuşunca dükkân açılmalı")
	await _screenshot("12_shop")
	var gold_before := GameState.gold
	_hud.shop._sell_everything()
	_check(GameState.inventory.is_empty() and GameState.gold > gold_before, "Değerli eşyalar satılabilmeli")
	GameState.gold += 50
	var potions := GameState.health_potions
	_check(GameState.buy_health_potion() and GameState.health_potions == potions + 1, "Dükkândan iksir alınabilmeli")
	_hud.shop.close()
	await _frames(2)
	# Demirci: cevher + altınla silah güçlendirme
	GameState.add_material("iron_ore", 1, false)
	GameState.gold += 30
	var damage_before := GameState.get_attack_damage()
	_hud._on_window_requested("smith")
	await _frames(3)
	_check(_hud.smith.visible, "Demirci penceresi açılmalı")
	await _screenshot("13_smith")
	_check(GameState.upgrade_weapon() and GameState.get_attack_damage() > damage_before, "Silah güçlendirilince hasar artmalı")
	_hud.smith.close()
	await _frames(2)


func _test_inventory_and_save(_player: Player) -> void:
	await _tap_action("toggle_inventory", 1, true)
	await get_tree().process_frame
	_check(get_tree().paused and _hud.inventory.visible, "Envanter açılınca oyun durmalı")
	_hud.inventory.tabs.current_tab = InventoryWindow.TAB_QUESTS
	await get_tree().process_frame
	await _screenshot("10_quests")
	_hud.inventory.close()
	await get_tree().process_frame
	_check(not get_tree().paused, "Envanter kapanınca oyun devam etmeli")
	_hud.open_pause_menu()
	await get_tree().process_frame
	await _screenshot("11_pause")
	_hud.pause_menu.resume()
	# Kayıt / yükleme
	GameState.save_game(_main.player.global_position)
	var gold := GameState.gold
	var shard_count := GameState.shards.size()
	var level := GameState.level
	var weapon_level := GameState.weapon_level
	GameState.gold = 999999
	GameState.shards.clear()
	GameState.level = 1
	GameState.weapon_level = 0
	_check(GameState.load_game(), "Kayıt dosyası yüklenebilmeli")
	_check(GameState.gold == gold and GameState.shards.size() == shard_count, "Yüklenen kayıt altını ve parçaları geri getirmeli")
	_check(GameState.level == level and GameState.weapon_level == weapon_level, "Yüklenen kayıt seviyeyi ve silah seviyesini geri getirmeli")
	_check(Quests.get_state("q_main_fenris") == Quests.State.DONE, "Yüklenen kayıt görev durumlarını geri getirmeli")


# --- Yardımcılar ---------------------------------------------------------------

func _check(condition: bool, description: String) -> void:
	print(("[OK] " if condition else "[HATA] ") + description)
	if not condition:
		_failures.append(description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# Bir aksiyonu kısa süre basılı tutar (dokunmatik butona dokunmak gibi)
func _tap_action(action: String, hold_frames: int = 2, process_frames: bool = false) -> void:
	# "Yeni basıldı" yalnızca basıldığı karede geçerli: basışı karenin başında yap
	if process_frames:
		await get_tree().process_frame
	else:
		await get_tree().physics_frame
	Input.action_press(action)
	for i in hold_frames:
		if process_frames:
			await get_tree().process_frame
		else:
			await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().process_frame


func _finish_dialogue() -> void:
	var guard := 0
	while Dialogue.is_active() and guard < 40:
		await _wait(0.25)
		_hud.dialogue_box._advance()
		guard += 1


func _go_to_map(path: String, spawn: String) -> void:
	_main.change_map(path, spawn)
	await _frames(10)


func _heal() -> void:
	GameState.hp = GameState.max_hp
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)


func _find_npc(npc_id: String) -> NPC:
	for node in get_tree().get_nodes_in_group("interactables"):
		if node is NPC and (node as NPC).npc_id == npc_id:
			return node
	return null


func _has_ground_effect(type: Variant) -> bool:
	if Map.current == null:
		return false
	for effect in Map.current.ground_effects.get_children():
		if is_instance_of(effect, type):
			return true
	return false


func _alive_enemies(group: EnemyGroup) -> int:
	var count := 0
	for child in group.get_children():
		if child is Enemy and (child as Enemy).state != Enemy.State.DEAD:
			count += 1
	return count


func _nearest_enemy(group: EnemyGroup, player: Player) -> Enemy:
	var best: Enemy = null
	for child in group.get_children():
		var enemy := child as Enemy
		if enemy and enemy.state != Enemy.State.DEAD:
			if best == null or player.global_position.distance_to(enemy.global_position) < player.global_position.distance_to(best.global_position):
				best = enemy
	return best


func _screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("user://smoke_%s.png" % file_name)
