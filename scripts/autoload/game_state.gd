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
## Özellikler (STR/AGI/INT/VIT) ya da dağıtılacak puan değişince
signal attributes_changed
signal shards_changed(count: int)
signal flag_changed(flag_name: String, value: Variant)
signal skill_cooldown_started(skill_id: String, duration: float)
## Yetenek ya da hızlı kullanım yuvalarının içeriği değişince
signal hotbar_changed
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
## Zırh sonrası hasar en az gelen hasarın bu oranı kadardır (en az 1)
const DAMAGE_FLOOR_RATIO := 0.25
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

## Çanta yuva sayısı (6x6). Aynı ad ve nadirlikteki değerli eşyalar, iksirler ve malzemeler tek yuvada yığılır.
const BAG_SIZE := 36
## Bir çanta yuvasında yığılabilecek en çok eşya (iksir, malzeme, değerli eşya); ekipman zaten yığılmaz
const MAX_STACK := 20
## Ekipman yuvaları. Silahlar iki set: main_1/off_1 (1. set), main_2/off_2 (2. set). ammo_*: sadak.
const EQUIP_SLOTS := [
	"helmet", "amulet", "armor", "cloak", "gloves", "belt", "ring", "boots",
	"main_1", "off_1", "main_2", "off_2", "ammo_1", "ammo_2", "ammo_3",
]
## Yuvaların çeviri anahtarları (boş yuvanın üstüne gelince yazar)
const SLOT_KEYS := {
	"helmet": "SLOT_HELMET", "amulet": "SLOT_AMULET", "armor": "SLOT_ARMOR", "cloak": "SLOT_CLOAK",
	"gloves": "SLOT_GLOVES", "belt": "SLOT_BELT", "ring": "SLOT_RING", "boots": "SLOT_BOOTS",
	"main_1": "SLOT_MAIN_HAND", "off_1": "SLOT_OFF_HAND", "main_2": "SLOT_MAIN_HAND", "off_2": "SLOT_OFF_HAND",
	"ammo_1": "SLOT_AMMO", "ammo_2": "SLOT_AMMO", "ammo_3": "SLOT_AMMO",
}
## Özellikler. Şimdilik hepsi 10 ve henüz bir etkileri yok.
const ATTRIBUTES := ["str", "agi", "int", "vit"]
const START_ATTRIBUTE := 10
## Kaç seviyede bir özellik puanı verilir (kullanıcı kararı 2026-10-06: şimdilik her seviyede;
## oyunun uzunluğu belli olunca yeniden bakılacak)
const LEVELS_PER_ATTRIBUTE_POINT := 1
## 1. seviyeden 2. seviyeye geçmek için gereken deneyim ([Açık] kullanıcıya sorulacak; şimdilik 100)
const XP_FIRST_LEVEL := 100
## Her seviyede gereken deneyim öncekinin bu yüzdesi; sonuç yukarı, 100'ün katına yuvarlanır
const XP_GROWTH_PERCENT := 160

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

## Tüketilebilir eşyalar (hızlı kullanım yuvalarına konabilir): id -> [ad anahtarı, ikon]
const CONSUMABLES := {
	"health_potion": ["ITEM_HEALTH_POTION", HEALTH_POTION_ICON],
	"mana_potion": ["ITEM_MANA_POTION", MANA_POTION_ICON],
}
## Yetenekler: id -> [ad anahtarı, ikon]. Davranışları ve bedelleri Player'da.
const SKILLS := {
	"ground_slam": ["SKILL_GROUND_SLAM", "res://addons/pixel_ui_fantasy/icons/skills/fire_nova.png"],
}
const SKILL_SLOT_COUNT := 3
const QUICK_SLOT_COUNT := 2
## E / R / T yuvaları (skill_1..3). İleride yetenek ağacından seçilecek.
const DEFAULT_SKILL_SLOTS: Array[String] = ["ground_slam", "", ""]
## 1 / 2 yuvaları (quick_slot_1..2)
const DEFAULT_QUICK_SLOTS: Array[String] = ["health_potion", "mana_potion"]

