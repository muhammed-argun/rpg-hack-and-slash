# Devir Notu (Handoff)

Son güncelleme: 2026-10-07. Bu dosya yeni bir Claude oturumunun **ilk okuyacağı** dosyadır. İşleri ajanlara dağıtma kuralları: `docs/agents.md`. Projenin şu anki durumunu ve sıradaki işleri anlatır. İş bitince bu dosyayı güncel tut.

## 1. Kısa geçmiş
1. Proje **mobil (Android)** hack and slash olarak başladı. Dokunmatik joystick ve ekran butonlarıyla oynanabilir bir dikey dilim yapıldı.
2. 2026-10-06 gecesi, kullanıcı yokken büyük bir otonom çalışmayla çekirdek sistemlerin hepsi eklendi (aşağıdaki tablo). Kullanıcı bunları push'ladı.
3. Aynı gün kullanıcı **PC'ye geçme** kararı aldı: Steam Deck destekli, gamepad ile de oynanabilir. Mobil port ileride yapılabilir. İş listesi 3. bölümde. **3.1–3.7 hepsi bitti** (2026-10-06). Kullanıcının onayı beklenen varsayılanlar 4. bölümün başında.

## 2. Şu an oyunda çalışanlar
Hepsi otomatik testlerle doğrulandı (duman testi: 241 kontrol; oyuncu sıradan vuruşta kilitlenmez, hurt animasyonu dash/saldırı ile kesilir, yalnızca `stun()` ve savunma kırılması kilitler; boss testi: 10 boss + Malphas + Fenris 3 faz testi).

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
| Dokunmatik kontroller (joystick, ekran butonları) | ⏸ HUD'dan kaldırıldı, kod mobil port için saklı | `touch_joystick.gd`, `action_button.gd` |

### Şu anki kontroller (ayarlardan değiştirilebilir)
Klavye/fare: WASD hareket · Sol tık saldırı · Sağ tık blok/parry · Space yuvarlanma · F konuş · E/R/T yetenekler · 1/2 hızlı kullanım (can/mana iksiri) · Q silah seti · I/C karakter ve çanta · J görevler · Esc duraklat/geri.
Gamepad (Xbox / Steam Deck): Sol çubuk hareket · Sağ çubuk nişan · X saldırı · LT blok · A yuvarlanma · Y konuş · RB/RT/B yetenekler · Yön sol/sağ hızlı kullanım · LB silah seti · Back envanter · Yön yukarı karakter · Yön aşağı görevler · Start duraklat · B geri.
Saldırı, karakterin son hareket yönüne (`aim_direction`) gidiyor; görsel yalnızca sağa/sola bakıyor.

## 3. SIRADAKİ İŞ: PC'ye geçiş (kullanıcının istekleri)
Kullanıcı bunları açıkça istedi. Sırayla yap; her adımdan sonra duman testini çalıştır, gerekirse testi güncelle.

