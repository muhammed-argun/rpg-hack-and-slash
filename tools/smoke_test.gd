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
	await _test_stun_and_charge(player)
	await _test_dialogue(player)
	await _test_language()
	await _test_defense(player)
	await _test_combat(player)
	await _test_herbs_and_crafting(player)
	await _test_skill(player)
	await _test_boss(player)
	await _test_progression(player)
	await _test_inventory_and_save(player)
	await _test_damage_floor_and_stagger(player)
	await _test_talk_hint_times_out()
	await _test_dev_console(player)

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
	# Dash düşmanı itmemeli: düşmanın fiziği açıkken içinden geçilir, düşmanın konumu değişmez
	orc.set_physics_process(true)
	orc.detect_radius = 0.0
	orc.state = Enemy.State.IDLE
	orc.velocity = Vector2.ZERO
	player.global_position = orc.global_position + Vector2(-20, 0)
	await _frames(5)
	# Önceki testten kalan sendeleme/yaralanma bitsin (yuvarlanma yalnızca serbestken başlar)
	var guard := 0
	while player.state != Player.State.NORMAL and guard < 120:
		await _frames(1)
		guard += 1
	_heal()
	GameState.stamina = GameState.max_stamina
	var orc_before := orc.global_position
	Input.action_press("move_right")
	await _tap_action("dodge", 1)
	var max_shift := 0.0
	for i in 30:
		await _frames(1)
		max_shift = maxf(max_shift, orc.global_position.distance_to(orc_before))
	Input.action_release("move_right")
	_check(max_shift < 1.0, "Dash sırasında düşman itilmemeli (en çok %.2f piksel kaydı)" % max_shift)
	_check(player.global_position.x > orc_before.x + 6.0, "Dash düşmanı aşıp arkasına geçmeli (%.0f > %.0f)" % [player.global_position.x, orc_before.x])
	orc.detect_radius = 110.0
	await _wait(0.5)


