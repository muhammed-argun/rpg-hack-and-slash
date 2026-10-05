class_name CharacterSprite
extends AnimatedSprite2D
## Karakter animasyonlarını isimlendirme kuralına göre klasörden otomatik yükler.
##
## Dosya adı kuralı: <animasyon>_<yön>_<kare numarası>.png
##   Örnek: walk_right_01.png, walk_right_02.png, attack_down_01.png
## Animasyonlar: idle, walk, attack, hurt, death
## Yönler: down, up, right, left
## - Kareler 01'den başlar ve ilk eksik numarada durur; istenen sayıda kare eklenebilir.
## - Sol yön (left) çizilmemişse sağ yön (right) aynalanarak kullanılır.
## - Bir yön hiç yoksa aşağı (down) yön kullanılır.

const ANIMATIONS := ["idle", "walk", "attack", "hurt", "death"]
const DIRECTIONS := ["down", "up", "right", "left"]
const LOOPING_ANIMATIONS := ["idle", "walk"]
const DEFAULT_FPS := {"idle": 4.0, "walk": 8.0, "attack": 12.0, "hurt": 10.0, "death": 8.0}
const MAX_FRAMES := 99

## Görsellerin bulunduğu klasör (ör. res://assets/characters/warrior)
@export_dir var sprite_folder: String = ""
## Animasyon hızlarını değiştirmek için, ör. {"walk": 10.0}
@export var fps_overrides: Dictionary = {}

# Aynı klasörü kullanan karakterler (ör. tüm goblinler) aynı SpriteFrames'i paylaşır
static var _cache: Dictionary = {}


func _ready() -> void:
	sprite_frames = _get_frames()
	centered = true
	_align_feet()


## Animasyonu karakterin baktığı yöne göre oynatır.
## restart true ise animasyon zaten oynuyorsa bile baştan başlar.
func play_directional(anim: String, facing: String, restart: bool = false) -> void:
	var resolved := _resolve(anim, facing)
	if resolved.is_empty():
		return
	flip_h = facing == "left" and resolved.ends_with("_right")
	if restart or animation != resolved:
		play(resolved)
		set_frame_and_progress(0, 0.0)
	elif not is_playing():
		play(resolved)


## Verilen animasyonun bu karakter için var olup olmadığı.
func has_directional(anim: String) -> bool:
	return not _resolve(anim, "down").is_empty()


func get_current_frame_count() -> int:
	return sprite_frames.get_frame_count(animation)


func _resolve(anim: String, facing: String) -> String:
	if sprite_frames == null:
		return ""
	var candidates := ["%s_%s" % [anim, facing]]
	if facing == "left":
		candidates.append("%s_right" % anim)
	candidates.append("%s_down" % anim)
	for candidate: String in candidates:
		if sprite_frames.has_animation(candidate):
			return candidate
	return ""


func _get_frames() -> SpriteFrames:
	if _cache.has(sprite_folder):
		return _cache[sprite_folder]
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: String in ANIMATIONS:
		for dir: String in DIRECTIONS:
			var textures := _load_sequence(anim, dir)
			if textures.is_empty():
				continue
			var anim_name := "%s_%s" % [anim, dir]
			frames.add_animation(anim_name)
			frames.set_animation_loop(anim_name, anim in LOOPING_ANIMATIONS)
			frames.set_animation_speed(anim_name, fps_overrides.get(anim, DEFAULT_FPS[anim]))
			for texture in textures:
				frames.add_frame(anim_name, texture)
	if frames.get_animation_names().is_empty():
		push_warning("CharacterSprite: '%s' klasöründe animasyon bulunamadı." % sprite_folder)
	_cache[sprite_folder] = frames
	return frames


func _load_sequence(anim: String, dir: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for i in range(1, MAX_FRAMES + 1):
		var path := "%s/%s_%s_%02d.png" % [sprite_folder, anim, dir, i]
		if not ResourceLoader.exists(path):
			break
		result.append(load(path))
	return result


# Görselin alt kenarını node'un konumuna hizalar; böylece konum = karakterin ayakları olur.
# Bu, 3/4 görünümde derinlik sıralamasının (y-sort) doğru çalışması için gerekli.
func _align_feet() -> void:
	for anim_name in sprite_frames.get_animation_names():
		var texture := sprite_frames.get_frame_texture(anim_name, 0)
		if texture:
			offset = Vector2(0, -floorf(texture.get_height() / 2.0))
			return