### 3.1 Ekrandaki dokunmatik kontrolleri kaldır ✅ (2026-10-06)
Yapılanlar (ayrıntı: `decisions.md`): joystick ve aksiyon butonları HUD'dan çıktı; duraklat/çanta/görev normal `Button`; `emulate_touch_from_mouse=false`; yeni `interact` aksiyonu (F) ve NPC üstünde `[F] Konuş`; `HINT_*` ve `UI_TAP_*` metinleri PC'ye göre, tuş adları `Settings.format_action_keys()` ile atamadan okunuyor. Duman testine 3 kontrol eklendi.
(Geçici eksik olan iksir sayısı ve bekleme süresi 3.4'te `Hotbar` ile geri geldi.)

Aşağıdaki madde listesi orijinal istek (kayıt için duruyor):
- HUD'dan joystick ve aksiyon butonlarını (saldırı, yetenek, blok, yuvarlanma, iksirler) **kaldır**.
- Dosyaları silme (`touch_joystick.gd`, `action_button.gd`, `action_button.tscn`). İleride mobil port için lazım olabilir. HUD'daki çanta/görev/duraklat butonları da ActionButton kullanıyor; PC'de bunlar ya fareyle tıklanan normal butonlara dönüşmeli ya da kalkmalı (kısayolları var).
- `project.godot`: `input_devices/pointing/emulate_touch_from_mouse=true` ayarı kapatılmalı (fare artık nişan için kullanılacak).
- Saldırı butonunun üstündeki "Konuş" balonu (`InteractPrompt`) yerine NPC'nin üstünde tuş ipucu gösterilebilir (ör. "[F] Konuş"). Etkileşim tuşu ayrı bir aksiyon olmalı (`interact`, varsayılan **F**), çünkü sol tık artık saldırı.
- Öğretici ipuçlarının metinleri (`HINT_*`, `ui.csv`) dokunmatiğe göre yazıldı ("joystick ile yürü"). PC'ye göre yeniden yazılmalı.

### 3.2 Ayarlara tuş atama ekranı ✅ (2026-10-06)
Yapılanlar: yeni autoload `Controls` (`scripts/autoload/controls.gd`). Varsayılan tuşlar (klavye/fare + gamepad) `Controls.DEFAULTS`'ta; **project.godot'ta artık aksiyon tanımı yok**. Ayarlar > Kontroller penceresi (`controls_window.gd`): tıkla, yeni tuşa bas; çakışan tuş eski aksiyondan kalkar ve yazılır; Esc ya da 5 sn iptal; "Varsayılana Dön". Kayıt `settings.cfg` [controls]. Son kullanılan cihaz (`Controls.using_gamepad`) izleniyor; ipuçları gamepad'de gamepad tuşunu gösteriyor. Gamepad ile menülerde odak: `menus` grubundaki görünür son pencerenin ilk butonu otomatik seçilir. Esc / gamepad B: açık pencereyi kapatır, alt menüden üst menüye döner.
Aksiyonlar son haline getirildi (3.4 ile uyumlu): `skill_1/2/3` (E/R/T), `quick_slot_1/2` (1/2), `toggle_character` (C), saldırı sol tık, blok sağ tık, yuvarlanma Space. Şimdilik `quick_slot_1` = can iksiri, `quick_slot_2` = mana iksiri; `skill_2/3` boş.
- Ayarlar penceresine (`settings_window.gd`) "Kontroller" bölümü: her aksiyon için klavye/fare ve gamepad tuşu gösterilsin, tıklayıp yeni tuşa basınca değişsin, "Varsayılana dön" butonu olsun.
- Atamalar `user://settings.cfg` dosyasına kaydedilip açılışta `InputMap`'e uygulanmalı (`Settings` autoload).
- Aynı tuş iki aksiyona atanırsa uyar ya da eskisini boşalt.
- Gamepad ile menülerde gezinebilmek için Control'lerde odak (focus) düzgün çalışmalı (Steam Deck).

### 3.3 Hades tarzı savaş: WASD ile yürü, imleç yönüne saldır ✅ (2026-10-06)
Yapılanlar: `Player.get_aim_direction()` tek nişan kaynağı (fare: karakterden imlece; gamepad: sağ çubuk, bırakılınca hareket yönü, o da yoksa son nişan). Saldırı ve blok nişan tarafına döner; yuvarlanma `move_direction`'a gider. Fare bir HUD butonunun üstündeyken sol tık saldırmaz. Gamepad'de ayağın çevresinde küçük nişan oku (`AimMarker`), fare imleci gizlenir; fare oynayınca geri gelir. Özel imleç `Controls._update_cursor()`: pencere ölçeğine göre 1x-4x. Gamepad'e özel ipucu metinleri `HINT_*_PAD`.
- Hareket WASD ile (değişmiyor).
- **Saldırı imlecin (fare) gösterdiği yöne:** saldırı alanı `player → imleç` yönünde konumlanır. Karakter görseli imlecin bulunduğu yana (sağ/sol) döner ve saldırı animasyonu oynar.
- Mevcut kod: `Player.aim_direction` saldırı yönü, `Player.facing` ("right"/"left") görsel yön. Saldırıda `aim_direction` imleçten hesaplanmalı (`get_global_mouse_position()`).
- **Gamepad/Steam Deck:** Sağ analog çubuk nişan yönünü verir. Çubuk bırakılınca son nişan yönü ya da hareket yönü kullanılır. Fare hareket ederse fareye, sağ çubuk kullanılırsa çubuğa geçilir.
- Yetenek ve yuvarlanma da nişan yönünü kullanabilir. Yuvarlanma şimdilik hareket yönüne gidiyor; Hades'te de öyle, bu doğru.
- İleride menzilli silah, ok ve büyüler de bu nişanı kullanacak; o yüzden nişan yönü tek bir yerden okunmalı (ör. `Player.get_aim_direction()`).
- **Özel imleç:** `addons/pixel_ui_fantasy/cursor.png` (ve `cursor_2x/3x/4x.png`). İmleç ekran ölçeğiyle büyümediği için pencere boyutuna uygun kopya seçilir (1440×810 için 3x). Hotspot sol üst piksel. Ayar: `display/mouse_cursor/custom_image` ya da `Input.set_custom_mouse_cursor()`.

### 3.4 Yetenekler E, R, T; iksirler 1, 2 ✅ (2026-10-06)
Yapılanlar: `GameState.skill_slots` (varsayılan `["ground_slam", "", ""]`) ve `GameState.quick_slots` (`["health_potion", "mana_potion"]`), kayda yazılıyor. Yetenek tanımları `GameState.SKILLS` (ad, ikon); davranış, mana bedeli ve bekleme süresi `Player`'da (`_try_use_skill`, `get_skill_mana_cost`, `get_skill_cooldown_duration`). Her yeteneğin kendi bekleme süresi var. HUD'da alt ortada `Hotbar`: 3 yetenek + 2 hızlı kullanım yuvası, üstünde tuş adı, mana bedeli/iksir sayısı, bekleme karartması. Yuvaya eşya koyma: `GameState.set_quick_slot()`; aynı eşya diğer yuvadaysa yer değiştirirler. Envanterden yuva atama 3.5 penceresinde.
- 3 aktif yetenek yuvası: varsayılan **E, R, T** (Dota gibi), ayarlardan değiştirilebilir. Şu an tek yetenek var (Yer Sarsıntısı) → E yuvasına. Diğer yuvalar boş görünür.
- HUD'da yetenek çubuğu: 3 yuva (ikon + tuş harfi + bekleme süresi karartması + mana bedeli). Pixel UI Fantasy'deki `SkillSlot` varyasyonu ve `cooldown.png` kullanılabilir.
- **Hızlı kullanım yuvaları 1 ve 2:** Envanterdeki (ya da bir "kuşak"taki) sıraya göre çalışır. 1. yuvada can iksiri varsa onu, mana iksiri varsa onu kullanır. İleride başka tüketilebilir eşyalar da buraya konabilir. Varsayılan: 1 = can iksiri, 2 = mana iksiri.
- Bu yüzden şu anki `use_potion` (Q) ve `use_mana_potion` (E) aksiyonları `quick_slot_1` (1) ve `quick_slot_2` (2) olarak değişmeli. E artık yetenek tuşu.

### 3.5 – 3.6 Envanter + Karakter penceresi (birleşik) ✅ (2026-10-06)
Yapılanlar: `InventoryWindow` baştan yazıldı (kodla kuruluyor, I ve C açar). Solda 36 yuvalı çanta, eşya bilgisi, Kullan/Kuşan/Çıkar ve "1"/"2" hızlı kullanım yuvasına koyma. Sağda seviye, can/mana, XP barı (üstüne gelince "350/1000"), 8 ekipman yuvası (kask, zırh, eldiven, ayakkabı | kolye, pelerin, yüzük, kemer), iki silah seti (I/II; çift elli silahta ikinci el kilitli; Q / gamepad LB ile set değişir), sadak (3 yuva), özellikler STR/AGI/INT/VIT (hepsi 10, etkisi yok) ve "+" ile puan dağıtma. Sağ tık hızlı eylem. Yuvalar buton: gamepad ile odaklanır.
Veri: `GameState.equipment` (yuva -> ItemData), `active_weapon_set`, `attributes`, `attribute_points`, `BAG_SIZE`; eski kayıtlardaki `weapon`/`armor` yeni yuvalara taşınıyor. `ItemData` yeni türler (kask, eldiven, ayakkabı, pelerin, yüzük, kolye, kemer, kalkan, ok) ve `two_handed`/`ranged`; ikonlar `tools/generate_placeholders.gd` ile üretilen yer tutucular. Sandıklar artık her tür eşya düşürüyor. Çanta doluyken gelen eşya değerine satılıyor.
XP: `GameState.xp_needed_for()` → 100, 200, 400, 700, 1200, 2000... Özellik puanı 3, 6, 9... seviyelerde.
**Görevler ayrı pencereye taşındı:** `QuestWindow` (J, gamepad yön aşağı, HUD'daki "!" butonu).
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

### 3.7 PC için diğer ayarlar ✅ (2026-10-06)
Yapılanlar: Ayarlar'a tam ekran, pencere boyutu (480x270'in tam katları, ekrana sığanlar) ve V-Sync (`Settings.fullscreen/window_scale/vsync`, [display] bölümü). Titreşim artık gamepad'i titreştiriyor (`Settings.vibrate`). `export_presets.cfg`: "Windows Desktop" (`build/windows/KulPrensi.exe`) ve "Linux (Steam Deck)" (`build/linux/KulPrensi.x86_64`), Android ile aynı `data/*.json` ve hariç tutma filtreleri; `/build/` git'e girmez. **Dışa aktarma şablonları bu bilgisayarda kurulu değil** (Editör > Dışa Aktarma Şablonlarını Yönet); bu yüzden gerçek bir dışa aktarma denenmedi.
- Ayarlar: tam ekran / pencere, çözünürlük (tam sayı ölçek), V-Sync.
- Dışa aktarma: Windows ve Linux (Steam Deck) ayarları `export_presets.cfg` dosyasına eklenmeli. Şu an sadece Android ayarı var (`data/*.json` include filtresiyle; aynı filtre PC ayarlarına da konmalı).
- `docs/design.md` ve `docs/roadmap.md` dosyalarındaki mobil kısımlar PC'ye göre güncellendi; kod değiştikçe onları da güncel tut.

## 3b. Kullanıcı geri bildirimiyle yapılanlar (2026-10-06) ✅
Ana menü ortalama, envanterde sürükle-bırak + Split (kaydırıcı, imlece yapışan yığın), ikonların yuvaya ortalanması, eşya bilgisi kutusu (pencere büyümez), altın kesesi boyu, konuşmada sağda portre (yer tutucu), dükkânda solda çanta + satış + Split, dash ile düşmanların içinden geçme. Ayrıntı: `decisions.md`.
**2. tur geri bildirim (2026-10-06) ✅:** yığın limiti 20 (`GameState.MAX_STACK`), gamepad ile taşı (X) / böl (Y) + B ile iptal (envanter ve dükkân, ayarlarda `menu_move`/`menu_split`), Blood Monster ve boss hücumu artık hasar verir ve stun'lar (Blood Monster 0,6 sn, boss 1,0 sn; blok/parry/yuvarlanma korur), Blood Monster normal hasarı 8, boss 2. faz çağırma işaretlerinin takılı kalması giderildi, dash düşmanları artık itmiyor. Ayrıntı ve kök nedenler: `decisions.md`. Duman testi artık 184 kontrol; boss testi alan/uyarı temizliği ve Fenris atılma kontrolleri içeriyor.
**Dikkat (kullanıcıya sorulabilir):** Boss çağırma işaretleri (küçük sarı daire) hasar alanı değil, yardımcıların doğma yeri; oyuncular hasar alanı sanıyor. İstenirse ayrı renk/şekil verilebilir. Ayrıca bu Godot sürümünde `ui_accept`/`ui_cancel` varsayılanında gamepad A/B yok; gamepad ile menü gezinmede A'nın butona basıp basmadığı gerçek bir gamepad ile denenmeli (gerekirse `ui_accept`/`ui_cancel`'e `Controls.apply()` içinde joypad A/B eklenir).
**3. tur geri bildirim (2026-10-07) ✅:** (1) Stun: Blood Monster hücumunda yalnızca zamanında parry korur (sıradan blok korumaz), boss hücumları (Fenris dahil) bloklanamaz/parry'lenemez (UNBLOCKABLE, kırmızı uyarı), yuvarlanma hâlâ kurtarır. (2) Hasar: Blood Monster normal hasarı 11 (~%9 can), hücum 16; `GameState.damage_player` hasar tabanı (zırh sonrası en az hasarın %25'i, en az 1). (3) Fenris 3 faz: 1. faz kılıç+alan+atılma, %60'ta 2. faz (2 Demon + 2 Blood Monster çağırır; kök neden: çağırma hazırlığını sprite olayları bölüyordu + haritadaki Fenris eski saldırı listesini eziyordu), %30'da 3. faz (çağırma sürer + 5 kırmızı yanıp sönen patlama dairesi, yalnızca oyuncuya hasar). Ayrıntı `docs/bosses.md`. (4) Stagger yalnızca Yer Sarsıntısı'ndan (boss hariç; `Enemy.stagger_resistant` ileride için); parry aynen çalışır. (5) Dev konsolu: Enter -> "zort" -> Enter dev modunu açar, **F9** konsolu açar (ışınlan, god mode, düşman çağır, çantaya eşya ekle); ayarlarda görünmez. Duman testi 220 kontrol, boss testi 20 `[OK]` + 10 boss. **Kullanıcıya sorulabilir:** F9 yerine başka tuş istenir mi; Fenris hasar/zamanlama (patlama 20 hasar, 5 daire, 7 sn bekleme; çağırma 15 sn) elle dengelenmeli; gerçek gamepad/elle oynanışta denenmedi.
**4. tur geri bildirim (2026-10-07) ✅:** (1) Normal vuruş artık düşmanı/boss'u hiç kesintiye uğratmıyor (kök neden: `take_damage` her vuruşta HURT durumu + hurt animasyonu atıyordu; ayrıntı `decisions.md`). (2) Normal vuruş yalnızca en yakın tek sersemletilebilir mob'u sersemletir; yeni `Enemy.normal_hit_stagger_immune` (sahne başına, şimdilik hiçbirinde true); Yer Sarsıntısı hepsini sersemletir; boss yalnız parry ile. (3) Fenris çağırma her 20 sn (yardımcı yaşasa da), en fazla 8 canlı yardımcı. (4) Oyuncu ölünce boss barı kapanır. (5) "F ile konuş" ipucu 3 sn. Duman testi 233 `[OK]`, boss testi 27 `[OK]` + 10 boss.
**Kullanıcıdan beklenen:** NPC portre PNG'leri → `assets/portraits/<id>.png` (id'ler: ezra, mira, kadir, borak, rurik, seren, pip, player; 64x64 önerilir).

