class_name ItemData
extends Resource
## Bir eşyanın verileri. Sandıklardan create_random() ile rastgele üretilir.
## Ad bir çeviri anahtarıdır (ör. "ITEM_RUBY"); ekranda seçili dile göre gösterilir.

## Kayıtta sayı olarak durur: yeni türler hep sona eklenir.
enum Type { WEAPON, ARMOR, VALUABLE, HELMET, GLOVES, BOOTS, CLOAK, RING, AMULET, BELT, OFFHAND, AMMO }
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

## Silahlar: [ad anahtarı, çift elli mi, menzilli mi]
const WEAPONS := [
	["ITEM_SWORD", false, false],
	["ITEM_AXE", false, false],
	["ITEM_WARHAMMER", true, false],
	["ITEM_GREATSWORD", true, false],
	["ITEM_BOW", true, true],
]
## Savunma eşyaları: tür -> ad anahtarları
const GEAR_KEYS := {
	Type.ARMOR: ["ITEM_LEATHER_ARMOR", "ITEM_CHAIN_ARMOR", "ITEM_PLATE_ARMOR"],
	Type.HELMET: ["ITEM_HELMET"],
	Type.GLOVES: ["ITEM_GLOVES"],
	Type.BOOTS: ["ITEM_BOOTS"],
	Type.CLOAK: ["ITEM_CLOAK"],
	Type.BELT: ["ITEM_BELT"],
	Type.OFFHAND: ["ITEM_SHIELD"],
}
const JEWELRY_KEYS := {Type.RING: ["ITEM_RING"], Type.AMULET: ["ITEM_AMULET"]}
const AMMO_KEYS := ["ITEM_ARROWS"]
## Türün çeviri anahtarı (eşya bilgisinde gösterilir)
const TYPE_KEYS := {
	Type.WEAPON: "ITEM_TYPE_WEAPON", Type.ARMOR: "ITEM_TYPE_ARMOR", Type.VALUABLE: "ITEM_TYPE_VALUABLE",
	Type.HELMET: "ITEM_TYPE_HELMET", Type.GLOVES: "ITEM_TYPE_GLOVES", Type.BOOTS: "ITEM_TYPE_BOOTS",
	Type.CLOAK: "ITEM_TYPE_CLOAK", Type.RING: "ITEM_TYPE_RING", Type.AMULET: "ITEM_TYPE_AMULET",
	Type.BELT: "ITEM_TYPE_BELT", Type.OFFHAND: "ITEM_TYPE_OFFHAND", Type.AMMO: "ITEM_TYPE_AMMO",
}
## Hangi tür hangi ekipman yuvalarına takılabilir (GameState.EQUIP_SLOTS)
const TYPE_SLOTS := {
	Type.WEAPON: ["main_1", "main_2"], Type.OFFHAND: ["off_1", "off_2"],
	Type.AMMO: ["ammo_1", "ammo_2", "ammo_3"],
	Type.HELMET: ["helmet"], Type.ARMOR: ["armor"], Type.GLOVES: ["gloves"], Type.BOOTS: ["boots"],
	Type.CLOAK: ["cloak"], Type.RING: ["ring"], Type.AMULET: ["amulet"], Type.BELT: ["belt"],
}
## Kendi ikonu olmayan eşyalar için türün varsayılan ikonu
const TYPE_ICONS := {
	Type.WEAPON: "res://addons/pixel_ui_fantasy/icons/sword.png",
	Type.ARMOR: "res://assets/items/armor.png",
	Type.HELMET: "res://addons/pixel_ui_fantasy/icons/helmet.png",
	Type.GLOVES: "res://assets/items/gloves.png",
	Type.BOOTS: "res://assets/items/boots.png",
	Type.CLOAK: "res://assets/items/cloak.png",
	Type.RING: "res://assets/items/ring.png",
	Type.AMULET: "res://assets/items/necklace.png",
	Type.BELT: "res://assets/items/belt.png",
	Type.OFFHAND: "res://addons/pixel_ui_fantasy/icons/shield.png",
	Type.AMMO: "res://assets/items/arrows.png",
}
const BOW_ICON := "res://assets/items/bow.png"
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
## Silah: iki eli de kullanır (ikinci el yuvası kilitlenir)
@export var two_handed: bool = false
## Silah: menzilli (ok gerektirir; ileride)
@export var ranged: bool = false
## Envanterde gösterilen ikon
@export_file("*.png") var icon_path: String = ""


