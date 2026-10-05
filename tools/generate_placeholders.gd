extends SceneTree
## Demo için yer tutucu (placeholder) görselleri üretir.
## Var olan dosyaların ÜZERİNE YAZMAZ; yalnızca eksik olanları oluşturur.
## Böylece kendi çizdiğin bir görseli silersen, bu araç yerine yer tutucusunu geri koyar.
##
## Çalıştırma (proje klasöründe):
##   godot --headless --path . --script res://tools/generate_placeholders.gd

const FRAME := 32
const OUTLINE := Color(0.08, 0.08, 0.1)
const STEEL := Color(0.78, 0.82, 0.9)
const FACING := {"down": Vector2.DOWN, "up": Vector2.UP, "right": Vector2.RIGHT}
# Yer tutucu kare sayıları; kendi çizimlerinde istediğin kadar kare kullanabilirsin
const FRAME_COUNTS := {"idle": 2, "walk": 4, "attack": 4, "hurt": 2, "death": 4}

var _created := 0


func _init() -> void:
	_make_character("res://assets/characters/warrior", Color.WHITE)
	_make_character("res://assets/enemies/goblin", Color(0.85, 0.25, 0.25))
	_make_chest()
	_make_tileset()
	_make_ui()
	print("Yer tutucu görseller: %d yeni dosya oluşturuldu." % _created)
	quit()


# --- Karakterler -----------------------------------------------------------

func _make_character(folder: String, body: Color) -> void:
	for anim: String in FRAME_COUNTS:
		for dir: String in FACING:
			for i in FRAME_COUNTS[anim]:
				var path := "%s/%s_%s_%02d.png" % [folder, anim, dir, i + 1]
				_save_if_missing(path, _character_frame(anim, dir, i, body))


func _character_frame(anim: String, dir: String, i: int, body: Color) -> Image:
	var img := _new_image(FRAME, FRAME)
	var center := Vector2(16, 20)
	var radius := 9.0
	var color := body
	var facing: Vector2 = FACING[dir]
	match anim:
		"idle":
			center.y += i
		"walk":
			center.y -= i % 2
		"hurt":
			center -= facing * (2 - i)
		"death":
			radius = 9.0 - i * 2.0
			color = body.lerp(Color(0.35, 0.35, 0.35), i / 3.0)
			center.y += i

	var sword_length := 0
	if anim == "attack":
		sword_length = [3, 7, 11, 6][i]
	# Yukarı bakarken kılıç gövdenin arkasında kalır
	if sword_length > 0 and dir == "up":
		_draw_sword(img, center, facing, radius, sword_length)
	_draw_circle(img, center, radius, OUTLINE)
	_draw_circle(img, center, radius - 1.0, color)
	if sword_length > 0 and dir != "up":
		_draw_sword(img, center, facing, radius, sword_length)
	if anim != "death" or i == 0:
		_draw_eyes(img, center, dir)
	return img


func _draw_sword(img: Image, center: Vector2, facing: Vector2, radius: float, length: int) -> void:
	var side := Vector2(-facing.y, facing.x)
	var start := center + facing * (radius - 2.0)
	for s in length:
		var p := start + facing * s
		_px(img, p, STEEL)
		_px(img, p + side, STEEL.darkened(0.25))


func _draw_eyes(img: Image, center: Vector2, dir: String) -> void:
	match dir:
		"down":
			_rect(img, Rect2i(int(center.x) - 4, int(center.y), 2, 2), OUTLINE)
			_rect(img, Rect2i(int(center.x) + 2, int(center.y), 2, 2), OUTLINE)
		"right":
			_rect(img, Rect2i(int(center.x) + 3, int(center.y) - 1, 2, 2), OUTLINE)


# --- Sandık ----------------------------------------------------------------

func _make_chest() -> void:
	var wood := Color(0.55, 0.33, 0.15)
	var gold := Color(1.0, 0.82, 0.25)

	var closed := _new_image(FRAME, FRAME)
	_rect(closed, Rect2i(5, 15, 22, 15), OUTLINE)
	_rect(closed, Rect2i(6, 16, 20, 13), wood)
	_rect(closed, Rect2i(6, 16, 20, 4), wood.lightened(0.2))
	_rect(closed, Rect2i(6, 20, 20, 1), OUTLINE)
	_rect(closed, Rect2i(14, 19, 4, 4), gold)
	_save_if_missing("res://assets/objects/chest_closed.png", closed)

	var opened := _new_image(FRAME, FRAME)
	_rect(opened, Rect2i(5, 9, 22, 8), OUTLINE)
	_rect(opened, Rect2i(6, 10, 20, 6), wood.darkened(0.3))
	_rect(opened, Rect2i(5, 17, 22, 13), OUTLINE)
	_rect(opened, Rect2i(6, 18, 20, 11), wood)
	_rect(opened, Rect2i(8, 16, 16, 3), gold)
	_save_if_missing("res://assets/objects/chest_open.png", opened)


# --- Tileset ---------------------------------------------------------------
# Sıra (soldan sağa, her biri 32x32): 0 çimen, 1 toprak yol, 2 parke taşı,
# 3 duvar, 4 ağaç, 5 su. Duvar, ağaç ve su engel (çarpışma) oluşturur.

