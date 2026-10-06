# Kül Prensi (Prince of Ash) — Proje Kuralları

Bu dosya her Claude oturumunun başında otomatik okunur.
**Yeni bir oturumdaysan önce `docs/handoff.md` dosyasını oku.** Projenin şu anki durumu, sıradaki işler ve kullanıcının bekleyen istekleri orada.

## Proje özeti
- **Ne:** 2D, pixel art, Diablo/Hades karışımı hack and slash RPG. Karanlık fantastik hikâye, 9 boss + final (Kral → Malphas).
- **Motor:** Godot 4.7.2, dil yalnızca GDScript (C# yok)
- **Platform:** **PC (Windows) öncelikli, Steam Deck ve gamepad destekli.** Proje mobil (Android) olarak başladı, 2026-10-06'da PC'ye geçme kararı alındı. Mobil sürüm ileride port olarak eklenebilir; bu yüzden dokunmatik kod dosyaları silinmez, sadece kullanılmaz.
- **Görünüm:** Üstten 3/4 kamera (Stardew Valley gibi), 32×32 tile. Karakterler **yandan görünür**: sadece sağa bakan kareler var, sola bakış aynalamayla yapılıyor. Aşağı/yukarı görsel yok.
- **Çözünürlük:** Temel 480×270, `canvas_items` stretch, `expand` aspect, tam sayı ölçekleme (pixel art keskin kalsın diye). PC penceresi 1440×810 açılır.
- **Renderer:** Compatibility (OpenGL 3). Değiştirmek şart değil.
- **Dil:** Oyun Türkçe ve İngilizce (ayarlardan değişir). Kullanıcıyla iletişim **Türkçe**.

## Kullanıcı hakkında
- Oyun geliştirmede ve git'te yeni, öğrenmeye istekli. Adımları neden yaptığınla birlikte, sade bir dille açıkla.
- Illustrator ve Photoshop biliyor, oyun grafiği çizmedi. Hazır asset paketleri kullanıyoruz.
- **Commit ve push'u kendisi yapar.** İstemeden commit veya push yapma.
- Bazen "ben yokken çalış" diyerek uzun, otonom iş verir. O zaman ilerlemeyi belgelere yazarak çalış.

## Belgeler (docs/)
| Dosya | İçerik |
|---|---|
| `handoff.md` | **Buradan başla.** Şu anki durum, sıradaki işler, bekleyen sorular |
| `design.md` | Oyun tasarımı: kontroller, savaş, sınıflar, ekonomi ([Karar]/[Öneri]/[Açık] etiketli) |
| `roadmap.md` | Yol haritası ve sistemlerin durumu |
| `decisions.md` | Tarihli teknik kararlar ve **öğrenilen dersler** (en yeni en üstte). Yeni karar ya da ders çıkınca buraya ekle |
| `story.md` | Dünya, karakterler, hikâye akışı |
| `bosses.md` | 9 boss + Kral + Malphas dövüş tasarımları ve uygulama durumu |
| `assets.md` | Görsel isimlendirme kuralları ve hangi görselin nerede olduğu |
| `downloads.md` | Kullanıcının indireceği asset paketleri (bağlantı, lisans, klasör adı) |
| `credits.md` | Kullanılan dış asset'ler ve lisansları (CC BY kredileri dahil) |

## Klasör yapısı
- `assets/` görseller: `characters/`, `enemies/`, `items/`, `objects/`, `tiles/`, `ui/` (tema + yer tutucular), `fonts/quill_tr.*` (Türkçe harfli font)
- `scenes/` sahneler: `main_menu.tscn` (başlangıç sahnesi), `main.tscn` (oyun), `maps/`, `player/`, `enemies/`, `bosses/`, `objects/`, `world/`, `ui/`
- `scripts/` scriptler, sahnelerle aynı alt klasör düzeninde. Ek klasörler: `autoload/`, `systems/`, `effects/`, `items/`, `components/`
- `data/` oyun verileri (JSON): `quests.json`, `dialogue.json`, `recipes.json`, `audio.json`, `translations/ui.csv`, `translations/story.csv`
- `addons/pixel_bars`, `addons/pixel_ui_fantasy`: hazır UI eklentileri. **Dokunulmaz**; değişiklikler kopyalarda yapılır (ör. `assets/ui/game_theme.tres`)
- `tools/`: geliştirme araçları ve otomatik testler (oyuna dahil değil, dışa aktarmada hariç)
- `ReadyAssetSets/`: indirilen ham paketler (`.gdignore` ile Godot'dan gizli). Klasör adları kısa olmalı (Windows 260 karakter yol sınırı)

## Mimari
- **Autoload'lar:** `Settings` (dil, ses, titreşim; `user://settings.cfg`), `Quests` (görevler), `Dialogue` (NPC konuşmaları), `Audio` (efekt ve müzik), `GameState` (oyuncu durumu, kayıt/yükleme; `user://save.json`)
- `Main` (`scenes/main.tscn`) haritaları yükler. Oyuncu tek bir instance; harita değişince yeni haritaya taşınır (`Map.add_player`)
- Yeni oyun `scenes/maps/prologue.tscn` haritasında başlar; ölünce `town.tscn` haritasında doğulur
- **Haritalar:** Kök node'da `Map` scripti (`map_size`, `map_id`, `name_key`, `tint`, `music`). Alt yapı: `Ground` (TileMapLayer), `Entities` (y-sort; içinde `Walls` TileMapLayer, NPC'ler, düşman bölükleri), `Spawns` (Marker2D), `Exits` (MapExit). Navigasyon harita açılırken engellerden otomatik çıkarılır.
- **Veriye dayalı içerik:** Görevler, diyaloglar, tarifler, sesler JSON'da. Koşullar `GameConditions` ile değerlendirilir. Boss'lar `Boss` + `BossAttack` kaynakları + `BossArena`.
- **Metinler:** Oyuncuya görünen her metin bir çeviri anahtarıdır. Yeni metin eklerken `data/translations/*.csv` dosyasına TR ve EN birlikte eklenir. Arayüzde `text = "ANAHTAR"` yazmak yeter (Godot otomatik çevirir), koddan `tr("ANAHTAR")`.
- **Karakter görselleri:** `CharacterSprite`, klasörden `<animasyon>_<yön>_<NN>.png` kuralıyla yükler (ayrıntı: `docs/assets.md`). Görsel eklemek kod değişikliği gerektirmez.
- **Savaş:** Düşman saldırıları `Player.take_damage(miktar, kaynak, Combat.Kind)` ile verilir. `Combat.Kind`: NORMAL, HEAVY (turuncu uyarı), UNBLOCKABLE (kırmızı uyarı). Sonuç `Combat.Result` (HIT, BLOCKED, PARRIED, DODGED, GUARD_BROKEN).
- **Girdi:** Oyun kodu yalnızca Input Map aksiyonlarını okur (`move_*`, `attack`, `interact`, `skill`, `block`, `dodge`, `use_potion`, `use_mana_potion`, `toggle_inventory`, `pause`). Klavye ve gamepad aynı aksiyonları tetikler (dokunmatik kod mobil port için saklı, HUD'da yok). Metinde tuş adı gerekirse `Settings.format_action_keys("{interact}")` kullanılır, tuş adı metne yazılmaz.
- **Pencereler** (envanter, simya, dükkân, demirci, diyalog, duraklatma) açıkken `get_tree().paused = true`; HUD `PROCESS_MODE_ALWAYS`.
- Çarpışma katmanları: 1 = world, 2 = player, 3 = enemy
- Yer efektleri (uyarı alanı, şok dalgası) `Map.add_ground_effect()` ile zemin ve karakterler arasına çizilir.

## Kod kuralları (GDScript)
- Statik tipler: `var hp: int = 100`, `func take_damage(amount: int) -> void:`
- İsimler: dosya/değişken `snake_case`, sınıf `PascalCase`, sabit `UPPER_SNAKE_CASE`. Kod içi isimler İngilizce, **yorumlar Türkçe**.
- Tekrar kullanılan scriptlerde `class_name`. Node referansları `@onready var` ile.
- Sistemler arası iletişimde sinyaller tercih edilir.
- Arayüz fontu Quill bitmap font (10 px): font boyutu değiştirilmez. Font sadece Latin-1 + ı İ ş Ş ğ Ğ içerir; ★ ✔ • gibi karakterler görünmez.
- Oyun ekranının üstündeki yazılar `HudLabel` tema varyasyonunu kullanır.

## Araçlar ve test
Godot: `E:\GodotSetup\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (aşağıda `godot` diye geçer). Komutlar proje klasöründe çalıştırılır.
| Amaç | Komut |
|---|---|
| Script hata kontrolü / içe aktarma | `godot --headless --path . --import` (yeni addon/tema sonrası ilk çalıştırma doku hatası verebilir, ikinci temiz olmalı) |
| **Duman testi** (73 kontrol, oyunu otomatik oynar) | `godot --path . res://tools/smoke_test.tscn --quit-after 20000` |
| **Boss testi** (10 boss) | `godot --path . res://tools/boss_test.tscn --quit-after 50000 -- --all` |
| Tek boss'u elle dene | `godot --path . res://tools/boss_test.tscn -- --boss=fenris` |
| Haritaları üret (var olanın üzerine yazmaz) | `godot --headless --path . res://tools/build_demo_maps.tscn` |
| Boss sahnelerini üret (var olanın üzerine yazmaz) | `godot --headless --path . res://tools/build_bosses.tscn` |
| Yer tutucu görseller | `godot --headless --path . --script res://tools/generate_placeholders.gd` |
| Tiny RPG paketini karelere böl | `godot --headless --path . --script res://tools/import_tiny_rpg_pack.gd` |
| Türkçe fontu yeniden üret | `godot --headless --path . --script res://tools/make_turkish_font.gd` |

- Testler ekran görüntülerini `%APPDATA%\Godot\app_userdata\RPGHackAndSlash\` klasörüne kaydeder; Read aracıyla bakılabilir. Testler oyuncunun kaydına dokunmaz, kendi kayıt dosyalarını kullanır.
- **Bir özelliği değiştirdikten sonra duman testini çalıştır. Yeni özellik ekleyince teste kontrol ekle.**
- `--script` modunda autoload'lar derlenmez; oyun scriptlerini kullanan araçlar sahne olarak (`.tscn`) çalıştırılır.

## Çalışma şekli
- Commit/push yapma (kullanıcı yapar).
- Godot editörü açıkken `project.godot` ve sahneleri düzenleme; gerekiyorsa kullanıcıdan editörü kapatmasını iste.
- PowerShell'de `.tscn` dosyalarına regex ile toplu değişiklik yaparken dikkat: aynı satır birçok node'da olabilir (bkz. decisions.md dersleri).
- Silme işlemlerinde `Remove-Item -LiteralPath "<tam yol>"` kullan (joker karakterli silme engelleniyor).