## Dükkânda tanesinin satış fiyatı (0 ya da yoksa satılamaz; görev eşyaları satılmaz)
const CONSUMABLE_SELL_VALUES := {"health_potion": 10, "mana_potion": 12}
const MATERIAL_SELL_VALUES := {"bloodweed": 3, "moonlotus": 5, "iron_ore": 6}

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
## İksir sayıları çantadan hesaplanır (yazılamaz; eklemek için add_health_potions)
var health_potions: int:
	get:
		return count_in_bag("health_potion")
var mana_potions: int:
	get:
		return count_in_bag("mana_potion")
## Takılı ekipman: yuva adı (EQUIP_SLOTS) -> ItemData
var equipment := {}
## Kullanılan silah seti: 1 ya da 2
var active_weapon_set: int = 1
## Özellik değerleri: "str"/"agi"/"int"/"vit" -> sayı
var attributes := {}
## Dağıtılmayı bekleyen özellik puanı
var attribute_points: int = 0
## Yetenek yuvaları (E/R/T): yetenek id'si ya da boş
var skill_slots: Array[String] = DEFAULT_SKILL_SLOTS.duplicate()
## Hızlı kullanım yuvaları (1/2): tüketilebilir eşya id'si ya da boş
var quick_slots: Array[String] = DEFAULT_QUICK_SLOTS.duplicate()
## Çanta: BAG_SIZE yuva; her yuva bir BagStack ya da null. İksirler, malzemeler ve eşyalar burada.
var bag: Array[BagStack] = []
## Yenilen boss'ların id'leri; her biri bir kristal parçası demek
var shards: Array[String] = []
## Hikâye bayrakları (ör. "barrier_broken": true)
var flags: Dictionary = {}
## Kayıt için: oyuncunun bulunduğu harita ve konumu
var current_map: String = START_MAP
var current_spawn: String = START_SPAWN
var saved_position: Variant = null
## Dev konsolu: komut çubuğuna "zort" yazılınca açılır (oturum boyunca; kayda yazılmaz)
var dev_mode: bool = false
## Dev konsolu: açıksa oyuncu hasar almaz. Kayda yazılmaz.
var god_mode: bool = false

## Kayıt dosyası (testler kendi dosyasını kullanır, oyuncunun kaydına dokunmaz)
var save_path: String = "user://save.json"
var _stamina_delay := 0.0


func _init() -> void:
	_clear_bag()


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
	for slot: String in _active_slots():
		if not slot.begins_with("ammo"):
			damage += (equipment[slot] as ItemData).damage_bonus
	return damage


func get_defense() -> int:
	var defense := BASE_DEFENSE
	for slot: String in _active_slots():
		defense += (equipment[slot] as ItemData).defense_bonus
	return defense


# Dolu ve etkin ekipman yuvaları (kullanılmayan silah seti hariç)
func _active_slots() -> Array[String]:
	var slots: Array[String] = []
	var inactive := 2 if active_weapon_set == 1 else 1
	for slot: String in equipment:
		if equipment[slot] == null or slot.ends_with("_%d" % inactive):
			continue
		slots.append(slot)
	return slots


## Bir saldırının hasarını hesaplar. Dönüş: {"amount": int, "crit": bool}
func roll_damage(multiplier: float = 1.0) -> Dictionary:
	var amount := get_attack_damage() * multiplier * randf_range(0.85, 1.15)
	var crit := randf() < CRIT_CHANCE
	if crit:
		amount *= CRIT_MULTIPLIER
	return {"amount": roundi(amount), "crit": crit}


## Oyuncuya hasar uygular, savunmadan sonra kalan hasarı döndürür. Zırh gelen hasarın en fazla
## %75'ini keser (DAMAGE_FLOOR_RATIO); apply_floor=false: blok sızıntısı gibi önceden hesaplanmış hasar.
func damage_player(raw_damage: int, apply_floor: bool = true) -> int:
	var dealt := maxi(1, raw_damage - get_defense())
	if apply_floor:
		dealt = maxi(dealt, ceili(raw_damage * DAMAGE_FLOOR_RATIO))
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
	remove_from_bag("health_potion", 1)
	var before := hp
	hp = mini(max_hp, hp + roundi(max_hp * HEALTH_POTION_RATIO))
	hp_changed.emit(hp, max_hp)
	return hp - before


