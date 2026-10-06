# Kararlar ve Dersler

Her kayıt: tarih, karar/ders, kısa gerekçe. En yeni kayıt en üste eklenir.

## 2026-10-06 — Kullanıcı geri bildirimi: yerleşimli çanta, split, dükkân, portre, dash
- **Çanta artık yerleşimli:** `GameState.bag` 36 elemanlı dizi, her yuva bir `BagStack` (id + adet + gerekirse `ItemData`) ya da null. İksir ve malzeme sayaçları kalktı; `health_potions`, `get_material()` gibi değerler çantadan hesaplanıyor. Dışarıya açık fonksiyonların adı değişmedi (`add_health_potions`, `add_material`, `spend_materials`...). Eski kayıtlar (sayaçlar + `inventory` listesi) yüklenirken çantaya taşınıyor.
- Yığın sınırı yok; ekipman yığılmaz. Değerli eşyalar ad+nadirlikle yığılır.
- `BagPanel` ortak bileşen (envanter + dükkân): sürükle-bırak bütün yığını taşır; Split kaydırıcısıyla seçilen adet imlece yapışır, tıklanan yuvaya bırakılır (boş: yerleşir, aynı tür: birleşir, farklı: yer değiştirir ve oradaki eşya imlece geçer). Pencere kapanırken imlecteki yığın çantaya döner.
- Eşya bilgisi `ItemTooltip` kutusunda; pencereler metne göre büyümüyor. Ders: autowrap'lı Label yüksekliği metinle büyür ve içeriğine göre boy alan pencereyi ekrandan taşırır; uzun metin sabit boyutlu ya da ayrı bir kutuda olmalı.
- İkonlar `IconFit` ile yerleştiriliyor: görselin dolu kısmı kesilip yuvanın içine tam piksele ortalanıyor, büyükse küçültülüyor. Sebep: 32x32 çizimlerin içeriği tuvalin ortasında değildi.
- Dükkân: solda çanta (Sat, sağ tıkla hızlı sat, Split), sağda satın alma. Satış fiyatları `CONSUMABLE_SELL_VALUES`, `MATERIAL_SELL_VALUES` (yoksa satılamaz; görev eşyaları satılmaz), eşyalarda `ItemData.value`.
- Çanta doluysa: ot toplanmaz, simya ürün vermez (malzeme harcanmaz), dükkândan alınmaz.
- Konuşma kutusunda sağda portre: `res://assets/portraits/<konuşmacı id>.png` (ör. `ezra.png`, `player.png`), yoksa `placeholder.png`. Önerilen boyut 64x64.
- Dash/yuvarlanma sırasında oyuncunun çarpışma maskesinden düşman katmanı çıkarılıyor: normal düşmanların ve boss'ların içinden geçilir, duvarlardan geçilmez. İçeride biterse en fazla 0,25 sn daha kayarak dışarı çıkar.
- Ana menü: ortalama artık `CenterContainer` ile; ders: `_ready` sırasında elle `set_anchors_and_offsets_preset(CENTER, MINSIZE)` yapmak, boyut henüz kesinleşmediği için kaymaya yol açabiliyor.
- Altın kesesi: panel temasının iç boşluğu küçültüldü, duraklat butonuyla aynı boy (24 px).

## 2026-10-06 — PC geçişi 3.7: ekran ayarları ve dışa aktarma
- Pencere boyutu yalnızca temel çözünürlüğün (480x270) tam katları; tam ekranda Godot'nun tam sayı ölçeklemesi (`scale_mode=integer`) kenarlarda siyah boşluk bırakabilir, bu pixel art'ın keskin kalması için bilerek seçildi.
- `Settings.apply()` ekran ayarlarını da uygular; headless çalışmada (testler, araçlar) pencereye dokunulmaz.
- Titreşim ayarı mobilde telefonu, PC'de gamepad'i titreştirir.
- Dışa aktarma: Windows ve Linux (Steam Deck) ayarları eklendi; şablonlar kurulmadan dışa aktarılamaz.
- Ders (araç kullanımı): PowerShell here-string'iyle (`@"..."@`) metin eklerken sondaki satır sonu kaybolabiliyor; GDScript'te iki satır birleşip "Expected end of statement" hatası veriyor. Ekledikten sonra `\S\t+\w` desenini aramak bu hatayı yakalıyor.

