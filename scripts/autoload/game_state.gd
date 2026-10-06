extends Node
## Oyuncunun haritalar arasında korunan durumu: can, mana, stamina, altın, iksirler, malzemeler,
## ekipman, çanta, kristal parçaları ve hikâye bayrakları. Kayıt/yükleme de burada.
## Autoload olarak "GameState" adıyla her yerden erişilebilir.

signal hp_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal stamina_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal health_potions_changed(amount: int)
signal mana_potions_changed(amount: int)
signal inventory_changed
signal equipment_changed
signal shards_changed(count: int)
signal flag_changed(flag_name: String, value: Variant)
signal skill_cooldown_started(duration: float)
signal message(text: String, color: Color)
signal map_change_requested(map_path: String, spawn_name: String)
signal player_died
signal boss_started(boss: Node)
signal boss_ended(boss: Node)
signal xp_changed(xp: int, needed: int, level: int)
signal level_up(level: int)

const SAVE_VERSION := 1
## Yeni oyunun başladığı yer (prolog) ve ölünce doğulan yer (şehir)
const NEW_GAME_MAP := "res://scenes/maps/prologue.tscn"
const NEW_GAME_SPAWN := "start"
const START_MAP := "res://scenes/maps/town.tscn"
const START_SPAWN := "start"
const SHARDS_REQUIRED := 9

# Warrior temel değerleri (sınıf sistemi gelince ayrı bir veri dosyasına taşınacak)
const BASE_MAX_HP := 120
const BASE_MAX_MANA := 60
const BASE_MAX_STAMINA := 100
const BASE_DAMAGE := 14
const BASE_DEFENSE := 2
const CRIT_CHANCE := 0.05
const CRIT_MULTIPLIER := 1.5
## Saniyede dolan mana (yavaş; hızlı doldurmak için mana iksiri)
const MANA_REGEN_PER_SECOND := 1.0
## Saniyede dolan stamina ve son harcamadan sonra dolmaya başlama gecikmesi
const STAMINA_REGEN_PER_SECOND := 30.0
const STAMINA_REGEN_DELAY := 0.7
const HEALTH_POTION_RATIO := 0.5
const MANA_POTION_RATIO := 0.5
const START_HEALTH_POTIONS := 3
const START_MANA_POTIONS := 1

# Seviye atlayınca artan değerler
const MAX_LEVEL := 30
const HP_PER_LEVEL := 12
const MANA_PER_LEVEL := 5
const DAMAGE_PER_LEVEL := 2
# Demirci güçlendirmesi: seviye başına hasar, en yüksek seviye ve bedeli
const WEAPON_DAMAGE_PER_LEVEL := 3
const MAX_WEAPON_LEVEL := 10
const WEAPON_UPGRADE_GOLD := 30
# Dükkân fiyatları
const HEALTH_POTION_PRICE := 20
const MANA_POTION_PRICE := 25

const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const HEAL_COLOR := Color(0.4, 1.0, 0.4)
const MANA_COLOR := Color(0.45, 0.65, 1.0)
const STAMINA_COLOR := Color(0.55, 0.9, 0.4)
const QUEST_COLOR := Color(1.0, 0.8, 0.45)

const HEALTH_POTION_ICON := "res://assets/items/potion_health.png"
const MANA_POTION_ICON := "res://assets/items/potion_mana.png"

