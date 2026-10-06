extends Node
## Boss sahnelerini (scenes/bosses/*.tscn) docs/bosses.md'deki tasarıma göre üretir.
## Var olan dosyaların ÜZERİNE YAZMAZ; bir boss'u yeniden üretmek için önce dosyasını sil.
## Görseller şimdilik yer tutucu (eldeki karakterler büyütülüp renklendirildi). Zerie paketleri
## gelince sahnede Sprite > Sprite Folder değiştirilir.
##
## Çalıştırma (proje klasöründe):
##   godot --headless --path . res://tools/build_bosses.tscn

const BOSS_SCRIPT := "res://scripts/bosses/boss.gd"
const SPRITE_SCRIPT := "res://scripts/components/character_sprite.gd"
const BAR_SCRIPT := "res://scripts/components/health_bar_2d.gd"
const OUT_DIR := "res://scenes/bosses"

const SKELETON := "res://scenes/enemies/orc.tscn"
const IMP := "res://scenes/enemies/blood_monster.tscn"
const DEMON := "res://scenes/enemies/demon.tscn"

const N := Combat.Kind.NORMAL
const H := Combat.Kind.HEAVY
const U := Combat.Kind.UNBLOCKABLE
const T := BossAttack.Type


func _ready() -> void:
	for def: Dictionary in _definitions():
		var path := "%s/%s.tscn" % [OUT_DIR, def["id"]]
		if FileAccess.file_exists(path):
			continue
		_build(def, path)
		print("Boss üretildi: ", path)
	get_tree().quit()


