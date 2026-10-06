extends Node
## Diyalog verisi ve NPC konuşma kuralları (data/dialogue.json). Autoload olarak "Dialogue".
## NPC'ye dokunulunca kurallar sırayla denenir; koşulu sağlanan ilk diyalog oynatılır.
## Diyalog bitince "actions" çalışır ve aktif görevlere "talk" bildirilir.
##
## Eylemler: {"start_quest": id}, {"turn_in": id}, {"set_flag": ad}, {"open": "crafting"}

signal dialogue_started(npc_id: String, dialogue_id: String, lines: Array)
signal dialogue_finished(npc_id: String, dialogue_id: String)
signal window_requested(window_name: String)

const DATA_PATH := "res://data/dialogue.json"

var npcs: Dictionary = {}
var dialogues: Dictionary = {}
## Şu an oynayan diyalog (yoksa boş)
var active_npc: String = ""
var active_dialogue: String = ""


func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		npcs = parsed.get("npcs", {})
		dialogues = parsed.get("dialogues", {})
	else:
		push_error("Dialogue: %s okunamadı." % DATA_PATH)


func is_active() -> bool:
	return not active_dialogue.is_empty()


func get_npc_name(npc_id: String) -> String:
	if npc_id == "player":
		return tr("NPC_PLAYER")
	return tr(npcs[npc_id].get("name", npc_id)) if npcs.has(npc_id) else npc_id


## NPC'nin üstünde gösterilecek işaret: "?" teslim edilecek görev, "!" yeni görev, "" yok
func get_marker(npc_id: String) -> String:
	for quest_id: String in Quests.get_open_quests():
		if Quests.get_state(quest_id) == Quests.State.READY and Quests.get_turn_in_npc(quest_id) == npc_id:
			return "?"
	if npcs.has(npc_id):
		for quest_id: Variant in npcs[npc_id].get("offers", []):
			if Quests.is_available(str(quest_id)):
				return "!"
	return ""


func choose_dialogue(npc_id: String) -> String:
	if not npcs.has(npc_id):
		return ""
	for rule: Dictionary in npcs[npc_id].get("rules", []):
		if GameConditions.evaluate(rule.get("if")):
			return rule.get("dialogue", "")
	return ""


## NPC ile konuşmayı başlatır. Arayüz dialogue_started sinyalini dinleyip metni gösterir.
func talk_to(npc_id: String) -> void:
	if is_active():
		return
	var dialogue_id := choose_dialogue(npc_id)
	if dialogue_id.is_empty() or not dialogues.has(dialogue_id):
		push_warning("Dialogue: %s için diyalog bulunamadı." % npc_id)
		return
	active_npc = npc_id
	active_dialogue = dialogue_id
	dialogue_started.emit(npc_id, dialogue_id, dialogues[dialogue_id].get("lines", []))


## Arayüz son satır geçilince çağırır.
func finish() -> void:
	if not is_active():
		return
	var npc_id := active_npc
	var dialogue_id := active_dialogue
	active_npc = ""
	active_dialogue = ""
	Quests.notify("talk", npc_id)
	for action: Dictionary in dialogues[dialogue_id].get("actions", []):
		_run_action(action)
	dialogue_finished.emit(npc_id, dialogue_id)


func _run_action(action: Dictionary) -> void:
	if action.has("start_quest"):
		Quests.start(action["start_quest"])
	if action.has("turn_in"):
		Quests.turn_in(action["turn_in"])
	if action.has("set_flag"):
		GameState.set_flag(action["set_flag"])
	if action.has("open"):
		window_requested.emit(action["open"])
