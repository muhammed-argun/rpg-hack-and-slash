# Görsel (Asset) Rehberi

## Şu an kullanılan görseller
| Karakter | Klasör | Kaynak |
|---|---|---|
| Oyuncu (Warrior yerine geçici) | `assets/characters/soldier/` | Tiny RPG Character Asset Pack 01 (Zerie) |
| Orc | `assets/enemies/orc/` | Tiny RPG Character Asset Pack 01 (Zerie) |
| Demon | `assets/enemies/demon/` | Tiny RPG Character Asset Pack 02 (Zerie) |
| Blood Monster | `assets/enemies/blood_monster/` | Tiny RPG Character Asset Pack 02 (Zerie) |
| Warrior (yer tutucu, beyaz top) | `assets/characters/warrior/` | Kendi çizimin buraya gelecek |
| Goblin (yer tutucu, kırmızı top) | `assets/enemies/goblin/` | Haritalarda kullanılmıyor, yeni düşman şablonu |

Hazır paketler `ReadyAssetSets/` klasöründe ham hâlleriyle duruyor. Bu klasörde bir `.gdignore` dosyası var, bu yüzden Godot onu yok sayıyor ve oyuna dahil etmiyor. Paketteki sprite sheet'ler `tools/import_tiny_rpg_pack.gd` aracıyla karelere bölündü:
```
godot --headless --path . --script res://tools/import_tiny_rpg_pack.gd
```
Oyuncuyu kendi Warrior çizimine geri döndürmek için `scenes/player/player.tscn` sahnesinde `Sprite` node'unun `Sprite Folder` alanını `res://assets/characters/warrior` yap.

Sandık, zemin ve arayüz görselleri hâlâ **yer tutucu**.
Kod görselleri **dosya adına göre** otomatik yüklüyor. Bir dosyayı **aynı isimle** değiştirdiğinde oyunda senin çizimin görünür. Kodda hiçbir şeyi değiştirmen gerekmez.

## Temel kurallar
- Format: **PNG**, şeffaf arka plan
- Kare (tile) boyutu: **32×32 piksel**
- Karakter kareleri: önerilen **32×32**. Daha büyük de olabilir (ör. 48×48), ama bir animasyonun bütün kareleri aynı boyutta olmalı.
- Karakterin **ayakları görselin alt kenarına** yakın olmalı. Kod, görselin alt kenarını karakterin bastığı nokta kabul eder.
- Görseli değiştirdikten sonra Godot editörüne geçmen yeterli. Godot yeni dosyayı otomatik içe aktarır.

## Çizim ve dışa aktarma (Illustrator / Photoshop)
- Her kare için 32×32 piksellik bir alan kullan. Karakterin boyu bunun içinde 20-26 piksel olsun, ayakların altında 1-2 piksel boşluk bırak.
- Tüm karelerde karakterin ayak hizası ve yatay merkezi aynı yerde olmalı, yoksa animasyon titrer.
- **Kenar yumuşatma (anti-aliasing) kapalı olmalı.** Açık kalırsa kenarlar bulanık, yarı saydam piksellerle çıkar.
- 1x ölçekte, 72 ppi dışa aktar. Büyütmeyi oyun kendisi yapar.
- **Illustrator:** Her kare için ayrı bir 32×32 artboard aç ve artboard'a dosya adını ver (ör. `walk_right_01`). View → Pixel Preview'u aç, nesneleri piksel ızgarasına hizala. File → Export → Export for Screens ile PNG olarak, 1x ölçekte dışa aktar. Ayarlarda (dişli simgesi) Anti-aliasing: **None** seç. Dosyalar artboard adlarıyla kaydedilir.
- **Photoshop:** 32×32 px belge aç. Fırça yerine **Pencil** aracını kullan. Preferences → General → Image Interpolation: **Nearest Neighbor** seç. File → Export → Export As → PNG ile kaydet.

## Karakter animasyonları

Klasörler:
- Warrior: `assets/characters/warrior/`
- Goblin: `assets/enemies/goblin/`

Dosya adı kuralı: **`<animasyon>_<yön>_<kare numarası>.png`**

| Animasyon | Ne zaman oynar | Yer tutucu kare sayısı | Döngü |
|---|---|---|---|
| `idle` | Dururken | 2 | Evet |
| `walk` | Yürürken | 4 | Evet |
| `attack` | Saldırırken | 4 | Hayır |
| `special` | Yetenek (oyuncu) / özel saldırı (düşman) | yok | Hayır |
| `hurt` | Hasar alınca | 2 | Hayır |
| `death` | Ölünce | 4 | Hayır |

Yönler: `right` (sağ) ve isteğe bağlı `left` (sol). Karakterler yandan görünür, aşağı/yukarı yön yoktur. Yukarı ya da aşağı giderken karakter en son baktığı yana bakar. Çapraz giderken (ör. sol+yukarı) hemen o yana döner.

Örnek: Warrior'ın sağa yürüme animasyonu
```
assets/characters/warrior/walk_right_01.png
assets/characters/warrior/walk_right_02.png
assets/characters/warrior/walk_right_03.png
assets/characters/warrior/walk_right_04.png
```