# Stun: hareket, saldırı ve blok engellenir. Blood Monster'ın hücumu hasar verir ve ~0,6 sn sersemletir;
# yalnızca zamanında parry (ve yuvarlanma) sersemlemeyi engeller, sıradan blok engellemez.
func _test_stun_and_charge(player: Player) -> void:
	_heal()
	await _wait(0.5)
	# Stun sırasında hiçbir eylem yapılamaz
	player.stun(0.8)
	_check(player.is_stunned() and player.state == Player.State.STAGGER, "Stun oyuncuyu sersemletmeli")
	var stun_position := player.global_position
	Input.action_press("move_right")
	Input.action_press("attack")
	Input.action_press("block")
	await _frames(20)
	_check(player.state == Player.State.STAGGER and player.global_position.distance_to(stun_position) < 0.5, "Sersemlemişken hareket, saldırı ve blok yapılamamalı")
	Input.action_release("move_right")
	Input.action_release("attack")
	Input.action_release("block")
	await _wait(0.8)
	_check(not player.is_stunned(), "Stun süresi bitince oyuncu serbest kalmalı")
	# Sadece basic attack (NORMAL) kilitlemez; hurt animasyonu dash/saldırı ile kesilir
	for action: String in ["dodge", "attack"]:
		_heal()
		GameState.stamina = GameState.max_stamina
		await _wait(0.4)
		for i in 5:
			player.take_damage(1, null, Combat.Kind.NORMAL)
			await _frames(1)
		_check(not player.is_stunned(), "Ardışık basic attack vuruşları oyuncuyu sersemletmemeli")
		Input.action_press(action)
		await _frames(3)
		Input.action_release(action)
		var expected := Player.State.DODGE if action == "dodge" else Player.State.ATTACK
		_check(player.state == expected, "Hasar animasyonu sırasında '%s' girdisi anında kabul edilmeli (durum %d)" % [action, player.state])
		await _wait(0.7)
	# Alan/ağır vuruşlar (HEAVY) sersemletir
	_heal()
	await _wait(0.4)
	player.take_damage(1, null, Combat.Kind.HEAVY)
	await _frames(1)
	_check(player.state == Player.State.STAGGER, "Ağır/alan vuruşu oyuncuyu sersemletmeli")
	await _wait(0.9)
	# Yuvarlanırken stun alınmaz
	GameState.stamina = GameState.max_stamina
	await _tap_action("dodge", 1)
	player.stun(1.0)
	_check(player.state == Player.State.DODGE, "Yuvarlanma sırasında stun alınmamalı")
	await _wait(0.6)

	# Hücum: Blood Monster oyuncuya doğru atılır (diğer düşmanlar karışmasın diye durdurulur)
	var frozen: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other and other.is_physics_processing():
			other.set_physics_process(false)
			frozen.append(other)
	var monster := (load("res://scenes/enemies/blood_monster.tscn") as PackedScene).instantiate() as Enemy
	_main.current_map.get_node("Entities").add_child(monster)
	monster.detect_radius = 0.0
	# Hücum yolu açık olsun: oyuncunun etrafında duvarsız bir yön seç (canavar o yönde 60 px uzakta)
	var charge_offset := Vector2(-60, 0)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if not player.test_move(player.global_transform, direction * 80.0):
			charge_offset = direction * 60.0
			break
	monster.global_position = player.global_position + charge_offset
	await _frames(3)
	_heal()
	var hp_before := GameState.hp
	var hp_after_hit := hp_before
	monster._start_special()
	var stunned := 0.0
	var waited := 0.0
	while waited < 3.0:
		await _frames(1)
		var step := get_physics_process_delta_time()
		waited += step
		if player.is_stunned():
			if stunned == 0.0:
				# İsabet anı: sonradan gelen normal saldırılar hesaba katılmasın
				hp_after_hit = GameState.hp
			stunned += step
		elif stunned > 0.0:
			break
	var expected := maxi(1, monster.special_damage - GameState.get_defense())
	_check(hp_before - hp_after_hit == expected, "Blood Monster hücumu hasar vermeli (%d bekleniyor, %d)" % [expected, hp_before - hp_after_hit])
	_check(stunned >= 0.55 and stunned <= 0.9, "Hücum oyuncuyu ~0,6 sn sersemletmeli (%.2f sn)" % stunned)
	# Sıradan blok (parry penceresi dışı): hasarı azaltır ama stun'u ENGELLEMEZ
	await _wait(0.8)
	monster.global_position = player.global_position + charge_offset
	monster.state = Enemy.State.CHASE
	monster._special_cooldown = 0.0
	await _frames(3)
	_heal()
	hp_before = GameState.hp
	Input.action_press("block")
	await _frames(3)
	monster._start_special()
	var stunned_while_blocking := false
	waited = 0.0
	while waited < 2.5:
		await _frames(1)
		waited += get_physics_process_delta_time()
		if player.state == Player.State.STAGGER:
			stunned_while_blocking = true
	Input.action_release("block")
	_check(stunned_while_blocking and GameState.hp > hp_before - monster.special_damage, "Sıradan blok hücumun hasarını azaltmalı ama stun'u engellememeli")
	# Parry (tam çarpma anında blok): stun yok, hasar yok, hücumu yapan düşman sersemler
	await _wait(1.0)
	monster.global_position = player.global_position + charge_offset
	monster.state = Enemy.State.CHASE
	monster._special_cooldown = 0.0
	monster.hp = monster.max_hp
	GameState.stamina = GameState.max_stamina
	await _frames(3)
	_heal()
	hp_before = GameState.hp
	monster._start_special()
	var stunned_after_parry := false
	var monster_stunned := false
	var block_pressed := false
	waited = 0.0
	while waited < 2.5:
		await _frames(1)
		waited += get_physics_process_delta_time()
		# Hücum başlayıp yaklaşınca (çarpmaya ~7 kare kala) blok: parry penceresi (0,2 sn) içinde kalır
		if not block_pressed and monster.state == Enemy.State.CHARGING and monster.global_position.distance_to(player.global_position) < 45.0:
			Input.action_press("block")
			block_pressed = true
		if player.state == Player.State.STAGGER:
			stunned_after_parry = true
		if monster.state == Enemy.State.STUNNED:
			monster_stunned = true
	Input.action_release("block")
	_check(block_pressed and not stunned_after_parry and GameState.hp == hp_before, "Hücuma tam zamanında parry: oyuncu sersemlemez ve hasar almaz")
	_check(monster_stunned, "Hücuma parry yapınca düşman sersemlemeli")
	var hit_ratio := float(monster.damage) / GameState.BASE_MAX_HP
	_check(hit_ratio >= 0.08 and hit_ratio <= 0.10, "Blood Monster'ın normal saldırısı başlangıç canının %%8-10'u olmalı (%.1f%%)" % (hit_ratio * 100.0))
	monster.queue_free()
	for other in frozen:
		if is_instance_valid(other):
			other.set_physics_process(true)
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
	await _test_boss_bar_hides_on_death(player)
	_heal()
	await _go_to_map(DEN_PATH, "from_wild")
	_check(Quests._states["q_main_fenris"]["progress"][0] == 1, "Kurt İni'ne girince görev hedefi ilerlemeli")
	var boss := _main.current_map.get_node("Entities/BossArena/Fenris") as Boss
	_check(boss != null and not boss.active, "Fenris arenada uyuyor olmalı")
	if boss == null:
		return
	var leap: BossAttack = null
	for attack in boss.attacks:
		if attack.type == BossAttack.Type.CHARGE:
			leap = attack
	_check(leap != null and is_equal_approx(leap.stun_time, 1.0), "Fenris atılma saldırısı oyuncuyu 1 sn sersemletmeli")
	_check(is_equal_approx(boss.phase2_threshold, 0.6) and is_equal_approx(boss.phase3_threshold, 0.3), "Fenris 2. faza %60'ta, 3. faza %30'da geçmeli")
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
	_check(boss.phase == 2, "Canı %60'a inince Fenris 2. faza geçmeli")
	await _wait(2.5)
	await _screenshot("08_boss_phase2")
	_heal()
	while boss.hp > boss.max_hp * 0.25:
		boss.take_damage(30, false, player.global_position)
		await _frames(2)
	_check(boss.phase == 3, "Canı %30'a inince Fenris 3. faza geçmeli")
	await _wait(2.0)
	await _screenshot("08b_boss_phase3")
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
	# Boss dövüşünden kalan sersemleme/yaralanma bitsin (etkileşim yalnızca serbestken çalışır)
	var free_guard := 0
	while player.state != Player.State.NORMAL and free_guard < 120:
		await _frames(1)
		free_guard += 1
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
	await _test_stack_limit_and_pad_move(window, bag)

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


