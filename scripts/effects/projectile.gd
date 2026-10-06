class_name Projectile
extends Area2D
## Düşman mermisi (büyü küresi, ok, ruh oku). Oyuncuya çarpınca hasar verir, duvarda kaybolur.
## Görseli şimdilik çizilen parlayan bir küre; Zerie paketindeki mermi görselleri gelince
## texture ile değiştirilebilir.

var velocity := Vector2.ZERO
var damage := 10
var kind: Combat.Kind = Combat.Kind.NORMAL
var lifetime := 3.0
## 0 = düz gider, 1'e yakın = oyuncuyu sıkı takip eder
var homing := 0.0
var color := Color(0.75, 0.45, 1.0)
var radius := 4.0
var _player: Player
var _time := 0.0


static func spawn(at: Vector2, direction: Vector2, speed: float, projectile_damage: int, projectile_kind: Combat.Kind, projectile_color: Color, homing_strength: float = 0.0) -> Projectile:
	var projectile := Projectile.new()
	projectile.position = at
	projectile.velocity = direction.normalized() * speed
	projectile.damage = projectile_damage
	projectile.kind = projectile_kind
	projectile.color = projectile_color
	projectile.homing = homing_strength
	if Map.current:
		Map.current.entities.add_child(projectile)
		Audio.play_sfx("projectile")
	return projectile


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	monitorable = false
	z_index = 5
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_player = get_tree().get_first_node_in_group("player") as Player


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	if homing > 0.0 and is_instance_valid(_player) and _player.is_inside_tree():
		var wanted := global_position.direction_to(_player.global_position + Vector2(0, -8)) * velocity.length()
		velocity = velocity.lerp(wanted, clampf(homing * delta * 3.0, 0.0, 1.0))
	position += velocity * delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.2 * sin(_time * 20.0)
	draw_circle(Vector2.ZERO, radius * 1.8 * pulse, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius * pulse, color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1, 1, 1, 0.9))


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# Mermiler parry'lenebilir ama atanı sersemletmez (kaynak verilmez)
		(body as Player).take_damage(damage, null, kind)
	elif body is Enemy:
		return
	queue_free()
