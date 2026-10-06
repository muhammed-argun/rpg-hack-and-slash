class_name ItemData
extends Resource
## Bir eşyanın verileri. Sandıklardan create_random() ile rastgele üretilir.
## Ad bir çeviri anahtarıdır (ör. "ITEM_RUBY"); ekranda seçili dile göre gösterilir.

enum Type { WEAPON, ARMOR, VALUABLE }
enum Rarity { COMMON, MAGIC, RARE, LEGENDARY }

const RARITY_KEYS := ["RARITY_COMMON", "RARITY_MAGIC", "RARITY_RARE", "RARITY_LEGENDARY"]
const RARITY_COLORS := [
	Color(0.9, 0.9, 0.9),
	Color(0.45, 0.65, 1.0),
	Color(1.0, 0.9, 0.3),
	Color(1.0, 0.55, 0.1),
]
const RARITY_MULTIPLIERS := [1.0, 1.4, 1.9, 2.6]
# Düşme ağırlıkları: yüksek sayı = daha sık
const RARITY_WEIGHTS := [60, 28, 10, 2]

const WEAPON_KEYS := ["ITEM_SWORD", "ITEM_AXE", "ITEM_WARHAMMER"]
const ARMOR_KEYS := ["ITEM_LEATHER_ARMOR", "ITEM_CHAIN_ARMOR", "ITEM_PLATE_ARMOR"]
# Değerli eşyalar: [ad anahtarı, ikon]
const VALUABLES := [
	["ITEM_RUBY", "res://assets/items/gem.png"],
	["ITEM_CRYSTAL", "res://assets/items/crystal.png"],
	["ITEM_GOLD_INGOT", "res://assets/items/gold_ore.png"],
	["ITEM_OLD_MAP", "res://assets/items/map.png"],
	["ITEM_RUSTY_KEY", "res://assets/items/key.png"],
]

## Çeviri anahtarı
@export var name_key: String = ""
@export var type: Type = Type.VALUABLE
@export var rarity: Rarity = Rarity.COMMON
@export var damage_bonus: int = 0
@export var defense_bonus: int = 0
## Dükkânda satış değeri (altın)
@export var value: int = 0
## Envanterde gösterilen ikon
@export_file("*.png") var icon_path: String = ""


func get_color() -> Color:
	return RARITY_COLORS[rarity]


func get_display_name() -> String:
	if rarity == Rarity.COMMON:
		return TranslationServer.translate(name_key)
	return "%s %s" % [TranslationServer.translate(RARITY_KEYS[rarity]), TranslationServer.translate(name_key)]


func get_icon() -> Texture2D:
	return load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null


func to_dict() -> Dictionary:
	return {
		"name": name_key, "type": type, "rarity": rarity,
		"damage": damage_bonus, "defense": defense_bonus, "value": value, "icon": icon_path,
	}


static func from_dict(data: Dictionary) -> ItemData:
	var item := ItemData.new()
	item.name_key = data.get("name", "")
	item.type = int(data.get("type", Type.VALUABLE)) as Type
	item.rarity = int(data.get("rarity", Rarity.COMMON)) as Rarity
	item.damage_bonus = int(data.get("damage", 0))
	item.defense_bonus = int(data.get("defense", 0))
	item.value = int(data.get("value", 0))
	item.icon_path = data.get("icon", "")
	return item


## Verilen seviyeye uygun rastgele bir eşya üretir. types boşsa her tür çıkabilir.
static func create_random(level: int = 1, types: Array[Type] = []) -> ItemData:
	var item := ItemData.new()
	item.rarity = _roll_rarity()
	var multiplier: float = RARITY_MULTIPLIERS[item.rarity]
	var allowed: Array[Type] = [Type.WEAPON, Type.ARMOR, Type.VALUABLE]
	if not types.is_empty():
		allowed = types
	item.type = allowed.pick_random()
	match item.type:
		Type.WEAPON:
			item.name_key = WEAPON_KEYS.pick_random()
			item.damage_bonus = roundi(randi_range(2, 5) * level * multiplier)
		Type.ARMOR:
			item.name_key = ARMOR_KEYS.pick_random()
			item.defense_bonus = roundi(randi_range(1, 3) * level * multiplier)
		Type.VALUABLE:
			var valuable: Array = VALUABLES.pick_random()
			item.name_key = valuable[0]
			item.icon_path = valuable[1]
	item.value = roundi(randi_range(8, 15) * level * multiplier)
	if item.type == Type.VALUABLE:
		item.value *= 2
	return item


static func _roll_rarity() -> Rarity:
	var total := 0
	for weight: int in RARITY_WEIGHTS:
		total += weight
	var roll := randi_range(1, total)
	for i in RARITY_WEIGHTS.size():
		roll -= RARITY_WEIGHTS[i]
		if roll <= 0:
			return i as Rarity
	return Rarity.COMMON
