extends Node
## Otomatik duman testi: oyunu başlatır, vahşi bölgeye geçer, düşmanlarla savaşır (özel saldırılar
## dahil), yeteneği, iksirleri ve envanteri dener, sonuçları konsola yazar. Ekran görüntülerini user:// klasörüne kaydeder.
##
## Çalıştırma (proje klasöründe):
##   godot --path . res://tools/smoke_test.tscn

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _main: Node
var _failures: Array[String] = []


func _ready() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _frames(20)
	_check(_main.current_map.name == "Town", "Oyun şehirde başlamalı")
	_screenshot("01_town")
	var player: Player = _main.player

	# Yön: sağ+yukarı -> sağa bakar; yukarı basılıyken sola geçince hemen sola döner
	Input.action_press("move_right")
	Input.action_press("move_up")
	await _frames(5)
	_check(player.facing == "right" and not player.sprite.flip_h, "Sağ+yukarıda karakter sağa bakmalı")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(5)
	_check(player.facing == "left" and player.sprite.flip_h, "Yukarı basılıyken sola geçince karakter sola dönmeli")
	Input.action_release("move_left")
	await _frames(5)
	_check(player.facing == "left", "Sadece yukarı basılıyken son yatay yön korunmalı")
	Input.action_release("move_up")

	# Batıya yürü, çıkıştan vahşi bölgeye geç
	player.global_position = _main.current_map.get_spawn_position("from_wild") + Vector2(-40, 0)
	Input.action_press("move_left")
	await _frames(30)
	Input.action_release("move_left")
	await _frames(10)
	_check(_main.current_map.name == "Wild", "Batı çıkışı vahşi bölgeye götürmeli")
	_screenshot("02_wild")

	# İlk düşman bölüğünün (orklar) yanına git ve saldır; orkların özel saldırısı hemen hazır olsun
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
			# Hedefe doğru nişan al (joystick'i hedefe doğru tutmak gibi)
			var to_target := target.global_position - player.global_position
			player.aim_direction = to_target.normalized()
			player.facing = "right" if to_target.x >= 0 else "left"
			if player.global_position.distance_to(target.global_position) > 18.0:
				player.global_position = player.global_position.move_toward(target.global_position, 2.0)
		if not saw_telegraph and _has_ground_effect(AreaTelegraph):
			saw_telegraph = true
			_screenshot("03_orc_special")
		if waited == 60:
			_screenshot("03_combat")
		await _frames(1)
		waited += 1
	Input.action_release("attack")
	_check(_alive_enemies(group) == 0, "Bölükteki tüm düşmanlar ölmeli")
	_check(saw_telegraph, "Ork özel saldırısı uyarı alanı göstermeli")
	print("Savaş süresi: %d kare, oyuncu canı: %d/%d" % [waited, GameState.hp, GameState.max_hp])

	# Sandığın düşmesini bekle ve üstüne yürü
	await _frames(20)
	var chest: Chest = null
	for child in _main.current_map.get_node("Entities").get_children():
		if child is Chest:
			chest = child
	_check(chest != null, "Bölük yenilince sandık düşmeli")
	if chest:
		_screenshot("04_chest")
		player.global_position = chest.global_position + Vector2(0, 30)
		await _frames(50)
		player.global_position = chest.global_position
		await _frames(20)
		_check(GameState.gold > gold_before, "Sandık altın vermeli")
		_screenshot("05_loot")

	# Yetenek: iblislerin ortasında yere vur
	_heal_player()
	var demons := _main.current_map.get_node("Entities/EnemyGroup3") as EnemyGroup
	for child in demons.get_children():
		child.set("_special_cooldown", 99.0)
	player.global_position = demons.global_position + Vector2(0, 6)
	await _frames(5)
	GameState.mana = GameState.max_mana
	var mana_before := GameState.mana
	Input.action_press("skill")
	await _frames(2)
	Input.action_release("skill")
	await _frames(20)
	_screenshot("06_skill")
	var damaged := 0
	for child in demons.get_children():
		var demon := child as Enemy
		if demon and demon.hp < demon.max_hp:
			damaged += 1
	_check(GameState.mana <= mana_before - player.skill_mana_cost + 1.0, "Yetenek mana harcamalı")
	_check(damaged >= 2, "Yetenek çevredeki tüm iblislere vurmalı (%d vuruldu)" % damaged)
	await _frames(60)

	# Kan canavarı hücumu
	_heal_player()
	var monsters := _main.current_map.get_node("Entities/EnemyGroup2") as EnemyGroup
	var charger := monsters.get_child(0) as Enemy
	for child in monsters.get_children():
		child.set("_special_cooldown", 99.0)
	charger.set("_special_cooldown", 0.0)
	player.global_position = charger.global_position + Vector2(90, 0)
	var saw_charge := false
	for i in 120:
		await _frames(1)
		if charger.state == Enemy.State.SPECIAL and i % 10 == 0 and not saw_charge:
			_screenshot("07_charge_warning")
		if charger.state == Enemy.State.CHARGING:
			saw_charge = true
	_check(saw_charge, "Kan canavarı hücum etmeli")

	# İksirler
	GameState.hp = 50
	GameState.mana = 0.0
	var health_before := GameState.health_potions
	var mana_potions_before := GameState.mana_potions
	Input.action_press("use_potion")
	Input.action_press("use_mana_potion")
	await _frames(2)
	Input.action_release("use_potion")
	Input.action_release("use_mana_potion")
	_check(health_before == 0 or GameState.health_potions == health_before - 1, "Can iksiri kullanılmalı")
	_check(mana_potions_before == 0 or GameState.mana_potions == mana_potions_before - 1, "Mana iksiri kullanılmalı")

	# Envanter: aç, oyun dursun, kapat
	GameState.add_item(ItemData.create_random(1, [ItemData.Type.VALUABLE]))
	Input.action_press("toggle_inventory")
	await get_tree().process_frame
	Input.action_release("toggle_inventory")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(get_tree().paused, "Envanter açılınca oyun durmalı")
	await _screenshot("08_inventory")
	var inventory := _main.get_node("HUD").get_node("%InventoryWindow") as InventoryWindow
	inventory.close()
	await get_tree().process_frame
	_check(not get_tree().paused, "Envanter kapanınca oyun devam etmeli")

	print("Altın: %d, can iksiri: %d, mana iksiri: %d, çanta: %d eşya" % [
		GameState.gold, GameState.health_potions, GameState.mana_potions, GameState.inventory.size()])
	if _failures.is_empty():
		print("DUMAN TESTİ BAŞARILI")
	else:
		print("DUMAN TESTİ BAŞARISIZ:\n- " + "\n- ".join(_failures))
	get_tree().quit()


func _check(condition: bool, description: String) -> void:
	print(("[OK] " if condition else "[HATA] ") + description)
	if not condition:
		_failures.append(description)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _heal_player() -> void:
	GameState.hp = GameState.max_hp
	GameState.hp_changed.emit(GameState.hp, GameState.max_hp)


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
