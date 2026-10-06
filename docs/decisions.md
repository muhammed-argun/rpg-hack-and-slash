# Kararlar ve Dersler

Her kayıt: tarih, karar/ders, kısa gerekçe. En yeni kayıt en üste eklenir.

## 2026-10-07 (5. tur, düzeltildi) — Yalnızca basic attack (NORMAL) oyuncuyu kilitlemez; alan/ağır vuruşlar (HEAVY, UNBLOCKABLE) yine sersemletir (kullanıcı düzeltmesi: "normal vuruş" = sadece basic attack). Aşağıdaki "tüm kind" ifadesi geçersiz.
- **Kök neden:** `Player.take_damage` NORMAL dışı her vuruşta (HEAVY/UNBLOCKABLE alan, mermi, boss saldırısı) `_stagger()` çağırıyordu (0,6 sn tam kilit, her vuruşta yenilenir: mob kalabalığında sürekli kilit). NORMAL vuruşta ise `State.HURT`'e giriliyordu ve `HURT` `_physics_process`'te `_:` koluna düşüp hurt animasyonu bitene kadar girdiyi yok sayıyordu. Çözüm: sıradan vuruş (kind ne olursa olsun) yalnızca hasar + flash + hurt animasyonu; `HURT` durumunda yeni `_process_hurt()` herhangi bir girdi (dash, saldırı, yetenek, blok, etkileşim, hareket) gelince `NORMAL`'e geçip `_process_normal()` çalıştırır, animasyon kesilir. Kalan bilinçli kilitler: `stun()` (hücum) ve savunma kırılması (GUARD_BROKEN `_stagger`). Blok/parry/i-frame değişmedi. Test: 5 ardışık NORMAL/HEAVY vuruştan sonra dash ve saldırı anında kabul ediliyor.

## 2026-10-07 (4. tur) — Normal vuruş kesinti kök nedeni, tek mob stagger, Fenris çağırma 20 sn, boss barı, ipucu süresi
- **Kök neden (normal vuruş hâlâ "sersemletiyordu", boss bazen):** `stagger=false` olsa da `Enemy.take_damage` her vuruşta durumu `CHASE`'e çekiyor, hurt animasyonu varsa `State.HURT`'e sokup hurt animasyonunu oynatıyordu. `HURT` durumunda `_physics_process` `_:` koluna düşer (hareket/saldırı yok) ve `ATTACK` (yakın saldırı hazırlığı) bu atamayla iptal edilirdi; yalnızca `SPECIAL`/`CHARGING` korunuyordu. Boss `Enemy.take_damage`'i çağırdığı için aynı kod onda da çalışıyordu: boss `SPECIAL`/`CHARGING`'deyken vuruş kesmez, `ATTACK`/`CHASE`'te keserdi -> "bazen sersemliyor". Çözüm: sersemletmeyen vuruş durumu hiç değiştirmez (yalnızca `IDLE/RETURN` -> `CHASE`, yani boşta olan saldırgan olur), hurt animasyonu/`HURT` ataması kalktı; geriye hasar, `_flash()` tonu ve hafif geri savurma (`Player.NORMAL_HIT_KNOCKBACK_SCALE` 0,35; boss 0) kaldı. Ders: "kesinti yok" iddiası yalnız bayrak (`stagger`) kontrolüyle değil, hasar yolundaki bütün durum atamalarıyla doğrulanmalı; testte durum + hazırlık bayrakları 12x4 denemeyle ölçülüyor.
- **Stagger modeli:** Normal vuruş vuruş alanındaki sersemletilebilir mob'ların oyuncuya EN YAKIN TEKİNİ sersemletir (`Player._deal_attack_damage`), diğerleri yalnız hasar alır. Aday: `Enemy.can_be_normal_hit_staggered()` = `can_be_staggered()` (boss false, `stagger_resistant` false) ve `not normal_hit_stagger_immune`. Yeni alan `Enemy.normal_hit_stagger_immune` (varsayılan false, sahne başına; şimdilik hiçbirinde true): yalnızca normal vuruştan muaf, seçimde sayılmaz; `stagger_resistant` her tür stagger'a (E dahil) dirençli. Yer Sarsıntısı eskisi gibi alandaki tüm `can_be_staggered()` mob'ları sersemletir (muaf olan dahil). Parry değişmedi. Boss normal vuruşta/E'de hiç kesintiye uğramaz, yalnız parry sersemletir.
- **Fenris çağırma:** "canlı yardımcı varken seçilmez" kuralı kalktı (mob'ları öldürmeden çağırtmama exploit'i). `Fenris` çağırma `cooldown` 20 sn (yardımcılar yaşasa da yeni çağırma yapılır). Taşma önlemi: `Boss.MAX_MINIONS = 8`; 8 canlı yardımcı varken çağırma seçilmez, sınıra yakınken `_finish_summon` yalnızca kalan kadar doğurur.
- **Boss barı:** `HUD`, `GameState.player_died`'ı dinler: `_boss` bırakılır, bar hemen kapanır, görev takibi eski opaklığa döner. Boss/arena durumuna dokunulmadı (oyuncu şehirde doğar, Kurt İni yeniden yüklenince boss dolu canla başlar, `boss_started` barı geri getirir; "yanına gidince canı dolsun" davranışı aynen korundu).
- **İpucu:** `TutorialHints.TIMED_HINTS = {"talk": 3.0}`: "F ile konuş" ipucu 3 sn gösterilip `_complete` ile kaybolur ve `tutorial_talk` bayrağıyla bir daha çıkmaz (diğer ipuçları eylemle tamamlanmaya devam eder).

