# Oyun Tasarımı

Durum etiketleri: **[Karar]** kesinleşti · **[Öneri]** henüz onaylanmadı · **[Açık]** karar bekliyor · **[Yapılacak]** kararlaştırıldı ama henüz kodlanmadı

## Genel bakış
- **[Karar]** 2D pixel art hack and slash RPG. Diablo'nun loot ve ilerleme sistemi, Hades'in savaş hissi.
- **[Karar]** Platform: **PC (Windows) öncelikli, Steam Deck ve gamepad destekli.** Mobil (Android) ileride port olarak gelebilir. (2026-10-06 kararı; proje mobil olarak başlamıştı.)
- **[Karar]** Oyun adı (öneri olarak kullanılıyor): "Kül Prensi / Prince of Ash". **[Açık]** Kullanıcı isimleri onaylamadı.
- **[Karar]** Ton: karanlık fantastik, dram var ama vahşet yok. Ayrıntı: `story.md`.
- **[Karar]** Kamera: üstten 3/4 görünüm (Stardew Valley gibi), oyuncuyu takip eder.
- **[Karar]** Çözünürlük: temel 480×270, tam sayı ölçekleme (1080p'de 4 kat, 4K'da 8 kat). Pikseller keskin kalır.
- **[Karar]** Diller: Türkçe ve İngilizce, ayarlardan değişir.

## Kontroller (PC)
- **[Yapılacak]** Hareket: WASD (gamepad: sol çubuk)
- **[Yapılacak]** **Hades tarzı nişan:** Saldırı imlecin gösterdiği yöne yapılır. Karakter imlecin bulunduğu yana döner. Gamepad'de nişan sağ çubukla alınır. İleride menzilli silahlar ve büyüler de aynı nişanı kullanacak.
- **[Yapılacak]** Sol tık: saldırı (basılı tutunca sürekli)
- **[Yapılacak]** Yetenekler: E, R, T (3 aktif yuva)
- **[Yapılacak]** Hızlı kullanım: 1 ve 2. Hangi eşyayı kullanacağı envanterdeki sıraya göre belirlenir (varsayılan: 1 = can iksiri, 2 = mana iksiri).
- **[Yapılacak]** Blok/parry, yuvarlanma, etkileşim (F), envanter (I), karakter (C, aynı pencere), duraklatma (Esc)
- **[Yapılacak]** Bütün tuşlar ayarlardan değiştirilebilir (klavye ve gamepad).
- **[Yapılacak]** Özel imleç: Pixel UI Fantasy paketindeki cursor.
- **[Karar]** Ekrandaki dokunmatik kontroller (joystick, butonlar) PC'de kaldırılacak; kodları mobil port için saklanıyor.

## Dünya ve haritalar
- **[Karar]** Dünya birbirine bağlı ayrı haritalardan oluşur. Her harita ayrı bir sahne; kenarlardaki çıkışlar diğer haritalara bağlanır.
- **[Karar]** Kare boyutu 32×32 px. Harita boyutları türüne göre değişir: vahşi bölge 64×40, şehir 48×32, küçük alan/arena 32×24 ile 40×30 arası.
- **[Karar]** Yapı: Prolog (Varneth Yolu) → Varneth (şehir, merkez) → 9 bölge (3 perde × 3) → Kale. Ayrıntı: `story.md`, `roadmap.md`.
- **[Karar]** Her bölgenin sonunda bir boss arenası var. Boss yenilince 1 kristal parçası düşer. 9 parça Kül Kalkanı'nı kırar, kalede Kral ve Malphas dövüşü olur.
- **[Öneri]** Ziyaret edilen bölgelere şehirden ışınlanma (waypoint).

## Karakterler ve sınıflar
- **[Karar]** Karakterler yandan görünür: sadece sağa bakan kareler var, sola bakış aynalamayla yapılıyor.
- **[Karar]** 4 sınıf:

| Sınıf | Rol | Öne çıkan özellik | Görsel (Zerie paketi) |
|---|---|---|---|
| Warrior | Ağır yakın dövüş | Yüksek hasar | Soldier (şu an oynanan) |
| Paladin | Tank | Savunma, kalkan | Knight **[Öneri]** |
| Wizard | Alan hasarı | Elemental büyüler | Wizard **[Öneri]** |
| Rogue | Çevik | Kritik vuruş, hız | Swordsman **[Öneri]** |

