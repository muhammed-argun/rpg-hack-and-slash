# Ajanlarla Çalışma Rehberi

Bu dosya, ana oturumun (kullanıcıyla konuşan Claude) işleri ajanlara nasıl dağıtacağını anlatır.
Kullanıcı Pro planında: kredi sınırlı. Amaç, her işi onu yapabilecek **en ucuz** modele vermek.

## Kim kimdir

| Ajan | Model | Dosya | Ne yapar |
|---|---|---|---|
| **Ana oturum (yönetici)** | Sonnet (kullanıcı seçer) | — | Kullanıcıyla konuşur, işi anlar, böler, ajanlara verir, sonucu kontrol eder, belgeleri günceller |
| `oracle` | Opus (pahalı) | `.claude/agents/oracle.md` | Büyük tasarım ve plan. Kod yazmaz |
| `neo` | Sonnet | `.claude/agents/neo.md` | GDScript kod, sahne, test |
| `hiroshi` | Haiku (en ucuz) | `.claude/agents/hiroshi.md` | Çeviri metni, görsel değiştirme, belge, JSON değeri |

Önemli: alt ajanlar başka ajan başlatamaz. Dağıtımı her zaman ana oturum yapar.

## Hangi iş kime

| İş | Kime | Örnek |
|---|---|---|
| Metin/çeviri ekleme, yazım düzeltme | `hiroshi` | "Dükkân başlığını 'Kadir'in Dükkânı' yap" |
| Kullanıcının verdiği PNG'yi yerine koyma | `hiroshi` | Portreler, ikonlar, tileset dosyaları |
| Belge düzenleme, JSON'da sayı değiştirme | `hiroshi` | Bir görevin ödül altınını 50 yap |
| Tek dosyada küçük, net kod düzeltmesi | Ana oturum kendisi | Bir sabiti değiştirmek, tek satır hata |
| Yeni özellik, birden fazla dosya, sahne, test | `neo` | Yığın sınırı, yeni pencere, yeni düşman davranışı |
| Yeni sistem tasarımı, büyük yeniden yapılanma | Önce `oracle`, sonra adım adım `neo` / `hiroshi` | Yetenek ağacı, menzilli silah, sınıf sistemi |
| Kök nedeni bulunamayan hata (2 deneme başarısız) | `oracle` | — |

Kararsızsan: oyun mantığına dokunuyor mu? Evet → `neo`. Hayır → `hiroshi`.
Çok kısa işlerde (bir iki dosya okuyup tek değişiklik) ajan çağırma; ajan sıfırdan başlar ve dosyaları yeniden okur, bu da kredi harcar.

## Ajana iş verirken (brief)
Ajan bu konuşmayı görmez. Her görevde şunları yaz:
1. **Ne istendiği**: kullanıcının isteği, mümkünse kendi cümleleriyle.
2. **Nerede**: ilgili dosya yolları (biliyorsan), ilgili sınıf/fonksiyon adları.
3. **Kabul ölçütü**: bitince ne doğru olmalı ("duman testi geçmeli", "TR ve EN eklenmeli").
4. **Kapsam sınırı**: neye dokunmamalı.
5. Kullanıcının verdiği kararlar (ör. "yığın sınırı 20, kullanıcı onayladı").

Birbirine bağlı olmayan işleri tek seferde ver (ör. 8 portre + 5 metin düzeltmesi tek `hiroshi` çağrısında).
Birbirinden bağımsız iki büyük iş varsa iki ajanı paralel çalıştırabilirsin, ama **aynı dosyaya dokunacaklarsa sırayla** çalıştır.

## İş akışı
1. Kullanıcının isteğini anla; belirsizse kullanıcıya sor (ajana sordurma).
2. Gerekirse `oracle`'dan plan al; planı kullanıcıya özetle, oyun tasarımı kararlarını kullanıcıya sor.
3. İşi uygun ajana ver.
4. Ajanın raporunu oku. Kod değiştiyse duman testi sonucunu kontrol et (ajan koşmadıysa sen koş).
5. Belgeleri güncelle: `docs/handoff.md` (durum), `docs/decisions.md` (karar/ders), gerekirse `CLAUDE.md`. Basit belge güncellemesini `hiroshi`'e verebilirsin.
6. Kullanıcıya sade bir dille, Türkçe özet ver. Commit/push'u kullanıcı yapar.

## Model seçimi (kullanıcı için)
- Ana oturum varsayılan olarak **Sonnet** olmalı. Opus'u ana oturumda sadece çok büyük bir tasarım konuşması yapılacaksa seç.
- `model:` satırı ajan dosyasında yazar; değiştirmek için o satırı `haiku`, `sonnet` ya da `opus` yap.

## Kredi tasarrufu ipuçları
- Ana oturumu uzun tutma: bir iş bitince yeni oturum açmak, konuşma geçmişinin büyümesini önler. Durum zaten `docs/handoff.md`'de.
- `oracle`'ı (Opus) sadece gerçekten büyük işlerde çağır.
- Haiku'ya verilen işler net ve mekanik olmalı; yorum gerektiren işi Haiku'ya verme, yanlış yapıp tekrar ettirmek daha pahalıya gelir.
