extends Node
## Oyuncunun haritalar arasında korunan durumu: can, altın, iksir, ekipman.
## Autoload olarak "GameState" adıyla her yerden erişilebilir.

signal hp_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal potions_changed(amount: int)
signal equipment_changed
signal message(text: String, color: Color)
signal map_change_requested(map_path: String, spawn_name: String)
signal player_died

# Warrior temel değerleri (sınıf sistemi gelince ayrı bir veri dosyasına taşınacak)
const BASE_MAX_HP := 120
const BASE_DAMAGE := 14
const BASE_DEFENSE := 2
const CRIT_CHANCE := 0.05
const CRIT_MULTIPLIER := 1.5
const POTION_HEAL_RATIO := 0.5
const START_POTIONS := 3

const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const HEAL_COLOR := Color(0.4, 1.0, 0.4)

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var gold: int = 0
var potions: int = START_POTIONS
var weapon: ItemData = null
var armor: ItemData = null
var inventory: Array[ItemData] = []


func get_attack_damage() -> int:
	var damage := BASE_DAMAGE
	if weapon:
		damage += weapon.damage_bonus
	return damage


func get_defense() -> int:
	var defense := BASE_DEFENSE
	if armor:
		defense += armor.defense_bonus
	return defense


## Bir saldırının hasarını hesaplar. Dönüş: {"amount": int, "crit": bool}
func roll_damage() -> Dictionary:
	var amount := get_attack_damage() * randf_range(0.85, 1.15)
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


## İksir kullanır, iyileşen can miktarını döndürür (kullanılamadıysa 0).
func use_potion() -> int:
	if potions <= 0 or hp <= 0 or hp >= max_hp:
		return 0
	potions -= 1
	var before := hp
	hp = mini(max_hp, hp + roundi(max_hp * POTION_HEAL_RATIO))
	potions_changed.emit(potions)
	hp_changed.emit(hp, max_hp)
	return hp - before


func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
	message.emit("+%d altın" % amount, GOLD_COLOR)


func add_potions(amount: int) -> void:
	potions += amount
	potions_changed.emit(potions)
	message.emit("+%d iksir" % amount, HEAL_COLOR)


## Eşyayı alır: mevcut ekipmandan iyiyse kuşanır, değilse çantaya koyar.
func add_item(item: ItemData) -> void:
	match item.type:
		ItemData.Type.WEAPON:
			if weapon == null or item.damage_bonus > weapon.damage_bonus:
				if weapon:
					inventory.append(weapon)
				weapon = item
				equipment_changed.emit()
				message.emit("Kuşanıldı: %s (+%d hasar)" % [item.get_display_name(), item.damage_bonus], item.get_color())
				return
		ItemData.Type.ARMOR:
			if armor == null or item.defense_bonus > armor.defense_bonus:
				if armor:
					inventory.append(armor)
				armor = item
				equipment_changed.emit()
				message.emit("Kuşanıldı: %s (+%d savunma)" % [item.get_display_name(), item.defense_bonus], item.get_color())
				return
	inventory.append(item)
	message.emit("Çantaya eklendi: %s" % item.get_display_name(), item.get_color())


## Ölümden sonra şehirde yeniden doğarken çağrılır.
func restore_after_death() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	message.emit("Şehirde yeniden doğdun", Color.WHITE)