### Esnek kurallar
- **Kare sayısı serbest.** Kod `01`'den başlayıp ilk eksik numaraya kadar okur. Yürüme 6 kare olacaksa `walk_right_05.png` ve `walk_right_06.png` dosyalarını eklemen yeterli. Daha az kare kullanacaksan fazla dosyaları sil.
- **Sol yön isteğe bağlı.** `*_left_*` dosyaları yoksa sağ yön aynalanarak kullanılır. Yer tutucularda sol yön bu yüzden yok.
- **Saldırı yönü:** Görsel sadece sağa ya da sola baksa da saldırı son hareket yönüne gider. Yukarı yürüyüp saldırırsan üstteki düşmana vurursun.
- **Görselin altındaki boşluk sorun değil.** Kod, karakterin çizili en alt pikselini (ayak ya da gölge) yere basan nokta kabul eder.
- **Saldırının vuruş anı:** Hasar, saldırı animasyonunun **3. karesinde** (`attack_*_03`) verilir. Bunu değiştirmek için Godot'da Player ya da Goblin sahnesindeki `Attack Hit Frame` değerini ayarla (0'dan başlar, yani 2 = 3. kare).
- **Animasyon hızı:** Saniyedeki kare sayısı: idle 4, walk 8, attack 12, hurt 10, death 8. Değiştirmek için sahnedeki `Sprite` node'unun `Fps Overrides` alanına örneğin `{"walk": 10.0}` yaz.

- **`special` animasyonu:** Oyuncuda yeteneğin (Yer Sarsıntısı), düşmanlarda özel saldırının animasyonudur. Vuruş anı sahnedeki `Skill Hit Frame` / `Special Hit Frame` değeriyle ayarlanır. Düşmanlar vuruştan önceki karede `Special Windup` süresi kadar bekler.

## Eşya ikonları
Klasör: `assets/items/` (Woshi paketi, 32×32): `potion_health`, `potion_mana`, `gold_coin`, `gem`, `crystal`, `gold_ore`, `map`, `key`. Değerli eşyaların hangi ikonu kullandığı `scripts/items/item_data.gd` içindeki `VALUABLES` listesinde.

## Arayüz (UI) paketleri
- Can/mana barları ve düşman can barları: `addons/pixel_bars` (`PixelBar` node'u)
- Tema, pencereler, butonlar, kutular, ikonlar: `addons/pixel_ui_fantasy`. Oyun bunun kopyası olan `assets/ui/game_theme.tres` temasını kullanır.
- Font: `assets/fonts/quill_tr.fnt` (Quill + Türkçe harfler). Yazı boyutunu değiştirme, 10 px'de keskin görünür.
- Joystick görselleri hâlâ yer tutucu: `assets/ui/joystick_base.png`, `joystick_knob.png`.

## Sandık
| Dosya | Açıklama |
|---|---|
| `assets/objects/chest_closed.png` | Kapalı sandık |
| `assets/objects/chest_open.png` | Açık sandık |

## Tileset (zemin ve engeller)
Dosya: `assets/tiles/tileset.png`. **192×32** boyutunda, yan yana 6 kare (her biri 32×32):

| Sıra | Kare | Engel mi? |
|---|---|---|
| 0 | Çimen | Hayır |
| 1 | Toprak yol | Hayır |
| 2 | Parke taşı | Hayır |
| 3 | Duvar | Evet |
| 4 | Ağaç | Evet (sadece gövde) |
| 5 | Su | Evet |

Bu dosyayı **aynı düzenle** çizersen haritalar otomatik olarak senin grafiklerinle görünür. Daha fazla çeşit (çiçekli çimen, köşe parçaları, ev çatısı vb.) istediğinde Godot'da yeni bir tileset kurarız.


## Yeni düşman türü eklemek
1. `scenes/enemies/goblin.tscn` dosyasını kopyala (ör. `skeleton.tscn`).
2. Görsellerini `assets/enemies/skeleton/` klasörüne aynı isimlendirmeyle koy.
3. Yeni sahnede `Sprite` node'unun `Sprite Folder` alanını `res://assets/enemies/skeleton` yap.
4. Kök node'da can, hasar, hız gibi değerleri ayarla.

## Harita düzenlemek
- Haritalar: `scenes/maps/town.tscn` (şehir, 48×32) ve `scenes/maps/wild.tscn` (vahşi bölge, 64×40)
- **Ground** katmanı zemindir (çimen, yol). **Entities/Walls** katmanı engellerdir (duvar, ağaç, su).
- Düşman bölüğü eklemek: `Entities` altına bir **EnemyGroup** node'u ekle, içine `goblin.tscn` sahnelerini sürükle. Bölükteki herkes ölünce sandık düşer.
- Yeni harita bağlamak için:
  - `Exits` altına `scenes/world/map_exit.tscn` ekle, `Target Map` ve `Target Spawn` alanlarını doldur.
  - Hedef haritada `Spawns` altına aynı isimde bir **Marker2D** koy.
  - Haritanın boyutu değişirse kök node'daki `Map Size` değerini güncelle.

## Yer tutucuları yeniden üretmek
Bir görseli silersen yer tutucusunu geri getirebilirsin. Araç var olan dosyaların üzerine yazmaz, sadece eksik olanları oluşturur:
```
godot --headless --path . --script res://tools/generate_placeholders.gd
```
