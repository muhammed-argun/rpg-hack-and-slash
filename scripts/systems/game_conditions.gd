class_name GameConditions
extends RefCounted
## Görev ve diyalog verilerindeki koşulları değerlendirir. Koşullar JSON'dan gelen sözlüklerdir:
##   {}                                         her zaman doğru
##   {"quest": "q_id", "state": "done"}         görev durumu: none, active, ready, done (dizi de olabilir)
##   {"flag": "ad"}  /  {"flag": "ad", "value": false}
##   {"shards_at_least": 3}
##   {"material": "bloodweed", "at_least": 5}
##   {"all": [...]}  {"any": [...]}  {"not": {...}}

const STATE_NAMES := {"none": 0, "active": 1, "ready": 2, "done": 3}


static func evaluate(condition: Variant) -> bool:
	if condition == null or not condition is Dictionary or (condition as Dictionary).is_empty():
		return true
	var c: Dictionary = condition
	if c.has("all"):
		for sub: Variant in c["all"]:
			if not evaluate(sub):
				return false
		return true
	if c.has("any"):
		for sub: Variant in c["any"]:
			if evaluate(sub):
				return true
		return false
	if c.has("not"):
		return not evaluate(c["not"])
	if c.has("quest"):
		var current: int = Quests.get_state(c["quest"])
		var wanted: Variant = c.get("state", "done")
		if wanted is Array:
			for name: Variant in wanted:
				if STATE_NAMES.get(str(name), -1) == current:
					return true
			return false
		return STATE_NAMES.get(str(wanted), -1) == current
	if c.has("flag"):
		return GameState.flags.get(c["flag"], false) == c.get("value", true)
	if c.has("shards_at_least"):
		return GameState.shards.size() >= int(c["shards_at_least"])
	if c.has("material"):
		return GameState.get_material(c["material"]) >= int(c.get("at_least", 1))
	push_warning("GameConditions: bilinmeyen koşul %s" % str(c))
	return false
