extends SceneTree
## Pixel UI Fantasy'nin "Quill" bitmap fontuna eksik Türkçe harfleri ekler: ı İ ş Ş ğ Ğ
## (ç ö ü Ç Ö Ü zaten var). Yeni harfler fontun kendi harflerinden türetilir:
##   ı = i'nin noktası silinir          İ = I + i'nin noktası
##   ş = s + ç'nin çengeli              Ş = S + Ç'nin çengeli
##   ğ = g + kısa (breve) işareti       Ğ = G + kısa işareti
## Sonuç assets/fonts/quill_tr.fnt ve quill_tr.png olarak kaydedilir (orijinal dosyalar değişmez).
##
## Çalıştırma (proje klasöründe):
##   godot --headless --path . --script res://tools/make_turkish_font.gd

const SOURCE_FNT := "res://addons/pixel_ui_fantasy/font/pixel_ui_fantasy_font.fnt"
const SOURCE_PNG := "res://addons/pixel_ui_fantasy/font/pixel_ui_fantasy_font.png"
const TARGET_FNT := "res://assets/fonts/quill_tr.fnt"
const TARGET_PNG := "res://assets/fonts/quill_tr.png"
const CANVAS := Vector2i(16, 16)
# Kısa (breve) işareti: 4x2 piksel
const BREVE := [Vector2i(0, 0), Vector2i(3, 0), Vector2i(1, 1), Vector2i(2, 1)]

var _atlas: Image
var _chars := {}  # id -> {x, y, width, height, xoffset, yoffset, xadvance}
var _ink := Color.WHITE


func _init() -> void:
	_atlas = Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PNG))
	_atlas.convert(Image.FORMAT_RGBA8)
	var lines := FileAccess.get_file_as_string(SOURCE_FNT).split("\n")
	for line in lines:
		if line.begins_with("char "):
			var c := _parse(line)
			_chars[c["id"]] = c
	_ink = _find_ink(_glyph(105))

	var made := {}
	# ı: i'nin x-yüksekliğinin (s'nin üst hizası) üstünde kalan nokta silinir
	var x_top: int = _chars[115]["yoffset"]
	var dotless := _glyph(105)
	dotless.fill_rect(Rect2i(0, 0, CANVAS.x, x_top), Color(0, 0, 0, 0))
	made[0x131] = [dotless, 105]

	# İ: I'nın üstüne i'nin noktası
	var dot := _glyph(105).get_region(Rect2i(0, 0, CANVAS.x, x_top))
	var dot_used := dot.get_used_rect()
	var cap_i := _glyph(73)
	var cap_top: int = _chars[73]["yoffset"]
	# Nokta, I'nın 1 piksel üstüne oturur
	cap_i.blend_rect(dot, dot_used, Vector2i(dot_used.position.x, cap_top - 1 - dot_used.size.y))
	made[0x130] = [cap_i, 73]

	# ş / Ş: ç ve Ç'nin, c ve C'nin altında kalan kısmı (çengel)
	made[0x15F] = [_with_cedilla(115, 231, 99), 115]
	made[0x15E] = [_with_cedilla(83, 199, 67), 83]

	# ğ / Ğ: harfin üstüne kısa işareti
	made[0x11F] = [_with_breve(103, _chars[115]["yoffset"] - 3), 103]
	made[0x11E] = [_with_breve(71, _chars[71]["yoffset"] - 3), 71]

	_write(lines, made)
	print("Türkçe font oluşturuldu: %s (%d yeni harf)" % [TARGET_FNT, made.size()])
	quit()


func _parse(line: String) -> Dictionary:
	var result := {}
	for part in line.split(" ", false):
		var kv := part.split("=")
		if kv.size() == 2 and kv[1].is_valid_int():
			result[kv[0]] = int(kv[1])
	return result


# Harfi, satırdaki yerine (yoffset) göre boş bir tuvale çizer.
func _glyph(id: int) -> Image:
	var c: Dictionary = _chars[id]
	var img := Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
	if c["width"] > 0:
		img.blit_rect(_atlas, Rect2i(c["x"], c["y"], c["width"], c["height"]), Vector2i(c["xoffset"], c["yoffset"]))
	return img


func _find_ink(img: Image) -> Color:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.9:
				return img.get_pixel(x, y)
	return Color.WHITE


func _with_cedilla(base_id: int, cedilla_id: int, plain_id: int) -> Image:
	var with_hook := _glyph(cedilla_id)
	var plain_bottom: int = _chars[plain_id]["yoffset"] + _chars[plain_id]["height"]
	var hook := with_hook.get_region(Rect2i(0, plain_bottom, CANVAS.x, CANVAS.y - plain_bottom))
	var used := hook.get_used_rect()
	var img := _glyph(base_id)
	if used.size == Vector2i.ZERO:
		return img
	# Çengeli harfin ortasına hizala
	var base_center: float = _chars[base_id]["width"] / 2.0
	var hook_center := used.position.x + used.size.x / 2.0
	var dx := roundi(base_center - hook_center)
	img.blend_rect(hook, used, Vector2i(used.position.x + dx, plain_bottom + used.position.y))
	return img


func _with_breve(base_id: int, top: int) -> Image:
	var img := _glyph(base_id)
	var left: int = roundi(_chars[base_id]["width"] / 2.0 - 2.0)
	for p: Vector2i in BREVE:
		img.set_pixel(left + p.x, top + p.y, _ink)
	return img


func _write(lines: PackedStringArray, made: Dictionary) -> void:
	var height := _atlas.get_height()
	var atlas := Image.create_empty(_atlas.get_width(), height + CANVAS.y + 2, false, Image.FORMAT_RGBA8)
	atlas.blit_rect(_atlas, Rect2i(Vector2i.ZERO, _atlas.get_size()), Vector2i.ZERO)

	var new_lines: Array[String] = []
	var x := 1
	for id: int in made:
		var img: Image = made[id][0]
		var source: Dictionary = _chars[made[id][1]]
		var used := img.get_used_rect()
		# Yatayda harfin sol kenarı korunur, dikeyde kırpılır
		var rect := Rect2i(0, used.position.y, maxi(used.end.x, int(source["width"])), used.size.y)
		atlas.blit_rect(img, rect, Vector2i(x, height + 1))
		new_lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=%d xadvance=%d page=0 chnl=15" % [
			id, x, height + 1, rect.size.x, rect.size.y, rect.position.y, source["xadvance"]])
		x += rect.size.x + 1

	var out: Array[String] = []
	for line in lines:
		var l := line.strip_edges(false, true)
		if l.begins_with("common "):
			l = l.replace("scaleH=%d" % height, "scaleH=%d" % atlas.get_height())
		elif l.begins_with("page "):
			l = 'page id=0 file="%s"' % TARGET_PNG.get_file()
		elif l.begins_with("chars count="):
			l = "chars count=%d" % (_chars.size() + made.size())
		if not l.is_empty():
			out.append(l)
		if l.begins_with("char id=8364"):
			out.append_array(new_lines)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET_FNT.get_base_dir()))
	atlas.save_png(ProjectSettings.globalize_path(TARGET_PNG))
	var file := FileAccess.open(TARGET_FNT, FileAccess.WRITE)
	file.store_string("\n".join(out) + "\n")
	file.close()
