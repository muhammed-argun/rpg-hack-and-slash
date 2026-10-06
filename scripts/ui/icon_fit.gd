class_name IconFit
## İkonları yuvaya yerleştirme yardımcıları. Eşya çizimleri 32x32 tuvalin ortasında durmayabiliyor;
## boş kenarlar kesilir (görselin dolu kısmı), sonra yuvanın iç alanına tam piksele ortalanır.
## Dolu kısım alandan büyükse en-boy oranı korunarak küçültülür.

static var _trim_cache := {}


## Görselin dolu (saydam olmayan) kısmı. Sonuç önbelleğe alınır.
static func trimmed(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if _trim_cache.has(texture):
		return _trim_cache[texture]
	var result: Texture2D = texture
	var image := texture.get_image()
	if image:
		if image.is_compressed():
			image.decompress()
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size != image.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(used)
			result = atlas
	_trim_cache[texture] = result
	return result


## TextureRect'i area içinde ortalar (büyükse küçültür). TextureRect'in anchor'ları sol üst olmalı.
static func place(rect: TextureRect, texture: Texture2D, area: Rect2) -> void:
	var fitted := trimmed(texture)
	rect.texture = fitted
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	if fitted == null:
		return
	var texture_size := fitted.get_size()
	var scale := minf(1.0, minf(area.size.x / texture_size.x, area.size.y / texture_size.y))
	var draw_size := (texture_size * scale).round()
	rect.position = (area.position + (area.size - draw_size) / 2.0).floor()
	rect.size = draw_size
