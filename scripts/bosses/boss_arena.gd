class_name BossArena
extends Node2D
## Boss arenası. Oyuncu tetik alanına girince kapılar kapanır ve boss uyanır;
## boss (ve varsa ikinci fazı) ölünce kapılar açılır. Yenilmiş boss haritaya bir daha gelmez.
## Yapı: BossArena (y-sort açık) > Boss, Trigger (Area2D), Gate'ler (ArenaGate)

@export var trigger_size: Vector2 = Vector2(320, 220)

var _boss: Boss
var _fight_started := false
var _gates: Array[ArenaGate] = []


func _ready() -> void:
	y_sort_enabled = true
	for child in get_children():
		if child is Boss:
			_boss = child
		elif child is ArenaGate:
			_gates.append(child)
	if _boss and GameState.has_flag("boss_" + _boss.boss_id):
		_boss.queue_free()
		_boss = null
	var trigger := Area2D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	trigger.monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = trigger_size
	shape.shape = rect
	trigger.add_child(shape)
	add_child(trigger)
	trigger.body_entered.connect(_on_trigger_body_entered)
	GameState.boss_ended.connect(_on_boss_ended)
	for gate in _gates:
		gate.set_closed(false)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _fight_started or _boss == null or not body is Player:
		return
	_fight_started = true
	for gate in _gates:
		gate.set_closed(true)
	_boss.activate()


func _on_boss_ended(boss: Node) -> void:
	# İkinci faz başlıyorsa kapılar kapalı kalır
	if not _fight_started or not is_instance_valid(boss) or not boss is Boss:
		return
	if (boss as Boss).next_boss_scene:
		return
	for gate in _gates:
		gate.set_closed(false)
