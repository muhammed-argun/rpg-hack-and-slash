class_name Afterimage
extends Sprite2D
## Yuvarlanma sırasında karakterin arkasında kalan, hızla kaybolan gölge kopyası.


static func spawn_from(sprite: AnimatedSprite2D, parent: Node, color: Color = Color(0.6, 0.8, 1.0, 0.6)) -> void:
	if parent == null or sprite.sprite_frames == null:
		return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		return
	var ghost := Afterimage.new()
	ghost.texture = texture
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.modulate = color
	ghost.z_index = -1
	parent.add_child(ghost)
	ghost.global_position = sprite.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ghost.queue_free)
