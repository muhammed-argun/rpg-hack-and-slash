extends Node
## Görev sistemi. Görev tanımları data/quests.json dosyasından okunur; metinler çeviri anahtarıdır.
## Autoload olarak "Quests" adıyla erişilir.
##
## Görev akışı: NONE -> start() -> ACTIVE -> (hedefler tamam) -> READY -> turn_in() -> DONE
## Teslim NPC'si ("turn_in") boş olan görevler hedefler tamamlanınca kendiliğinden biter.
##
## Hedef türleri (objectives[].type):
##   kill    target: düşman id'si ("any" = herhangi)     count: adet
##   collect target: malzeme id'si                       count: adet  ("consume": teslimde harcanır)
##   talk    target: NPC id'si
##   reach   target: harita id'si (Map.map_id)
##   boss    target: boss id'si
##   craft   target: tarif id'si
##   shards  count: toplam kristal parçası

signal quest_started(id: String)
signal quest_updated(id: String)
signal quest_ready(id: String)
signal quest_completed(id: String)
signal tracked_changed(id: String)

enum State { NONE, ACTIVE, READY, DONE }

const DATA_PATH := "res://data/quests.json"

var defs: Dictionary = {}
## Takip edilen (HUD'da gösterilen) görev
var tracked: String = ""
# id -> {"state": int, "progress": Array[int]}
var _states: Dictionary = {}


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		defs = parsed
	else:
		push_error("Quests: %s okunamadı." % DATA_PATH)


func reset() -> void:
	_states.clear()
	tracked = ""
	tracked_changed.emit(tracked)


func get_state(id: String) -> State:
	return int(_states[id]["state"]) as State if _states.has(id) else State.NONE


## Görev henüz alınmadıysa ve ön koşulları sağlanıyorsa true.
func is_available(id: String) -> bool:
	return defs.has(id) and get_state(id) == State.NONE and GameConditions.evaluate(defs[id].get("requires"))


func start(id: String) -> void:
	if not defs.has(id):
		push_warning("Quests: bilinmeyen görev %s" % id)
		return
	if get_state(id) != State.NONE:
		return
	var objectives: Array = defs[id].get("objectives", [])
	var progress: Array = []
	progress.resize(objectives.size())
	progress.fill(0)
	_states[id] = {"state": State.ACTIVE, "progress": progress}
	GameState.message.emit(tr("MSG_QUEST_STARTED") % get_title(id), GameState.QUEST_COLOR)
	Audio.play_sfx("quest_start", 0.0)
	# En son alınan görev takip edilir (HUD'da gösterilir)
	_set_tracked(id)
	quest_started.emit(id)
	_refresh_dynamic(id)
	_check_complete(id)


## Oyundaki bir olayı tüm aktif görevlere bildirir.
func notify(type: String, target: String = "", amount: int = 1) -> void:
	for id: String in _states.keys():
		if get_state(id) != State.ACTIVE:
			continue
		var objectives: Array = defs[id].get("objectives", [])
		var progress: Array = _states[id]["progress"]
		var changed := false
		for i in objectives.size():
			var objective: Dictionary = objectives[i]
			if objective.get("type") != type:
				continue
			var wanted: String = objective.get("target", "any")
			if wanted != "any" and wanted != target and type != "shards":
				continue
			var count: int = int(objective.get("count", 1))
			var before: int = progress[i]
			if type == "shards":
				progress[i] = mini(count, GameState.shards.size())
			else:
				progress[i] = mini(count, int(progress[i]) + amount)
			changed = changed or progress[i] != before
		if changed:
			quest_updated.emit(id)
			_check_complete(id)


func turn_in(id: String) -> void:
	if get_state(id) == State.READY:
		_complete(id)


func get_title(id: String) -> String:
	return tr(defs[id].get("title", id)) if defs.has(id) else id


func get_description(id: String) -> String:
	return tr(defs[id].get("desc", "")) if defs.has(id) else ""


func get_turn_in_npc(id: String) -> String:
	return defs[id].get("turn_in", "") if defs.has(id) else ""


## Hedefin ekranda gösterilecek metni, ör. "Ork öldür (2/4)"
func get_objective_text(id: String, index: int) -> String:
	var objective: Dictionary = defs[id]["objectives"][index]
	var count: int = int(objective.get("count", 1))
	var done: int = int(_states[id]["progress"][index]) if _states.has(id) else 0
	if get_state(id) == State.DONE:
		done = count
	var text := tr(objective.get("text", ""))
	return "%s (%d/%d)" % [text, done, count] if count > 1 else text


func get_objective_count(id: String) -> int:
	return defs[id].get("objectives", []).size() if defs.has(id) else 0


