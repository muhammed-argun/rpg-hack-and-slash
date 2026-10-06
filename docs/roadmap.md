# Yol Haritası

Durum işaretleri: ✅ bitti ve test edildi · 🔨 kodlandı, görsel bekliyor · ⏳ sırada · 💡 fikir aşamasında

## Büyük resim

```
Prolog (yol) → Varneth (şehir, merkez)
                 │
     ┌───────────┼────────────┐
  Kül Ormanı  Batık Mezarlık  Taş Labirent        ← 2. Perde (3 boss, istenen sırayla)
     └───────────┼────────────┘
          (3 parça) Ezra kaçırılır
     ┌───────────┼────────────┐
 Çürük Bataklık  Ayı Dağları  Yıkık Manastır      ← 3. Perde
     └───────────┼────────────┘
          (6 parça) Ezra kurtarılır
     ┌───────────┼────────────┐
  Kül Vadisi  Kara Kale Kapısı  Kül Tapınağı      ← 4. Perde
     └───────────┼────────────┘
          (9 parça) Kalkan kırılır
                 │
        Kale → Kral Aldric → Malphas → Son
```

### Harita planı
- Her bölge 2 haritadan oluşur: **giriş + NPC kampı** ve **derinlik + boss arenası**.
- Toplamda yaklaşık 9 × 2 = 18 bölge haritası, artı şehir, prolog ve kale.
- Bunların hepsini tek tek elle çizmek çok iş. Bu yüzden:
  - Haritaları tileset'ler gelince **yarı otomatik araçla** üreteceğiz.
  - Bölge başına bir "tema" (zemin, engeller, renk tonu) ve bir yerleşim şablonu olacak.
  - Sonra elle cilalayacağız (ev, NPC, sandık yerleri).
- Şehirden bölgelere **seyahat kapısı (Waypoint)**: Diablo'daki gibi, ziyaret edilen bölgelere şehirden ışınlanma. Mobilde uzun yürüyüşleri kısaltır.

## Sistemler

### Çekirdek (bu gece)
| Sistem | Durum | Not |
|---|---|---|
| Türkçe / İngilizce dil desteği | ✅ | `data/translations/*.csv`, ayarlardan değişiyor |
| Ana menü, ayarlar, duraklatma, çıkış onayı | ✅ | Ses düzeyleri, dil, titreşim |
| Kayıt / yükleme | ✅ | Otomatik kayıt: harita değişiminde ve görev ilerleyince. Mobilde şart. |
| Stamina (yeşil bar) | ✅ | Blok, parry ve yuvarlanma harcar |
| Blok ve parry | ✅ | Kalkan butonu: basılı tut = blok, doğru anda bas = parry |
| Yuvarlanma (dodge) | ✅ | Kısa dokunulmazlık süresi (i-frame) |
| Denge (poise) ve sersemleme (stagger) | ✅ | Düşmanlar ve oyuncu için |
| Engellenemez saldırılar | ✅ | Kırmızı parlama, sadece yuvarlanarak kaçılır |
| NPC ve diyalog sistemi | ✅ | Veri dosyalarından okunuyor, TR/EN |
| Görev sistemi ve görev günlüğü | ✅ | Öldür, topla, konuş, git; ödüller |
| Kristal parçaları ve Kül Kalkanı | ✅ | 9 parça toplanınca kalkan kırılır |
| Boss altyapısı | ✅ | Fazlar, saldırı kalıpları, boss barı, arena kilidi |
| 9 boss + Kral + Malphas (veri) | 🔨 | Hepsinin sahnesi ve saldırıları hazır, yer tutucu görsellerle test edildi. Görseller ve haritaları bekliyor |
| Oyun sonu | ✅ | Malphas yenilince bitiş ekranı |
| Ot toplama ve iksir yapma (crafting) | ✅ | Mira'da tarifler |