## Malzemeler: id -> [ad anahtarı, açıklama anahtarı, ikon]
const MATERIALS := {
	"bloodweed": ["MAT_BLOODWEED", "MAT_BLOODWEED_DESC", "res://assets/items/herb_red.png"],
	"moonlotus": ["MAT_MOONLOTUS", "MAT_MOONLOTUS_DESC", "res://assets/items/herb_blue.png"],
	"iron_ore": ["MAT_IRON_ORE", "MAT_IRON_ORE_DESC", "res://assets/items/iron_ore.png"],
	"pip_necklace": ["MAT_PIP_NECKLACE", "MAT_PIP_NECKLACE_DESC", "res://assets/items/necklace.png"],
}

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var max_mana: int = BASE_MAX_MANA
var mana: float = BASE_MAX_MANA
var max_stamina: int = BASE_MAX_STAMINA
var stamina: float = BASE_MAX_STAMINA
var gold: int = 0
var level: int = 1
var xp: int = 0
## Demircide güçlendirilen silah seviyesi
var weapon_level: int = 0
var health_potions: int = START_HEALTH_POTIONS
var mana_potions: int = START_MANA_POTIONS
var weapon: ItemData = null
var armor: ItemData = null
## Çantadaki eşyalar (iksirler ve malzemeler ayrı sayılır, burada değerli eşyalar durur)
var inventory: Array[ItemData] = []
## Malzeme id -> adet
var materials: Dictionary = {}
## Yenilen boss'ların id'leri; her biri bir kristal parçası demek
var shards: Array[String] = []
## Hikâye bayrakları (ör. "barrier_broken": true)
var flags: Dictionary = {}
## Kayıt için: oyuncunun bulunduğu harita ve konumu
var current_map: String = START_MAP
var current_spawn: String = START_SPAWN
var saved_position: Variant = null

## Kayıt dosyası (testler kendi dosyasını kullanır, oyuncunun kaydına dokunmaz)
var save_path: String = "user://save.json"
var _stamina_delay := 0.0


func _process(delta: float) -> void:
	if hp <= 0:
		return
	if mana < max_mana:
		var before := int(mana)
		mana = minf(max_mana, mana + MANA_REGEN_PER_SECOND * delta)
		if int(mana) != before:
			mana_changed.emit(int(mana), max_mana)
	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	elif stamina < max_stamina:
		var before_stamina := int(stamina)
		stamina = minf(max_stamina, stamina + STAMINA_REGEN_PER_SECOND * delta)
		if int(stamina) != before_stamina:
			stamina_changed.emit(int(stamina), max_stamina)


# --- Savaş ------------------------------------------------------------------

func get_attack_damage() -> int:
	var damage := BASE_DAMAGE + (level - 1) * DAMAGE_PER_LEVEL + weapon_level * WEAPON_DAMAGE_PER_LEVEL
	if weapon:
		damage += weapon.damage_bonus
	return damage


func get_defense() -> int:
	var defense := BASE_DEFENSE
	if armor:
		defense += armor.defense_bonus
	return defense


## Bir saldırının hasarını hesaplar. Dönüş: {"amount": int, "crit": bool}
func roll_damage(multiplier: float = 1.0) -> Dictionary:
	var amount := get_attack_damage() * multiplier * randf_range(0.85, 1.15)
	var crit := randf() < CRIT_CHANCE
	if crit:
		amount *= CRIT_MULTIPLIER
	return {"amount": roundi(amount), "crit": crit}


## Oyuncuya hasar uygular, savunmadan sonra kalan hasarı döndürür.
func damage_player(raw_damage: int) -> int:
	var dealt := maxi(1, raw_damage - get_defense())
	hp = maxi(0, hp - dealt)
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		player_died.emit()
	return dealt


## Yeterli mana varsa harcar ve true döndürür.
func spend_mana(cost: int) -> bool:
	if mana < cost:
		return false
	mana -= cost
	mana_changed.emit(int(mana), max_mana)
	return true


## Yeterli stamina varsa harcar ve true döndürür. allow_partial: kalan ne varsa harcanır
## (blok sırasında stamina biterse savunma kırılır).
func spend_stamina(cost: float, allow_partial: bool = false) -> bool:
	_stamina_delay = STAMINA_REGEN_DELAY
	if stamina < cost and not allow_partial:
		return false
	var enough := stamina >= cost
	stamina = maxf(0.0, stamina - cost)
	stamina_changed.emit(int(stamina), max_stamina)
	return enough


