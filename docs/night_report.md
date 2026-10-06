# Gece Raporu (6 Ekim 2026)

Sen yokken yaptıklarımın özeti. Ayrıntılar `docs/decisions.md` dosyasının en üstünde.

## 1. Önce bunlara bak
1. **İndirme listesi:** [downloads.md](downloads.md). Zorunlu paketler 5 dolar (Zerie'nin iki tam paketi), geri kalanı ücretsiz. Her paketin nereye ve hangi klasör adıyla konacağı yazıyor.
2. **Hikâye:** [story.md](story.md). Dünya, karakterler ve hikâye akışı.
3. **Boss'lar:** [bosses.md](bosses.md). 9 boss, Kral ve Malphas'ın dövüş tasarımları.
4. **Yol haritası:** [roadmap.md](roadmap.md). Neyin bittiği, neyin beklediği.

## 2. Oyunda neler değişti
Godot'yu açıp **F5**'e bas. Oyun artık ana menüyle açılıyor.

| Sistem | Ne yapıyor |
|---|---|
| Ana menü | Devam Et, Yeni Oyun, Ayarlar, Emeği Geçenler, Çıkış |
| Dil | Türkçe ve İngilizce, ayarlardan değişiyor. Fonta Türkçe harfleri ben ekledim. |
| Kayıt | Otomatik kayıt: harita değişiminde, görev ilerleyince, dakikada bir ve uygulama arka plana alınınca |
| Prolog | Gece, Varneth yolu. Önce kısa bir anlatı, sonra ork baskını ve öğretici ipuçları |
| Şehir | 6 NPC (Ezra, Seren, Mira, Borak, Kadir, Pip), görevler, kuzeyde Kül Kalkanı |
| Görevler | 3 ana ve 6 yan görev. Görev günlüğü envanterde, HUD'da da takip ediliyor. |
| Savunma | Blok, parry (doğru anda blok), yuvarlanma, stamina (yeşil bar), denge ve sersemleme |
| Saldırı türleri | Turuncu uyarı = ağır saldırı, kırmızı uyarı = engellenemez, sadece yuvarlanarak kaçılır |
| Crafting | Yerden ot toplama, Mira'da simya (iksir yapma) |
| İlerleme | Deneyim ve seviye, Kadir'in dükkânı (al/sat), Borak'ta silah güçlendirme |
| Boss'lar | Kurt İni'nde Fenris (oynanabilir). Diğer 8 boss, Kral ve Malphas hazır, harita bekliyor. |
| Oyun sonu | Malphas yenilince bitiş ekranı |
| Ses | Altyapı hazır. Ses dosyaları gelince otomatik çalacak. |
| Yol bulma | Düşmanlar artık ağaç ve duvarların etrafından dolaşıyor |

### Bilgisayarda kontroller
- **WASD / oklar:** hareket
- **Space / J:** saldırı ve konuşma
- **L / 3:** blok ve parry
- **Shift / 4:** yuvarlanma
- **K / 2:** yetenek
- **Q / 1:** can iksiri
- **E:** mana iksiri
- **I / Tab:** envanter
- **Esc / P:** duraklat

### Denemen için kısa yol
Yeni oyun → anlatıyı geç → orkları yen → doğudaki kapıdan şehre gir → Ezra ile konuş → batı kapısından ormana çık → kuzeyden Kurt İni'ne git → Fenris.

Boss'ları tek tek denemek için:
```
godot --path . res://tools/boss_test.tscn -- --boss=velzara
```

## 3. Testler
Bütün sistemleri otomatik deneyen iki test var ve ikisi de geçiyor:
- `tools/smoke_test.tscn`: 70 kontrol (prolog, diyalog, görevler, dil, savunma, savaş, crafting, yetenek, boss, seviye, dükkân, demirci, kayıt)
- `tools/boss_test.tscn -- --all`: 10 boss'un hepsi (Kral → Malphas geçişi ve oyun sonu dahil)

Testler oyuncunun kendi kaydına dokunmuyor, kendi kayıt dosyalarını kullanıyorlar.

## 4. Bilerek yapmadıklarım
- **Commit:** Hiçbir şey commit edilmedi. Çok sayıda dosya değişti. Önce oyunu dene, beğenirsen tek bir commit atabilirsin.
- **Kalan 8 boss'un haritaları:** Tileset paketleri gelmeden harita çizmek boşa iş olurdu. Boss'lar şimdilik sadece deneme aracıyla oynanabiliyor.
- **Bazı özel boss davranışları:** Bjorn'un karşı saldırı duruşu, Velzara'nın kopyaları, Malphas'ın uçma evresi. Görseller gelince birlikte tasarlayalım.
- **Ağaç kesip mızrak yapma:** Gerekçesi roadmap.md dosyasında. Onun yerine prolog ve crafting var.

## 5. Senin kararını bekleyenler
1. **İsimler:** Oyun adı ("Kül Prensi"), Eldmar, Varneth, Aldric, Malphas ve NPC isimleri uygun mu?
2. **Zorluk:** Fenris'i oyna. Çok mu kolay, çok mu zor? Değerleri buna göre ayarlarız.
3. **Boss sırası:** Her perdenin 3 boss'u istenen sırayla yapılabiliyor. Bu serbestlik iyi mi, yoksa sıralı mı olsun?
4. **Hikâye dramı:** Kahramanın kayıp kardeşi fikri (story.md) hoşuna gitti mi?
5. **Sınıflar:** Paladin, Wizard ve Rogue için Zerie paketindeki Knight, Wizard ve Swordsman uygun mu?

## 6. Sen dönünce sıradaki adımlar
1. Paketleri indir (downloads.md'deki kısa klasör adlarıyla).
2. Ben karakterleri bölüp tileset'leri kurarım, şehir ve Kül Ormanı'nı gerçek grafiklerle yeniden yaparım.
3. Sesleri bağlarım.
4. Birlikte oynayıp dengeyi ayarlarız.