# Yığın sınırı (20) ve gamepad ile taşı / böl. Çantayı geçici olarak boşaltır, bitince geri koyar.
func _test_stack_limit_and_pad_move(window: InventoryWindow, bag: BagPanel) -> void:
	var saved_bag := GameState.bag.duplicate()
	GameState._clear_bag()
	_check(GameState.MAX_STACK == 20, "Yığın sınırı 20 olmalı")
	# Ekleme: 45 malzeme 20 + 20 + 5 olarak yığınlanır
	_check(GameState.add_to_bag(BagStack.of_id("bloodweed", 45)) == 0, "45 malzeme çantaya sığmalı")
	_check(GameState.bag[0].count == 20 and GameState.bag[1].count == 20 and GameState.bag[2].count == 5, "45 malzeme 20+20+5 yığınlanmalı")
	_check(GameState.add_to_bag(BagStack.of_id("bloodweed", 10)) == 0 and GameState.bag[2].count == 15 and GameState.bag_used_slots() == 3, "Yeni eklenen mevcut yığının boşluğunu doldurmalı")
	_check(GameState.add_to_bag(BagStack.of_id("bloodweed", 10)) == 0 and GameState.bag[2].count == 20 and GameState.bag[3].count == 5, "Taşan kısım yeni yuvaya gitmeli")
	# Çanta dolu: taşan kısım geri döner, dükkân alımı reddedilir
	for i in GameState.BAG_SIZE:
		if GameState.bag[i] == null:
			GameState.bag[i] = BagStack.of_id("iron_ore", 20)
	GameState.bag[5] = BagStack.of_id("health_potion", 19)
	GameState._bag_changed()
	_check(GameState.bag_has_room_for(BagStack.of_id("health_potion", 1)) and not GameState.bag_has_room_for(BagStack.of_id("health_potion", 2)), "Dolu çantada yalnızca yığının boşluğu kadar yer olmalı")
	_check(GameState.add_to_bag(BagStack.of_id("health_potion", 4)) == 3 and GameState.bag[5].count == 20, "Sığmayan 3 iksir geri dönmeli")
	var gold_before := GameState.gold
	GameState.gold = 1000
	_check(not GameState.buy_health_potion() and GameState.gold == 1000, "Yığın dolu ve boş yuva yokken dükkândan iksir alınamamalı")
	GameState.gold = gold_before
	# Yer değiştirme/birleştirme: sınırı aşan kısım imlecte kalır
	GameState._clear_bag()
	GameState.bag[0] = BagStack.of_id("bloodweed", 15)
	GameState.bag[1] = BagStack.of_id("bloodweed", 12)
	GameState.move_slot(1, 0)
	_check(GameState.bag[0].count == 20 and GameState.bag[1] != null and GameState.bag[1].count == 7, "Sürükle: birleşince 20'yi aşan 7 tane eski yuvada kalmalı")
	var rest := GameState.place_in_slot(BagStack.of_id("bloodweed", 5), 0)
	_check(rest != null and rest.count == 5 and GameState.bag[0].count == 20, "Dolu yığına bırakılan eşya sığmayınca elde kalmalı")
	# Eski kayıttaki 20'den büyük yığın bölünür
	GameState._clear_bag()
	GameState.bag[0] = BagStack.of_id("health_potion", 50)
	GameState._split_oversized_stacks()
	_check(GameState.bag[0].count == 20 and GameState.count_in_bag("health_potion") == 50 and GameState.bag_used_slots() == 3, "Eski kayıttaki 50'lik yığın 20+20+10 olarak bölünmeli")

	# Gamepad ile taşı / böl (çanta düzeni: 0 = 12 Kanotu, 1 = 7 cevher, 2 boş)
	GameState._clear_bag()
	GameState.bag[0] = BagStack.of_id("bloodweed", 12)
	GameState.bag[1] = BagStack.of_id("iron_ore", 7)
	GameState._bag_changed()
	Controls._set_using_gamepad(true)
	_check(Controls.REBINDABLE.has("menu_move") and Controls.REBINDABLE.has("menu_split") and InputMap.has_action("menu_move") and InputMap.has_action("menu_split"), "Taşı ve Böl menü aksiyonları tanımlı ve atanabilir olmalı")
	bag.get_slot(0).grab_focus()
	await get_tree().process_frame
	var hint := bag._hint_label.text
	_check(hint.contains("X") and hint.contains("Y") and not hint.contains("{"), "Gamepad ipucu X (taşı) ve Y (böl) tuşlarını göstermeli (yazı: %s)" % hint)
	await _screenshot("10e_pad_hint")
	await _pad_press(JOY_BUTTON_X)
	_check(bag.is_holding() and bag._held.count == 12 and GameState.bag[0] == null, "Taşı tuşu odaklı yuvadaki yığını eline almalı")
	_check(bag._hint_label.text.contains("X") and bag._held_view.visible, "Elde eşya varken ipucu 'bırak' demeli ve eşya odaktaki yuvada görünmeli")
	bag.get_slot(1).grab_focus()
	await get_tree().process_frame
	await _pad_press(JOY_BUTTON_X)
	_check(bag.is_holding() and bag._held.id == "iron_ore" and GameState.bag[1].id == "bloodweed", "Taşı tuşu dolu yuvaya bırakınca yer değiştirmeli")
	bag.get_slot(0).grab_focus()
	await get_tree().process_frame
	await _pad_press(JOY_BUTTON_X)
	_check(not bag.is_holding() and GameState.bag[0].id == "iron_ore" and GameState.bag[0].count == 7, "Taşı tuşu boş yuvaya bırakınca eşya yerleşmeli")
	# Geri tuşu (B): elde tutulan eşya iptal edilir, pencere kapanmaz
	await _pad_press(JOY_BUTTON_X)
	_check(bag.is_holding(), "Taşı tuşu eşyayı almalı (iptal denemesi için)")
	window.go_back()
	_check(not bag.is_holding() and GameState.bag[0] != null and GameState.bag[0].count == 7 and window.visible, "Geri tuşu elde tutulan eşyayı yerine koymalı, pencereyi kapatmamalı")
	# Split: Y ile aç, miktar seç, A ile onayla, X ile bırak
	bag.get_slot(1).grab_focus()
	await get_tree().process_frame
	await _pad_press(JOY_BUTTON_Y)
	_check(bag.is_split_open() and int(bag._split_slider.max_value) == 12, "Böl tuşu odaklı yuva için Split penceresini açmalı")
	bag._split_slider.value = 5
	await _pad_press(JOY_BUTTON_A)
	_check(not bag.is_split_open() and bag.is_holding() and bag._held.count == 5 and GameState.bag[1].count == 7, "A Split miktarını onaylamalı, 5 tane ele alınmalı")
	bag.get_slot(2).grab_focus()
	await get_tree().process_frame
	await _pad_press(JOY_BUTTON_X)
	_check(not bag.is_holding() and GameState.bag[2].count == 5 and GameState.bag[1].count == 7, "Split edilen miktar boş yuvaya bırakılabilmeli")
	# Split açıkken B iptal eder
	bag.get_slot(1).grab_focus()
	await get_tree().process_frame
	await _pad_press(JOY_BUTTON_Y)
	window.go_back()
	_check(not bag.is_split_open() and window.visible and GameState.bag[1].count == 7, "Geri tuşu Split penceresini iptal etmeli, pencere açık kalmalı")
	Controls._set_using_gamepad(false)
	GameState.bag.assign(saved_bag)
	GameState._bag_changed()
	bag.select(-1)
	await get_tree().process_frame
	await get_tree().process_frame