func _make_tileset() -> void:
	var path := "res://assets/tiles/tileset.png"
	if FileAccess.file_exists(path):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var img := _new_image(FRAME * 6, FRAME)

	var grass := Color(0.32, 0.56, 0.26)
	_speckled_tile(img, 0, grass, rng)
	_speckled_tile(img, 1, Color(0.6, 0.46, 0.3), rng)

	# Parke taşı
	var stone := Color(0.56, 0.56, 0.6)
	_rect(img, Rect2i(2 * FRAME, 0, FRAME, FRAME), stone)
	for row in 4:
		_rect(img, Rect2i(2 * FRAME, row * 8 + 7, FRAME, 1), stone.darkened(0.3))
		var shift := 0 if row % 2 == 0 else 4
		for col in 4:
			_rect(img, Rect2i(2 * FRAME + col * 8 + shift, row * 8, 1, 7), stone.darkened(0.3))

	# Duvar (tuğla)
	var brick := Color(0.5, 0.42, 0.38)
	_rect(img, Rect2i(3 * FRAME, 0, FRAME, FRAME), brick)
	for row in 4:
		_rect(img, Rect2i(3 * FRAME, row * 8 + 7, FRAME, 1), brick.darkened(0.45))
		var shift := 0 if row % 2 == 0 else 8
		for col in 2:
			_rect(img, Rect2i(3 * FRAME + col * 16 + shift, row * 8, 1, 7), brick.darkened(0.45))
	_rect(img, Rect2i(3 * FRAME, 0, FRAME, 2), brick.lightened(0.25))

	# Ağaç (çimen zemin üstünde)
	_speckled_tile(img, 4, grass, rng)
	_rect(img, Rect2i(4 * FRAME + 13, 20, 6, 11), OUTLINE)
	_rect(img, Rect2i(4 * FRAME + 14, 20, 4, 10), Color(0.42, 0.27, 0.13))
	_draw_circle(img, Vector2(4 * FRAME + 16, 12), 12.0, OUTLINE)
	_draw_circle(img, Vector2(4 * FRAME + 16, 12), 11.0, Color(0.14, 0.38, 0.16))
	_draw_circle(img, Vector2(4 * FRAME + 13, 9), 5.0, Color(0.2, 0.48, 0.2))

	# Su
	var water := Color(0.22, 0.42, 0.75)
	_rect(img, Rect2i(5 * FRAME, 0, FRAME, FRAME), water)
	for k in 6:
		var x := 5 * FRAME + rng.randi_range(2, 24)
		var y := rng.randi_range(2, 29)
		_rect(img, Rect2i(x, y, 5, 1), water.lightened(0.35))

	_save_if_missing(path, img)


func _speckled_tile(img: Image, index: int, base: Color, rng: RandomNumberGenerator) -> void:
	_rect(img, Rect2i(index * FRAME, 0, FRAME, FRAME), base)
	for k in 24:
		var p := Vector2(index * FRAME + rng.randi_range(0, 31), rng.randi_range(0, 31))
		_px(img, p, base.lightened(0.15) if k % 2 == 0 else base.darkened(0.15))


# --- Arayüz ----------------------------------------------------------------

func _make_ui() -> void:
	var base := _new_image(48, 48)
	_draw_circle(base, Vector2(24, 24), 23.0, Color(1, 1, 1, 0.9))
	_draw_circle(base, Vector2(24, 24), 21.0, Color(1, 1, 1, 0.25))
	_save_if_missing("res://assets/ui/joystick_base.png", base)

	var knob := _new_image(22, 22)
	_draw_circle(knob, Vector2(11, 11), 11.0, OUTLINE)
	_draw_circle(knob, Vector2(11, 11), 10.0, Color(1, 1, 1, 0.95))
	_save_if_missing("res://assets/ui/joystick_knob.png", knob)

	var attack := _new_image(40, 40)
	_draw_circle(attack, Vector2(20, 20), 20.0, Color(1, 1, 1, 0.9))
	_draw_circle(attack, Vector2(20, 20), 18.0, Color(0.75, 0.18, 0.18, 0.9))
	for s in 18:
		_rect(attack, Rect2i(11 + s, 28 - s, 2, 2), Color.WHITE)
	_rect(attack, Rect2i(11, 22, 8, 2), Color.WHITE)
	_save_if_missing("res://assets/ui/button_attack.png", attack)

	var potion := _new_image(28, 28)
	_draw_circle(potion, Vector2(14, 14), 14.0, Color(1, 1, 1, 0.9))
	_draw_circle(potion, Vector2(14, 14), 12.0, Color(0.15, 0.15, 0.25, 0.9))
	_draw_circle(potion, Vector2(14, 16), 6.0, Color(0.9, 0.2, 0.3))
	_rect(potion, Rect2i(12, 6, 4, 5), Color(0.85, 0.85, 0.9))
	_save_if_missing("res://assets/ui/button_potion.png", potion)


# --- Çizim yardımcıları ----------------------------------------------------

func _new_image(width: int, height: int) -> Image:
	return Image.create_empty(width, height, false, Image.FORMAT_RGBA8)


func _px(img: Image, p: Vector2, color: Color) -> void:
	var x := int(p.x)
	var y := int(p.y)
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)


func _rect(img: Image, rect: Rect2i, color: Color) -> void:
	img.fill_rect(rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height())), color)


func _draw_circle(img: Image, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	for y in range(int(center.y - radius) - 1, int(center.y + radius) + 2):
		for x in range(int(center.x - radius) - 1, int(center.x + radius) + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
				_px(img, Vector2(x, y), color)


func _save_if_missing(path: String, img: Image) -> void:
	if FileAccess.file_exists(path):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Kaydedilemedi: %s (hata %d)" % [path, err])
		return
	_created += 1