## Mana iksiri içer, dolan mana miktarını döndürür (kullanılamadıysa 0).
func use_mana_potion() -> int:
	if mana_potions <= 0 or hp <= 0 or mana >= max_mana:
		return 0
	remove_from_bag("mana_potion", 1)
	var before := int(mana)
	mana = minf(max_mana, mana + max_mana * MANA_POTION_RATIO)
	mana_changed.emit(int(mana), max_mana)
	return int(mana) - before


## Bir tüketilebilir eşyadan çantada kaç tane var.
func consumable_count(id: String) -> int:
	return count_in_bag(id)


static func consumable_icon(id: String) -> Texture2D:
	return load(CONSUMABLES[id][1]) if CONSUMABLES.has(id) else null


static func skill_icon(id: String) -> Texture2D:
	return load(SKILLS[id][1]) if SKILLS.has(id) else null


## Hızlı kullanım yuvasına eşya koyar. Aynı eşya diğer yuvadaysa yer değiştirirler.
func set_quick_slot(index: int, id: String) -> void:
	var other := quick_slots.find(id)
	if other >= 0 and other != index:
		quick_slots[other] = quick_slots[index]
	quick_slots[index] = id
	hotbar_changed.emit()


func set_skill_slot(index: int, id: String) -> void:
	var other := skill_slots.find(id)
	if other >= 0 and other != index:
		skill_slots[other] = skill_slots[index]
	skill_slots[index] = id
	hotbar_changed.emit()


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	message.emit(tr("MSG_GOLD") % amount, GOLD_COLOR)
	Audio.play_sfx("coin")


## Çantaya iksir koyar; sığmayan kısım kaybolur (oyuncuya söylenir). Eklenen adet döner.
func add_health_potions(amount: int, announce: bool = true) -> int:
	var added := amount - add_to_bag(BagStack.of_id("health_potion", amount))
	if announce and added > 0:
		message.emit(tr("MSG_HEALTH_POTION") % added, HEAL_COLOR)
	return added


func add_mana_potions(amount: int, announce: bool = true) -> int:
	var added := amount - add_to_bag(BagStack.of_id("mana_potion", amount))
	if announce and added > 0:
		message.emit(tr("MSG_MANA_POTION") % added, MANA_COLOR)
	return added


func get_material(id: String) -> int:
	return count_in_bag(id)


## Çantaya malzeme koyar, eklenen adedi döndürür (çanta doluysa 0 olabilir).
func add_material(id: String, amount: int = 1, announce: bool = true) -> int:
	var added := amount - add_to_bag(BagStack.of_id(id, amount))
	if added <= 0:
		return 0
	if announce and MATERIALS.has(id):
		message.emit(tr("MSG_PICKED") % [added, tr(MATERIALS[id][0])], Color.WHITE)
		Audio.play_sfx("pickup")
	Quests.notify("collect", id, added)
	return added


## Malzeme yeterliyse harcar ve true döndürür.
func spend_materials(cost: Dictionary) -> bool:
	for id: String in cost:
		if get_material(id) < int(cost[id]):
			return false
	for id: String in cost:
		remove_from_bag(id, int(cost[id]))
	return true


static func material_icon(id: String) -> Texture2D:
	var path: String = MATERIALS[id][2] if MATERIALS.has(id) else ""
	return load(path) if not path.is_empty() and ResourceLoader.exists(path) else null


## Eşyayı alır: takılabilir bir eşyaysa ve yuvası boşsa kuşanır, değilse çantaya koyar.
## Çanta doluysa eşya değerine satılır (sandıktan çıkan eşya kaybolmasın).
func add_item(item: ItemData) -> void:
	var slot := _free_slot_for(item)
	if not slot.is_empty():
		equipment[slot] = item
		equipment_changed.emit()
		message.emit(tr("MSG_EQUIPPED") % item.get_display_name(), item.get_color())
		return
	if add_to_bag(BagStack.of_item(item)) > 0:
		add_gold(item.value)
		message.emit(tr("MSG_BAG_FULL_SOLD") % item.get_display_name(), Color(1, 0.6, 0.4))
		return
	message.emit(tr("MSG_ADDED_TO_BAG") % item.get_display_name(), item.get_color())


