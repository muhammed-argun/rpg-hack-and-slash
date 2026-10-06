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
	# Oyuncunun ayar dosyasına dokunma; tuşlar varsayılan olsun (testler F, W A S D gibi tuşları bekliyor)
	Settings.config_path = "user://settings_smoke_test.cfg"
	Controls.config_path = "user://settings_smoke_test.cfg"
	Controls.reset_to_defaults()
	await _test_main_menu()
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
	var purse_rect: Rect2 = _hud.purse.get_global_rect()
	_check(purse_rect.end.y <= _hud.quest_button.get_global_rect().position.y and absf(purse_rect.size.y - _hud.pause_button.size.y) <= 0.5, "Altın kesesi duraklat butonu boyunda olmalı ve görev butonunun üstüne binmemeli (%s)" % purse_rect)

	await _test_direction(player)
	await _test_aim(player)
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
		GameState.gold, GameState.health_potions, GameState.mana_potions, GameState.shards.size(), GameState.bag_used_slots()])
	if _failures.is_empty():
		print("DUMAN TESTİ BAŞARILI")
	else:
		print("DUMAN TESTİ BAŞARISIZ:\n- " + "\n- ".join(_failures))
	get_tree().quit()


# --- Testler -------------------------------------------------------------------

# Ana menü: buton paneli ve başlık ekranın ortasında olmalı
func _test_main_menu() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	add_child(menu)
	await _frames(10)
	await _screenshot("00_main_menu")
	var center_x := get_viewport().get_visible_rect().size.x / 2.0
	var panel: Control = menu.get("_buttons").get_parent()
	var panel_center := panel.get_global_rect().get_center().x
	_check(absf(panel_center - center_x) <= 1.0, "Ana menü butonları ortada olmalı (merkez %.1f, ekran %.1f)" % [panel_center, center_x])
	var title: Control = menu.get("_title")
	if title:
		var title_center := title.global_position.x + title.size.x * title.scale.x / 2.0
		_check(absf(title_center - center_x) <= 2.0, "Ana menü başlığı ortada olmalı (merkez %.1f)" % title_center)
	menu.queue_free()
	await _frames(2)

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


# Hades tarzı nişan: saldırı gamepad'de sağ çubuğa, fareyle imlece doğru
func _test_aim(player: Player) -> void:
	await _wait(0.4)
	Controls._set_using_gamepad(true)
	_aim_stick(Vector2.LEFT)
	await _tap_action("attack")
	_check(player.facing == "left" and player.attack_area.position.x < 0.0, "Sağ çubuk sola itilince saldırı sola gitmeli")
	_check(player._aim_marker.visible, "Gamepad ile oynarken nişan oku görünmeli")
	await _wait(0.5)
	_aim_stick(Vector2(0.2, 1.0))
	await _tap_action("attack")
	_check(player.attack_area.position.y > 0.0, "Sağ çubuk aşağı itilince saldırı aşağı gitmeli")
	_aim_stick(Vector2.ZERO)
	await _wait(0.5)
	# Fare: imleç karakterin sağındaysa sağa nişan
	Controls._set_using_gamepad(false)
	var screen := player.get_global_transform_with_canvas().origin
	get_viewport().warp_mouse(screen + Vector2(80, -8))
	await _frames(3)
	var aim := player.get_aim_direction()
	_check(aim.x > 0.9, "İmleç karakterin sağındaysa nişan sağa olmalı (%s)" % aim)
	get_viewport().warp_mouse(screen + Vector2(-6, 70))
	await _frames(3)
	aim = player.get_aim_direction()
	_check(aim.y > 0.9, "İmleç karakterin altındaysa nişan aşağı olmalı (%s)" % aim)
	_check(not player._aim_marker.visible, "Fareyle oynarken nişan oku gizli olmalı")
	# Çanta butonunun üstündeyken tıklamak saldırı değil
	var bag: Button = _hud.bag_button
	get_viewport().warp_mouse(bag.get_global_rect().get_center())
	await _frames(3)
	_check(player._pointer_over_ui(), "İmleç arayüz butonunun üstündeyken sol tık saldırı sayılmamalı")
	get_viewport().warp_mouse(screen + Vector2(80, -8))
	await _frames(3)