func get_color() -> Color:
	return RARITY_COLORS[rarity]


func get_display_name() -> String:
	if rarity == Rarity.COMMON:
		return TranslationServer.translate(name_key)
	return "%s %s" % [TranslationServer.translate(RARITY_KEYS[rarity]), TranslationServer.translate(name_key)]


func get_icon() -> Texture2D:
	var path := icon_path
	if path.is_empty() or not ResourceLoader.exists(path):
		path = TYPE_ICONS.get(type, "")
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


## Ekipman yuvasına takılabilir mi (değerli eşyalar takılmaz)
func is_equippable() -> bool:
	return TYPE_SLOTS.has(type)


func get_slots() -> Array:
	return TYPE_SLOTS.get(type, [])


## Eşya bilgisi: tür, bonuslar, değer (pencerelerde gösterilir).
func get_details() -> String:
	var lines: Array[String] = [TranslationServer.translate(TYPE_KEYS.get(type, ""))]
	if two_handed:
		lines[0] += ", " + TranslationServer.translate("ITEM_TWO_HANDED")
	if damage_bonus > 0:
		lines.append(TranslationServer.translate("ITEM_DAMAGE_BONUS") % damage_bonus)
	if defense_bonus > 0:
		lines.append(TranslationServer.translate("ITEM_DEFENSE_BONUS") % defense_bonus)
	lines.append(TranslationServer.translate("ITEM_VALUE_DESC") % value)
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"name": name_key, "type": type, "rarity": rarity,
		"damage": damage_bonus, "defense": defense_bonus, "value": value, "icon": icon_path,
		"two_handed": two_handed, "ranged": ranged,
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
	item.two_handed = bool(data.get("two_handed", false))
	item.ranged = bool(data.get("ranged", false))
	return item


## Verilen seviyeye uygun rastgele bir eşya üretir. types boşsa her tür çıkabilir.
static func create_random(level: int = 1, types: Array[Type] = []) -> ItemData:
	var item := ItemData.new()
	item.rarity = _roll_rarity()
	var multiplier: float = RARITY_MULTIPLIERS[item.rarity]
	var allowed: Array[Type] = [Type.WEAPON, Type.ARMOR, Type.VALUABLE, Type.HELMET, Type.GLOVES, Type.BOOTS,
		Type.CLOAK, Type.RING, Type.AMULET, Type.BELT, Type.OFFHAND, Type.AMMO]
	if not types.is_empty():
		allowed = types
	item.type = allowed.pick_random()
	match item.type:
		Type.WEAPON:
			var weapon: Array = WEAPONS.pick_random()
			item.name_key = weapon[0]
			item.two_handed = weapon[1]
			item.ranged = weapon[2]
			if item.ranged:
				item.icon_path = BOW_ICON
			# Çift elli silah daha çok vurur
			item.damage_bonus = roundi(randi_range(2, 5) * level * multiplier * (1.5 if item.two_handed else 1.0))
		Type.RING, Type.AMULET:
			item.name_key = JEWELRY_KEYS[item.type].pick_random()
			item.damage_bonus = roundi(randi_range(1, 2) * level * multiplier)
		Type.AMMO:
			item.name_key = AMMO_KEYS.pick_random()
			item.damage_bonus = roundi(randi_range(1, 2) * level * multiplier)
		Type.ARMOR, Type.HELMET, Type.GLOVES, Type.BOOTS, Type.CLOAK, Type.BELT, Type.OFFHAND:
			item.name_key = GEAR_KEYS[item.type].pick_random()
			# Gövde zırhı ve kalkan diğer parçalardan daha çok korur
			var big := item.type == Type.ARMOR or item.type == Type.OFFHAND
			item.defense_bonus = roundi(randi_range(1, 3) * level * multiplier * (1.0 if big else 0.5))
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
