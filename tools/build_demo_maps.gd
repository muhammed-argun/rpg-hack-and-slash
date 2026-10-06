extends Node
## Demo için tileset'i ve örnek haritaları oluşturur: Varneth (şehir), Kül Ormanı Eteği (vahşi bölge)
## ve Kurt İni (Fenris'in boss arenası). Var olan harita ve tileset dosyalarının ÜZERİNE YAZMAZ;
## bir haritayı yeniden üretmek için önce dosyasını sil.
##
## Çalıştırma (proje klasöründe, önce generate_placeholders.gd ve --import çalışmış olmalı):
##   godot --headless --path . res://tools/build_demo_maps.tscn
## (Sahne olarak çalışır, çünkü oyun scriptleri autoload'lara ihtiyaç duyar.)

const TILESET_TEXTURE := "res://assets/tiles/tileset.png"
const TILESET_PATH := "res://assets/tiles/tileset.tres"
const TOWN_PATH := "res://scenes/maps/town.tscn"
const WILD_PATH := "res://scenes/maps/wild.tscn"
const DEN_PATH := "res://scenes/maps/ashwood_den.tscn"
const PROLOGUE_PATH := "res://scenes/maps/prologue.tscn"
const EXIT_SCENE := "res://scenes/world/map_exit.tscn"
const NPC_SCENE := "res://scenes/world/npc.tscn"
const PICKUP_SCENE := "res://scenes/world/resource_pickup.tscn"
const ORC_SCENE := "res://scenes/enemies/orc.tscn"
const BLOOD_MONSTER_SCENE := "res://scenes/enemies/blood_monster.tscn"
const DEMON_SCENE := "res://scenes/enemies/demon.tscn"
const FENRIS_SCENE := "res://scenes/bosses/fenris.tscn"
const TILE := 32

# Tileset içindeki kare sırası (assets/tiles/tileset.png, soldan sağa)
enum T { GRASS, DIRT, COBBLE, WALL, TREE, WATER }


func _ready() -> void:
	var tileset := _get_tileset()
	if not FileAccess.file_exists(TOWN_PATH):
		_build_town(tileset)
	if not FileAccess.file_exists(WILD_PATH):
		_build_wild(tileset)
	if not FileAccess.file_exists(DEN_PATH):
		_build_den(tileset)
	if not FileAccess.file_exists(PROLOGUE_PATH):
		_build_prologue(tileset)
	print("Demo haritaları hazır.")
	get_tree().quit()


# --- Tileset ---------------------------------------------------------------

func _get_tileset() -> TileSet:
	if FileAccess.file_exists(TILESET_PATH):
		return load(TILESET_PATH)
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TILESET_TEXTURE)
	source.texture_region_size = Vector2i(TILE, TILE)
	for i in T.size():
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)

	var half := TILE / 2.0
	var full := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	_set_collision(source, T.WALL, full)
	_set_collision(source, T.WATER, full)
	# Ağaçta yalnızca gövdenin alt kısmı engel olur, oyuncu yaprakların arkasına geçebilir
	_set_collision(source, T.TREE, PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(8, 14), Vector2(-8, 14)]))

	ResourceSaver.save(tileset, TILESET_PATH)
	return load(TILESET_PATH)


func _set_collision(source: TileSetAtlasSource, tile: T, points: PackedVector2Array) -> void:
	var data := source.get_tile_data(Vector2i(tile, 0), 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, points)


# --- Harita iskeleti ve yardımcılar ------------------------------------------

func _new_map(map_name: String, size: Vector2i, tileset: TileSet) -> Dictionary:
	var map := Node2D.new()
	map.name = map_name
	map.set_script(load("res://scripts/world/map.gd"))
	map.set("map_size", size)

	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	_add(map, map, ground)

	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	_add(map, map, entities)

	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tileset
	walls.y_sort_enabled = true
	_add(map, entities, walls)

	var spawns := Node2D.new()
	spawns.name = "Spawns"
	_add(map, map, spawns)

	var exits := Node2D.new()
	exits.name = "Exits"
	_add(map, map, exits)

	return {"map": map, "ground": ground, "walls": walls, "entities": entities, "spawns": spawns, "exits": exits}


func _set_map_info(parts: Dictionary, map_id: String, name_key: String, tint: Color = Color.WHITE, music: String = "wild") -> void:
	var map: Node = parts["map"]
	map.set("music", music)
	map.set("map_id", map_id)
	map.set("name_key", name_key)
	map.set("tint", tint)


func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node


func _fill(layer: TileMapLayer, rect: Rect2i, tile: T) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			layer.set_cell(Vector2i(x, y), 0, Vector2i(tile, 0))


