# Oyun Tasarımı

Durum etiketleri: **[Karar]** kesinleşti · **[Öneri]** henüz onaylanmadı · **[Açık]** karar bekliyor

## Genel Bakış
- **[Karar]** Telefonda oynanan, Diablo benzeri 2D hack and slash RPG (Android)
- **[Karar]** Görsel stil: pixel art
- **[Karar]** Kamera açısı: Stardew Valley gibi üstten 3/4 görünüm
- **[Öneri]** Ekran yönü: yatay (landscape)
- **[Öneri]** Temel çözünürlük 480×270. Telefonlarda tam sayı katlarıyla (1080p'de 4×) büyütülür, böylece pikseller keskin kalır. Geniş ekranlı telefonlarda görüş yatayda genişler.

## Grafik Üretimi
- **[Öneri]** Grafikler gelene kadar yer tutucu (placeholder) görseller ya da ücretsiz bir asset paketi kullanılır. Kod grafiklere bağlı olmadan yazılır.
- **[Öneri]** Yapay zekâ konsept tasarım, eşya ikonları ve portreler için kullanılır. Tile ve animasyonlu karakterlerde yapay zekâ çıktısı elle temizlenir ya da asset paketlerinden yararlanılır.
- **[Karar]** Karakterler yandan görünür, yalnızca sağa bakan kareler çizilir. Sol yön, sağ yönün aynalanmasıyla elde edilir. Aşağı/yukarı yön yoktur.

## Dünya ve Haritalar
- **[Karar]** Dünya, birbirine bağlı ayrı haritalardan oluşur. Her harita kendi sahnesidir.
- **[Karar]** Haritalar sabit boyutlu değildir, türüne göre değişir. Şehir ya da vahşi bölge (wild lands) olabilir. Başlangıç ölçüleri:

| Harita türü | Boyut (kare) | Ekran sayısı (yaklaşık) | Yürüyerek geçiş |
|---|---|---|---|
| Vahşi bölge | 64×40 | 4×5 | ~15 sn |
| Şehir | 48×32 | 3×4 | ~11 sn |
| Küçük alan / son nokta (kale arka bahçesi gibi) | 32×24 | 2×3 | ~8 sn |

- **[Karar]** Ekran yaklaşık 15×8 kare gösterir (geniş telefonlarda yatayda ~19 kare). Kamera oyuncuyu takip eder.
- **[Karar]** Haritaların kenarlarında (kuzey, güney, doğu, batı) çıkışlar vardır. Dünyanın ucundaki haritalarda daha az çıkış bulunur.
- **[Karar]** Bir çıkışa girildiğinde bağlı harita yüklenir ve oyuncu o haritanın karşı kenarındaki girişte belirir.
- **[Karar]** Kare (tile) boyutu: 32×32 px

### Örnek dünya bağlantısı
```
[Vahşi Bölge] ←batı— [Şehir] —doğu→ [Kale] —doğu→ [Kale Arka Bahçesi] (dünyanın ucu)
```

## Sınıflar
- **[Karar]** 4 sınıf:

| Sınıf | Rol | Öne çıkan özellik |
|---|---|---|
| Paladin | Tank | Yüksek savunma, zırh ve kalkan |
| Wizard | Alan hasarı | Yüksek büyü gücü, elemental alan büyüleri |
| Warrior | Ağır yakın dövüş | Yüksek hasar, yavaş saldırı |
| Rogue | Çevik yakın dövüş | Kritik vuruş, yüksek hız |

- **[Açık]** Her sınıfın yetenek sayısı ve listesi
- **[Karar]** Warrior (şimdilik Soldier görseli) mana kullanır: 60 mana, saniyede 1 dolar
- **[Karar]** Warrior yeteneği "Yer Sarsıntısı": kılıcı yere saplar, çevresindeki tüm düşmanlara hasar verir, 20 mana
- **[Açık]** Diğer sınıfların kaynak sistemi (enerji, öfke vb.)

## Oyuncu ve Kontroller
- **[Karar]** Sol tarafta, dokunulan yerde beliren sanal joystick ile hareket
- **[Karar]** Sağ altta saldırı, yetenek, can iksiri ve mana iksiri butonları; sağ üstte altın ve çanta butonu
- **[Karar]** Klavye (test için): WASD/oklar, Space/J saldırı, K/2 yetenek, Q/1 can iksiri, E mana iksiri, I/Tab envanter

## Savaş Sistemi
- **[Karar]** Düşmanlar gruplar (bölükler) hâlinde bulunur
- **[Açık]** Hasar formülü, kritik vuruş, savunma hesabı

## Loot ve Ekonomi
- **[Karar]** Bir düşman grubu yenildiğinde sandık düşer
- **[Karar]** Sandıktan çıkabilecekler: silah, zırh, iksir, altın, satılabilir değerli eşyalar
- **[Karar]** Şehirlerde eşya alınıp satılabilir
- **[Öneri]** Nadirlik seviyeleri renklerle gösterilir: Sıradan (beyaz), Büyülü (mavi), Nadir (sarı), Efsanevi (turuncu)
- **[Karar]** Envanter: 12 kutuluk çanta (iksirler ve değerli eşyalar üst üste durur), Ekipman sekmesi silah/zırh görselleri gelince açılacak
- **[Açık]** Sınıfa özel eşyalar

## Düşmanlar
| Düşman | Özellik | Özel saldırı |
|---|---|---|
| Ork | Orta can, yavaş | Önüne baltayla yer vuruşu (alan) |
| Kan Canavarı | Az can, hızlı | Uzaktan hücum (çizgi boyunca atılma) |
| İblis | Yüksek can ve hasar | Etrafına geniş alan vuruşu |
- **[Karar]** Özel saldırılardan önce yerde kırmızı uyarı alanı belirir; oyuncu kaçabilir

## Hikâye
- **[Açık]** Dünyanın ve kahramanın hikâyesi henüz belirlenmedi

## Arayüz
_Henüz belirlenmedi._

## Geliştirme Sırası
- **[Karar]** Önce küçük bir oynanabilir dilim (vertical slice): 1 sınıf (Warrior), 1 şehir, 1 vahşi bölge, 1 düşman türü, sandık ve basit envanter. Temel sistemler oturduktan sonra içerik genişletilir.
