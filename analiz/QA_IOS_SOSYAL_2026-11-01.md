# iOS arkadaşlık ve sosyal görünüm kontrolü — 1 Kasım 2026

Yerel Supabase ve tek iPhone 17 simülatörü kullanıldı. Test, normal uygulamalar ve sürmekteki 50 dakikalık Android QA seansı yerine ayrı `com.pomosprint.qa.nov1social` uygulama kimliğinde yürütüldü. Canlıya istekle test hesabı oluşturulmadı; cihaz veya mevcut hesaplar sıfırlanmadı.

## Kapsam ve sonuç

- `nov1-social-1101` koşusu öncesinde aynı etiketli hesap/manifest ve QA bundle yokluğu kontrol edildi. Sonra yalnız yerelde yeni dokuz etiketli hesap açıldı: bir gözlemci ve sekiz arkadaş. Arkadaş istekleri/kabulü gerçek yerel RPC'lerle iki yönde doğrulandı.
- Gözlemcinin sunucu yanıtında sekiz benzersiz arkadaş, dört odak, iki mola ve iki deneme durumu doğrulandı. Native sosyal ekranda her kişinin adı, durumu ve durum noktası Türkçe ve İngilizcede kontrol edildi.
- Bir QA arkadaşının durumu odaktan molaya çevrildi. Kullanıcı manuel yenileme veya sekme değiştirme yapmadan açık ekranda doğal yaklaşık 30 saniyelik periyodik sorgu değişimi gösterdi. Bu, sunucu push/gerçek zamanlı soket iddiası değildir.
- `integration_test/q_social_eight_accounts_test.dart`: **1/1 PASS**, süreç çıkışı **0**. Testin toplam süresi 44 saniyeydi; sosyal güncelleme için bekleme bu sürenin içindedir.

## Güvenli temizlik ve sınırlar

Başarılı testten sonra manifestte dokuz benzersiz kimlik, roller ve tam QA e-posta eşlemesi; veritabanında dokuz kaydın bu koşuya ait metadata'sı ve yeni oluşturulma koşulu doğrulandı. Ardından fixture'ın kendi UID + tam e-posta + run etiketi guard'lı temizliği kullanıldı. Son salt okunur kontrolde bu fixture'a ait hesap **0**, sürmekte olan ayrı Android 50 dakika QA hesabı **1** bulundu. Başka kullanıcı veya fixture topluca silinmedi. Teste ait geçici host kontrollü kapatıldı.

Bu, bir native gözlemci ve API ile yönetilen sekiz hesaptır; dokuz eşzamanlı native cihaz, fiziksel cihazlar, tamamlanmış Maraton, sınavların gerçek süre bitişi veya canlı çok kullanıcılı performans testi değildir. Daha önceki tarihli testler bu koşuya eklenerek yeni test sayısı üretilmemiştir.

Kurulum, native tur ve temizliğin kimlik bilgisi içermeyen gerekli kanıt satırları [kalıcı kanıtta](kanit_2026-11-01/ios/social-safe.txt) saklanır; ham geçici günlükler ve ekranlar sürüm kontrolüne eklenmez.