### Sonraki adımlar
| Sistem | Durum | Not |
|---|---|---|
| Dükkân (al/sat) | ✅ | Kadir. Değerli eşyalar burada satılacak |
| Silah güçlendirme | ✅ | Borak. Cevher + altın → +1 silah seviyesi |
| Deneyim ve seviye | ✅ | Diablo hissi için önemli. Seviye atlayınca can, mana ve hasar artar. |
| Ekipman sekmesi | ⏳ | Shikashi ikonları gelince silah ve zırh düşmeye başlar |
| Seyahat kapıları (waypoint) | ⏳ | Şehirden bölgelere ışınlanma |
| Ses ve müzik | 🔨 | Altyapı ve olay bağlantıları hazır (`data/audio.json`). Dosyalar bekleniyor |
| Sınıf seçimi (Paladin, Wizard, Rogue) | ⏳ | Zerie paketleri gelince. Her sınıfın kendi yeteneği. |
| Düşman yol bulma (navigation) | ✅ | Harita açılırken engellerden navigasyon alanı çıkarılıyor |
| Prolog ve öğretici ipuçları | ✅ | Gece yolu, anlatı kartı, ork baskını, ilk dakikalarda ipuçları |
| Android dışa aktarma ayarı | ✅ | `export_presets.cfg`, JSON verileri dahil |
| Mini harita | 💡 | Köşede küçük harita |
| Günlük ödül, başarımlar | 💡 | Mobil oyuncuyu geri getirir |
| Hikâye sinematikleri | 💡 | Basit konuşma sahneleri: kamera kayması + diyalog |

### Neden "ağaç kesip mızrak yapma" yok?
Mobil oyuncu ilk dakikalarda dövüşmek ister. Oyunun açılışında malzeme toplamak tempoyu düşürür. Onun yerine:
- **Prolog** oyuncuyu doğrudan dövüşe sokuyor.
- **Crafting** isteğe bağlı ve ödüllendirici: otlardan iksir yapmak, cevherle silah güçlendirmek.

## Mobil kontrol düzeni (yeni)
```
 [Can][Mana][Stamina]                [Altın] [Çanta]
 [Görev takibi]                       [Duraklat]

                                   [İksir] [Mana İks.]
 (Joystick)                      [Yetenek] [Kalkan]
                                   [Yuvarlan] [SALDIRI]
```
- **Kalkan:** basılı tut = blok, saldırıdan hemen önce bas = parry
- **Yuvarlan:** joystick'in gösterdiği yöne kısa bir atılma
- **Etkileşim:** Bir NPC'ye yaklaşınca saldırı butonunun üstünde **"Konuş"** balonu belirir. Ayrı bir buton gerekmez.

## Aşamalar

### Aşama 1: Dikey dilim (şu anki hedef)
Hedef: Prolog + Varneth + 1 bölge (Kül Ormanı) + Fenris + 3 şehir görevi + crafting. Baştan sona oynanabilir olacak.
- [x] Temel savaş, loot, envanter, mana ve yetenek
- [x] Dil (TR/EN), ana menü, ayarlar, duraklatma, kayıt/yükleme
- [x] Stamina, blok, parry, yuvarlanma, denge ve sersemleme, engellenemez saldırılar
- [x] NPC'ler ve diyaloglar, 3 ana ve 6 yan görev, görev günlüğü, ot toplama ve simya
- [x] Boss altyapısı, Kurt İni arenası, Fenris (yer tutucu görselle), kristal parçası, Kül Kalkanı
- [ ] Paketler gelince: tileset'lerle Varneth ve Kül Ormanı haritaları, NPC görselleri, Fenris'in görseli, sesler

### Aşama 2: 2. Perde tamam
Batık Mezarlık + Taş Labirent, Morvane + Asterion, dükkân, silah güçlendirme, deneyim ve seviye.

### Aşama 3: 3. ve 4. Perde
Kalan 6 bölge ve 6 boss, Ezra'nın kaçırılma olayı, Corvin draması.

### Aşama 4: Final ve cila
Kale, Kral ve Malphas, son sahne, sınıf seçimi, ses ve müzik cilası, denge ayarları.

### Aşama 5: Yayın
Android dışa aktarma ayarları, performans testleri (eski telefonlarda), Google Play sayfası, kredi ekranı.

## Bu gece yaptıklarımın özeti
Sen döndüğünde en güncel durum için `docs/decisions.md` dosyasının en üstüne bak. Bu tablo da işler bittikçe güncellenecek.