# --- İksirler, altın, eşyalar -----------------------------------------------

## Can iksiri içer, iyileşen can miktarını döndürür (kullanılamadıysa 0).
func use_health_potion() -> int:
	if health_potions <= 0 or hp <= 0 or hp >= max_hp:
		return 0
	health_potions -= 1
	var before := hp
	hp = mini(max_hp, hp + roundi(max_hp * HEALTH_POTION_RATIO))
	health_potions_changed.emit(health_potions)
	hp_changed.emit(hp, max_hp)
	inventory_changed.emit()
	return hp - before


## Mana iksiri içer, dolan mana miktarını döndürür (kullanılamadıysa 0).
func use_mana_potion() -> int:
	if mana_potions <= 0 or hp <= 0 or mana >= max_mana:
		return 0
	mana_potions -= 1
	var before := int(mana)
	mana = minf(max_mana, mana + max_mana * MANA_POTION_RATIO)
	mana_potions_changed.emit(mana_potions)
	mana_changed.emit(int(mana), max_mana)
	inventory_changed.emit()
	return int(mana) - before


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	message.emit(tr("MSG_GOLD") % amount, GOLD_COLOR)
	Audio.play_sfx("coin")


func add_health_potions(amount: int, announce: bool = true) -> void:
	health_potions += amount
	health_potions_changed.emit(health_potions)
	inventory_changed.emit()
	if announce:
		message.emit(tr("MSG_HEALTH_POTION") % amount, HEAL_COLOR)


func add_mana_potions(amount: int, announce: bool = true) -> void:
	mana_potions += amount
	mana_potions_changed.emit(mana_potions)
	inventory_changed.emit()
	if announce:
		message.emit(tr("MSG_MANA_POTION") % amount, MANA_COLOR)


func get_material(id: String) -> int:
	return materials.get(id, 0)


func add_material(id: String, amount: int = 1, announce: bool = true) -> void:
	materials[id] = get_material(id) + amount
	inventory_changed.emit()
	if announce and MATERIALS.has(id):
		message.emit(tr("MSG_PICKED") % [amount, tr(MATERIALS[id][0])], Color.WHITE)
		Audio.play_sfx("pickup")
	Quests.notify("collect", id, amount)


## Malzeme yeterliyse harcar ve true döndürür.
func spend_materials(cost: Dictionary) -> bool:
	for id: String in cost:
		if get_material(id) < int(cost[id]):
			return false
	for id: String in cost:
		materials[id] = get_material(id) - int(cost[id])
	inventory_changed.emit()
	return true


static func material_icon(id: String) -> Texture2D:
	var path: String = MATERIALS[id][2] if MATERIALS.has(id) else ""
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


## Eşyayı alır: silah/zırh mevcut ekipmandan iyiyse kuşanır, değilse çantaya koyar.
func add_item(item: ItemData) -> void:
	match item.type:
		ItemData.Type.WEAPON:
			if weapon == null or item.damage_bonus > weapon.damage_bonus:
				if weapon:
					inventory.append(weapon)
				weapon = item
				equipment_changed.emit()
				inventory_changed.emit()
				message.emit(tr("MSG_EQUIPPED_WEAPON") % [item.get_display_name(), item.damage_bonus], item.get_color())
				return
		ItemData.Type.ARMOR:
			if armor == null or item.defense_bonus > armor.defense_bonus:
				if armor:
					inventory.append(armor)
				armor = item
				equipment_changed.emit()
				inventory_changed.emit()
				message.emit(tr("MSG_EQUIPPED_ARMOR") % [item.get_display_name(), item.defense_bonus], item.get_color())
				return
	inventory.append(item)
	inventory_changed.emit()
	message.emit(tr("MSG_ADDED_TO_BAG") % item.get_display_name(), item.get_color())


# --- Deneyim ve seviye --------------------------------------------------------