func is_objective_done(id: String, index: int) -> bool:
	if get_state(id) == State.DONE or get_state(id) == State.READY:
		return true
	var objective: Dictionary = defs[id]["objectives"][index]
	return int(_states[id]["progress"][index]) >= int(objective.get("count", 1))


## Aktif ve teslim bekleyen görevler (önce ana görevler)
func get_open_quests() -> Array[String]:
	var result: Array[String] = []
	for id: String in _states:
		var state := get_state(id)
		if state == State.ACTIVE or state == State.READY:
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return bool(defs[a].get("main", false)) and not bool(defs[b].get("main", false)))
	return result


func get_completed_quests() -> Array[String]:
	var result: Array[String] = []
	for id: String in _states:
		if get_state(id) == State.DONE:
			result.append(id)
	return result


func to_dict() -> Dictionary:
	return {"states": _states.duplicate(true), "tracked": tracked}


func from_dict(data: Dictionary) -> void:
	_states.clear()
	var saved: Dictionary = data.get("states", {})
	for id: String in saved:
		if not defs.has(id):
			continue
		var entry: Dictionary = saved[id]
		var progress: Array = []
		for value: Variant in entry.get("progress", []):
			progress.append(int(value))
		var needed: int = defs[id].get("objectives", []).size()
		while progress.size() < needed:
			progress.append(0)
		_states[id] = {"state": int(entry.get("state", State.ACTIVE)), "progress": progress}
	tracked = data.get("tracked", "")
	tracked_changed.emit(tracked)


# Envanterden okunan hedefleri (ör. zaten sahip olunan malzeme, toplam parça) günceller
func _refresh_dynamic(id: String) -> void:
	var objectives: Array = defs[id].get("objectives", [])
	var progress: Array = _states[id]["progress"]
	for i in objectives.size():
		var objective: Dictionary = objectives[i]
		var count: int = int(objective.get("count", 1))
		match objective.get("type"):
			"shards":
				progress[i] = mini(count, GameState.shards.size())
			"collect":
				progress[i] = mini(count, maxi(int(progress[i]), GameState.get_material(objective.get("target", ""))))


func _check_complete(id: String) -> void:
	if get_state(id) != State.ACTIVE:
		return
	var objectives: Array = defs[id].get("objectives", [])
	for i in objectives.size():
		if int(_states[id]["progress"][i]) < int(objectives[i].get("count", 1)):
			return
	if str(defs[id].get("turn_in", "")).is_empty():
		_complete(id)
	else:
		_states[id]["state"] = State.READY
		GameState.message.emit(tr("MSG_QUEST_READY") % get_title(id), GameState.QUEST_COLOR)
		quest_ready.emit(id)


func _complete(id: String) -> void:
	var def: Dictionary = defs[id]
	# Teslimde harcanan malzemeler
	var cost := {}
	for objective: Dictionary in def.get("objectives", []):
		if objective.get("type") == "collect" and objective.get("consume", false):
			cost[objective["target"]] = int(objective.get("count", 1))
	if not cost.is_empty() and not GameState.spend_materials(cost):
		# Malzeme sonradan harcandıysa görev tekrar aktif olur
		_states[id]["state"] = State.ACTIVE
		_refresh_materials(id)
		return
	_states[id]["state"] = State.DONE
	GameState.message.emit(tr("MSG_QUEST_DONE") % get_title(id), GameState.QUEST_COLOR)
	Audio.play_sfx("quest_complete", 0.0)
	_give_rewards(def.get("rewards", {}))
	quest_completed.emit(id)
	if tracked == id:
		var open := get_open_quests()
		_set_tracked(open[0] if not open.is_empty() else "")
	var next: String = def.get("next", "")
	if not next.is_empty() and is_available(next):
		start(next)


func _refresh_materials(id: String) -> void:
	var objectives: Array = defs[id].get("objectives", [])
	for i in objectives.size():
		if objectives[i].get("type") == "collect":
			_states[id]["progress"][i] = mini(int(objectives[i].get("count", 1)), GameState.get_material(objectives[i]["target"]))


func _give_rewards(rewards: Dictionary) -> void:
	if rewards.has("gold"):
		GameState.add_gold(int(rewards["gold"]))
	if rewards.has("health_potions"):
		GameState.add_health_potions(int(rewards["health_potions"]))
	if rewards.has("mana_potions"):
		GameState.add_mana_potions(int(rewards["mana_potions"]))
	var reward_materials: Dictionary = rewards.get("materials", {})
	for id: String in reward_materials:
		GameState.add_material(id, int(reward_materials[id]))
	for flag: Variant in rewards.get("flags", []):
		GameState.set_flag(str(flag))


func _set_tracked(id: String) -> void:
	tracked = id
	tracked_changed.emit(id)
