extends Node
## Oyuncunun haritalar arasında korunan durumu: can, mana, altın, iksirler, ekipman, çanta.
## Autoload olarak "GameState" adıyla her yerden erişilebilir.

signal hp_changed(current: int, maximum: int)
signal mana_changed(current: int, maximum: int)
signal gold_changed(amount: int)
signal health_potions_changed(amount: int)
signal mana_potions_changed(amount: int)
signal inventory_changed
signal equipment_changed
signal skill_cooldown_started(duration: float)
signal message(text: String, color: Color)
signal map_change_requested(map_path: String, spawn_name: String)
signal player_died

# Warrior temel değerleri (sınıf sistemi gelince ayrı bir veri dosyasına taşınacak)
const BASE_MAX_HP := 120
const BASE_MAX_MANA := 60
const BASE_DAMAGE := 14
const BASE_DEFENSE := 2
const CRIT_CHANCE := 0.05
const CRIT_MULTIPLIER := 1.5
## Saniyede dolan mana (yavaş; hızlı doldurmak için mana iksiri)
const MANA_REGEN_PER_SECOND := 1.0
const HEALTH_POTION_RATIO := 0.5
const MANA_POTION_RATIO := 0.5
const START_HEALTH_POTIONS := 3
const START_MANA_POTIONS := 1

const GOLD_COLOR := Color(1.0, 0.85, 0.3)
const HEAL_COLOR := Color(0.4, 1.0, 0.4)
const MANA_COLOR := Color(0.45, 0.65, 1.0)

const HEALTH_POTION_ICON := "res://assets/items/potion_health.png"
const MANA_POTION_ICON := "res://assets/items/potion_mana.png"

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var max_mana: int = BASE_MAX_MANA
var mana: float = BASE_MAX_MANA
var gold: int = 0
var health_potions: int = START_HEALTH_POTIONS
var mana_potions: int = START_MANA_POTIONS
var weapon: ItemData = null
var armor: ItemData = null
## Çantadaki eşyalar (iksirler ayrı sayılır, burada değerli eşyalar durur)
var inventory: Array[ItemData] = []


func _process(delta: float) -> void:
	if hp > 0 and mana < max_mana:
		var before := int(mana)
		mana = minf(max_mana, mana + MANA_REGEN_PER_SECOND * delta)
		if int(mana) != before:
			mana_changed.emit(int(mana), max_mana)


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
	message.emit("+%d altın" % amount, GOLD_COLOR)


func add_health_potions(amount: int) -> void:
	health_potions += amount
	health_potions_changed.emit(health_potions)
	inventory_changed.emit()
	message.emit("+%d can iksiri" % amount, HEAL_COLOR)


func add_mana_potions(amount: int) -> void:
	mana_potions += amount
	mana_potions_changed.emit(mana_potions)
	inventory_changed.emit()
	message.emit("+%d mana iksiri" % amount, MANA_COLOR)


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
				message.emit("Kuşanıldı: %s (+%d hasar)" % [item.get_display_name(), item.damage_bonus], item.get_color())
				return
		ItemData.Type.ARMOR:
			if armor == null or item.defense_bonus > armor.defense_bonus:
				if armor:
					inventory.append(armor)
				armor = item
				equipment_changed.emit()
				inventory_changed.emit()
				message.emit("Kuşanıldı: %s (+%d savunma)" % [item.get_display_name(), item.defense_bonus], item.get_color())
				return
	inventory.append(item)
	inventory_changed.emit()
	message.emit("Çantaya eklendi: %s" % item.get_display_name(), item.get_color())


## Ölümden sonra şehirde yeniden doğarken çağrılır.
func restore_after_death() -> void:
	hp = max_hp
	mana = max_mana
	hp_changed.emit(hp, max_hp)
	mana_changed.emit(int(mana), max_mana)
	message.emit("Şehirde yeniden doğdun", Color.WHITE)
