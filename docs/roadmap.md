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
- Şehirden bölgelere **seyahat kapısı (Waypoint)**: Diablo'daki gibi, ziyaret edilen bölgelere şehirden ışınlanma. Uzun yürüyüşleri kısaltır.

## Sistemler

### Çekirdek (2026-10-06 gecesi yapıldı)
| Sistem | Durum | Not |
|---|---|---|
| Türkçe / İngilizce dil desteği | ✅ | `data/translations/*.csv`, ayarlardan değişiyor |
| Ana menü, ayarlar, duraklatma, çıkış onayı | ✅ | Ses düzeyleri, dil, titreşim |
| Kayıt / yükleme | ✅ | Otomatik kayıt: harita değişiminde, görev ilerleyince, dakikada bir |
| Stamina (yeşil bar) | ✅ | Blok, parry ve yuvarlanma harcar |
| Blok ve parry | ✅ | Basılı tut = blok, doğru anda bas = parry |
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
| Android dışa aktarma ayarı | ✅ | `export_presets.cfg`, JSON verileri dahil (PC ayarları eklenecek) |
| Mini harita | 💡 | Köşede küçük harita |
| Steam başarımları | 💡 | GodotSteam eklentisiyle |
| Hikâye sinematikleri | 💡 | Basit konuşma sahneleri: kamera kayması + diyalog |

### Neden "ağaç kesip mızrak yapma" yok?
Oyunun açılışında malzeme toplamak tempoyu düşürür; oyuncu ilk dakikalarda dövüşmek ister. Onun yerine:
- **Prolog** oyuncuyu doğrudan dövüşe sokuyor.
- **Crafting** isteğe bağlı ve ödüllendirici: otlardan iksir yapmak, cevherle silah güçlendirmek.

## Aşamalar

### Aşama 0: PC'ye geçiş (ŞU ANKİ İŞ)
Ayrıntılı iş listesi: `handoff.md` 3. bölüm.
- [x] Ekrandaki dokunmatik kontrolleri kaldır (kodu mobil port için sakla), fare ile dokunma taklidini kapat
- [ ] Ayarlara tuş atama ekranı (klavye/fare + gamepad), atamaların kaydı
- [ ] Hades tarzı nişan: WASD ile hareket, imlece (gamepad'de sağ çubuğa) doğru saldırı, özel imleç
- [ ] Yetenek yuvaları E/R/T, hızlı kullanım yuvaları 1/2 (ayrı etkileşim tuşu F yapıldı)
- [ ] Birleşik envanter + karakter penceresi (I/C): 36 yuvalı çanta, ekipman yuvaları, iki silah seti, sadak, özellikler, XP barı
- [ ] Yeni XP formülü (1,6 kat, 100'e yukarı yuvarlama), seviye atlayınca özellik puanı
- [ ] Tam ekran/çözünürlük/V-Sync ayarları; Windows ve Linux (Steam Deck) dışa aktarma ayarları
- [x] Öğretici ipuçlarını PC kontrollerine göre yeniden yaz (tuş adları ayarlardaki atamadan okunuyor)

### Aşama 1: Dikey dilim
Hedef: Prolog + Varneth + 1 bölge (Kül Ormanı) + Fenris + şehir görevleri + crafting, baştan sona oynanabilir.
- [x] Temel savaş, loot, envanter, mana ve yetenek
- [x] Dil (TR/EN), ana menü, ayarlar, duraklatma, kayıt/yükleme
- [x] Stamina, blok, parry, yuvarlanma, denge ve sersemleme, engellenemez saldırılar
- [x] NPC'ler ve diyaloglar, 3 ana ve 6 yan görev, görev günlüğü, ot toplama ve simya
- [x] Boss altyapısı, Kurt İni arenası, Fenris (yer tutucu görselle), kristal parçası, Kül Kalkanı
- [x] Dükkân, demirci, deneyim ve seviye, yol bulma, prolog, öğretici ipuçları, ses altyapısı
- [ ] Paketler gelince: tileset'lerle Varneth ve Kül Ormanı, NPC ve Fenris görselleri, sesler

### Aşama 2: 2. Perde
Batık Mezarlık + Taş Labirent haritaları, Morvane + Asterion (boss verileri hazır), ekipman sistemi, sınıf seçimi.

### Aşama 3: 3. ve 4. Perde
Kalan 6 bölge ve boss haritaları, Ezra'nın kaçırılma olayı, Corvin draması, yetenek ağacı.

### Aşama 4: Final ve cila
Kale, Kral ve Malphas (verileri hazır), son sahne (hazır), özel boss davranışları, ses ve müzik cilası, denge ayarları.

### Aşama 5: Yayın
Windows/Linux dışa aktarma, Steam Deck testi, Steam sayfası, kredi ekranı. Mobil port isteğe bağlı.