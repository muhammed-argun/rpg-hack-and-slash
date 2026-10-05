extends Node
## Demo için tileset'i ve iki örnek haritayı (şehir ve vahşi bölge) oluşturur. Var olan harita ve tileset dosyalarının ÜZERİNE YAZMAZ.
##
## Çalıştırma (proje klasöründe, önce generate_placeholders.gd ve --import çalışmış olmalı):
##   godot --headless --path . res://tools/build_demo_maps.tscn
## (Sahne olarak çalışır, çünkü oyun scriptleri GameState autoload'una ihtiyaç duyar.)

const TILESET_TEXTURE := "res://assets/tiles/tileset.png"
const TILESET_PATH := "res://assets/tiles/tileset.tres"
const TOWN_PATH := "res://scenes/maps/town.tscn"
const WILD_PATH := "res://scenes/maps/wild.tscn"
const EXIT_SCENE := "res://scenes/world/map_exit.tscn"
const ORC_SCENE := "res://scenes/enemies/orc.tscn"
const BLOOD_MONSTER_SCENE := "res://scenes/enemies/blood_monster.tscn"
const DEMON_SCENE := "res://scenes/enemies/demon.tscn"
const TILE := 32

# Tileset içindeki kare sırası (assets/tiles/tileset.png, soldan sağa)
enum T { GRASS, DIRT, COBBLE, WALL, TREE, WATER }


func _ready() -> void:
	var tileset := _get_tileset()
	if not FileAccess.file_exists(TOWN_PATH):
		_build_town(tileset)
	if not FileAccess.file_exists(WILD_PATH):
		_build_wild(tileset)
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


# --- Harita iskeleti -------------------------------------------------------

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


func _save_map(parts: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var packed := PackedScene.new()
	var err := packed.pack(parts["map"])
	if err == OK:
		err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Harita kaydedilemedi: %s (hata %d)" % [path, err])
	(parts["map"] as Node).free()


# --- Şehir (48x32) ---------------------------------------------------------
# Batıda vahşi bölgeye çıkış. Düşman yok.

func _build_town(tileset: TileSet) -> void:
	var size := Vector2i(48, 32)
	var parts := _new_map("Town", size, tileset)
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	_fill(ground, Rect2i(6, 5, 36, 22), T.COBBLE)
	_fill(ground, Rect2i(0, 14, 6, 4), T.DIRT)

	_border(walls, size, T.WALL, [Rect2i(0, 14, 1, 4)])
	# Binalar
	for building in [Rect2i(10, 6, 7, 5), Rect2i(30, 6, 8, 5), Rect2i(10, 21, 7, 5), Rect2i(31, 21, 7, 5)]:
		_fill(walls, building, T.WALL)
	# Meydandaki havuz
	_fill(walls, Rect2i(23, 15, 2, 2), T.WATER)
	# Süs ağaçları
	for tree in [Vector2i(3, 4), Vector2i(4, 25), Vector2i(43, 4), Vector2i(43, 27), Vector2i(20, 3), Vector2i(27, 28)]:
		walls.set_cell(tree, 0, Vector2i(T.TREE, 0))

	_add_spawn(parts, "start", Vector2(24.5, 20))
	_add_spawn(parts, "from_wild", Vector2(3, 16))
	_add_exit(parts, "ExitWest", Vector2(0.5, 16), Vector2(1, 4), WILD_PATH, "from_town")
	_save_map(parts, TOWN_PATH)


# --- Vahşi bölge (64x40) ---------------------------------------------------
# Doğuda şehre dönüş. 3 düşman bölüğü: orklar, kan canavarları, iblisler.

func _build_wild(tileset: TileSet) -> void:
	var size := Vector2i(64, 40)
	var parts := _new_map("Wild", size, tileset)
	var ground: TileMapLayer = parts["ground"]
	var walls: TileMapLayer = parts["walls"]

	_fill(ground, Rect2i(Vector2i.ZERO, size), T.GRASS)
	var path_rects: Array[Rect2i] = [Rect2i(30, 19, 34, 2), Rect2i(30, 6, 2, 28)]
	for rect in path_rects:
		_fill(ground, rect, T.DIRT)

	_border(walls, size, T.TREE, [Rect2i(63, 18, 1, 4)])
	_fill(walls, Rect2i(18, 7, 6, 4), T.WATER)

	# Bölük adı: [konum (kare), düşman sayısı, ganimet seviyesi, düşman sahnesi]
	var groups := {
		"EnemyGroup1": [Vector2(44, 11), 2, 1, ORC_SCENE],
		"EnemyGroup2": [Vector2(20, 27), 3, 1, BLOOD_MONSTER_SCENE],
		"EnemyGroup3": [Vector2(10, 15), 2, 2, DEMON_SCENE],
	}

	# Rastgele ağaçlar (yollardan, gölden, bölüklerden ve girişten uzak)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in range(2, size.y - 2):
		for x in range(2, size.x - 2):
			if rng.randf() > 0.05:
				continue
			var cell := Vector2i(x, y)
			var blocked := Rect2i(17, 6, 8, 6).has_point(cell) or Rect2i(56, 16, 8, 8).has_point(cell)
			for rect in path_rects:
				if rect.grow(1).has_point(cell):
					blocked = true
			for info: Array in groups.values():
				if Vector2(cell).distance_to(info[0]) < 4.0:
					blocked = true
			if not blocked:
				walls.set_cell(cell, 0, Vector2i(T.TREE, 0))

	_add_spawn(parts, "from_town", Vector2(60, 20))
	_add_exit(parts, "ExitEast", Vector2(63.5, 20), Vector2(1, 4), TOWN_PATH, "from_wild")
	for group_name: String in groups:
		var info: Array = groups[group_name]
		_add_enemy_group(parts, group_name, info[0], info[1], info[2], info[3])
	_save_map(parts, WILD_PATH)
