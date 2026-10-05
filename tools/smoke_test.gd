extends Node
## Otomatik duman testi: oyunu başlatır, vahşi bölgeye geçer, bir goblin bölüğüyle
## savaşır, sandığı açar ve sonuçları konsola yazar. Ekran görüntülerini user:// klasörüne kaydeder.
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

	# Batıya yürü, çıkıştan vahşi bölgeye geç
	var player: Player = _main.player
	player.global_position = _main.current_map.get_spawn_position("from_wild") + Vector2(-40, 0)
	Input.action_press("move_left")
	await _frames(30)
	Input.action_release("move_left")
	await _frames(10)
	_check(_main.current_map.name == "Wild", "Batı çıkışı vahşi bölgeye götürmeli")
	_screenshot("02_wild")

	# İlk goblin bölüğünün yanına git ve saldır
	var group := _main.current_map.get_node("Entities/GoblinGroup1") as EnemyGroup
	player.global_position = group.global_position + Vector2(0, 40)
	var gold_before := GameState.gold
	Input.action_press("attack")
	var waited := 0
	while _alive_enemies(group) > 0 and waited < 900:
		var target := _nearest_enemy(group, player)
		if target:
			# Hedefe doğru dön (saldırı yönü baktığı yöne göre belirlenir)
			player.facing = _direction_name(target.global_position - player.global_position)
			if player.global_position.distance_to(target.global_position) > 18.0:
				player.global_position = player.global_position.move_toward(target.global_position, 2.0)
		if waited == 60:
			_screenshot("03_combat")
		await _frames(1)
		waited += 1
	Input.action_release("attack")
	_check(_alive_enemies(group) == 0, "Bölükteki tüm goblinler ölmeli")
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

	# İksir
	GameState.hp = 50
	var potions_before := GameState.potions
	Input.action_press("use_potion")
	await _frames(2)
	Input.action_release("use_potion")
	_check(potions_before == 0 or GameState.potions == potions_before - 1, "İksir kullanılmalı")

	print("Altın: %d, iksir: %d, silah: %s, zırh: %s, çanta: %d eşya" % [
		GameState.gold, GameState.potions,
		GameState.weapon.get_display_name() if GameState.weapon else "-",
		GameState.armor.get_display_name() if GameState.armor else "-",
		GameState.inventory.size()])
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


func _direction_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0 else "left"
	return "down" if direction.y > 0 else "up"


func _screenshot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("user://smoke_%s.png" % file_name)
