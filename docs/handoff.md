# Devir Notu (Handoff)

Son güncelleme: 2026-10-06. Bu dosya yeni bir Claude oturumunun **ilk okuyacağı** dosyadır. Projenin şu anki durumunu ve sıradaki işleri anlatır. İş bitince bu dosyayı güncel tut.

## 1. Kısa geçmiş
1. Proje **mobil (Android)** hack and slash olarak başladı. Dokunmatik joystick ve ekran butonlarıyla oynanabilir bir dikey dilim yapıldı.
2. 2026-10-06 gecesi, kullanıcı yokken büyük bir otonom çalışmayla çekirdek sistemlerin hepsi eklendi (aşağıdaki tablo). Kullanıcı bunları push'ladı.
3. Aynı gün kullanıcı **PC'ye geçme** kararı aldı: Steam Deck destekli, gamepad ile de oynanabilir. Mobil port ileride yapılabilir. **Bu geçiş henüz kodlanmadı**, 3. bölümdeki iş listesi bunun için.

## 2. Şu an oyunda çalışanlar
Hepsi otomatik testlerle doğrulandı (duman testi: 70 kontrol; boss testi: 10 boss).

| Sistem | Durum | Nerede |
|---|---|---|
| Ana menü, ayarlar (dil, ses, titreşim), duraklatma, onay pencereleri | ✅ | `scripts/ui/main_menu.gd`, `settings_window.gd`, `pause_menu.gd` |
| TR/EN dil desteği, Türkçe harfli pixel font | ✅ | `data/translations/*.csv`, `assets/fonts/quill_tr.*` |
| Kayıt/yükleme (otomatik) | ✅ | `GameState.save_game/load_game` |
| Prolog (gece yolu, anlatı kartı, ork baskını, öğretici ipuçları) | ✅ | `scenes/maps/prologue.tscn`, `story_card.gd`, `tutorial_hints.gd` |
| Şehir (6 NPC), vahşi bölge, Kurt İni (Fenris arenası) | ✅ (yer tutucu grafik) | `scenes/maps/` (`tools/build_demo_maps.gd` ile üretildi) |
| Diyalog ve görev sistemi, 3 ana + 6 yan görev, görev günlüğü | ✅ | `data/dialogue.json`, `data/quests.json` |
| Savaş: saldırı, alan yeteneği (Yer Sarsıntısı), blok, parry, yuvarlanma, stamina, denge/sersemleme, saldırı türleri | ✅ | `scripts/player/player.gd`, `scripts/enemies/enemy.gd`, `scripts/systems/combat.gd` |
| Düşmanların özel saldırıları ve uyarı alanları, düşman yol bulma | ✅ | `enemy.gd`, `scripts/effects/` |
| Loot (sandık), iksirler, ot toplama, simya, dükkân, demirci, seviye/deneyim | ✅ | `game_state.gd`, `scripts/ui/*_window.gd` |
| Boss altyapısı + 9 boss + Kral → Malphas + oyun sonu | ✅ (Fenris dışındakiler haritasız) | `scripts/bosses/`, `scenes/bosses/` |
| Ses altyapısı (olay sesleri, harita/boss müziği) | 🔨 Dosyalar yok | `scripts/autoload/audio.gd`, `data/audio.json` |
| HUD: can/mana/stamina, seviye/XP, görev takibi, boss barı, mesajlar | ✅ | `scenes/ui/hud.tscn`, `scripts/ui/hud.gd` |
| Dokunmatik kontroller (joystick, ekran butonları) | ✅ ama **PC'de kaldırılacak** | `touch_joystick.gd`, `action_button.gd` |

### Şu anki kontroller (değişecek, bkz. 3. bölüm)
WASD hareket · Space/J saldırı ve konuşma · L blok/parry · Shift yuvarlanma · K yetenek · Q can iksiri · E mana iksiri · I/Tab envanter · Esc/P duraklat.
Saldırı, karakterin son hareket yönüne (`aim_direction`) gidiyor; görsel yalnızca sağa/sola bakıyor.

## 3. SIRADAKİ İŞ: PC'ye geçiş (kullanıcının istekleri)
Kullanıcı bunları açıkça istedi. Sırayla yap; her adımdan sonra duman testini çalıştır, gerekirse testi güncelle.

### 3.1 Ekrandaki dokunmatik kontrolleri kaldır
- HUD'dan joystick ve aksiyon butonlarını (saldırı, yetenek, blok, yuvarlanma, iksirler) **kaldır**.
- Dosyaları silme (`touch_joystick.gd`, `action_button.gd`, `action_button.tscn`). İleride mobil port için lazım olabilir. HUD'daki çanta/görev/duraklat butonları da ActionButton kullanıyor; PC'de bunlar ya fareyle tıklanan normal butonlara dönüşmeli ya da kalkmalı (kısayolları var).
- `project.godot`: `input_devices/pointing/emulate_touch_from_mouse=true` ayarı kapatılmalı (fare artık nişan için kullanılacak).
- Saldırı butonunun üstündeki "Konuş" balonu (`InteractPrompt`) yerine NPC'nin üstünde tuş ipucu gösterilebilir (ör. "[F] Konuş"). Etkileşim tuşu ayrı bir aksiyon olmalı (`interact`, varsayılan **F**), çünkü sol tık artık saldırı.
- Öğretici ipuçlarının metinleri (`HINT_*`, `ui.csv`) dokunmatiğe göre yazıldı ("joystick ile yürü"). PC'ye göre yeniden yazılmalı.