# --- Çanta (36 yuva, yerleşimli) ------------------------------------------------
# Her yuva bir BagStack ya da null. İksir ve malzeme sayıları buradan hesaplanır.

## Çantada bu id'den toplam kaç tane var
func count_in_bag(id: String) -> int:
	var total := 0
	for stack in bag:
		if stack and stack.id == id:
			total += stack.count
	return total


## Dolu yuva sayısı
func bag_used_slots() -> int:
	var used := 0
	for stack in bag:
		if stack:
			used += 1
	return used


## Yığını çantaya koyar: önce aynı türden yığınların boşluğunu doldurur (en çok MAX_STACK),
## kalanı boş yuvalara MAX_STACK'lik parçalar hâlinde koyar.
## Sığmayan adedi döndürür (0 = hepsi sığdı).
func add_to_bag(stack: BagStack) -> int:
	var left := stack.count
	if stack.id != BagStack.EQUIPMENT_ID:
		for other in bag:
			if left <= 0:
				break
			if other and other.can_stack_with(stack):
				var moved := mini(left, maxi(0, MAX_STACK - other.count))
				other.count += moved
				left -= moved
	while left > 0:
		var index := bag.find(null)
		if index < 0:
			break
		var chunk := mini(left, MAX_STACK)
		bag[index] = stack.copy_with(chunk)
		left -= chunk
	if left < stack.count:
		_bag_changed()
	return left


## Yığının tamamı çantaya sığar mı (mevcut yığınların boşluğu + boş yuvalar)
func bag_has_room_for(stack: BagStack) -> bool:
	var room := bag.count(null) * MAX_STACK
	if stack.id != BagStack.EQUIPMENT_ID:
		for other in bag:
			if other and other.can_stack_with(stack):
				room += maxi(0, MAX_STACK - other.count)
	return room >= stack.count


## Bu id'den verilen adedi çantadan çıkarır (sondaki yığınlardan başlayarak). Yetmezse hiçbir şey yapmaz.
func remove_from_bag(id: String, amount: int) -> bool:
	if count_in_bag(id) < amount:
		return false
	for i in range(bag.size() - 1, -1, -1):
		if amount <= 0:
			break
		var stack := bag[i]
		if stack == null or stack.id != id:
			continue
		var taken := mini(amount, stack.count)
		stack.count -= taken
		amount -= taken
		if stack.count <= 0:
			bag[i] = null
	_bag_changed()
	return true


## Yuvadaki yığından verilen adedi alır ve ayrı bir yığın olarak döndürür (bölme / taşıma).
## amount yığının tamamıysa yuva boşalır.
func take_from_slot(index: int, amount: int) -> BagStack:
	var stack := bag[index]
	if stack == null or amount <= 0:
		return null
	amount = mini(amount, stack.count)
	var taken := stack.copy_with(amount)
	stack.count -= amount
	if stack.count <= 0:
		bag[index] = null
	_bag_changed()
	return taken


## Yığını yuvaya bırakır. Yuva boşsa yerleşir, aynı türse MAX_STACK'e kadar birleşir (artan kısım
## döner, imlecte kalır); farklı bir eşya varsa yer değiştirirler ve oradaki yığın döner (imlece geçer).
## Hiçbir şey dönmezse null.
func place_in_slot(stack: BagStack, index: int) -> BagStack:
	var current := bag[index]
	var displaced: BagStack = null
	if current == null:
		bag[index] = stack
	elif current.can_stack_with(stack):
		var moved := mini(stack.count, maxi(0, MAX_STACK - current.count))
		current.count += moved
		if moved < stack.count:
			displaced = stack.copy_with(stack.count - moved)
	else:
		bag[index] = stack
		displaced = current
	_bag_changed()
	return displaced


## Sürükle-bırak: yığının tamamını başka yuvaya taşır (aynı türse birleşir, değilse yer değiştirir).
func move_slot(from: int, to: int) -> void:
	if from == to or bag[from] == null:
		return
	var moving := bag[from]
	bag[from] = null
	var displaced := place_in_slot(moving, to)
	if displaced:
		bag[from] = displaced
	_bag_changed()


