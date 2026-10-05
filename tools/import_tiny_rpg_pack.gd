extends SceneTree
## "Tiny RPG Character Asset Pack" (Zerie) sprite sheet'lerini oyunun isimlendirme
## kuralına göre tek tek karelere böler: <animasyon>_right_<NN>.png
## Paket yalnızca sağa bakan kareler içerir; sol yön oyun içinde aynalanır.
##
## Kareler 100x100'den, tüm animasyonlarda ortak olan dolu alana kırpılır. Kırpma yatayda
## merkeze göre simetriktir, böylece aynalanınca karakter yerinden kaymaz.
##
## Çalıştırma (proje klasöründe):
##   godot --headless --path . --script res://tools/import_tiny_rpg_pack.gd
## Paketler başka bir klasördeyse:
##   godot --headless --path . --script res://tools/import_tiny_rpg_pack.gd -- --pack-root="res://Klasör Adı"

const DEFAULT_PACK_ROOT := "res://ReadyAssetSets"
const SOURCE_FRAME := 100

# Kaynak klasör (ReadyAssetSets altında), dosya öneki, hedef klasör
const CHARACTERS := [
	["Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc/Characters(100x100 split)/Soldier/Soldier with shadows", "Soldier", "res://assets/characters/soldier"],
	["Tiny RPG Character Asset Pack 01 v2.0 -Free Soldier&Orc/Characters(100x100 split)/Orc/Orc with shadows", "Orc", "res://assets/enemies/orc"],
	["Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A/Characters(100x100 split)/Demon_A/Demon_A with shadows", "Demon_A", "res://assets/enemies/demon"],
	["Tiny RPG Character Asset Pack 02 -Free Demon_A&Blood Monster_A/Characters(100x100 split)/Blood Monster_A/Blood Monster_A with shadows", "Blood Monster_A", "res://assets/enemies/blood_monster"],
]

# Paketteki animasyon adı -> oyundaki animasyon adı
const ANIMATION_MAP := {
	"Idle": "idle",
	"Walk": "walk",
	"Attack01": "attack",
	"Attack02": "special",
	"Hurt": "hurt",
	"Death": "death",
}


var _pack_root := DEFAULT_PACK_ROOT


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pack-root="):
			_pack_root = arg.get_slice("=", 1).trim_prefix('"').trim_suffix('"')
	for entry: Array in CHARACTERS:
		_import_character(entry[0], entry[1], entry[2])
	quit()


func _import_character(source_dir: String, prefix: String, target_dir: String) -> void:
	# Önce tüm kareleri yükle
	var frames_by_anim := {}
	for pack_anim: String in ANIMATION_MAP:
		var path := ProjectSettings.globalize_path("%s/%s/%s_%s.png" % [_pack_root, source_dir, prefix, pack_anim])
		var sheet := Image.load_from_file(path)
		if sheet == null:
			push_error("Bulunamadı: " + path)
			return
		var frames: Array[Image] = []
		for i in sheet.get_width() / SOURCE_FRAME:
			frames.append(sheet.get_region(Rect2i(i * SOURCE_FRAME, 0, SOURCE_FRAME, SOURCE_FRAME)))
		frames_by_anim[ANIMATION_MAP[pack_anim]] = frames

	# Tüm karelerin dolu alanlarının birleşimini bul
	var used := Rect2i()
	for frames: Array in frames_by_anim.values():
		for frame: Image in frames:
			var rect := frame.get_used_rect()
			if rect.size == Vector2i.ZERO:
				continue
			used = rect if used.size == Vector2i.ZERO else used.merge(rect)

	# Yatayda merkeze göre simetrik, 1 piksel pay bırakarak kırp
	var center := SOURCE_FRAME / 2
	var half_width := maxi(center - used.position.x, used.end.x - center) + 1
	var crop := Rect2i(center - half_width, used.position.y - 1, half_width * 2, used.size.y + 2)
	crop = crop.intersection(Rect2i(0, 0, SOURCE_FRAME, SOURCE_FRAME))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target_dir))
	var count := 0
	for anim: String in frames_by_anim:
		var frames: Array = frames_by_anim[anim]
		for i in frames.size():
			var out := (frames[i] as Image).get_region(crop)
			out.save_png(ProjectSettings.globalize_path("%s/%s_right_%02d.png" % [target_dir, anim, i + 1]))
			count += 1
	print("%s: %d kare -> %s (kare boyutu %dx%d)" % [prefix, count, target_dir, crop.size.x, crop.size.y])