# Gamepad sağ çubuğunu verilen yöne iter (Vector2.ZERO: bırakır)
func _aim_stick(direction: Vector2) -> void:
	var d := direction.normalized()
	for pair: Array in [["aim_right", d.x], ["aim_left", -d.x], ["aim_down", d.y], ["aim_up", -d.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


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
	_check(_hud.dialogue_box.portrait.visible and _hud.dialogue_box.portrait.texture != null, "Konuşmada sağda konuşanın portresi (yer tutucu) görünmeli")
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
	# Dash: düşmanın içinden geçip arkasına çıkmalı (yürüyerek geçilemez)
	orc.set_physics_process(false)
	orc.velocity = Vector2.ZERO
	player.global_position = orc.global_position + Vector2(-26, 0)
	await _frames(3)
	_heal()
	GameState.stamina = GameState.max_stamina
	Input.action_press("move_right")
	await _tap_action("dodge", 1)
	await _wait(0.6)
	Input.action_release("move_right")
	_check(player.global_position.x > orc.global_position.x + 6.0, "Dash ile düşmanın içinden geçip arkasına çıkılmalı (%.0f > %.0f)" % [player.global_position.x, orc.global_position.x])
	_check(player.collision_mask & Player.ENEMY_LAYER != 0 and not player._overlapping_enemy(), "Dash bitince düşmanla iç içe kalmamalı, çarpışma geri gelmeli")
	orc.set_physics_process(true)
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
			# Gamepad sağ çubuğuyla düşmana nişan al
			Controls.using_gamepad = true
			_aim_stick(to_target)
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
	_aim_stick(Vector2.ZERO)
	Controls._set_using_gamepad(false)
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
	await _tap_action("skill_1", 2)
	await _frames(20)
	await _screenshot("06_skill")
	var damaged := 0
	for child in demons.get_children():
		var demon := child as Enemy
		if demon and demon.hp < demon.max_hp:
			damaged += 1
	_check(GameState.mana <= mana_before - player.skill_mana_cost + 1.0, "Yetenek mana harcamalı")
	_check(damaged >= 2, "Yetenek çevredeki tüm iblislere vurmalı (%d vuruldu)" % damaged)
	var hotbar: Hotbar = _hud._hotbar
	_check(hotbar.skill_slots[0].get_cooldown_ratio() > 0.0, "Yetenek çubuğunda E yuvası bekleme süresi göstermeli")
	_check(player.get_skill_cooldown("ground_slam") > 0.0, "Yetenek kullanılınca bekleme süresi başlamalı")
	# Boş yuva (R) bir şey yapmamalı
	await _wait(1.0)
	var mana_after := GameState.mana
	await _tap_action("skill_2", 2)
	_check(player.state != Player.State.SKILL and GameState.mana >= mana_after, "Boş yetenek yuvası (R) bir şey yapmamalı")
	await _wait(1.0)
	await _test_quick_slots(player, hotbar)


# Hızlı kullanım 1/2 ve yetenek çubuğu
func _test_quick_slots(player: Player, hotbar: Hotbar) -> void:
	var keys: Array[String] = []
	for action: String in ["skill_1", "skill_2", "skill_3", "quick_slot_1", "quick_slot_2"]:
		keys.append(hotbar._key_labels[action].text)
	_check(keys == ["E", "R", "T", "1", "2"], "Yetenek çubuğunda tuşlar E R T 1 2 olmalı (%s)" % str(keys))
	_check(hotbar.skill_slots[0].has_icon() and not hotbar.skill_slots[1].has_icon(), "E yuvasında Yer Sarsıntısı olmalı, R boş olmalı")
	await _screenshot("06b_hotbar")
	GameState.add_health_potions(1, false)
	var potions := GameState.health_potions
	GameState.hp = GameState.max_hp / 2
	var hp_before := GameState.hp
	await _tap_action("quick_slot_1", 2)
	_check(GameState.hp > hp_before and GameState.health_potions == potions - 1, "1 tuşu (hızlı kullanım 1) can iksiri içmeli")
	_check(hotbar.quick_slots[0]._count.text == str(potions - 1), "Yetenek çubuğunda iksir sayısı azalmalı")
	# Yuvalar yer değiştirince 1 tuşu mana iksiri içmeli
	GameState.set_quick_slot(0, "mana_potion")
	_check(GameState.quick_slots == ["mana_potion", "health_potion"], "Aynı eşya diğer yuvaya konunca yer değiştirmeli")
	GameState.add_mana_potions(1, false)
	GameState.mana = 0.0
	var mana_potions := GameState.mana_potions
	await _tap_action("quick_slot_1", 2)
	_check(GameState.mana_potions == mana_potions - 1 and GameState.mana > 0.0, "Yer değişince 1 tuşu mana iksiri içmeli")
	_heal()


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
	_check(not _hud.shop._has_valuables() and GameState.gold > gold_before, "Değerli eşyalar satılabilmeli")
	# Dükkânda çantadan split ile bir kısmını satma
	GameState.add_material("iron_ore", 6, false)
	var shop_bag: BagPanel = _hud.shop.bag
	var ore_index := _bag_index_of_id("iron_ore")
	var ore_before := GameState.get_material("iron_ore")
	shop_bag.select(ore_index)
	shop_bag._open_split()
	shop_bag._split_slider.value = 2
	shop_bag._confirm_split()
	var empty := GameState.bag.find(null)
	shop_bag._on_slot_pressed(empty)
	gold_before = GameState.gold
	_hud.shop._sell(empty)
	_check(GameState.get_material("iron_ore") == ore_before - 2 and GameState.gold == gold_before + 2 * GameState.MATERIAL_SELL_VALUES["iron_ore"], "Dükkânda split edilen 2 cevher satılabilmeli")
	await _screenshot("12b_shop_split")
	var necklace_added := GameState.add_material("pip_necklace", 1, false)
	gold_before = GameState.gold
	_hud.shop._sell(_bag_index_of_id("pip_necklace"))
	_check(GameState.get_material("pip_necklace") > 0 and GameState.gold == gold_before, "Görev eşyası satılamamalı")
	GameState.remove_from_bag("pip_necklace", necklace_added)
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
	await _test_equipment()
	_hud.inventory.close()
	await get_tree().process_frame
	_check(not get_tree().paused, "Envanter kapanınca oyun devam etmeli")
	await _tap_action("toggle_character", 1, true)
	await get_tree().process_frame
	_check(_hud.inventory.visible, "C tuşu da aynı (karakter + çanta) penceresini açmalı")
	await _tap_action("toggle_character", 1, true)
	await get_tree().process_frame
	_check(not _hud.inventory.visible, "C tekrar basınca pencere kapanmalı")
	await _tap_action("toggle_quests", 1, true)
	await get_tree().process_frame
	_check(_hud._quests.visible and get_tree().paused, "J tuşu görev günlüğünü açmalı")
	await _screenshot("10_quests")
	_hud._quests.close()
	await get_tree().process_frame
	_hud.open_pause_menu()
	await get_tree().process_frame
	await _screenshot("11_pause")
	await _test_controls()
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
	var saved_quick_slots := GameState.quick_slots.duplicate()
	var saved_bag_used := GameState.bag_used_slots()
	var saved_potions := GameState.health_potions
	GameState._clear_bag()
	var saved_weapon := GameState.get_equipped("main_1")
	var saved_strength := GameState.get_attribute("str")
	GameState.equipment.clear()
	GameState.attributes.clear()
	GameState.quick_slots = ["", ""]
	_check(GameState.load_game(), "Kayıt dosyası yüklenebilmeli")
	_check(GameState.gold == gold and GameState.shards.size() == shard_count, "Yüklenen kayıt altını ve parçaları geri getirmeli")
	_check(GameState.level == level and GameState.weapon_level == weapon_level, "Yüklenen kayıt seviyeyi ve silah seviyesini geri getirmeli")
	_check(Quests.get_state("q_main_fenris") == Quests.State.DONE, "Yüklenen kayıt görev durumlarını geri getirmeli")
	_check(GameState.quick_slots == saved_quick_slots, "Yüklenen kayıt hızlı kullanım yuvalarını geri getirmeli")
	_check(GameState.bag_used_slots() == saved_bag_used and GameState.health_potions == saved_potions, "Yüklenen kayıt çantayı (yerleriyle) geri getirmeli")
	_check(saved_weapon != null and GameState.get_equipped("main_1") != null and GameState.get_equipped("main_1").name_key == saved_weapon.name_key, "Yüklenen kayıt takılı silahı geri getirmeli")
	_check(GameState.get_attribute("str") == saved_strength, "Yüklenen kayıt özellikleri geri getirmeli")


# Envanter penceresi açıkken: kuşanma, çift elli silah, silah seti, çanta sınırı, split, sürükleme,
# bilgi kutusu, hızlı kullanım, özellikler, XP
func _test_equipment() -> void:
	var window: InventoryWindow = _hud.inventory
	var bag: BagPanel = window.bag
	_check(bag._slots.size() == 36, "Çantada 36 yuva olmalı")
	_check([GameState.xp_needed_for(1), GameState.xp_needed_for(2), GameState.xp_needed_for(3), GameState.xp_needed_for(4), GameState.xp_needed_for(5)] == [100, 200, 400, 700, 1200], "XP formülü 100, 200, 400, 700, 1200 olmalı")
	# Tek elli kılıç: çantadan kuşan
	GameState.equipment.clear()
	var sword := _make_item(ItemData.Type.WEAPON, "ITEM_SWORD", 5, 0, false)
	var shield := _make_item(ItemData.Type.OFFHAND, "ITEM_SHIELD", 0, 3, false)
	var greatsword := _make_item(ItemData.Type.WEAPON, "ITEM_GREATSWORD", 9, 0, true)
	for item in [sword, shield, greatsword]:
		GameState.add_to_bag(BagStack.of_item(item))
	await get_tree().process_frame
	var damage_before := GameState.get_attack_damage()
	window._quick_action_bag(GameState.bag_index_of(sword))
	_check(GameState.get_equipped("main_1") == sword and GameState.bag_index_of(sword) < 0, "Sağ tık / Kuşan: kılıç ana ele takılmalı")
	_check(GameState.get_attack_damage() == damage_before + 5, "Kuşanılan silah hasarı artırmalı")
	window._quick_action_bag(GameState.bag_index_of(shield))
	_check(GameState.get_equipped("off_1") == shield, "Kalkan ikinci ele takılmalı")
	# Çift elli silah: kalkan çantaya döner, ikinci el kilitlenir
	window._quick_action_bag(GameState.bag_index_of(greatsword))
	_check(GameState.get_equipped("main_1") == greatsword and GameState.get_equipped("off_1") == null, "Çift elli silah takılınca ikinci el boşalmalı")
	_check(GameState.bag_index_of(sword) >= 0 and GameState.bag_index_of(shield) >= 0, "Çıkan kılıç ve kalkan çantaya dönmeli")
	_check(not GameState.equip(shield), "Çift elli silah varken kalkan takılamamalı")
	await get_tree().process_frame
	await _screenshot("10_inventory")
	# Silah seti 2 boş: hasar düşmeli; geri dönünce artmalı
	var damage_set1 := GameState.get_attack_damage()
	window._on_set_pressed(2)
	_check(GameState.active_weapon_set == 2 and GameState.get_attack_damage() == damage_set1 - 9, "2. silah setine geçince 1. setin silahı sayılmamalı")
	window._on_set_pressed(1)
	# Ekipmanı çantada belli bir boş yuvaya sürükle (çıkar)
	var empty := GameState.bag.find(null)
	window._on_equipment_dropped("main_1", empty)
	_check(GameState.get_equipped("main_1") == null and GameState.bag_index_of(greatsword) == empty, "Sürükle: silah çantadaki boş yuvaya çıkmalı")
	# Çantadan ekipman yuvasına sürükle (kuşan)
	window._drop_equip(Vector2.ZERO, {"source": "bag", "index": GameState.bag_index_of(sword)}, "main_1")
	_check(GameState.get_equipped("main_1") == sword, "Sürükle: kılıç ana el yuvasına takılmalı")
	_check(not window._can_drop_equip(Vector2.ZERO, {"source": "bag", "index": GameState.bag_index_of(shield)}, "helmet"), "Kalkan kask yuvasına bırakılamamalı")

	# Split: 10 Kanotu'ndan 4'ünü ayır, boş yuvaya bırak
	var herb_before := GameState.get_material("bloodweed")
	GameState.add_material("bloodweed", 10, false)
	var herb_index := _bag_index_of_id("bloodweed")
	var herb_count := GameState.bag[herb_index].count
	bag.select(herb_index)
	_check(not bag._split_button.disabled, "En az 2 eşya varsa Split etkin olmalı")
	bag._open_split()
	_check(bag.is_split_open() and int(bag._split_slider.max_value) == herb_count, "Split kaydırıcısı yığın kadar olmalı")
	await _screenshot("10c_split")
	bag._split_slider.value = 4
	bag._confirm_split()
	_check(bag.is_holding() and bag._held.count == 4 and GameState.bag[herb_index].count == herb_count - 4, "Split: 4 tane imlece yapışmalı")
	var target := GameState.bag.find(null)
	bag._on_slot_pressed(target)
	_check(not bag.is_holding() and GameState.bag[target].count == 4 and GameState.bag[target].id == "bloodweed", "Split edilen 4 tane boş yuvaya bırakılmalı")
	# Aynı türe bırakınca birleşmeli
	bag.select(target)
	bag._open_split()
	bag._split_slider.value = 2
	bag._confirm_split()
	bag._on_slot_pressed(herb_index)
	_check(GameState.bag[herb_index].count == herb_count - 2 and GameState.bag[target].count == 2, "Split edilen eşya aynı türe bırakılınca yığınla birleşmeli")
	# Farklı eşyanın üstüne bırakınca yer değiştirmeli; o eşya imlece geçmeli
	var potion_index := _bag_index_of_id("health_potion")
	bag.select(target)
	bag._open_split()
	bag._split_slider.value = 2
	bag._confirm_split()
	bag._on_slot_pressed(potion_index)
	_check(GameState.bag[potion_index].id == "bloodweed" and bag.is_holding() and bag._held.id == "health_potion", "Farklı eşyaya bırakınca yer değiştirmeli, eski eşya imlece geçmeli")
	bag._on_slot_pressed(GameState.bag.find(null))
	_check(not bag.is_holding() and GameState.get_material("bloodweed") == herb_before + 10, "Split ve taşıma sonunda eşya kaybolmamalı")
	# Pencere kapanırken imlecteki yığın çantaya dönmeli
	bag.select(_bag_index_of_id("bloodweed"))
	bag._open_split()
	bag._split_slider.value = 1
	bag._confirm_split()
	bag.return_held()
	_check(GameState.get_material("bloodweed") == herb_before + 10, "İmlecteki yığın pencere kapanınca çantaya dönmeli")
	# Sürükle-bırak (yığının tamamı): boş yuvaya taşı, sonra başka eşyayla yer değiştir
	var from := _bag_index_of_id("bloodweed")
	var to := GameState.bag.find(null)
	bag._drop(Vector2.ZERO, {"source": "bag", "index": from}, to)
	_check(GameState.bag[from] == null or GameState.bag[from].id != "bloodweed" or from == to, "Sürükle: yığın eski yerinden ayrılmalı")
	_check(GameState.bag[to] != null and GameState.bag[to].id == "bloodweed", "Sürükle: yığın yeni yuvaya taşınmalı")
	var potion_at := _bag_index_of_id("health_potion")
	bag._drop(Vector2.ZERO, {"source": "bag", "index": to}, potion_at)
	_check(GameState.bag[potion_at].id == "bloodweed" and GameState.bag[to].id == "health_potion", "Sürükle: farklı eşyayla yer değiştirmeli")
	GameState.remove_from_bag("bloodweed", 10)

	# Bilgi kutusu: uzun metin pencereyi büyütmemeli, ekrandan taşmamalı
	var window_size := window.size
	bag._show_tooltip(GameState.bag_index_of(shield))
	await get_tree().process_frame
	var screen := get_viewport().get_visible_rect()
	_check(window.tooltip.visible and screen.encloses(window.tooltip.get_global_rect()), "Eşya bilgi kutusu ekranın içinde görünmeli")
	_check(window.size == window_size, "Eşya bilgisi pencereyi büyütmemeli")
	await _screenshot("10d_tooltip")
	window.tooltip.hide()

	# Hızlı kullanım yuvasına pencereden atama
	var mana_index := _bag_index_of_id("mana_potion")
	if mana_index >= 0:
		bag.select(mana_index)
		window._assign_quick_slot(0)
		_check(GameState.quick_slots[0] == "mana_potion", "Pencereden iksir 1. hızlı kullanım yuvasına konabilmeli")
		GameState.set_quick_slot(0, "health_potion")
	# Çanta sınırı: dolunca yeni eşya satılmalı
	var added: Array[ItemData] = []
	while GameState.bag_used_slots() < GameState.BAG_SIZE:
		var filler := _make_item(ItemData.Type.BOOTS, "ITEM_BOOTS", 0, 1, false)
		GameState.add_to_bag(BagStack.of_item(filler))
		added.append(filler)
	var gold_before := GameState.gold
	var extra := _make_item(ItemData.Type.BOOTS, "ITEM_BOOTS", 0, 1, false)
	extra.value = 7
	GameState.equipment["boots"] = _make_item(ItemData.Type.BOOTS, "ITEM_BOOTS", 0, 1, false)
	GameState.add_item(extra)
	_check(GameState.bag_used_slots() == GameState.BAG_SIZE and GameState.bag_index_of(extra) < 0 and GameState.gold == gold_before + 7, "Çanta doluyken gelen eşya satılmalı")
	await get_tree().process_frame
	await _screenshot("10b_bag_full")
	for item in added:
		GameState.bag[GameState.bag_index_of(item)] = null
	GameState.equipment.erase("boots")
	GameState._bag_changed()
	# Özellikler: her seviyede puan gelir, "+" ile dağıtılır
	var old_level := GameState.level
	var old_xp := GameState.xp
	GameState.level = 2
	GameState.xp = 0
	GameState.attribute_points = 0
	GameState.add_xp(GameState.xp_needed_for(2))
	_check(GameState.level == 3 and GameState.attribute_points == 1, "Seviye atlayınca özellik puanı gelmeli")
	await get_tree().process_frame
	_check(window._attribute_buttons["str"].visible, "Puan varken '+' butonu görünmeli")
	window._on_attribute_plus("str")
	_check(GameState.get_attribute("str") == 11 and GameState.attribute_points == 0, "'+' ile Güç 11 olmalı")
	GameState.level = maxi(old_level, GameState.level)
	GameState.xp = old_xp
	GameState._apply_level_stats()
	GameState.xp_changed.emit(GameState.xp, GameState.xp_to_next(), GameState.level)
	await get_tree().process_frame
	_check(window._xp_text.text == "%d/%d" % [GameState.xp, GameState.xp_to_next()], "XP barının üstüne gelince sayı yazmalı (%s)" % window._xp_text.text)


func _make_item(type: ItemData.Type, name_key: String, damage: int, defense: int, two_handed: bool) -> ItemData:
	var item := ItemData.new()
	item.type = type
	item.name_key = name_key
	item.damage_bonus = damage
	item.defense_bonus = defense
	item.two_handed = two_handed
	item.value = 10
	return item


func _bag_index_of_id(id: String) -> int:
	for i in GameState.bag.size():
		if GameState.bag[i] and GameState.bag[i].id == id:
			return i
	return -1

# Duraklatma menüsü açıkken: Ayarlar > Kontroller, tuş atama, çakışma, iptal, kayıt, geri tuşu
func _test_controls() -> void:
	_check(InputMap.has_action("skill_1") and InputMap.has_action("quick_slot_1") and InputMap.has_action("toggle_character"), "Yeni aksiyonlar (skill_1, quick_slot_1, toggle_character) olmalı")
	_check(Controls.get_binding("attack", 0) == "mouse:%d" % MOUSE_BUTTON_LEFT, "Saldırı varsayılan olarak sol tık olmalı")
	var settings: SettingsWindow = _hud.pause_menu._settings
	_hud.pause_menu._open_settings()
	await get_tree().process_frame
	await _screenshot("11a_settings")
	# Ekran: pencere boyutu temel çözünürlüğün tam katı olmalı; değiştirip geri al
	var window_before := get_window().size
	Settings.set_window_scale(2)
	await _frames(3)
	_check(get_window().size == Vector2i(960, 540), "Pencere boyutu 2x (960x540) olmalı (%s)" % get_window().size)
	Settings.set_window_scale(3)
	await _frames(3)
	_check(get_window().size == window_before, "Pencere boyutu geri dönmeli")
	Settings.set_vsync(false)
	var display := ConfigFile.new()
	display.load(Settings.config_path)
	_check(display.get_value("display", "vsync", true) == false and display.get_value("display", "window_scale", 0) == 3, "Ekran ayarları kaydedilmeli")
	Settings.set_vsync(true)
	settings._open_controls()
	await get_tree().process_frame
	var controls: ControlsWindow = settings._controls
	_check(controls.visible and not settings.visible, "Ayarlar > Kontroller penceresi açılmalı")
	await _screenshot("11b_controls")
	# Yuvarlanmayı G tuşuna ata
	controls._start_listening("dodge", 0)
	await _wait(0.3)
	await _press_key(KEY_G)
	var g_event := InputEventKey.new()
	g_event.physical_keycode = KEY_G
	_check(Controls.get_binding("dodge", 0) == "key:%d" % KEY_G and InputMap.event_is_action(g_event, "dodge"), "Tuş atama: yuvarlanma G tuşuna geçmeli")
	# Çakışma: etkileşimi E yap -> Yetenek 1'den kalkmalı ve oyuncuya söylenmeli
	controls._start_listening("interact", 0)
	await _wait(0.3)
	await _press_key(KEY_E)
	_check(Controls.get_binding("interact", 0) == "key:%d" % KEY_E and Controls.get_binding("skill_1", 0) == "", "Aynı tuş iki aksiyona atanınca eskisinden kalkmalı")
	_check(controls._status.text.contains(tr("ACTION_SKILL_1")), "Çakışma oyuncuya söylenmeli (yazı: %s)" % controls._status.text)
	await _screenshot("11c_controls_conflict")
	# Esc dinlemeyi iptal etmeli, duraklatma menüsünü kapatmamalı
	controls._start_listening("attack", 0)
	await _wait(0.3)
	await _press_key(KEY_ESCAPE)
	_check(not controls.is_listening() and controls.visible and _hud.pause_menu.visible, "Esc tuş beklemeyi iptal etmeli, menüyü kapatmamalı")
	_check(Controls.get_binding("attack", 0) == "mouse:%d" % MOUSE_BUTTON_LEFT, "İptal edilen atama değişmemeli")
	var saved := ConfigFile.new()
	saved.load(Controls.config_path)
	_check(saved.get_value("controls", "dodge", ["", ""])[0] == "key:%d" % KEY_G, "Atamalar ayar dosyasına kaydedilmeli")
	Controls.reset_to_defaults()
	_check(Controls.get_binding("dodge", 0) == "key:%d" % KEY_SPACE and Controls.get_binding("skill_1", 0) == "key:%d" % KEY_E, "Varsayılana dön çalışmalı")
	# Geri tuşu: Kontroller -> Ayarlar -> Duraklatma menüsü
	await _wait(0.1)
	await _press_key(KEY_ESCAPE)
	_check(not controls.visible and settings.visible, "Esc Kontroller'den Ayarlar'a dönmeli")
	await _press_key(KEY_ESCAPE)
	_check(not settings.visible and _hud.pause_menu.visible and _hud.pause_menu._panel.visible, "Esc Ayarlar'dan duraklatma menüsüne dönmeli")


# Gerçek bir klavye basışı gönderir (önce bas, sonra bırak)
func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame


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