## Çantadaki yuvayı satar (adet verilmezse tamamını). Kazanılan altın döner.
func sell_slot(index: int, amount: int = -1) -> int:
	var stack := bag[index]
	if stack == null or stack.unit_value() <= 0:
		return 0
	if amount < 0:
		amount = stack.count
	var sold := take_from_slot(index, amount)
	var earned := sold.unit_value() * sold.count
	gold += earned
	gold_changed.emit(gold)
	return earned


## Çantadaki ekipman ve değerli eşyalar
func bag_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for stack in bag:
		if stack and stack.item:
			items.append(stack.item)
	return items


func bag_index_of(item: ItemData) -> int:
	for i in bag.size():
		if bag[i] and bag[i].item == item:
			return i
	return -1


## Eski kayıtlardan gelen MAX_STACK'ten büyük yığınları böler: artan kısım boş yuvalara gider.
## Boş yuva yoksa fazlalık yerinde kalır (eşya kaybolmasın).
func _split_oversized_stacks() -> void:
	for i in bag.size():
		var stack := bag[i]
		if stack == null or stack.id == BagStack.EQUIPMENT_ID:
			continue
		while stack.count > MAX_STACK:
			var index := bag.find(null)
			if index < 0:
				return
			var chunk := mini(stack.count - MAX_STACK, MAX_STACK)
			bag[index] = stack.copy_with(chunk)
			stack.count -= chunk


func _clear_bag() -> void:
	bag.clear()
	bag.resize(BAG_SIZE)


func _bag_changed() -> void:
	inventory_changed.emit()
	health_potions_changed.emit(health_potions)
	mana_potions_changed.emit(mana_potions)


# --- Ekipman --------------------------------------------------------------------

## Takılı eşya (yoksa null).
func get_equipped(slot: String) -> ItemData:
	return equipment.get(slot) as ItemData


## Çantadaki eşyayı uygun yuvaya takar; yuvadaki eski eşya çantaya döner.
func equip(item: ItemData) -> bool:
	var slots := item.get_slots()
	if slots.is_empty() or bag_index_of(item) < 0:
		return false
	var slot: String = slots[0]
	match item.type:
		ItemData.Type.WEAPON:
			slot = "main_%d" % active_weapon_set
		ItemData.Type.OFFHAND:
			slot = "off_%d" % active_weapon_set
		ItemData.Type.AMMO:
			slot = _free_slot_for(item) if not _free_slot_for(item).is_empty() else "ammo_1"
	return equip_to(item, slot)


## Çantadaki eşyayı verilen yuvaya takar. Yuvadan çıkan eşya, takılan eşyanın çantadaki yerine geçer.
func equip_to(item: ItemData, slot: String) -> bool:
	var index := bag_index_of(item)
	if not slot in item.get_slots() or index < 0:
		return false
	var set_number := slot.right(1)
	# Çift elli silah takılıysa ikinci el kilitli
	if slot.begins_with("off_"):
		var main := get_equipped("main_" + set_number)
		if main and main.two_handed:
			message.emit(tr("MSG_OFFHAND_LOCKED"), Color(1, 0.6, 0.4))
			return false
	var returning: Array[ItemData] = []
	if get_equipped(slot):
		returning.append(get_equipped(slot))
	if item.two_handed and get_equipped("off_" + set_number):
		returning.append(get_equipped("off_" + set_number))
	# Takılan eşya bir yuva boşaltır; geri dönenler yer kaplar
	var free := bag.count(null) + 1
	if returning.size() > free:
		message.emit(tr("MSG_BAG_FULL"), Color(1, 0.6, 0.4))
		return false
	bag[index] = null
	if item.two_handed:
		equipment.erase("off_" + set_number)
	equipment[slot] = item
	for returned in returning:
		var target := index if bag[index] == null else bag.find(null)
		bag[target] = BagStack.of_item(returned)
	Audio.play_sfx("equip", 0.0)
	equipment_changed.emit()
	_bag_changed()
	return true