- **[Karar]** Şimdilik tek sınıf oynanabilir (Warrior). Yeteneği **Yer Sarsıntısı**: kılıcı yere saplar, çevresindeki herkese vurur, 20 mana harcar.
- **[Yapılacak]** Özellikler (attributes): STR, AGI, INT, VIT (ya da benzeri). Şimdilik hepsi 10, etkileri sonra tasarlanacak. Seviye atlayınca özellik puanı verilir; sıklığı **[Açık]** (ör. her 3 seviyede bir).
- **[Yapılacak]** Yetenek ağacı: açılan yeteneklerden 3'ü E/R/T yuvalarına konur.
- **[Açık]** Diğer sınıfların kaynak sistemi (mana, enerji, öfke).

## Savaş sistemi
- **[Karar]** Hades benzeri, okunabilir ve hızlı savaş.
- **[Karar]** Stamina: blok, parry ve yuvarlanma stamina harcar.
- **[Karar]** Blok hasarın %80'ini keser. Blok tuşuna vuruştan hemen önce (0,2 sn içinde) basılırsa **parry** olur: düşman sersemler, kısa bir yavaşlama efekti çıkar.
- **[Karar]** Yuvarlanma kısa süre dokunulmazlık verir.
- **[Karar]** Saldırı türleri: normal (bloklanır), ağır (turuncu uyarı, stamina'yı çok tüketir), engellenemez (kırmızı uyarı, sadece yuvarlanarak kaçılır).
- **[Karar]** Denge (poise): yeterince hasar alan düşman sersemler ve fazladan hasar alır.
- **[Karar]** Düşmanlar bölükler hâlinde dolaşır; özel saldırılardan önce yerde uyarı alanı belirir.

## Düşmanlar ve boss'lar
| Düşman | Özellik | Özel saldırı |
|---|---|---|
| Ork | Orta can, yavaş | Önüne baltayla alan vuruşu (ağır) |
| Kan Canavarı | Az can, hızlı | Uzaktan hücum (ağır) |
| İblis | Yüksek can ve hasar | Etrafına geniş alan vuruşu (engellenemez) |

- **[Karar]** 9 boss + Kral Aldric + Malphas. Tasarımları: `bosses.md`.

## İlerleme, loot ve ekonomi
- **[Karar]** Düşmanlar deneyim verir. Seviye atlayınca can, mana ve hasar artar.
- **[Yapılacak]** Yeni XP formülü: bir sonraki seviyenin gerekli XP'si, öncekinin 1,6 katı, yukarıya, 100'ün katına yuvarlanır. **[Açık]** Başlangıç değeri (öneri: 1→2 için 100).
- **[Karar]** Bir bölük yenilince sandık düşer: altın, iksirler, değerli eşyalar. Silah ve zırh, ekipman sistemi gelince düşmeye başlayacak.
- **[Karar]** Nadirlik renkleri: Sıradan (beyaz), Büyülü (mavi), Nadir (sarı), Efsanevi (turuncu).
- **[Karar]** Dükkân (Kadir): iksir alınır, değerli eşya satılır. Demirci (Borak): cevher + altınla silah +1'den +10'a güçlenir.
- **[Karar]** Crafting: yerden ot toplanır, Şifacı Mira'da iksir yapılır.
- **[Yapılacak]** Envanter + karakter penceresi (birleşik, I ve C aynı pencereyi açar):
  - Sol: 6×6 = 36 yuvalı çanta
  - Sağ: ekipman yuvaları (kask, zırh, eldiven, ayakkabı, pelerin...), iki silah seti (ana el + ikinci el; çift elli silah ikinci eli kilitler), 3 mühimmat türlü sadak, özellikler, seviye, azami can ve mana, XP barı (fareyle üstüne gelince "350/1000" yazar)

## Arayüz
- **[Karar]** Tema: Pixel UI Fantasy (parşömen) + Pixel Bars (can/mana/stamina, düşman ve boss barları).
- **[Karar]** HUD sol üst: can, mana, stamina, seviye ve XP, takip edilen görev. Sağ üst: altın. Üst orta: boss barı. Orta: olay mesajları.
- **[Yapılacak]** PC HUD'u: alt ortada yetenek çubuğu (E/R/T) ve hızlı kullanım yuvaları (1/2).
- **[Karar]** Pencereler açıkken oyun duraklar.

## Grafik ve ses
- **[Karar]** Hazır asset paketleri kullanılır (listesi: `downloads.md`). Eksik küçük parçaları (ikon, efekt, arayüz) Claude kodla çizebilir.
- **[Karar]** Ses altyapısı hazır. Ses dosyaları gelince `data/audio.json` adlarına göre bağlanacak.