### 3.2 Ayarlara tuş atama ekranı
- Ayarlar penceresine (`settings_window.gd`) "Kontroller" bölümü: her aksiyon için klavye/fare ve gamepad tuşu gösterilsin, tıklayıp yeni tuşa basınca değişsin, "Varsayılana dön" butonu olsun.
- Atamalar `user://settings.cfg` dosyasına kaydedilip açılışta `InputMap`'e uygulanmalı (`Settings` autoload).
- Aynı tuş iki aksiyona atanırsa uyar ya da eskisini boşalt.
- Gamepad ile menülerde gezinebilmek için Control'lerde odak (focus) düzgün çalışmalı (Steam Deck).

### 3.3 Hades tarzı savaş: WASD ile yürü, imleç yönüne saldır
- Hareket WASD ile (değişmiyor).
- **Saldırı imlecin (fare) gösterdiği yöne:** saldırı alanı `player → imleç` yönünde konumlanır. Karakter görseli imlecin bulunduğu yana (sağ/sol) döner ve saldırı animasyonu oynar.
- Mevcut kod: `Player.aim_direction` saldırı yönü, `Player.facing` ("right"/"left") görsel yön. Saldırıda `aim_direction` imleçten hesaplanmalı (`get_global_mouse_position()`).
- **Gamepad/Steam Deck:** Sağ analog çubuk nişan yönünü verir. Çubuk bırakılınca son nişan yönü ya da hareket yönü kullanılır. Fare hareket ederse fareye, sağ çubuk kullanılırsa çubuğa geçilir.
- Yetenek ve yuvarlanma da nişan yönünü kullanabilir. Yuvarlanma şimdilik hareket yönüne gidiyor; Hades'te de öyle, bu doğru.
- İleride menzilli silah, ok ve büyüler de bu nişanı kullanacak; o yüzden nişan yönü tek bir yerden okunmalı (ör. `Player.get_aim_direction()`).
- **Özel imleç:** `addons/pixel_ui_fantasy/cursor.png` (ve `cursor_2x/3x/4x.png`). İmleç ekran ölçeğiyle büyümediği için pencere boyutuna uygun kopya seçilir (1440×810 için 3x). Hotspot sol üst piksel. Ayar: `display/mouse_cursor/custom_image` ya da `Input.set_custom_mouse_cursor()`.

### 3.4 Yetenekler E, R, T; iksirler 1, 2
- 3 aktif yetenek yuvası: varsayılan **E, R, T** (Dota gibi), ayarlardan değiştirilebilir. Şu an tek yetenek var (Yer Sarsıntısı) → E yuvasına. Diğer yuvalar boş görünür.
- HUD'da yetenek çubuğu: 3 yuva (ikon + tuş harfi + bekleme süresi karartması + mana bedeli). Pixel UI Fantasy'deki `SkillSlot` varyasyonu ve `cooldown.png` kullanılabilir.
- **Hızlı kullanım yuvaları 1 ve 2:** Envanterdeki (ya da bir "kuşak"taki) sıraya göre çalışır. 1. yuvada can iksiri varsa onu, mana iksiri varsa onu kullanır. İleride başka tüketilebilir eşyalar da buraya konabilir. Varsayılan: 1 = can iksiri, 2 = mana iksiri.
- Bu yüzden şu anki `use_potion` (Q) ve `use_mana_potion` (E) aksiyonları `quick_slot_1` (1) ve `quick_slot_2` (2) olarak değişmeli. E artık yetenek tuşu.

### 3.5 – 3.6 Envanter + Karakter penceresi (birleşik)
Kullanıcı ayrı bir karakter ekranı yerine **tek bir birleşik pencere** istiyor. **I** ve **C** aynı pencereyi açar.
- **Sol taraf:** 6×6 = **36 yuvalı çanta**.
- **Sağ taraf: karakter paneli**
  - **Ekipman yuvaları:** kask, zırh, eldiven, ayakkabı, pelerin (gerekirse yüzük, kolye, kemer).
  - **İki silah seti:** Her sette ana el + ikinci el. Çift elli silah takılınca ikinci el yuvası kilitlenir. 2. set genelde menzilli silah için.
  - **Sadak (quiver):** menzilli silah için 3 tür mühimmat yuvası.
  - **Özellikler (attributes):** STR, AGI, INT, VIT (ya da benzeri). **Şimdilik hepsi 10**, henüz bir etkileri yok.
  - **Üstte:** seviye, azami can ve mana, XP barı. **Fare XP barının üstüne gelince "350/1000" gibi** sayısal değer yazar.
