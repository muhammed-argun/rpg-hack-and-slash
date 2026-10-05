# Kararlar ve Dersler

Her kayıt: tarih, karar/ders, kısa gerekçe. En yeni kayıt en üste eklenir.

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
