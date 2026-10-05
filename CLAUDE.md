# RPG Hack and Slash — Proje Kuralları

Bu dosya her Claude oturumunun başında otomatik okunur. Kalıcı kurallar ve kararlar buraya yazılır.

## Proje
- Motor: Godot 4.7.2, dil: yalnızca GDScript (C# yok)
- Tür: Mobil hack and slash RPG
- Boyut: 2D (2D node'lar kullanılır: `CharacterBody2D`, `Area2D`, `Sprite2D`/`AnimatedSprite2D` vb.)
- Hedef platform: Android
- Renderer: Compatibility (OpenGL ES 3), eski Android cihazlarla uyum için. Forward+/Mobile'a özel özellikler kullanılmaz
- Ekran: stretch mode `canvas_items`, aspect `expand`

## Belgeler
- `docs/design.md`: oyun tasarımı (sistemler, mekanikler, içerik)
- `docs/decisions.md`: alınan teknik kararlar ve öğrenilen dersler. Yeni bir karar alındığında ya da bir hatadan ders çıkarıldığında buraya eklenir.

## Kod Kuralları (GDScript)
- Statik tipler kullanılır: `var hp: int = 100`, `func take_damage(amount: int) -> void:`
- İsimlendirme: dosya ve değişkenler `snake_case`, sınıflar `PascalCase`, sabitler `UPPER_SNAKE_CASE`
- Tekrar kullanılan script'lerde `class_name` tanımlanır
- Node referansları `@onready var` ile önbelleğe alınır; `_process`/`_physics_process` içinde `get_node` kullanılmaz
- Sistemler arası iletişimde doğrudan referans yerine sinyaller tercih edilir
- Oyun verileri (silah, düşman, yetenek istatistikleri) `Resource` (`.tres`) olarak tutulur, koda gömülmez
- Kod yorumları Türkçe yazılır; kod içindeki isimler (değişken, fonksiyon, sınıf) İngilizce kalır

## Klasör Yapısı
- `assets/` görseller (isimlendirme kuralı: `docs/assets.md`)
- `scenes/` sahneler: `main.tscn` (ana sahne), `maps/`, `player/`, `enemies/`, `objects/`, `world/`, `ui/`
- `scripts/` scriptler, sahnelerle aynı alt klasör düzeninde; `autoload/game_state.gd` = GameState
- `tools/` geliştirme araçları (oyuna dahil değil)
- `docs/` belgeler

## Mimari
- `Main` haritaları yükler; oyuncu tek bir instance olarak haritalar arasında taşınır
- Haritalar arası korunan durum (can, altın, iksir, ekipman) `GameState` autoload'unda tutulur
- Karakter görselleri `CharacterSprite` ile klasörden isimlendirme kuralına göre yüklenir; görsel eklemek kod değişikliği gerektirmez
- Dokunmatik kontroller ve klavye aynı Input Map aksiyonlarını kullanır: `move_left/right/up/down`, `attack`, `use_potion`
- Çarpışma katmanları: 1 = world, 2 = player, 3 = enemy
- Godot 4.7'de yerleşik `VirtualJoystick` sınıfı var, bu yüzden kendi joystick sınıfımızın adı `TouchJoystick`

## Araçlar ve Test
Godot: `E:\GodotSetup\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Duman testi (oyunu otomatik oynar, sonucu yazar): `godot --path . res://tools/smoke_test.tscn`
- Eksik yer tutucu görselleri üret: `godot --headless --path . --script res://tools/generate_placeholders.gd`
- Script değişikliğinden sonra hata kontrolü: `godot --headless --path . --import`
- Not: `--script` modunda autoload'lar yüklenmez. Oyun scriptlerini kullanan araçlar sahne olarak çalıştırılır.

## Mobil Kısıtlar
- Dokunmatik kontroller birincil giriş yöntemidir
- Performans her özellikte göz önünde tutulur (draw call, parçacık sayısı, fizik yükü)

## Çalışma Şekli
- Git: Claude, kullanıcı istemeden commit veya push yapmaz
- `project.godot` mümkünse Godot editöründen düzenlenir
- Claude bir sahneyi (`.tscn`) düzenlemeden önce, o sahnenin editörde kaydedilmemiş değişiklikle açık olmamasına dikkat edilir
- Kullanıcıyla iletişim Türkçe
