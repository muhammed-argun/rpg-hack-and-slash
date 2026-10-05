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
- `docs/` belgeler; dış kaynaklı asset'ler `docs/credits.md` dosyasına işlenir
- `ReadyAssetSets/` indirilen ham asset paketleri (`.gdignore` ile Godot'dan gizli)
- `addons/pixel_bars`, `addons/pixel_ui_fantasy` hazır UI eklentileri (dokunulmaz; değişiklikler `assets/ui/` altındaki kopyalarda yapılır)
- `assets/ui/game_theme.tres` oyunun genel teması (parşömen teması + Türkçe font + `HudLabel` varyasyonu); `assets/fonts/quill_tr.*` Türkçe harfli font

## Mimari
- `Main` haritaları yükler; oyuncu tek bir instance olarak haritalar arasında taşınır
- Haritalar arası korunan durum (can, altın, iksir, ekipman) `GameState` autoload'unda tutulur
- Karakter görselleri `CharacterSprite` ile klasörden isimlendirme kuralına göre yüklenir; görsel eklemek kod değişikliği gerektirmez
- Dokunmatik kontroller ve klavye aynı Input Map aksiyonlarını kullanır: `move_left/right/up/down`, `attack`, `skill`, `use_potion`, `use_mana_potion`, `toggle_inventory`
- Dokunmatik butonlar `ActionButton` (TouchScreenButton tabanlı, çoklu dokunma için); normal `Button` yalnızca ilk parmağı algıladığı için oyun içi kontrollerde kullanılmaz
- Envanter açıkken `get_tree().paused = true`; HUD `PROCESS_MODE_ALWAYS`
- Çarpışma katmanları: 1 = world, 2 = player, 3 = enemy
- Yer efektleri (uyarı alanları, şok dalgaları) `Map.add_ground_effect()` ile zeminle karakterler arasına çizilir
- Arayüz yazılarında font boyutu değiştirilmez (Quill 10 px bitmap font); oyun ekranı üstündeki yazılar `HudLabel` varyasyonunu kullanır
- Godot 4.7'de yerleşik `VirtualJoystick` sınıfı var, bu yüzden kendi joystick sınıfımızın adı `TouchJoystick`

## Araçlar ve Test
Godot: `E:\GodotSetup\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`
- Duman testi (oyunu otomatik oynar, sonucu yazar): `godot --path . res://tools/smoke_test.tscn`
- Eksik yer tutucu görselleri üret: `godot --headless --path . --script res://tools/generate_placeholders.gd`
- Tiny RPG paketini karelere böl: `godot --headless --path . --script res://tools/import_tiny_rpg_pack.gd`  (paket klasörü farklıysa sonuna `-- --pack-root="res://Klasör"`)
- Türkçe fontu yeniden üret: `godot --headless --path . --script res://tools/make_turkish_font.gd`
- Duman testini takılmaya karşı süre sınırıyla çalıştır: sonuna `--quit-after 5000` ekle
- Not: Yeni addon/tema eklendikten sonraki ilk `--import` doku yükleme hataları verebilir; ikinci çalıştırma temiz olmalı
- Demo haritalarını üret (var olanların üzerine yazmaz): `godot --headless --path . res://tools/build_demo_maps.tscn`
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