## 2026-10-07 — Stun kuralları, hasar tabanı, Fenris 3 faz, yalnızca E ile stagger, dev konsolu
- **Hücum stun'u:** `Enemy._update_charge` artık `PARRIED` ve `DODGED` dışındaki her sonuçta (HIT, BLOCKED, GUARD_BROKEN) oyuncuyu sersemletir. Yani Blood Monster hücumunda **yalnızca parry penceresi (0,2 sn) içinde bloklamak** stun'u engeller (ve hücum eden düşmanı sersemletir, hasar yok); sıradan blok hasarı azaltır ama stun yer; yuvarlanma i-frame'i yine kurtarır. Boss hücumları (`BossAttack.Type.CHARGE`, Fenris dahil hepsi) `Boss._execute` içinde kind ne yazarsa yazsın `UNBLOCKABLE` yapılır: kırmızı uyarı, blok/parry işe yaramaz, isabet stun verir (Fenris sahnesindeki `kind` verisi de 2 yapıldı; diğer boss sahneleri veride HEAVY kalsa da çalışma anında UNBLOCKABLE).
- **Hasar tabanı:** `GameState.damage_player(raw, apply_floor = true)`: `max(1, raw - savunma, ceil(raw x 0.25))` (`DAMAGE_FLOOR_RATIO`). Bütün düşman/boss hasarını etkiler. Blok sızıntısı `apply_floor = false` ile çağrılır (zaten hesaplanmış ve savunma eklenmiş değer, taban onu şişirmesin). Mevcut test sayıları (180 -> 162 vb.) değişmedi çünkü zayıf zırhta taban devreye girmiyor. Blood Monster normal hasarı 8 -> **11** (başlangıç canı 120'nin ~%9'u; zırh 2 ile 9 hasar), hücum hasarı 12 -> 16 (`blood_monster.tscn` ve `wild.tscn`'deki 3 örnek).
- **Fenris kök neden (çağırma mob doğurmuyordu):** `Boss._start_summon` boss'u `State.SPECIAL`'a sokuyor, ama `Enemy`'nin sprite olayları (`_on_sprite_frame_changed`/`_on_sprite_animation_finished`) SPECIAL durumunu alan vuruşu mantığıyla yönetiyor: önceki bir alan/hücum saldırısından kalan `_windup_held`, `_hit_done`, `special_windup` değerleriyle "special" animasyonu çağırma hazırlığını bölüp durumu CHASE'e çeviriyordu; `_finish_summon` durum SPECIAL değil diye işaretleri silip hiçbir şey doğurmadan çıkıyordu (sarı daireler kayboluyor, mob yok). Aynı hata `_start_cast` (mermi/ışın) ve ışınlanmada da olabilirdi. Ayrıca gerçek harita (`ashwood_den.tscn`) Fenris sahnesinin üstüne eski saldırı listesini (2 çağırma, tek sahne) baked olarak ezmişti; ezmeler silindi, harita artık `fenris.tscn`'i olduğu gibi kullanır (**ders: örnek sahnede `attacks` gibi dizi/kaynak ezmesi bırakma; kaynak sahne değişince haritadaki kopya eski kalır**). Çözüm: `Boss._casting` bayrağı + `_cast_id` (her hazırlık başında artar; iptal edilen hazırlığın geciken çağrısı id'yi kıyaslayıp çıkar); `_casting` iken boss sprite olayları göz ardı edilir.
- **Faz sistemi:** `Boss.phase3_threshold` (0 = yok), `BossAttack.min_phase` (zaten vardı), yeni `BossAttack.phase_opener` (faza girince ilk yapılan saldırı), `cooldown` (saldırıya özel bekleme; `Boss._clock`/`_attack_ready`), `summon_scenes` (i. yardımcı `summon_scenes[i % boyut]`), `blink` (BARRAGE daireleri yanıp söner: `AreaTelegraph.blink`). Hız çarpanı yalnızca 2. faza girerken uygulanır. Faz geçişinde hazırlığı süren çağırma/patlama iptal edilir (`_abort_cast`: işaretler ve havadaki yağmur vuruşları silinir), sürmekte olan pençe/alan/hücum bölünmez (animasyon uyarısız vurmasın; önceki tur dersi korundu). Mesaj: `MSG_BOSS_PHASE_2/3`.
- **Fenris tasarımı:** 1. faz kılıç + alan (Kül Fırtınası, artık 1. fazdan) + atılma; 2. faz (%60) 4 yardımcı (2 Demon + 2 Blood Monster); 3. faz (%30) yanıp sönen kırmızı patlama daireleri (BARRAGE türü, yarıçap 20 = çağırma işaretinin 2 katı, 1,5 sn, 5 daire, 20 hasar, 7 sn bekleme, yalnızca oyuncuya). Tekrar çağırma sınırı: canlı yardımcı varken seçilmez + 15 sn bekleme; yardımcılar `xp_reward = 0` ve görev sayımsız (aksi hâlde çağırtıp XP kasılırdı). Ayrıntı `docs/bosses.md`.
- **Stagger yalnızca Yer Sarsıntısı:** `Enemy.take_damage(..., knockback_scale, stagger: bool = false)`; `poise_scale` kalktı. Normal saldırı hurt animasyonu/geri savurma yapar ama sersemletmez; `Player._deal_skill_damage` `stagger = true` verir. `Enemy.stagger_resistant` (varsayılan false; ileride güçlü mob'lar) ve `can_be_staggered()` (Boss override: false). Parry ayrı mekanik: `on_parried()` -> `stun()` her düşmanda (boss dahil) aynen çalışır. Eski `poise` alanları sahneler değer atadığı için duruyor ama artık kullanılmıyor.
- **Dev konsolu:** Enter (hiçbir pencere açık değil, oyun duraklı değil, arayüz Enter'ı tüketmediyse; `HUD._unhandled_input`) `DevPrompt` çubuğunu açar; "zort" (büyük/küçük harf fark etmez) yazılıp Enter'a basılırsa `GameState.dev_mode` açılır (oturumluk, kayda yazılmaz, mesaj gösterilir), başka bir şey yazılırsa çubuk sessizce kapanır, Esc de kapatır. Çubuk açıkken oyun **duraklar** (yazarken basılan WASD vb. `Input.is_action_pressed` ile okunduğu için duraklatılmazsa karakter yürürdü) ve diğer pencereler gibi HUD'un `_is_busy_except`/`_close_top_window` listelerindedir. Dev modu açıkken **F9** (`DevConsole.TOGGLE_KEY`, ham `InputEventKey`; `Controls.DEFAULTS`/`REBINDABLE`'a koyulmadı, bu yüzden ayarlarda görünmez ve ayrı aksiyon yok) `DevConsole` penceresini açar/kapatır; dev modu kapalıyken hiçbir şey yapmaz. Sekmeler: ışınlanma (haritaların `Spawns` düğümlerinden okunur, `GameState.map_change_requested` ile Main'in harita değiştirme yolu), God mode (`GameState.god_mode`: `Player.is_invulnerable()` true döner, hasar ve stun yok; ayrıca "can/mana/stamina doldur"), düşman/boss çağırma (oyuncunun çevresine halka, adet girilir; boss çağırmak ölünce gerçek ilerleme verir), eşya ekleme (iksir, malzeme, değerli eşya, ekipman + nadirlik + adet; `GameState.add_health_potions/add_material`, eşyalar `add_to_bag` ile **çantaya** girer, `add_item` gibi otomatik kuşanılmaz). **Çeviri kuralı istisnası:** dev konsolu/çubuğu oyuncuya görünmeyen geliştirici aracıdır, metinleri sabit İngilizce dizelerdir, çeviri anahtarı değildir. Kullanılmayan bir tuş seçimi: F9 oyunda hiçbir şeye bağlı değil.
- Ders: Bir node'un `State.SPECIAL` gibi ortak durumunu hem kare/animasyon olaylarıyla yöneten bir mantık hem de zamanlayıcıyla yöneten başka bir mantık varsa (çağırma, büyü) biri ötekini bozabilir; zamanlayıcıyla yönetilen hazırlığa ayrı bir bayrak + iptal kimliği ver. Ders: `Map` örnek sahnelerinde kaynak ezmesi (override) kopyası eskir; test çağırma "işaret var mı" yerine "yardımcı doğdu mu" ölçmeli (ikisini de ölçen test eklendi). Ders: GDScript'te `SceneState.get_node_path(i, true)` ebeveyn yolunu "./Spawns" biçiminde verir. Ders: `Control.set_anchors_and_offsets_preset(PRESET_CENTER, PRESET_MODE_MINSIZE)` `custom_minimum_size`'ı hesaba katmaz; boyutu belli panelleri `position = (size - panel.size)/2` ile ortala.

## 2026-10-06 — Yığın limiti, gamepad ile taşı/böl, hücum hasarı ve stun, takılı uyarılar, dash
- **Yığın limiti 20** (`GameState.MAX_STACK`): `add_to_bag` önce mevcut yığınların boşluğunu doldurur, kalanı 20'şer parça boş yuvalara koyar, sığmayanı döndürür. `bag_has_room_for` toplam boşluğa (yığın boşluğu + boş yuva x 20) bakar. `place_in_slot` / `move_slot` birleştirirken 20'de durur, artan kısım imlece (ya da eski yuvaya) döner. Eski kayıttaki 20'den büyük yığınlar yüklenirken `_split_oversized_stacks` ile bölünür (boş yuva yoksa fazlalık yerinde kalır, eşya kaybolmaz).
- **Gamepad ile taşı/böl:** yeni menü aksiyonları `menu_move` (varsayılan X / klavye X) ve `menu_split` (Y / V), ayarlar ekranında atanabilir. Odaktaki (fareyle oynarken imlecin altındaki) yuvada taşı tuşu yığını eline alır, ikinci basış bırakır (boş: yerleşir, aynı tür: birleşir, farklı: yer değiştirir). Böl tuşu Split penceresini açar: sol/sağ miktarı ayarlar, A onaylar, B iptal; B ayrıca elde tutulan eşyayı iptal eder (`BagPanel.handle_back`, pencere kapanmaz). Mantık `BagPanel`'de olduğu için envanter ve dükkân aynı. Bu aksiyonlar oyun içi aksiyonlarla (X = saldırı, Y = konuş) tuş paylaşır; sorun olmaz çünkü pencereler açıkken oyun duraklı ve `BagPanel._input` yalnızca görünürken çalışır. Ders: bu Godot sürümünde varsayılan `ui_accept`/`ui_cancel` eşlemesinde gamepad A/B yok (yalnızca klavye); gamepad A'yı `ui_accept`'e güvenmeden doğrudan `JOY_BUTTON_A` ile de oku.
- **Hücum (charge) hasar vermiyordu — kök neden:** `Enemy._special_hit()` başında `_hit_done = true` yapıyor, `_update_charge` ise `not _hit_done` bekliyordu; bayrak hücum başlarken sıfırlanmadığı için çarpma kodu hiç çalışmıyordu (Blood Monster ve bütün boss CHARGE saldırıları). Ayrıca çarpma merkezler arası mesafe <= `special_radius` ile ölçülüyordu; oyuncunun gövdesi hücumu fiziksel olarak durdurduğundan mesafe 14 px'e hiç inmeyebilirdi. Şimdi önceki-şimdiki konum çizgisi ile oyuncu arasındaki mesafe, `max(special_radius, iki gövdenin yarıçapı) + 2` ile karşılaştırılıyor; bir hücumda en fazla bir vuruş.
- **Stun:** `Player.stun(süre)` oyuncuyu `STAGGER` durumuna sokar (hareket, saldırı, yetenek, blok, yuvarlanma yok; sarımsı ton + "Sersemledin!" yazısı), süre uzar ama kısalmaz. Hücum yalnızca sonuç `HIT` ise sersemletir: blok/parry/yuvarlanma (i-frame) stun'dan korur (blok = "stun'dan kurtulma" kararı; hasar yine blok kuralıyla azalır). Süre: normal düşman `charge_stun_time` 0,6 sn, boss `BossAttack.stun_time` 1,0 sn (Fenris dahil bütün boss CHARGE'ları). Hücum türü: sahnelerdeki `special_kind` (HEAVY) aynen kaldı.
- **Blood Monster normal hasarı 7 -> 8** (sahne + `wild.tscn` örnekleri; örnekler özellikleri tek tek ezdiği için ikisi de değişti). Oyuncu hasarı `max(1, hasar - zırh)`: başlangıç zırhı 2 ile 6 hasar (120 canın %5'i), bir-iki zırh parçasıyla 4-5; zırh 7'yi geçince yine 1'e düşer (düz çıkarma formülünün özelliği; formüle dokunulmadı). Kullanıcının gördüğü "1" büyük ihtimalle zırhlı oyuncu ya da blok (blokta kalan hasar 1).
- **2. faz takılı sarı daireler — kök neden:** Boss'un çağırma (SUMMON, Fenris'in uluması) küçük sarı işaretleri `AreaTelegraph.circle(NORMAL)` ile çiziliyor ve `_finish_summon` ile patlatılıyordu; ama hazırlık sırasında boss sersemler (`state != SPECIAL`) ya da ölürse (tween boss'a bağlı) fonksiyon patlatmadan çıkıyor, işaretler harita değişene kadar kalıyordu. Çizgi uyarısı da (`_start_line`) aynı yolla yetim kalabiliyordu. Bunlar hasar alanı değil, çağrılacak yardımcıların doğma yeri işaretidir (bu yüzden hasar vermez). Çözüm: Boss kendi uyarılarını tutar (`_attack_telegraphs`), `_cancel_special`/`_die`/`_exit_tree`'de siler; ölünce yağmur (barrage) vuruşları da iptal edilir (uyarılara sahip boss kimliği meta olarak yazılır); `Enemy._exit_tree` yetim uyarıyı siler; `AreaTelegraph` patlatılmadıysa süre + 1,5 sn sonra kendini siler (güvenlik ağı). Faz geçişinde sürmekte olan saldırı bilerek iptal edilmiyor (iptal edilirse animasyon uyarısız vurur).
- **Dash düşmanı itiyordu — kök neden:** Dash'te oyuncunun maskesinden düşman katmanı çıkıyordu ama düşmanın maskesi oyuncu katmanını (2) içerdiği için düşmanın `move_and_slide`'ı iç içe kalınca düşmanı dışarı sürüklüyordu. Çözüm: dash başında oyuncu ve (o an var olan) bütün "enemies" grubu üyeleri karşılıklı `add_collision_exception_with`, dash bitince kaldırılır; dash sırasında doğan düşmanlar `Enemy._update_player_collision` ile yakalanır. Duvar, NPC (StaticBody, katman 1), ağaç ve nesnelere dokunulmadığı için onlar engel olarak kalır. Test: düşman fiziği açıkken dash'te düşman 0 piksel kayar (düzeltmesiz 81 px kayıyordu).
- Ders: `Enemy` içinde bir bayrağı (`_hit_done`) iki aşamalı saldırıda (uyarı vuruşu + hücum) paylaşmak, ikinci aşamanın hiç çalışmamasına yol açabilir; aşama başlarken bayrağı sıfırla. Ders: sonuç yalnızca "hasar azaldı" diye kontrol edilen testler bu hatayı yakalamamıştı; hücum için hasar + stun süresini ölçen test eklendi.

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

- **Ders (Neo):** Belirsiz isteği (ör. "normal vuruş" hangileri?) varsayımla genişletme; sor. Kural `.claude/agents/neo.md`de.