# Her saldırı: [tür, saldırı türü, hasar, min menzil, maks menzil, faz, ağırlık, {ek ayarlar}]
func _definitions() -> Array[Dictionary]:
	return [
		{"id": "morvane", "hp": 520, "speed": 50.0, "range": 24.0, "poise": 100.0, "xp": 170,
		"folder": "res://assets/enemies/demon", "tint": Color(0.7, 0.55, 1.0), "scale": 1.5,
		"attacks": [
			[T.PROJECTILE, N, 10, 30, 220, 1, 3.0, {"count": 3, "spread": 30.0, "windup": 0.5, "recovery": 1.0}],
			[T.SUMMON, N, 0, 0, 300, 1, 1.0, {"summon": SKELETON, "summon_count": 3, "windup": 0.8, "recovery": 2.5}],
			[T.BARRAGE, U, 18, 0, 260, 1, 1.5, {"count": 1, "radius": 22.0, "windup": 0.8, "recovery": 1.2}],
			[T.TELEPORT, N, 0, 0, 50, 2, 2.0, {"teleport_distance": 120.0, "recovery": 0.4}],
			[T.PROJECTILE, N, 9, 30, 260, 2, 2.0, {"count": 5, "spread": 60.0, "homing": 0.25, "windup": 0.6}],
		]},
		{"id": "asterion", "hp": 640, "speed": 55.0, "range": 30.0, "poise": 160.0, "xp": 190,
		"folder": "res://assets/enemies/orc", "tint": Color(0.75, 0.5, 0.35), "scale": 2.0,
		"attacks": [
			[T.SLAM, H, 22, 0, 40, 1, 3.0, {"radius": 34.0, "offset": 18.0, "windup": 0.6, "recovery": 1.0}],
			[T.CHARGE, U, 26, 60, 220, 1, 2.0, {"radius": 18.0, "windup": 0.7, "charge_speed": 330.0, "charge_distance": 200.0, "recovery": 1.6}],
			[T.LINE, N, 18, 20, 200, 1, 1.5, {"radius": 12.0, "length": 180.0, "windup": 0.6}],
			[T.CHARGE, U, 26, 60, 220, 2, 3.0, {"radius": 18.0, "windup": 0.45, "charge_speed": 360.0, "charge_distance": 220.0, "recovery": 1.0}],
		]},
		{"id": "gozcu", "hp": 560, "speed": 45.0, "range": 60.0, "poise": 110.0, "xp": 210,
		"folder": "res://assets/enemies/blood_monster", "tint": Color(0.75, 0.95, 0.45), "scale": 1.8,
		"attacks": [
			[T.LINE, U, 24, 0, 260, 1, 3.0, {"radius": 10.0, "length": 240.0, "windup": 0.9, "recovery": 1.2}],
			[T.BARRAGE, N, 12, 0, 260, 1, 2.0, {"count": 4, "spread": 60.0, "radius": 18.0, "windup": 0.7}],
			[T.TELEPORT, N, 0, 0, 40, 1, 1.0, {"teleport_distance": 90.0, "recovery": 0.5}],
			[T.PROJECTILE, N, 10, 0, 260, 2, 2.0, {"count": 3, "spread": 40.0, "windup": 0.5, "projectile_color": Color(0.7, 1.0, 0.4)}],
		]},
		{"id": "bjorn", "hp": 760, "speed": 55.0, "range": 28.0, "poise": 200.0, "xp": 230,
		"folder": "res://assets/enemies/orc", "tint": Color(0.45, 0.32, 0.25), "scale": 2.1,
		"attacks": [
			[T.MELEE, H, 28, 0, 34, 1, 3.0, {"hit_frame": 3, "combo_hits": 1, "recovery": 1.2}],
			[T.RING, U, 24, 0, 60, 1, 1.5, {"radius": 64.0, "windup": 0.9, "recovery": 1.4}],
			[T.CHARGE, H, 20, 60, 180, 1, 1.0, {"radius": 18.0, "windup": 0.6, "charge_speed": 280.0, "charge_distance": 150.0}],
			[T.MELEE, H, 24, 0, 34, 2, 3.0, {"hit_frame": 3, "combo_hits": 2, "recovery": 0.9}],
		]},
		{"id": "velzara", "hp": 600, "speed": 75.0, "range": 34.0, "poise": 110.0, "xp": 250,
		"folder": "res://assets/enemies/demon", "tint": Color(1.0, 0.5, 0.55), "scale": 1.6,
		"attacks": [
			[T.MELEE, N, 16, 0, 40, 1, 3.0, {"hit_frame": 4, "combo_hits": 2, "recovery": 0.8}],
			[T.SUMMON, N, 0, 0, 300, 1, 1.0, {"summon": IMP, "summon_count": 2, "windup": 0.7, "recovery": 2.0}],
			[T.TELEPORT, N, 0, 0, 60, 1, 1.5, {"teleport_distance": 50.0, "recovery": 0.3}],
			[T.BARRAGE, U, 16, 0, 300, 2, 2.5, {"count": 7, "spread": 90.0, "radius": 16.0, "windup": 0.8}],
		]},
		{"id": "surtr", "hp": 860, "speed": 45.0, "range": 34.0, "poise": 220.0, "xp": 280,
		"folder": "res://assets/enemies/orc", "tint": Color(1.0, 0.55, 0.25), "scale": 2.2,
		"attacks": [
			[T.SLAM, H, 28, 0, 44, 1, 3.0, {"radius": 38.0, "offset": 18.0, "windup": 0.7, "recovery": 1.1}],
			[T.RING, U, 30, 0, 70, 1, 1.5, {"radius": 80.0, "windup": 1.0, "recovery": 1.5}],
			[T.BARRAGE, N, 20, 0, 300, 1, 2.0, {"count": 5, "spread": 80.0, "radius": 22.0, "windup": 0.9, "projectile_color": Color(1.0, 0.5, 0.2)}],
			[T.BARRAGE, U, 22, 0, 300, 2, 2.5, {"count": 8, "spread": 110.0, "radius": 22.0, "windup": 0.8}],
		]},
		{"id": "corvin", "hp": 820, "speed": 80.0, "range": 30.0, "poise": 180.0, "xp": 300,
		"folder": "res://assets/characters/soldier", "tint": Color(0.35, 0.33, 0.42), "scale": 1.6,
		"attacks": [
			[T.MELEE, N, 18, 0, 34, 1, 4.0, {"hit_frame": 3, "combo_hits": 4, "recovery": 0.9}],
			[T.CHARGE, U, 24, 50, 200, 1, 1.5, {"radius": 14.0, "windup": 0.5, "charge_speed": 380.0, "charge_distance": 170.0}],
			[T.SLAM, H, 22, 0, 40, 1, 1.5, {"radius": 30.0, "offset": 14.0, "windup": 0.6}],
			[T.MELEE, H, 22, 0, 34, 2, 4.0, {"hit_frame": 3, "combo_hits": 4, "recovery": 0.7}],
		]},
		{"id": "azgoroth", "hp": 900, "speed": 50.0, "range": 26.0, "poise": 150.0, "xp": 330,
		"folder": "res://assets/enemies/demon", "tint": Color(0.5, 0.35, 0.6), "scale": 1.6,
		"attacks": [
			[T.PROJECTILE, N, 14, 0, 260, 1, 3.0, {"count": 2, "spread": 25.0, "homing": 0.5, "projectile_speed": 80.0, "windup": 0.5}],
			[T.SUMMON, N, 0, 0, 300, 1, 1.0, {"summon": DEMON, "summon_count": 2, "windup": 0.9, "recovery": 3.0}],
			[T.BARRAGE, U, 24, 0, 300, 1, 2.0, {"count": 5, "spread": 100.0, "radius": 26.0, "windup": 1.0}],
			[T.TELEPORT, N, 0, 0, 50, 2, 1.5, {"teleport_distance": 110.0, "recovery": 0.4}],
			[T.CHARGE, H, 22, 50, 200, 2, 1.5, {"radius": 16.0, "windup": 0.5, "charge_speed": 320.0, "charge_distance": 160.0}],
		]},
		{"id": "malphas", "hp": 1400, "speed": 70.0, "range": 32.0, "poise": 260.0, "xp": 800,
		"folder": "res://assets/enemies/demon", "tint": Color(0.45, 0.2, 0.2), "scale": 2.3, "gives_shard": false,
		"attacks": [
			[T.MELEE, H, 26, 0, 40, 1, 3.0, {"hit_frame": 4, "combo_hits": 3, "recovery": 0.9}],
			[T.SUMMON, N, 0, 0, 300, 1, 1.0, {"summon": DEMON, "summon_count": 2, "windup": 0.9, "recovery": 3.0}],
			[T.TELEPORT, N, 0, 0, 300, 1, 1.5, {"teleport_distance": 30.0, "recovery": 0.2}],
			[T.BARRAGE, U, 26, 0, 320, 2, 2.0, {"count": 9, "spread": 120.0, "radius": 24.0, "windup": 0.9}],
			[T.LINE, U, 30, 0, 300, 2, 2.0, {"radius": 12.0, "length": 280.0, "windup": 0.8}],
			[T.RING, U, 30, 0, 70, 2, 1.0, {"radius": 90.0, "windup": 1.0}],
		]},
		{"id": "aldric", "hp": 1100, "speed": 60.0, "range": 32.0, "poise": 220.0, "xp": 400,
		"folder": "res://assets/characters/soldier", "tint": Color(1.0, 0.85, 0.5), "scale": 1.8,
		"gives_shard": false, "next": "res://scenes/bosses/malphas.tscn",
		"attacks": [
			[T.MELEE, H, 24, 0, 38, 1, 3.0, {"hit_frame": 3, "combo_hits": 3, "recovery": 1.0}],
			[T.CHARGE, H, 20, 40, 140, 1, 1.5, {"radius": 18.0, "windup": 0.55, "charge_speed": 260.0, "charge_distance": 110.0}],
			[T.SUMMON, N, 0, 0, 300, 1, 1.0, {"summon": SKELETON, "summon_count": 2, "windup": 0.9, "recovery": 3.0}],
			[T.BARRAGE, U, 24, 0, 300, 2, 2.0, {"count": 6, "spread": 90.0, "radius": 22.0, "windup": 0.9, "projectile_color": Color(0.6, 0.95, 1.0)}],
		]},
	]


