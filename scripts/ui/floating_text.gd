class_name FloatingText
extends Label
## Hasar sayıları ve kısa bilgiler için yukarı süzülüp kaybolan yazı.
## Kullanım: FloatingText.spawn(get_parent(), global_position, "12", Color.WHITE)

const THEME := preload("res://assets/ui/game_theme.tres")


static func spawn(parent: Node, world_position: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := FloatingText.new()
	label.theme = THEME
	label.theme_type_variation = &"HudLabel"
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(60, 13)
	label.z_index = 100
	parent.add_child(label)
	label.global_position = (world_position - label.size / 2.0).round()
	label._animate()


func _animate() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - 16.0, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)
	tween.chain().tween_callback(queue_free)
