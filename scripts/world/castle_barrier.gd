class_name CastleBarrier
extends Interactable
## Kalenin yolunu kapatan Kül Kalkanı. 9 kristal parçası Ezra'ya teslim edilince
## ("barrier_broken" bayrağı) kırılır. Yaklaşınca kaç parça gerektiğini söyler.

@export var size: Vector2 = Vector2(96, 32)

var _gate: ArenaGate


func _ready() -> void:
	super._ready()
	prompt_key = "BARRIER_NAME"
	_gate = ArenaGate.new()
	_gate.size = size
	_gate.color = Color(0.85, 0.1, 0.15)
	add_child(_gate)
	if GameState.has_flag("barrier_broken"):
		queue_free()
		return
	_gate.set_closed(true)
	GameState.flag_changed.connect(_on_flag_changed)


func can_interact() -> bool:
	return not GameState.has_flag("barrier_broken")


func interact(_player: Player) -> void:
	GameState.message.emit(tr("MSG_BARRIER") % [GameState.shards.size(), GameState.SHARDS_REQUIRED], Color(1.0, 0.45, 0.4))


func _on_flag_changed(flag_name: String, _value: Variant) -> void:
	if flag_name != "barrier_broken":
		return
	GameState.message.emit(tr("MSG_BARRIER_BROKEN"), Color(0.6, 0.95, 1.0))
	Shockwave.spawn(global_position, 80.0, Color(1.0, 0.5, 0.4))
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)