## Yuvadaki eşyayı çıkarıp çantaya koyar. to_index verilirse ve boşsa oraya.
func unequip(slot: String, to_index: int = -1) -> bool:
	var item := get_equipped(slot)
	if item == null:
		return false
	var target := to_index if to_index >= 0 and bag[to_index] == null else bag.find(null)
	if target < 0:
		message.emit(tr("MSG_BAG_FULL"), Color(1, 0.6, 0.4))
		return false
	equipment.erase(slot)
	bag[target] = BagStack.of_item(item)
	equipment_changed.emit()
	_bag_changed()
	return true


## Silah setleri arasında geçiş (1 <-> 2).
func swap_weapon_set() -> void:
	active_weapon_set = 2 if active_weapon_set == 1 else 1
	equipment_changed.emit()
	message.emit(tr("MSG_WEAPON_SET") % active_weapon_set, Color(0.9, 0.85, 0.7))


# Eşyanın boş bir yuvası varsa adı (silahlar için önce kullanılan set), yoksa ""
func _free_slot_for(item: ItemData) -> String:
	var slots := item.get_slots().duplicate()
	# Silahlarda önce kullanılan set denenir (yuvalar [x_1, x_2] sırasında)
	if (item.type == ItemData.Type.WEAPON or item.type == ItemData.Type.OFFHAND) and active_weapon_set == 2:
		slots.reverse()
	for slot: String in slots:
		if get_equipped(slot) != null:
			continue
		if slot.begins_with("off_"):
			var main := get_equipped("main_" + slot.right(1))
			if main and main.two_handed:
				continue
		if item.two_handed and get_equipped("off_" + slot.right(1)) != null:
			continue
		return slot
	return ""

# --- Özellikler -----------------------------------------------------------------

func get_attribute(attribute: String) -> int:
	return attributes.get(attribute, START_ATTRIBUTE)


## Dağıtılmayı bekleyen bir puanı özelliğe verir.
func add_attribute_point(attribute: String) -> bool:
	if attribute_points <= 0 or not attribute in ATTRIBUTES:
		return false
	attribute_points -= 1
	attributes[attribute] = get_attribute(attribute) + 1
	attributes_changed.emit()
	return true


func _reset_attributes() -> void:
	attributes.clear()
	for attribute: String in ATTRIBUTES:
		attributes[attribute] = START_ATTRIBUTE
	attribute_points = 0

# --- Deneyim ve seviye --------------------------------------------------------

## Bir sonraki seviye için gereken deneyim
func xp_to_next() -> int:
	return xp_needed_for(level)


## Verilen seviyeden bir sonrakine geçmek için gereken deneyim. 1. seviye XP_FIRST_LEVEL;
## her seviye öncekinin (yuvarlanmış hâlinin) 1,6 katı, yukarı ve 100'ün katına yuvarlanır:
## 100, 200, 400, 700, 1200, 2000...
static func xp_needed_for(for_level: int) -> int:
	var needed := XP_FIRST_LEVEL
	for i in range(1, for_level):
		# Tam sayıyla hesapla (ondalıklı 1.6 çarpımı 800.0000001 gibi değerler verip yanlış yuvarlar)
		var grown := needed * XP_GROWTH_PERCENT
		needed = ((grown + 9999) / 10000) * 100
	return needed


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
		if level % LEVELS_PER_ATTRIBUTE_POINT == 0:
			attribute_points += 1
			attributes_changed.emit()
			message.emit(tr("MSG_ATTRIBUTE_POINT"), Color(1.0, 0.9, 0.4))
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
	if not bag_has_room_for(BagStack.of_id("health_potion", 1)):
		message.emit(tr("MSG_BAG_FULL"), Color(1, 0.5, 0.4))
		return false
	if not spend_gold(HEALTH_POTION_PRICE):
		message.emit(tr("MSG_NOT_ENOUGH_GOLD"), Color(1, 0.5, 0.4))
		return false
	add_health_potions(1)
	return true