func _build(def: Dictionary, path: String) -> void:
	var boss := CharacterBody2D.new()
	boss.name = str(def["id"]).capitalize()
	boss.collision_layer = 4
	boss.collision_mask = 7
	boss.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	boss.set_script(load(BOSS_SCRIPT))
	boss.set("boss_id", def["id"])
	boss.set("name_key", "BOSS_" + str(def["id"]).to_upper())
	boss.set("title_key", "BOSS_" + str(def["id"]).to_upper() + "_TITLE")
	boss.set("max_hp", def["hp"])
	boss.set("xp_reward", def["xp"])
	boss.set("move_speed", def["speed"])
	boss.set("attack_range", def["range"])
	boss.set("poise", def["poise"])
	boss.set("stun_time", 2.0)
	boss.set("gives_shard", def.get("gives_shard", true))
	if def.has("next") and ResourceLoader.exists(def["next"]):
		boss.set("next_boss_scene", load(def["next"]))
	var attacks: Array[BossAttack] = []
	for entry: Array in def["attacks"]:
		attacks.append(_attack(entry))
	boss.set("attacks", attacks)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	sprite.set_script(load(SPRITE_SCRIPT))
	sprite.set("sprite_folder", def["folder"])
	sprite.set("fps_overrides", {"idle": 8.0})
	sprite.modulate = def["tint"]
	sprite.scale = Vector2.ONE * float(def["scale"])
	_add(boss, sprite)

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 6.0 * float(def["scale"])
	shape.shape = circle
	shape.position = Vector2(0, -6)
	_add(boss, shape)

	var bar := Node2D.new()
	bar.name = "HealthBar"
	bar.set_script(load(BAR_SCRIPT))
	bar.position = Vector2(0, -32 * float(def["scale"]))
	_add(boss, bar)

	var packed := PackedScene.new()
	packed.pack(boss)
	ResourceSaver.save(packed, path)
	boss.free()


func _attack(entry: Array) -> BossAttack:
	var attack := BossAttack.make(entry[0], entry[1], entry[2], entry[3], entry[4], entry[5], entry[6])
	var extra: Dictionary = entry[7]
	for key: String in extra:
		match key:
			"summon":
				attack.summon_scene = load(extra[key])
			_:
				attack.set(key, extra[key])
	if attack.type == BossAttack.Type.MELEE:
		attack.animation = "attack"
	return attack


func _add(owner_node: Node, child: Node) -> void:
	owner_node.add_child(child)
	child.owner = owner_node