## Bir sonraki seviye için gereken deneyim
func xp_to_next() -> int:
	return roundi(40.0 * pow(level, 1.5))


func add_xp(amount: int) -> void:
	if level >= MAX_LEVEL or amount <= 0:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		_apply_level_stats()
		hp = max_hp
		mana = max_mana
		hp_changed.emit(hp, max_hp)
		mana_changed.emit(int(mana), max_mana)
		message.emit(tr("MSG_LEVEL_UP") % level, Color(1.0, 0.9, 0.4))
		Audio.play_sfx("level_up", 0.0)
		level_up.emit(level)
	xp_changed.emit(xp, xp_to_next(), level)


func _apply_level_stats() -> void:
	max_hp = BASE_MAX_HP + (level - 1) * HP_PER_LEVEL
	max_mana = BASE_MAX_MANA + (level - 1) * MANA_PER_LEVEL


# --- Dükkân ve demirci ---------------------------------------------------------

## Altın yeterliyse harcar ve true döndürür.
func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func buy_health_potion() -> bool:
	if not spend_gold(HEALTH_POTION_PRICE):
		message.emit(tr("MSG_NOT_ENOUGH_GOLD"), Color(1, 0.5, 0.4))
		return false
	add_health_potions(1)
	return true


func buy_mana_potion() -> bool:
	if not spend_gold(MANA_POTION_PRICE):
		message.emit(tr("MSG_NOT_ENOUGH_GOLD"), Color(1, 0.5, 0.4))
		return false
	add_mana_potions(1)
	return true


## Çantadaki eşyayı satar, kazanılan altını döndürür.
func sell_item(item: ItemData) -> int:
	var index := inventory.find(item)
	if index < 0:
		return 0
	inventory.remove_at(index)
	gold += item.value
	gold_changed.emit(gold)
	inventory_changed.emit()
	return item.value


## Silahı bir seviye güçlendirmenin bedeli: {"iron_ore": n, "gold": n}
func weapon_upgrade_cost() -> Dictionary:
	return {"iron_ore": weapon_level + 1, "gold": WEAPON_UPGRADE_GOLD * (weapon_level + 1)}


func upgrade_weapon() -> bool:
	if weapon_level >= MAX_WEAPON_LEVEL:
		return false
	var cost := weapon_upgrade_cost()
	if gold < int(cost["gold"]) or get_material("iron_ore") < int(cost["iron_ore"]):
		message.emit(tr("MSG_NOT_ENOUGH"), Color(1, 0.5, 0.4))
		return false
	spend_gold(int(cost["gold"]))
	spend_materials({"iron_ore": int(cost["iron_ore"])})
	weapon_level += 1
	equipment_changed.emit()
	Audio.play_sfx("anvil")
	message.emit(tr("MSG_WEAPON_UPGRADED") % weapon_level, Color(1.0, 0.75, 0.4))
	return true


# --- Kristal parçaları ve bayraklar -------------------------------------------

func add_shard(boss_id: String) -> void:
	if boss_id in shards:
		return
	shards.append(boss_id)
	shards_changed.emit(shards.size())
	Audio.play_sfx("shard", 0.0)
	message.emit(tr("MSG_SHARD") % [shards.size(), SHARDS_REQUIRED], Color(0.6, 0.95, 1.0))
	Quests.notify("shards", "", 0)


func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


func set_flag(flag_name: String, value: Variant = true) -> void:
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


# --- Ölüm --------------------------------------------------------------------

## Ölümden sonra şehirde yeniden doğarken çağrılır.
func restore_after_death() -> void:
	hp = max_hp
	mana = max_mana
	stamina = max_stamina
	hp_changed.emit(hp, max_hp)
	mana_changed.emit(int(mana), max_mana)
	stamina_changed.emit(int(stamina), max_stamina)
	message.emit(tr("MSG_RESPAWN"), Color.WHITE)