func _border(layer: TileMapLayer, size: Vector2i, tile: T, gaps: Array[Rect2i]) -> void:
	for y in size.y:
		for x in size.x:
			if x != 0 and y != 0 and x != size.x - 1 and y != size.y - 1:
				continue
			var cell := Vector2i(x, y)
			var in_gap := false
			for gap in gaps:
				if gap.has_point(cell):
					in_gap = true
			if not in_gap:
				layer.set_cell(cell, 0, Vector2i(tile, 0))


func _add_spawn(parts: Dictionary, spawn_name: String, cell: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = spawn_name
	marker.position = cell * TILE
	_add(parts["map"], parts["spawns"], marker)


func _add_exit(parts: Dictionary, exit_name: String, center_cell: Vector2, size_tiles: Vector2, target_map: String, target_spawn: String) -> void:
	var exit := (load(EXIT_SCENE) as PackedScene).instantiate()
	exit.name = exit_name
	exit.position = center_cell * TILE
	exit.set("exit_size", size_tiles * TILE)
	exit.set("target_map", target_map)
	exit.set("target_spawn", target_spawn)
	_add(parts["map"], parts["exits"], exit)


func _add_enemy_group(parts: Dictionary, group_name: String, cell: Vector2, count: int, loot_level: int, enemy_scene: String) -> void:
	var group := Node2D.new()
	group.set_script(load("res://scripts/enemies/enemy_group.gd"))
	group.name = group_name
	group.position = cell * TILE
	group.y_sort_enabled = true
	group.set("loot_level", loot_level)
	_add(parts["map"], parts["entities"], group)
	var offsets := [Vector2(-20, -10), Vector2(18, -6), Vector2(0, 16), Vector2(-14, 20)]
	for i in count:
		var enemy := (load(enemy_scene) as PackedScene).instantiate()
		enemy.name = "%s%d" % [enemy.name, i + 1]
		enemy.position = offsets[i % offsets.size()]
		_add(parts["map"], group, enemy)


func _add_npc(parts: Dictionary, npc_id: String, cell: Vector2, tint: Color, face_left: bool = false) -> void:
	var npc := (load(NPC_SCENE) as PackedScene).instantiate()
	npc.name = npc_id.capitalize()
	npc.position = cell * TILE
	npc.set("npc_id", npc_id)
	npc.set("tint", tint)
	npc.set("face_left", face_left)
	_add(parts["map"], parts["entities"], npc)


func _add_pickup(parts: Dictionary, material_id: String, cell: Vector2, required_quest: String = "") -> void:
	var pickup := (load(PICKUP_SCENE) as PackedScene).instantiate()
	pickup.name = "%s_%d_%d" % [material_id.capitalize().replace(" ", ""), int(cell.x), int(cell.y)]
	pickup.position = cell * TILE
	pickup.set("material_id", material_id)
	pickup.set("required_quest", required_quest)
	_add(parts["map"], parts["entities"], pickup)


func _save_map(parts: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(parts["map"])
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Harita kaydedilemedi: %s (hata %d)" % [path, err])
	(parts["map"] as Node).free()


# --- Şehir: Varneth (48x32) ----------------------------------------------------
# Batıda vahşi bölgeye çıkış, kuzeyde Kül Kalkanı'yla kapalı kale yolu. NPC'ler burada.

func _build_town(tileset: TileSet) -> void:
	var size := Vector2i(48, 32)
	var parts := _new_map("Town", size, tileset)
	_set_map_info(parts, "town", "MAP_TOWN", Color.WHITE, "town")
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	_fill(ground, Rect2i(6, 5, 36, 22), T.COBBLE)
	_fill(ground, Rect2i(0, 14, 6, 4), T.DIRT)
	_fill(ground, Rect2i(22, 0, 4, 5), T.DIRT)
	_fill(ground, Rect2i(22, 27, 4, 5), T.DIRT)

	_border(walls, size, T.WALL, [Rect2i(0, 14, 1, 4), Rect2i(22, 0, 4, 1), Rect2i(22, 31, 4, 1)])
	# Binalar: tapınak (sol üst), şifacı (sağ üst), demirci (sol alt), tüccar (sağ alt)
	for building in [Rect2i(10, 6, 7, 5), Rect2i(30, 6, 8, 5), Rect2i(10, 21, 7, 5), Rect2i(31, 21, 7, 5)]:
		_fill(walls, building, T.WALL)
	# Meydandaki havuz
	_fill(walls, Rect2i(23, 15, 2, 2), T.WATER)
	# Süs ağaçları
	for tree in [Vector2i(3, 4), Vector2i(4, 25), Vector2i(43, 4), Vector2i(43, 27), Vector2i(19, 3), Vector2i(28, 3), Vector2i(27, 28)]:
		walls.set_cell(tree, 0, Vector2i(T.TREE, 0))

	_add_npc(parts, "ezra", Vector2(13.5, 12.5), Color(1.0, 0.95, 0.75))
	_add_npc(parts, "mira", Vector2(33.5, 12.5), Color(0.7, 1.0, 0.75), true)
	_add_npc(parts, "borak", Vector2(13.5, 19.5), Color(0.8, 0.65, 0.55))
	_add_npc(parts, "kadir", Vector2(34.5, 19.5), Color(1.0, 0.8, 0.5), true)
	_add_npc(parts, "seren", Vector2(7.5, 13.5), Color(0.7, 0.8, 1.0))
	_add_npc(parts, "pip", Vector2(21.5, 18.5), Color(1.0, 0.9, 0.9))

	# Kale yolu: Kül Kalkanı
	var barrier := Node2D.new()
	barrier.set_script(load("res://scripts/world/castle_barrier.gd"))
	barrier.name = "CastleBarrier"
	barrier.position = Vector2(24, 1.5) * TILE
	barrier.set("size", Vector2(4 * TILE, TILE))
	barrier.set("interact_radius", 40.0)
	_add(parts["map"], parts["entities"], barrier)

	_add_spawn(parts, "start", Vector2(24.5, 20))
	_add_spawn(parts, "from_wild", Vector2(3, 16))
	_add_spawn(parts, "from_prologue", Vector2(24, 28.5))
	_add_exit(parts, "ExitWest", Vector2(0.5, 16), Vector2(1, 4), WILD_PATH, "from_town")
	_add_exit(parts, "ExitSouth", Vector2(24, 31.5), Vector2(4, 1), PROLOGUE_PATH, "from_town")
	_save_map(parts, TOWN_PATH)


# --- Vahşi bölge: Kül Ormanı Eteği (64x40) ---------------------------------------
# Doğuda şehir, kuzeyde Kurt İni. Rurik'in kampı, otlar, cevherler, 4 düşman bölüğü.

func _build_wild(tileset: TileSet) -> void:
	var size := Vector2i(64, 40)
	var parts := _new_map("Wild", size, tileset)
	_set_map_info(parts, "ashwood_outskirts", "MAP_WILD")
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	var path_rects: Array[Rect2i] = [Rect2i(30, 19, 34, 2), Rect2i(30, 0, 2, 34)]
	for rect in path_rects:
		_fill(ground, rect, T.DIRT)

	_border(walls, size, T.TREE, [Rect2i(63, 18, 1, 4), Rect2i(29, 0, 4, 1)])
	_fill(walls, Rect2i(18, 7, 6, 4), T.WATER)

	# Bölük adı: [konum (kare), düşman sayısı, ganimet seviyesi, düşman sahnesi]
	var groups := {
		"EnemyGroup1": [Vector2(44, 11), 2, 1, ORC_SCENE],
		"EnemyGroup2": [Vector2(20, 27), 3, 1, BLOOD_MONSTER_SCENE],
		"EnemyGroup3": [Vector2(10, 15), 2, 2, DEMON_SCENE],
		"EnemyGroup4": [Vector2(48, 29), 2, 1, ORC_SCENE],
	}
	var bloodweed := [Vector2(36, 16), Vector2(40, 23), Vector2(26, 21), Vector2(46, 17), Vector2(34, 26), Vector2(55, 25), Vector2(24, 14), Vector2(42, 32)]
	var moonlotus := [Vector2(17, 12), Vector2(24.5, 11.5), Vector2(16.5, 8), Vector2(25, 8), Vector2(20.5, 12)]
	var ore := [Vector2(8, 8), Vector2(12, 31), Vector2(26, 34), Vector2(48, 5), Vector2(58, 34)]
	var necklace := Vector2(42, 21.5)
	var camp := Rect2i(50, 9, 9, 7)
	var pickups: Array = bloodweed + moonlotus + ore + [necklace]

	# Rastgele ağaçlar (yollardan, gölden, kamptan, bölüklerden ve eşyalardan uzak)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(2, size.y - 2):
		for x in range(2, size.x - 2):
			if rng.randf() > 0.05:
				continue
			var cell := Vector2i(x, y)
			var blocked := Rect2i(15, 5, 12, 9).has_point(cell) or Rect2i(56, 16, 8, 8).has_point(cell) or camp.has_point(cell)
			for rect in path_rects:
				if rect.grow(1).has_point(cell):
					blocked = true
			for info: Array in groups.values():
				if Vector2(cell).distance_to(info[0]) < 4.0:
					blocked = true
			for spot: Vector2 in pickups:
				if Vector2(cell).distance_to(spot) < 1.5:
					blocked = true
			if not blocked:
				walls.set_cell(cell, 0, Vector2i(T.TREE, 0))

	_add_npc(parts, "rurik", Vector2(54, 12), Color(0.85, 0.75, 0.55), true)
	for spot: Vector2 in bloodweed:
		_add_pickup(parts, "bloodweed", spot)
	for spot: Vector2 in moonlotus:
		_add_pickup(parts, "moonlotus", spot)
	for spot: Vector2 in ore:
		_add_pickup(parts, "iron_ore", spot)
	_add_pickup(parts, "pip_necklace", necklace, "q_pip_necklace")

	_add_spawn(parts, "from_town", Vector2(60, 20))
	_add_spawn(parts, "from_den", Vector2(31, 3))
	_add_exit(parts, "ExitEast", Vector2(63.5, 20), Vector2(1, 4), TOWN_PATH, "from_wild")
	_add_exit(parts, "ExitNorth", Vector2(31, 0.5), Vector2(4, 1), DEN_PATH, "from_wild")
	for group_name: String in groups:
		var info: Array = groups[group_name]
		_add_enemy_group(parts, group_name, info[0], info[1], info[2], info[3])
	_save_map(parts, WILD_PATH)


# --- Boss arenası: Kurt İni (40x30) -----------------------------------------------
# Güneyden giriş. Oyuncu arenaya girince kapı kapanır ve Fenris uyanır.

func _build_den(tileset: TileSet) -> void:
	var size := Vector2i(40, 30)
	var parts := _new_map("AshwoodDen", size, tileset)
	_set_map_info(parts, "ashwood_den", "MAP_ASHWOOD_DEN", Color(0.82, 0.76, 0.76))
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	_fill(ground, Rect2i(18, 22, 4, 8), T.DIRT)
	_fill(ground, Rect2i(12, 8, 16, 10), T.DIRT)
	_border(walls, size, T.TREE, [Rect2i(18, 29, 4, 1)])
	# Arenayı daraltan iç ağaçlar (köşeler)
	for tree in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(34, 4), Vector2i(35, 4), Vector2i(35, 5),
			Vector2i(4, 22), Vector2i(4, 23), Vector2i(35, 22), Vector2i(35, 23), Vector2i(9, 13), Vector2i(30, 13)]:
		walls.set_cell(tree, 0, Vector2i(T.TREE, 0))

	var arena := Node2D.new()
	arena.set_script(load("res://scripts/bosses/boss_arena.gd"))
	arena.name = "BossArena"
	arena.position = Vector2(20, 13) * TILE
	arena.y_sort_enabled = true
	arena.set("trigger_size", Vector2(34, 20) * TILE)
	_add(parts["map"], parts["entities"], arena)
	var boss := (load(FENRIS_SCENE) as PackedScene).instantiate()
	boss.name = "Fenris"
	_add(parts["map"], arena, boss)
	var gate := StaticBody2D.new()
	gate.set_script(load("res://scripts/bosses/arena_gate.gd"))
	gate.name = "SouthGate"
	gate.position = Vector2(20, 28.5) * TILE - arena.position
	gate.set("size", Vector2(5 * TILE, TILE))
	_add(parts["map"], arena, gate)

	_add_spawn(parts, "from_wild", Vector2(20, 26))
	_add_exit(parts, "ExitSouth", Vector2(20, 29.5), Vector2(4, 1), WILD_PATH, "from_den")
	_save_map(parts, DEN_PATH)


# --- Prolog: Varneth Yolu (50x18) -------------------------------------------------
# Gece. Oyun burada başlar: ork yağmacıları saldırır, öğretici ipuçları çıkar. Doğuda şehir kapısı.

func _build_prologue(tileset: TileSet) -> void:
	var size := Vector2i(50, 18)
	var parts := _new_map("Prologue", size, tileset)
	_set_map_info(parts, "prologue", "MAP_PROLOGUE", Color(0.55, 0.6, 0.85), "wild")
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	var road := Rect2i(0, 8, 50, 2)
	_fill(ground, road, T.DIRT)
	_border(walls, size, T.TREE, [Rect2i(49, 7, 1, 4)])
	var group_spot := Vector2(26, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in range(2, size.y - 2):
		for x in range(2, size.x - 2):
			if rng.randf() > 0.07:
				continue
			var cell := Vector2i(x, y)
			if road.grow(1).has_point(cell) or Vector2(cell).distance_to(group_spot) < 4.0 or x < 6:
				continue
			walls.set_cell(cell, 0, Vector2i(T.TREE, 0))
	for spot in [Vector2(12, 11.5), Vector2(19, 5.5), Vector2(35, 12)]:
		_add_pickup(parts, "bloodweed", spot)

	_add_spawn(parts, "start", Vector2(3, 9))
	_add_spawn(parts, "from_town", Vector2(46, 9))
	_add_exit(parts, "ExitEast", Vector2(49.5, 9), Vector2(1, 4), TOWN_PATH, "from_prologue")
	_add_enemy_group(parts, "Raiders", group_spot, 2, 1, ORC_SCENE)
	_save_map(parts, PROLOGUE_PATH)