## 2026-10-06 — PC geçişi 3.5–3.6: birleşik envanter ve karakter penceresi
- Çanta "yerleşimli" değil, listeli: iksirler, malzemeler ve eşyalar sırayla dizilir; 36 yuva bir **sınır**. Sürükle-bırak yok (tıkla/sağ tık/gamepad A). Sebep: iksir ve malzemeler sayaç olarak tutuluyor; yerleşimli çanta için hepsinin tek bir eşya modeline geçmesi gerekir. İleride gerekirse yapılır.
- Değerli eşyalar ad+nadirliğe göre yığılır; ekipman yığılmaz (`GameState.bag_stack_key`).
- Çanta doluyken sandıktan gelen eşya kaybolmasın diye değerine satılıyor.
- Dükkândaki toplu satış artık yalnızca değerli eşyaları satıyor (`Değerlileri Sat`); ekipman tek tek satılır.
- `ItemData.Type` kayıtta sayı olarak durduğu için yeni türler hep sona eklenir.
- Silah setinde yalnızca etkin setin silahları hasara/zırha sayılır.
- XP formülü tam sayıyla hesaplanıyor. Ders: `500 * 1.6 = 800.0000001` gibi değerler yukarı yuvarlamada 900 verir.
- Görev günlüğü ayrı pencere (`QuestWindow`, J). Pencere sığmadığı için birleşik pencereye sekme olarak konmadı.
- Ders: `GridContainer` gizli çocukları atlar; bir hücreyi gizlemek bütün ızgarayı kaydırır. Gizlenecek buton bir `HBoxContainer` hücresinin içine konmalı.

## 2026-10-06 — PC geçişi 3.4: yetenek ve hızlı kullanım yuvaları
- Yetenek kimliği (`ground_slam`) yuvada durur; `skill_1..3` aksiyonları yuvanın içeriğini kullanır. Yetenek ağacı gelince sadece `GameState.skill_slots` değişecek.
- Yetenek verisi ikiye bölündü: görünen kısım (ad, ikon) `GameState.SKILLS`, oynanış (mana, bekleme, hasar) `Player` export'ları. Yetenek sayısı artınca ikisi bir `SkillData` kaynağında birleştirilebilir.
- `skill_cooldown_started` sinyali artık `(skill_id, duration)` taşıyor.
- Hızlı kullanım yuvaları eşya kimliği tutar (`health_potion`/`mana_potion`); sayı `GameState.consumable_count()`'tan okunur. Yeni tüketilebilir eklemek: `CONSUMABLES` + `consumable_count` + `Player._use_consumable`.
- Yetenek çubuğu fareyi yakalamaz (`MOUSE_FILTER_IGNORE`); yoksa imleç üstündeyken saldırı engellenirdi.

## 2026-10-06 — PC geçişi 3.3: nişan
- Nişan tek yerden: `Player.get_aim_direction()`. Menzilli silah ve büyüler de bunu kullanmalı.
- Gamepad'de sağ çubuk bırakılınca hareket yönü kullanılıyor, duruyorsa son nişan yönü. Hades'teki gibi.
- Görsel yalnızca saldırı/blok anında nişan tarafına döner; yürürken hareket yönüne bakar.
- Fare HUD butonunun üstündeyken saldırı yok (`Viewport.gui_get_hovered_control()`). Ders: HUD'da fareyi yakalamaması gereken her Control `mouse_filter = IGNORE` olmalı, yoksa imleç üstündeyken saldırı engellenir.
- Ders: CSV çevirileri ancak `--import` ile yeniden derlenir. Metin değiştirdikten sonra testten önce import çalıştır.
- Test, nişanı sağ çubuk aksiyonlarına (`aim_*`) güç vererek simüle ediyor; fareyi `warp_mouse` ile taşıyor.