func buy_mana_potion() -> bool:
	if not bag_has_room_for(BagStack.of_id("mana_potion", 1)):
		message.emit(tr("MSG_BAG_FULL"), Color(1, 0.5, 0.4))
		return false
	if not spend_gold(MANA_POTION_PRICE):
		message.emit(tr("MSG_NOT_ENOUGH_GOLD"), Color(1, 0.5, 0.4))
		return false
	add_mana_potions(1)
	return true


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
	_clear_bag()
	add_to_bag(BagStack.of_id("health_potion", START_HEALTH_POTIONS))
	add_to_bag(BagStack.of_id("mana_potion", START_MANA_POTIONS))
	equipment.clear()
	active_weapon_set = 1
	_reset_attributes()
	skill_slots = DEFAULT_SKILL_SLOTS.duplicate()
	quick_slots = DEFAULT_QUICK_SLOTS.duplicate()
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
	var bag_data: Array = []
	for stack in bag:
		bag_data.append(stack.to_dict() if stack else null)
	var equipped := {}
	for slot: String in equipment:
		equipped[slot] = (equipment[slot] as ItemData).to_dict()
	var data := {
		"version": SAVE_VERSION,
		"hp": hp, "mana": mana, "stamina": stamina,
		"gold": gold,
		"level": level, "xp": xp, "weapon_level": weapon_level,
		"equipment": equipped,
		"weapon_set": active_weapon_set,
		"attributes": attributes,
		"attribute_points": attribute_points,
		"bag": bag_data,
		"skill_slots": skill_slots,
		"quick_slots": quick_slots,
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
	equipment.clear()
	var saved_equipment: Variant = data.get("equipment", {})
	if saved_equipment is Dictionary:
		for slot: String in saved_equipment:
			if slot in EQUIP_SLOTS and saved_equipment[slot] is Dictionary:
				equipment[slot] = ItemData.from_dict(saved_equipment[slot])
	# Eski kayıtlar: tek silah ve zırh yuvası vardı
	if data.get("weapon") is Dictionary:
		equipment["main_1"] = ItemData.from_dict(data["weapon"])
	if data.get("armor") is Dictionary:
		equipment["armor"] = ItemData.from_dict(data["armor"])
	active_weapon_set = 2 if int(data.get("weapon_set", 1)) == 2 else 1
	_reset_attributes()
	var saved_attributes: Variant = data.get("attributes", {})
	if saved_attributes is Dictionary:
		for attribute: String in ATTRIBUTES:
			attributes[attribute] = int(saved_attributes.get(attribute, START_ATTRIBUTE))
	attribute_points = int(data.get("attribute_points", 0))
	skill_slots = _load_slots(data.get("skill_slots"), DEFAULT_SKILL_SLOTS)
	quick_slots = _load_slots(data.get("quick_slots"), DEFAULT_QUICK_SLOTS)
	_clear_bag()
	var saved_bag: Variant = data.get("bag")
	if saved_bag is Array:
		for i in mini(saved_bag.size(), BAG_SIZE):
			if saved_bag[i] is Dictionary:
				bag[i] = BagStack.from_dict(saved_bag[i])
	else:
		# Eski kayıtlar: iksir ve malzeme sayaçları + eşya listesi vardı
		add_to_bag(BagStack.of_id("health_potion", int(data.get("health_potions", START_HEALTH_POTIONS))))
		add_to_bag(BagStack.of_id("mana_potion", int(data.get("mana_potions", START_MANA_POTIONS))))
		var saved_materials: Variant = data.get("materials", {})
		if saved_materials is Dictionary:
			for id: String in saved_materials:
				if int(saved_materials[id]) > 0:
					add_to_bag(BagStack.of_id(id, int(saved_materials[id])))
		for entry: Variant in data.get("inventory", []):
			if entry is Dictionary:
				add_to_bag(BagStack.of_item(ItemData.from_dict(entry)))
	_split_oversized_stacks()
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


# Kayıttaki yuva listesini okur; eski kayıtlarda yoksa ya da boyu tutmuyorsa varsayılanı kullanır
func _load_slots(saved: Variant, defaults: Array[String]) -> Array[String]:
	var slots: Array[String] = defaults.duplicate()
	if saved is Array and saved.size() == defaults.size():
		for i in slots.size():
			slots[i] = str(saved[i])
	return slots


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
	hotbar_changed.emit()
	equipment_changed.emit()
	attributes_changed.emit()