- **Seviye atlayınca özellik puanı:** Herhangi bir özelliğe puan verilebilir. Kaç seviyede bir puan verileceği sonra ayarlanacak (ör. her 3 seviyede bir). Arayüzde "+" butonu.
- **XP formülü değişiyor:** Bir sonraki seviye için gereken XP, bir önceki seviyede gerekenin **1,6 katı**, **yukarıya, 100'ün katına yuvarlanmış.** Bu, şu anki `GameState.xp_to_next()` fonksiyonunun (`40 * level^1.5`) yerini alır.
  - Örnek (1. seviye 100 kabul edilirse): 100 → 160 yuvarlanır 200 → 320 yuvarlanır 400 → 640 yuvarlanır 700 → 1120 yuvarlanır 1200 ...
  - Önceki seviyenin **yuvarlanmış** değeri kullanılır. **Başlangıç değerini (1→2 için 100 mü?) kullanıcıya sor.**
- **İleride:** Yetenek ağacı. Açılan yeteneklerden 3'ü aktif yuvalara (E/R/T) konur.
- Mevcut envanter penceresi (`inventory_window.gd`): 12 yuva, "Çanta / Ekipman / Görevler" sekmeleri. Görevler sekmesi korunabilir ya da ayrı bir günlük olabilir; **kullanıcıya sor.**
- Silah ve zırh eşyaları şu an düşmüyor (`Chest.LOOT_TYPES` sadece değerli eşya). Ekipman yuvaları eklenince eşya sistemi (`ItemData`) yuva türleriyle genişletilmeli.

### 3.7 PC için diğer ayarlar
- Ayarlar: tam ekran / pencere, çözünürlük (tam sayı ölçek), V-Sync.
- Dışa aktarma: Windows ve Linux (Steam Deck) ayarları `export_presets.cfg` dosyasına eklenmeli. Şu an sadece Android ayarı var (`data/*.json` include filtresiyle; aynı filtre PC ayarlarına da konmalı).
- `docs/design.md` ve `docs/roadmap.md` dosyalarındaki mobil kısımlar PC'ye göre güncellendi; kod değiştikçe onları da güncel tut.

## 4. Bekleyen diğer işler
- **Asset paketleri:** `docs/downloads.md`. Kullanıcının indirip indirmediği bilinmiyor; **sor.** Zorunlu: Zerie Tiny RPG 01 + 02 tam sürümleri (toplam 5 dolar). Gelince yapılacaklar:
  - `tools/import_tiny_rpg_pack.gd` aracını yeni karakterler için genişlet.
  - Tileset'lerle şehir ve Kül Ormanı'nı yeniden kur.
  - NPC ve boss görsel klasörlerini değiştir.
  - Sesleri `data/audio.json` adlarına göre `assets/audio/` altına kopyala.
- **Kullanıcının kararını bekleyen konular:** İsimler (oyun adı "Kül Prensi", Eldmar, Varneth, Aldric, Malphas, NPC'ler), Fenris'in zorluğu, boss sırası (serbest mi, sıralı mı), "kahramanın kayıp kardeşi" dram fikri (`story.md`), sınıf görselleri (Knight = Paladin, Wizard, Swordsman = Rogue).
- **Kalan 8 boss'un haritaları** (tileset bekliyor). Boss'lar `tools/boss_test.tscn` ile denenebiliyor.
- **Yapılmamış özel boss davranışları:** Bjorn'un karşı saldırı duruşu, Velzara'nın kopyaları ve kontrolleri ters çevirmesi, Surtr'un daralan arenası, Azgoroth'un kalkanı, Malphas'ın uçma evresi.
- **Kullanıcının önerdiği deneme:** Claude'un kodla pixel art çizip (ör. kristal parçası ikonu, Kül Kalkanı efekti) oyuna koyması. Claude bunu yapabilir; zayıf yanı animasyonlu karakterler, iyi olduğu yerler ikon/efekt/arayüz/paket düzenleme. Kullanıcı henüz "yap" demedi.

## 5. Dikkat edilecek tuzaklar
Ayrıntılar ve diğerleri `docs/decisions.md` dosyasındaki "Ders" maddelerinde.
- Harita değişince fizik motoru oyuncuyu bir kare eski konumunda görüyor. `Player.prepare_for_map_change()` bu yüzden var; kaldırma.
- `is_action_just_pressed` sadece basıldığı karede doğru. Testlerde tuş basışını karenin başında yap (`smoke_test.gd` içindeki `_tap_action`).
- Ölen bir node'a bağlı gecikmeli çağrılar çalışmaz; boss geçişleri statik fonksiyonla yapılıyor.
- Godot 4.7'de yerleşik `VirtualJoystick` sınıfı var; aynı adla `class_name` tanımlanamaz.
- Font yalnızca Latin-1 + Türkçe harfleri içeriyor.