## 2026-10-06 — PC geçişi 3.2: tuş atama ve Controls autoload'u
- **Tuşların tek kaynağı kod:** `Controls.DEFAULTS`. project.godot'taki `[input]` bölümü kaldırıldı; aksiyonlar açılışta `Controls.apply()` ile oluşturuluyor. Sebep: varsayılanlar iki yerde durursa birbirinden kopar. Editörün Input Map ekranı artık boş görünür, bu normal.
- Her aksiyonun iki yuvası var: klavye/fare ve gamepad. Ok tuşlarıyla yürüme kalktı (WASD tek tuş). İstenirse ayarlardan atanır.
- Kayıt formatı okunabilir kodlar: `key:<fiziksel tuş>`, `mouse:<buton>`, `joy:<buton>`, `axis:<eksen>:<±1>`. Fiziksel tuş = klavye düzeninden bağımsız konum; ekranda oyuncunun düzenindeki harf gösterilir.
- Tuş atama beklerken (`Controls.capturing`) HUD aksiyon okumaz. Ders: `set_input_as_handled()` sadece GUI'ye gitmeyi durdurur; `Input.is_action_just_pressed` yine true olur. Yakalanan tuşun durumu o kare sürdüğü için bayrak iki kare sonra kalkar.
- Testler ayar dosyası olarak `user://settings_smoke_test.cfg` kullanır (`Settings.config_path`, `Controls.config_path`) ve tuşları varsayılana çeker.
- Gamepad odağı: pencereler `menus` grubuna girer; gamepad kullanılırken odakta bir şey yoksa `Controls` görünür son menünün ilk butonunu seçer. Yeni pencere eklerken `add_to_group("menus")` unutulmamalı.

## 2026-10-06 — PC geçişi 3.1: dokunmatik kontroller kaldırıldı
- HUD'dan TouchJoystick ve ActionButtons (saldırı, yetenek, blok, yuvarlanma, iksir butonları) çıkarıldı. Scriptler ve ction_button.tscn duruyor (mobil port için).
- Duraklat/çanta/görev butonları normal Button oldu (ocus_mode = none, klavye/gamepad odağını çalmasınlar diye).
- emulate_touch_from_mouse kapatıldı.
- Yeni aksiyon interact (F). Konuşma artık saldırı tuşuyla değil bununla başlar; NPC yanında saldırı tuşu saldırır. Diyalog ve hikâye kartı hem interact hem ttack ile ilerler; bitince ikisi de bırakılır (yoksa aynı karede konuşma yeniden başlıyor).
- Tuş adları metne gömülmüyor: Settings.get_action_key_label(aksiyon) ve Settings.format_action_keys("... {interact} ...") güncel atamadan okuyor. 3.2'deki tuş atama ekranından sonra ipuçları kendiliğinden doğru tuşu gösterecek. Fiziksel tuş kodu, kullanıcının klavye düzenindeki harfe çevriliyor.
- Ders: Boss testi, prolog eklendikten sonra bozulmuştu. Yeni oyunda prolog hikâye kartı oyunu duraklatıyor ve hiçbir boss uyanmıyordu. Testte `intro_seen` bayrağı önceden konuyor. Yeni oyun başlatan her araç bunu hesaba katmalı.
- Geçici eksik: iksir sayıları ve yetenek bekleme süresi HUD'da görünmüyor (butonlarla gitti). 3.4'teki yetenek çubuğu ve hızlı kullanım yuvalarıyla geri gelecek.

