class_name BagStack
extends RefCounted
## Çantadaki bir yuvanın içeriği: aynı türden eşyalar (id + adet).
## id: tüketilebilir ("health_potion"), malzeme ("bloodweed"), değerli eşya ("val:<ad>|<nadirlik>")
## ya da ekipman ("item"; ekipman yığılmaz, her biri ayrı yuvada). item: değerli eşya ve ekipmanda dolu.

const EQUIPMENT_ID := "item"

var id: String = ""
var count: int = 1
var item: ItemData = null


static func of_id(stack_id: String, amount: int) -> BagStack:
	var stack := BagStack.new()
	stack.id = stack_id
	stack.count = amount
	return stack


static func of_item(new_item: ItemData, amount: int = 1) -> BagStack:
	var stack := BagStack.new()
	stack.item = new_item
	stack.count = amount
	if new_item.type == ItemData.Type.VALUABLE:
		stack.id = "val:%s|%d" % [new_item.name_key, new_item.rarity]
	else:
		stack.id = EQUIPMENT_ID
	return stack


## Bu yığınla aynı yuvada birleşebilir mi (ekipman birleşmez)
func can_stack_with(other: BagStack) -> bool:
	return other != null and id == other.id and id != EQUIPMENT_ID


## Aynı türden, verilen adette yeni bir yığın (bölmede kullanılır)
func copy_with(amount: int) -> BagStack:
	var stack := BagStack.new()
	stack.id = id
	stack.item = item
	stack.count = amount
	return stack


func is_consumable() -> bool:
	return GameState.CONSUMABLES.has(id)


func is_material() -> bool:
	return GameState.MATERIALS.has(id)


func get_icon() -> Texture2D:
	if item:
		return item.get_icon()
	if is_consumable():
		return GameState.consumable_icon(id)
	return GameState.material_icon(id)


func get_display_name() -> String:
	if item:
		return item.get_display_name()
	if is_consumable():
		return TranslationServer.translate(GameState.CONSUMABLES[id][0])
	if is_material():
		return TranslationServer.translate(GameState.MATERIALS[id][0])
	return id


func get_details() -> String:
	if item:
		return item.get_details()
	if is_consumable():
		var ratio := GameState.HEALTH_POTION_RATIO if id == "health_potion" else GameState.MANA_POTION_RATIO
		return TranslationServer.translate(GameState.CONSUMABLES[id][0] + "_DESC") % roundi(ratio * 100)
	if is_material():
		return TranslationServer.translate(GameState.MATERIALS[id][1])
	return ""


func get_color() -> Color:
	return item.get_color() if item else Color.WHITE


func get_rarity() -> int:
	return item.rarity if item else -1


## Tek bir tanesinin dükkânda satış fiyatı (0 = satılamaz, ör. görev eşyası)
func unit_value() -> int:
	if item:
		return item.value
	if is_consumable():
		return GameState.CONSUMABLE_SELL_VALUES.get(id, 0)
	return GameState.MATERIAL_SELL_VALUES.get(id, 0)


func to_dict() -> Dictionary:
	var data := {"id": id, "count": count}
	if item:
		data["item"] = item.to_dict()
	return data


static func from_dict(data: Dictionary) -> BagStack:
	var stack := BagStack.new()
	stack.id = str(data.get("id", ""))
	stack.count = maxi(1, int(data.get("count", 1)))
	if data.get("item") is Dictionary:
		stack.item = ItemData.from_dict(data["item"])
	return stack