## 4. Bekleyen diğer işler- **Kullanıcıya sorulacak (PC geçişinde varsayılan seçildi, kolayca değişir):**
  - XP: 1→2 için **100**, çarpan 1,6 şimdilik kalsın (kullanıcı kararı). İleride öneri: çarpan 1,4 + '2 anlamlı basamağa' yuvarlama (100, 140, 200, 270...) ve mob XP'sini eğriye bağlamak: `mob_xp = gereken_xp(mob seviyesi) / seviye başına öldürme hedefi (ör. 25) × tür katsayısı`. Böylece çarpan değişse de grind miktarı değişmez. Eski formülde 40'tı; seviye atlamak artık daha yavaş. Düşman/boss XP ödülleri buna göre ayarlanabilir.
  - Özellik puanı: kullanıcı **her seviyede 1** dedi (`GameState.LEVELS_PER_ATTRIBUTE_POINT = 1`); oyun uzunluğu belli olunca yeniden bakılacak.
  - Görevler: envanterden çıkarılıp **ayrı görev günlüğü** yapıldı (J). Kullanıcı birleşik pencerede sekme isterse geri eklenebilir.
  - Özelliklerin (STR/AGI/INT/VIT) etkileri henüz yok; ne yapacakları kararlaştırılmalı (`ATTR_*_DESC` metinlerinde öneri var).
  - Ekipman ikonları yer tutucu; asset paketi gelince `ItemData.TYPE_ICONS` değiştirilecek.
  - Menzilli silah (yay) ve ok takılabiliyor ama henüz ateş etmiyor.- **Asset paketleri:** `docs/downloads.md`. Kullanıcının indirip indirmediği bilinmiyor; **sor.** Zorunlu: Zerie Tiny RPG 01 + 02 tam sürümleri (toplam 5 dolar). Gelince yapılacaklar:
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