## 2026-10-06 — PC'ye geçiş kararı
- **Platform PC (Windows) oldu**; Steam Deck ve gamepad desteklenecek. Mobil (Android) ileride port olarak gelebilir.
- Ekrandaki dokunmatik kontroller kaldırılacak. Kodları (`TouchJoystick`, `ActionButton`) mobil port için saklanıyor.
- Savaş Hades tarzına geçiyor: WASD ile hareket, imlece (gamepad'de sağ çubuğa) doğru saldırı.
- Tuşlar: yetenekler E/R/T, hızlı kullanım 1/2, envanter I, karakter C (birleşik pencere). Tüm tuşlar ayarlardan değiştirilebilir olacak.
- XP formülü değişecek: öncekinin 1,6 katı, 100'e yukarı yuvarlanır.
- Bu kararların iş listesi: `handoff.md` 3. bölüm. Yazıldığı anda henüz kodlanmamıştı.

## 2026-10-06 — Gece çalışması: ses, ipuçları, yol bulma, prolog
- **Ses:** `Audio` autoload'u. Oyundaki olaylar isimli sesler çalar (`swing`, `hit`, `parry`...). Ad → dosya eşlemesi `data/audio.json` dosyasında; dosya yoksa ses atlanır. Haritaların müziği `Map.music`, boss dövüşünde boss müziği çalar.
- **Öğretici ipuçları:** İlk oyunda hareket, konuşma, saldırı, blok/parry, yuvarlanma ve yetenek için sırayla ipucu çıkar. Her biri bir kez yapılınca kaybolur (`tutorial_*` bayrakları).
- **Yol bulma:** Her harita açılırken Walls katmanındaki engellerden navigasyon alanı çıkarılıyor (ayrı iş parçacığında). Düşmanlar `NavigationAgent2D` ile engellerin etrafından dolaşıyor.
- **Prolog:** Yeni oyun gece "Varneth Yolu" haritasında, kısa bir anlatı kartıyla başlıyor. Ork yağmacıları ve öğretici ipuçları burada. Doğudaki kapı şehrin güneyine açılıyor. Ölünce şehirde doğuluyor.
- **Android dışa aktarma:** `export_presets.cfg`, `data/*.json` dosyalarını içeri alıyor; `tools`, `docs` ve `ReadyAssetSets` klasörlerini dışarıda bırakıyor. Paket adı `com.example.kulprensi` bir yer tutucu, yayından önce değiştirilmeli.

## 2026-10-06 — Gece çalışması: ilerleme ve boss'lar
- **Seviye:** Düşmanlar deneyim verir. Seviye başına +12 can, +5 mana, +2 hasar; seviye atlayınca can ve mana dolar. En yüksek seviye 30.
- **Dükkân (Kadir):** Can iksiri 20, mana iksiri 25 altın. Değerli eşyalar tek tek ya da hepsi birden satılır.
- **Demirci (Borak):** Silah +1'den +10'a kadar güçlenir. Her seviye +3 hasar; bedeli seviye × (1 cevher + 30 altın).
- **Boss'lar:** 9 boss + Kral + Malphas veri olarak hazır. Kral ölünce aynı arenada Malphas başlar; Malphas parça vermez, `game_completed` bayrağıyla oyun sonu ekranı açılır.
- **Yeni boss saldırı türleri:** mermi, ışınlanma, yağmur (çoklu alan), çizgi (ışın/yarık).
- **Ders:** Ölen bir node'a bağlı gecikmeli çağrılar, node silinince çalışmaz. Kral→Malphas geçişi ve yağmur saldırıları bu yüzden statik fonksiyonlarla yapılıyor.

## 2026-10-06 — Gece çalışması: çekirdek sistemler
- **Dil:** TR/EN. Metinler `data/translations/ui.csv` (arayüz) ve `story.csv` (görev, diyalog, NPC) dosyalarında. Arayüzde metin yerine çeviri anahtarı yazılır, Godot otomatik çevirir. Koddan `tr("ANAHTAR")` kullanılır.
- **Ayarlar:** `Settings` autoload'u; dil, müzik ve efekt sesi (Music/SFX bus'ları), titreşim. `user://settings.cfg` dosyasına kaydedilir.
- **Ana menü** (başlangıç sahnesi): Devam Et, Yeni Oyun, Ayarlar, Emeği Geçenler, Çıkış. **Duraklatma menüsü:** Esc, P, Android geri tuşu ya da HUD'daki duraklat butonu.
- **Kayıt:** `user://save.json`. Harita değişiminde, görev ilerleyince, 60 saniyede bir ve uygulama arka plana alınınca otomatik kaydedilir.
- **Savunma:** Blok (L / kalkan butonu) hasarın %80'ini keser, stamina harcar; stamina biterse savunma kırılır. Blok tuşuna saldırıdan en fazla 0,2 sn önce basılırsa **parry** olur: düşman sersemler, ekran kısa süre yavaşlar. Yuvarlanma (Shift / ok butonu) 0,22 sn dokunulmazlık verir.
- **Saldırı türleri:** Normal, ağır (turuncu uyarı), engellenemez (kırmızı uyarı). İblisin alan vuruşu engellenemez.
- **Denge (poise):** Düşmanlar yeterince hasar alınca sersemler ve 1,5 kat hasar alır.
- **Diyalog ve görevler:** `Dialogue` ve `Quests` autoload'ları. Veriler `data/dialogue.json` ve `data/quests.json` dosyalarında, koşullar `GameConditions` ile değerlendiriliyor. NPC üstünde `!` yeni görev, `?` teslim edilecek görev demek.
- **Crafting:** Otlar yerden toplanıyor, tarifler `data/recipes.json` dosyasında, Mira'da simya.
- **Boss altyapısı:** `Boss` (Enemy'den türer) + `BossAttack` verileri + `BossArena`. İlk boss Fenris, şimdilik büyütülmüş iblis görseliyle yer tutucu.
- **Kül Kalkanı:** Şehrin kuzeyinde. 9 parça Ezra'ya teslim edilince `barrier_broken` bayrağıyla kırılır.
- **Ders:** Oyuncu haritalar arasında taşınırken fizik motoru onu bir kare eski konumunda görüyor ve yeni haritadaki alanlar yanlışlıkla tetiklenebiliyor. Bu yüzden harita değişiminden sonra çarpışma 2 fizik karesi boyunca kapalı kalıyor (`Player.prepare_for_map_change`).
- **Ders:** Godot'da "yeni basıldı" bilgisi (`is_action_just_pressed`) sadece basıldığı karede geçerli. Testlerde basışın karenin başında yapılması gerekiyor.
- **Ders:** Paket fontunda olmayan karakterler (★ ✔ •) görünmez. Sadece Latin-1 ve eklediğimiz Türkçe harfler kullanılmalı.

## 2026-10-05 — Arayüz, mana, yetenek ve özel saldırılar
- UI: Pixel Bars (can/mana barları, düşman ince barları) ve Pixel UI Fantasy (parşömen teması, envanter) eklenti olarak `addons/` altına kuruldu. Eşya ikonları Woshi paketinden.
- Paket fontlarında ı İ ş Ş ğ Ğ yoktu; `tools/make_turkish_font.gd` bunları fontun kendi harflerinden türetiyor.
- Mana: 60, saniyede 1 dolar (yavaş). Mana iksiri %50 doldurur, E tuşu. Can iksiri Q.
- Yetenek "Yer Sarsıntısı": Soldier'ın Attack02 animasyonu (`special`), 20 mana, 2 sn bekleme, 44 px yarıçap, 1.6× hasar.
- Düşman özel saldırıları (Attack02): Ork önüne alan vuruşu, İblis etrafına geniş alan vuruşu, Kan Canavarı hücum. Hepsi önce yerde uyarı alanı gösterir ve vuruştan önceki karede `special_windup` kadar bekler (mobilde kaçabilmek için).
- Özel saldırı sırasında düşman sendelemez ve geri savrulmaz.
- Sandıklar şimdilik silah/zırh düşürmüyor (görselleri yok); altın, iki tür iksir ve değerli eşya düşürüyor.
- Envanter açılınca oyun duraklar.
- Pixel Bars'taki kalpler ve yeşil (dayanıklılık) bar şimdilik kullanılmadı, karşılık gelen sistem yok.

## 2026-10-05 — Yalnızca sağ/sol yön
- Aşağı/yukarı görünüm kaldırıldı. Görsel sadece sağa ya da sola bakar. Yatay girdi varsa (çaprazda bile) karakter hemen o yöne döner. Sadece dikey girdide son yatay yön korunur.
- Saldırı alanı görselin yönünü değil, son hareket yönünü (`aim_direction`) takip eder. Böylece üstteki ve alttaki düşmanlara da vurulabilir.
- Ders: Eski kod baskın ekseni seçiyordu. Tam çaprazda iki eksen eşit olduğundan dikey yön kazanıyor, karakter sola dönmüyordu.

## 2026-10-05 — Hazır karakter paketleri
- Zerie'nin Tiny RPG paketlerinden Soldier oyuncu karakteri (Warrior yerine geçici), Orc/Demon/Blood Monster düşman olarak eklendi. Vahşi bölgede her bölük bir türden oluşuyor.
- Paket yalnızca yandan (sağa bakan) görünüm içeriyor.
- Ayak hizası artık görselin çizili en alt pikseline göre hesaplanıyor; böylece etrafında boşluk olan sprite sheet'ler de doğru hizalanıyor.
- Paket kareleri 100×100'den, tüm animasyonların ortak dolu alanına kırpıldı. Kırpma yatayda simetrik, aynalanınca karakter kaymıyor.

## 2026-10-05 — Warrior demosu
- Görseller isimlendirme kuralıyla (`<animasyon>_<yön>_<NN>.png`) çalışma anında yüklenir. Kullanıcı görsel değiştirince kod değişmez.
- Çözünürlük 480×270, tam sayı ölçekleme, Nearest doku filtresi, piksel yakalama (snap) açık, ekran yatay.
- Sol yön görselleri isteğe bağlı: yoksa sağ yön aynalanır.
- Sandık, bölüğün son düşmanının öldüğü yere düşer. Oyuncu üstüne yürüyünce açılır. Daha iyi eşya otomatik kuşanılır.
- Saldırı butonu basılı tutulunca sürekli saldırılır (mobilde rahatlık için).
- Ölünce 2 saniye sonra şehirde tam canla doğulur (şimdilik ceza yok).
- Ders: Godot 4.7'de yerleşik `VirtualJoystick` sınıfı var, aynı adla `class_name` tanımlanamaz.
- Ders: `--script` ile çalışan araçlarda autoload'lar yüklenmez. Ayrıca kodla oluşturulan InputEventKey'ler `device = -1` olmalı, yoksa klavye çalışmaz.

## 2026-10-05 — Temel tercihler
- Oyun 2D olacak, hedef platform Android.
- Kod yorumları Türkçe, tanımlayıcılar İngilizce.
- Renderer Mobile'dan Compatibility'ye alındı: 2D oyun Vulkan özelliklerine ihtiyaç duymuyor, Compatibility daha fazla Android cihazda çalışıyor.
- Android export için ETC2/ASTC doku sıkıştırması açıldı.

## 2026-10-05 — Proje kurulumu
- Godot 4.7.2, GDScript, Mobile renderer, Jolt Physics ile başlandı.
- Proje kuralları `CLAUDE.md` dosyasında, tasarım ve kararlar `docs/` klasöründe tutulacak.