# --- Kayıt / yükleme ----------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Yeni oyun: her şeyi başlangıç değerlerine döndürür ve eski kaydı siler.
func new_game() -> void:
	max_hp = BASE_MAX_HP
	hp = max_hp
	max_mana = BASE_MAX_MANA
	mana = max_mana
	max_stamina = BASE_MAX_STAMINA
	stamina = max_stamina
	gold = 0
	level = 1
	xp = 0
	weapon_level = 0
	_apply_level_stats()
	hp = max_hp
	mana = max_mana
	health_potions = START_HEALTH_POTIONS
	mana_potions = START_MANA_POTIONS
	weapon = null
	armor = null
	inventory.clear()
	materials.clear()
	shards.clear()
	flags.clear()
	current_map = NEW_GAME_MAP if ResourceLoader.exists(NEW_GAME_MAP) else START_MAP
	current_spawn = NEW_GAME_SPAWN
	saved_position = null
	Quests.reset()
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_emit_all()


func save_game(player_position: Variant = null) -> void:
	var items: Array = []
	for item in inventory:
		items.append(item.to_dict())
	var data := {
		"version": SAVE_VERSION,
		"hp": hp, "mana": mana, "stamina": stamina,
		"gold": gold,
		"level": level, "xp": xp, "weapon_level": weapon_level,
		"health_potions": health_potions, "mana_potions": mana_potions,
		"weapon": weapon.to_dict() if weapon else null,
		"armor": armor.to_dict() if armor else null,
		"inventory": items,
		"materials": materials,
		"shards": shards,
		"flags": flags,
		"map": current_map,
		"spawn": current_spawn,
		"position": [player_position.x, player_position.y] if player_position is Vector2 else null,
		"quests": Quests.to_dict(),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		push_warning("GameState: kayıt dosyası okunamadı.")
		return false
	var data: Dictionary = parsed
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	weapon_level = int(data.get("weapon_level", 0))
	_apply_level_stats()
	hp = int(data.get("hp", max_hp))
	if hp <= 0:
		hp = max_hp
	mana = float(data.get("mana", BASE_MAX_MANA))
	stamina = float(data.get("stamina", BASE_MAX_STAMINA))
	gold = int(data.get("gold", 0))
	health_potions = int(data.get("health_potions", START_HEALTH_POTIONS))
	mana_potions = int(data.get("mana_potions", START_MANA_POTIONS))
	weapon = ItemData.from_dict(data["weapon"]) if data.get("weapon") is Dictionary else null
	armor = ItemData.from_dict(data["armor"]) if data.get("armor") is Dictionary else null
	inventory.clear()
	for entry: Variant in data.get("inventory", []):
		if entry is Dictionary:
			inventory.append(ItemData.from_dict(entry))
	materials.clear()
	var saved_materials: Dictionary = data.get("materials", {})
	for id: String in saved_materials:
		materials[id] = int(saved_materials[id])
	shards.clear()
	for id: Variant in data.get("shards", []):
		shards.append(str(id))
	flags = data.get("flags", {})
	current_map = data.get("map", START_MAP)
	if not ResourceLoader.exists(current_map):
		current_map = START_MAP
	current_spawn = data.get("spawn", START_SPAWN)
	var position: Variant = data.get("position")
	saved_position = Vector2(position[0], position[1]) if position is Array and position.size() == 2 else null
	Quests.from_dict(data.get("quests", {}))
	_emit_all()
	return true


func _emit_all() -> void:
	hp_changed.emit(hp, max_hp)
	mana_changed.emit(int(mana), max_mana)
	stamina_changed.emit(int(stamina), max_stamina)
	gold_changed.emit(gold)
	xp_changed.emit(xp, xp_to_next(), level)
	health_potions_changed.emit(health_potions)
	mana_potions_changed.emit(mana_potions)
	shards_changed.emit(shards.size())
	inventory_changed.emit()
	equipment_changed.emit()