# Gamepad tuşuna gerçek bir girdi olayı gönderir (BagPanel._input aksiyonları olaydan okur)
func _pad_press(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


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


# Hasar tabanı (zırh sonrası en az gelen hasarın %25'i) ve sersemletme kuralı: normal vuruş sersemletmez,
# Yer Sarsıntısı normal düşmanı sersemletir, boss ve stagger_resistant düşman yetenekle sersemlemez, parry boss'u sersemletir
func _test_damage_floor_and_stagger(player: Player) -> void:
	_heal()
	var old_armor: Variant = GameState.equipment.get("armor")
	GameState.equipment["armor"] = _make_item(ItemData.Type.ARMOR, "ITEM_PLATE_ARMOR", 0, 50, false)
	_check(GameState.damage_player(20) == 5, "Hasar tabanı: 20 hasar çok zırhla bile en az 5 olmalı (%25)")
	_heal()
	_check(GameState.damage_player(3) == 1, "Hasar tabanı: en az 1 hasar")
	_heal()
	_check(GameState.damage_player(20, false) == 1, "Taban kapalıyken (blok sızıntısı) yalnızca zırh düşer")
	if old_armor:
		GameState.equipment["armor"] = old_armor
	else:
		GameState.equipment.erase("armor")
	_heal()
	GameState.hp = GameState.max_hp
	_check(GameState.damage_player(40) == 38, "Zayıf zırhta hasar normal hesaplanmalı (40 - 2 savunma)")
	_heal()
	# Sersemletme: yalnızca Yer Sarsıntısı
	var orc := (load("res://scenes/enemies/orc.tscn") as PackedScene).instantiate() as Enemy
	_main.current_map.get_node("Entities").add_child(orc)
	orc.global_position = player.global_position + Vector2(20, 0)
	orc.max_hp = 5000
	orc.hp = 5000
	orc.detect_radius = 0.0
	orc.set_physics_process(false)
	# Stagger parametresi vermeyen vuruş düşmanı hiç kesintiye uğratmaz: durum, animasyon, hazırlık değişmez
	var interrupted := false
	for i in 12:
		for s in [Enemy.State.CHASE, Enemy.State.ATTACK, Enemy.State.SPECIAL, Enemy.State.CHARGING]:
			orc.state = s
			orc._windup_held = true
			orc._hit_done = false
			orc.take_damage(14, false, player.global_position, Player.NORMAL_HIT_KNOCKBACK_SCALE, false)
			if orc.state != s or not orc._windup_held or orc._hit_done:
				interrupted = true
	orc.state = Enemy.State.CHASE
	orc._windup_held = false
	_check(not interrupted, "Normal vuruş (stagger yok) düşmanın durumunu/hazırlığını hiç değiştirmemeli (48 deneme)")
	orc.stagger_resistant = true
	orc.take_damage(14, false, player.global_position, 1.0, true)
	_check(orc.state != Enemy.State.STUNNED, "stagger_resistant düşman Yer Sarsıntısı'ndan sersemlememeli")
	orc.stagger_resistant = false
	player.global_position = orc.global_position + Vector2(-10, 0)
	player._deal_skill_damage()
	_check(orc.state == Enemy.State.STUNNED, "Yer Sarsıntısı normal düşmanı sersemletmeli")
	orc.on_parried()
	_check(orc.state == Enemy.State.STUNNED, "Parry düşmanı yine sersemletmeli")
	orc.queue_free()
	await _test_normal_hit_single_stagger(player)
	# Boss: yetenekle sersemlemez, parry sersemletir
	var boss := (load("res://scenes/bosses/fenris.tscn") as PackedScene).instantiate() as Boss
	_main.current_map.get_node("Entities").add_child(boss)
	boss.global_position = player.global_position + Vector2(60, 0)
	boss.set_physics_process(false)
	boss.activate()
	boss.take_damage(5, false, player.global_position, 1.0, true)
	_check(boss.state != Enemy.State.STUNNED and not boss.can_be_staggered(), "Boss Yer Sarsıntısı'ndan sersemlememeli")
	boss.on_parried()
	_check(boss.state == Enemy.State.STUNNED, "Parry boss'u sersemletmeli")
	GameState.boss_ended.emit(boss)
	boss.queue_free()
	await _wait(0.3)
	_heal()


# Normal vuruş yalnızca vuruş alanındaki sersemletilebilir mob'ların en yakınını sersemletir; muaf mob sayılmaz;
# Yer Sarsıntısı hepsini sersemletir; boss etkilenmez ve normal vuruşta hiç kesintiye uğramaz (yinelenen denemelerle)
func _test_normal_hit_single_stagger(player: Player) -> void:
	_heal()
	var orcs: Array[Enemy] = []
	var offsets := [Vector2(8, -6), Vector2(18, 0), Vector2(24, -8)]
	var scene := load("res://scenes/enemies/orc.tscn") as PackedScene
	for off in offsets:
		var o := scene.instantiate() as Enemy
		_main.current_map.get_node("Entities").add_child(o)
		o.global_position = player.global_position + off
		o.max_hp = 5000
		o.hp = 5000
		o.detect_radius = 0.0
		o.set_physics_process(false)
		orcs.append(o)
	player.attack_area.position = Vector2(16, -8)
	await _frames(3)
	player._deal_attack_damage()
	_check(orcs[0].state == Enemy.State.STUNNED and orcs[1].state != Enemy.State.STUNNED and orcs[2].state != Enemy.State.STUNNED, "3 mob vuruş alanındayken normal vuruş yalnızca en yakınını sersemletmeli")
	_check(orcs[1].hp < 5000 and orcs[2].hp < 5000, "Sersemletilmeyen mob'lar normal vuruşta yine hasar almalı")
	# Muaf mob "en yakın" seçiminde sayılmaz: bir sonraki en yakın sersemler
	orcs[0]._end_stun()
	orcs[0].state = Enemy.State.CHASE
	orcs[0].normal_hit_stagger_immune = true
	player._deal_attack_damage()
	_check(orcs[0].state != Enemy.State.STUNNED and orcs[1].state == Enemy.State.STUNNED and orcs[2].state != Enemy.State.STUNNED, "normal_hit_stagger_immune mob sayılmamalı, sıradaki en yakın sersemlemeli")
	# Yer Sarsıntısı muaf olanı da dahil hepsini sersemletir
	for o in orcs:
		o._end_stun()
		o.state = Enemy.State.CHASE
	player.global_position = orcs[1].global_position + Vector2(-10, 0)
	player._deal_skill_damage()
	var all_stunned := true
	for o in orcs:
		if o.state != Enemy.State.STUNNED:
			all_stunned = false
	_check(all_stunned, "Yer Sarsıntısı alandaki bütün mob'ları (normal vuruştan muaf olan dahil) sersemletmeli")
	# Boss: normal vuruşta hiç kesintiye uğramaz, aday olarak da seçilmez
	for o in orcs:
		o.queue_free()
	await _frames(2)
	var boss := (load("res://scenes/bosses/fenris.tscn") as PackedScene).instantiate() as Boss
	_main.current_map.get_node("Entities").add_child(boss)
	boss.global_position = player.global_position + Vector2(18, 0)
	boss.set_physics_process(false)
	boss.max_hp = 100000
	boss.hp = 100000
	boss.activate()
	await _frames(3)
	var boss_interrupted := false
	for i in 12:
		for s in [Enemy.State.CHASE, Enemy.State.ATTACK, Enemy.State.SPECIAL, Enemy.State.CHARGING]:
			boss.state = s
			boss._hit_done = false
			player._deal_attack_damage()
			if boss.state != s or boss._hit_done:
				boss_interrupted = true
	_check(not boss_interrupted, "Boss normal vuruşta hiç kesintiye uğramamalı (48 deneme)")
	_check(boss.hp < boss.max_hp, "Boss normal vuruştan hasar almalı")
	GameState.boss_ended.emit(boss)
	boss.queue_free()
	await _wait(0.3)
	_heal()


# Öğretici "talk" ipucu 3 sn sonra kendiliğinden kaybolur ve bir daha çıkmaz
func _test_talk_hint_times_out() -> void:
	var hints := TutorialHints.new()
	_hud.get_node("Root").add_child(hints)
	var had_flag := GameState.has_flag("tutorial_talk")
	GameState.flags.erase("tutorial_talk")
	hints._show("talk", "HINT_TALK")
	await _wait(1.0)
	_check(hints.visible and hints._current == "talk" and hints._label.text.contains("F"), "Etkileşim ipucu başta görünmeli ve F tuşunu göstermeli (yazı: %s)" % hints._label.text)
	await _wait(3.0)
	_check(hints._current.is_empty() and GameState.has_flag("tutorial_talk"), "Etkileşim ipucu ~3 sn sonra kaybolmalı ve tekrar gösterilmemek üzere kaydedilmeli")
	hints.queue_free()
	if had_flag:
		GameState.set_flag("tutorial_talk")


# Oyuncu ölünce boss barı kalkar; boss'a yeniden yaklaşılınca (yeni dövüş) bar tekrar çıkar
func _test_boss_bar_hides_on_death(player: Player) -> void:
	_heal()
	await _go_to_map(DEN_PATH, "from_wild")
	var boss := _main.current_map.get_node_or_null("Entities/BossArena/Fenris") as Boss
	if boss == null:
		_check(GameState.has_flag("boss_fenris"), "Boss barı testi: Fenris (yenilmediyse) arenada olmalı")
		return
	player.global_position = boss.global_position + Vector2(0, 80)
	await _frames(5)
	_check(boss.active and _hud.boss_bar.visible, "Boss barı testi: dövüş başlayınca bar görünmeli")
	GameState.damage_player(GameState.hp + 1000, false)
	await _frames(3)
	_check(not _hud.boss_bar.visible and _hud._boss == null, "Oyuncu ölünce boss barı kapanmalı")
	await _wait(3.0)
	_check(not _hud.boss_bar.visible, "Oyuncu yeniden doğarken boss barı kapalı kalmalı")
	# Yeniden doğma şehre taşır; Kurt İni'ne dönünce boss dolu canla başlar ve bar tekrar çıkar
	await _go_to_map(DEN_PATH, "from_wild")
	var boss2 := _main.current_map.get_node_or_null("Entities/BossArena/Fenris") as Boss
	_check(boss2 != null and boss2.hp == boss2.max_hp and not boss2.active, "Yeniden girince Fenris dolu canla uyuyor olmalı")
	if boss2:
		player.global_position = boss2.global_position + Vector2(0, 80)
		await _frames(5)
		_check(boss2.active and _hud.boss_bar.visible, "Boss'a yeniden yaklaşınca boss barı tekrar görünmeli")
	_heal()


# Geliştirici konsolu: Enter çubuğu, "zort" ile açılma, F9 konsol, god mode, eşya ekleme, düşman çağırma, ışınlanma
func _test_dev_console(player: Player) -> void:
	_heal()
	await _wait(0.3)
	var prompt: DevPrompt = _hud._dev_prompt
	var console: DevConsole = _hud._dev_console
	_check(not GameState.dev_mode and not prompt.visible and not console.visible, "Dev modu başta kapalı olmalı")
	# F9 dev modu kapalıyken hiçbir şey yapmaz
	await _press_key(DevConsole.TOGGLE_KEY)
	_check(not console.visible and not get_tree().paused, "Dev modu kapalıyken konsol tuşu bir şey yapmamalı")
	# Enter komut çubuğunu açar ve oyunu duraklatır
	await _press_key(KEY_ENTER)
	_check(prompt.visible and get_tree().paused, "Enter komut çubuğunu açmalı (oyun duraklar)")
	await _screenshot("12a_dev_prompt")
	# Yanlış kelime: çubuk kapanır, dev modu açılmaz
	prompt._edit.text = "abc"
	await _press_key(KEY_ENTER)
	_check(not prompt.visible and not get_tree().paused and not GameState.dev_mode, "Yanlış kelime yalnızca çubuğu kapatmalı")
	# Esc çubuğu kapatır
	await _press_key(KEY_ENTER)
	_check(prompt.visible, "Enter çubuğu tekrar açmalı")
	await _press_key(KEY_ESCAPE)
	_check(not prompt.visible and not get_tree().paused and not _hud.pause_menu.visible, "Esc çubuğu kapatmalı (duraklatma menüsü açılmamalı)")
	# Bir pencere açıkken Enter çubuğu açmaz
	_hud._on_window_opened()
	_hud._quests.open()
	await _press_key(KEY_ENTER)
	_check(not prompt.visible, "Pencere açıkken Enter komut çubuğunu açmamalı")
	_hud._quests.close()
	await get_tree().process_frame
	# "ZORT" (büyük harf fark etmez) dev modunu açar
	await _press_key(KEY_ENTER)
	prompt._edit.text = "ZORT"
	await _press_key(KEY_ENTER)
	_check(GameState.dev_mode and not prompt.visible and not get_tree().paused, "'zort' yazılınca dev modu açılmalı ve çubuk kapanmalı")
	_check(not Controls.REBINDABLE.has("dev_console") and not InputMap.has_action("dev_console"), "Dev konsolu tuşu ayarlarda görünmemeli")
	# F9 konsolu açar
	await _press_key(DevConsole.TOGGLE_KEY)
	_check(console.visible and get_tree().paused, "Dev modunda konsol tuşu konsolu açmalı")
	await _screenshot("12b_dev_console")
	# God mode: hasar yok
	console._god_check.button_pressed = true
	_check(GameState.god_mode, "God mode açılmalı")
	var hp_before := GameState.hp
	var result := player.take_damage(30, null, Combat.Kind.UNBLOCKABLE)
	_check(result == Combat.Result.DODGED and GameState.hp == hp_before and not player.is_stunned(), "God mode'da oyuncu hasar almamalı")
	console._god_check.button_pressed = false
	_check(not GameState.god_mode, "God mode kapanmalı")
	# Eşya ekleme
	var potions := GameState.health_potions
	var used := GameState.bag_used_slots()
	var entries := console._item_entries
	var potion_entry: Dictionary = entries.filter(func(e: Dictionary) -> bool: return e["kind"] == "health_potion")[0]
	var gear_entry: Dictionary = entries.filter(func(e: Dictionary) -> bool: return e.get("name_key", "") == "ITEM_SWORD")[0]
	_check(console.add_to_bag(potion_entry, 3) == 3 and GameState.health_potions == potions + 3, "Dev konsolu çantaya iksir eklemeli")
	used = GameState.bag_used_slots()
	_check(console.add_to_bag(gear_entry, 2, ItemData.Rarity.RARE) == 2 and GameState.bag_used_slots() == used + 2, "Dev konsolu çantaya ekipman eklemeli (her biri ayrı yuva)")
	var found_rare := false
	for stack in GameState.bag:
		if stack and stack.item and stack.item.name_key == "ITEM_SWORD" and stack.item.rarity == ItemData.Rarity.RARE and stack.item.damage_bonus > 0:
			found_rare = true
	_check(found_rare, "Eklenen kılıç seçilen nadirlikte ve güçlü olmalı")
	# Düşman çağırma
	var before := get_tree().get_nodes_in_group("enemies").size()
	var spawned := console.spawn_enemies("res://scenes/enemies/blood_monster.tscn", 3)
	_check(spawned == 3 and get_tree().get_nodes_in_group("enemies").size() == before + 3, "Dev konsolu istenen sayıda düşman çağırmalı")
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy and (node as Enemy).enemy_id == "blood_monster" and (node as Enemy).global_position.distance_to(player.global_position) < 80.0:
			node.queue_free()
	# Işınlanma: şehir
	var target_index := -1
	for i in console._teleport_targets.size():
		if console._teleport_targets[i][0].ends_with("town.tscn") and console._teleport_targets[i][1] == "from_wild":
			target_index = i
	_check(target_index >= 0, "Işınlanma listesinde şehir giriş noktaları olmalı")
	_main.change_map(WILD_PATH, "from_town")
	await _frames(10)
	console._teleport_list.select(target_index)
	console._teleport()
	await _frames(10)
	_check(_main.current_map.name == "Town" and not console.visible and not get_tree().paused, "Dev konsolundan ışınlanınca harita değişmeli ve oyun devam etmeli")
	# F9 ve Esc ile kapanır
	await _press_key(DevConsole.TOGGLE_KEY)
	_check(console.visible, "Konsol tekrar açılmalı")
	await _press_key(DevConsole.TOGGLE_KEY)
	_check(not console.visible and not get_tree().paused, "Konsol tuşu konsolu kapatmalı")
	await _press_key(DevConsole.TOGGLE_KEY)
	await _press_key(KEY_ESCAPE)
	_check(not console.visible and not get_tree().paused and not _hud.pause_menu.visible, "Esc konsolu kapatmalı")
	GameState.dev_mode = false
	_heal()


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
