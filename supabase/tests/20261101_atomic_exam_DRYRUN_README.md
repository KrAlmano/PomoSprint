# 1 Kasım 2026 — Deneme ve lig geçişi için SQL Editor DRYRUN

> **Tarihsel:** Canlı DRYRUN ve ardından kurulum 1 Kasım'da tamamlandı. Bu dosyayı veya eski kurulum paketini tekrar çalıştırmayın. [Canlı sonuç](../../analiz/ATOMIK_DENEME_ADAYI_2026-11-01.md).

**Bu adım kurulum değildir.** [SQL Editor DRYRUN](20261101_atomic_exam_DRYRUN_SQL_EDITOR.sql) tek işlem içinde aday değişiklikleri, 14 koruma kontrolünü ve ardından `ROLLBACK` çalıştırır. Canlı veritabanında bu test henüz çalıştırılmamıştır. **İnceleme altındaki kurulum ve geri alma dosyalarını çalıştırmayın.**

## SQL Editor'de

1. Canlı Supabase projesinin SQL Editor'ünde [DRYRUN dosyasının](20261101_atomic_exam_DRYRUN_SQL_EDITOR.sql) tamamını tek seferde çalıştırın; kodun yalnız seçili bir bölümünü çalıştırmayın. Aynı anda başka bir yönetici cron ayarını değiştirmesin.
2. Hata yoksa 14 kontrolün tamamı `true` olur; son sonuç satırı **“14/14 kontrol başarılı; işlem geri alındı. Kurulum yapılmadı.”** der. Son satırdan önce herhangi bir hata görüldüyse başarı saymayın; hatayı ve sonucu paylaşın. SQL Editor'ün bu projedeki çoklu sorgu/son sonuç gösterimi henüz canlıda doğrulanmamıştır.
3. Dosya `ROLLBACK` ile biter ve sonrasında yalnız bilgi veren bir `SELECT` çalışır. Kalıcı kurulum, yayın veya kullanıcı verisi silme yapılmaz. Ancak bu **`READ ONLY` sorgusu değildir**: işlem içinde geçici şema, katalog ve cron değişikliği denenir; bunlar geri alınır. Gerçek kullanıcı veya sahte test hesabı oluşturulmaz, e-posta gönderilmez.

## Etki ve durma koşulları

- Başta `profiles` üzerinde `ACCESS EXCLUSIVE`, diğer ilgili tablolarda `SHARE ROW EXCLUSIVE` kilitleri **NOWAIT** alınır. Çakışan etkin işlem varsa test kendi işlemini beklemeden hata ile durdurur. Kilitler alındıktan sonra test bitene kadar profil okumaları dahil diğer işlemler bekleyebilir. Sonraki kilitler için `lock_timeout=2s`, her ayrı komut için `statement_timeout=120s` uygulanır; bunlar tüm işlemin süresi için garanti değildir.
- Yerel, ağsız gerçek pg_cron içeren **sentetik** ortamda işlem yaklaşık 0,8 saniye sürdü; bu rakam canlıda gecikme garantisi değildir. Testi düşük trafik zamanında çalıştırın. Oturum rolü uygun değilse, kaynak fonksiyonlar veya cron değişmişse, ay sınırına 5 dakika içindeyse ya da bir kontrol geçmezse test hata ile durur. Hata mesajını değiştirerek guard'ları kaldırmayın.
- Önceden oluşturulmuş gerçek profiller, seanslar, ligler, üyelikler, başlangıç kayıtları ve avatar açılışları işlem içinde özetlenip aynı kaldıkları sınanır. Kişisel satır içerikleri sonuçta gösterilmez. Testin bittiğini ve sunucunun eski durumda olduğunu ayrıca salt okunur kontrol etmek gerekir.
- Aday sırası **27 → 28 → 29 → 30 → 32**; 31 dahil değildir. Tüm gövdeler tek transaction'da denenir: eski düşük ödüllü 28 ile güncel ödüllü 32 ayrı commit edilmez. Bu test, canlıda uygulanacak kurulum paketine onay veya güvenlik garantisi değildir.
- 29 numaralı paket Kasım 2026 içinde kurulursa aylık normal lig **1 Aralık 2026 00.00 İstanbul** saatinde etkinleşir; o zamana kadar eski lig devam eder. Aday cron günlük çalışır; eski motorun günlük çağrıları profil kilidi nedeniyle mevcut haftalık düzene göre ek yük yaratabilir. Aday normal çevrimdışı seans ödül riskini tek başına çözmez.

## Yerel kanıt ve sınırı

12 ilgili canlı fonksiyonun hash'i kişisel veri taşımayan yerel şemayla eşleşti; canlı salt okunur kontrolde Deneme tabloları yok, eski cron sahibinin ve veritabanının `postgres` olduğu görüldü. Ayrı, `--network none` Docker ortamında gerçek `pg_cron 1.6.4`, tek sahte profil ve tek sahte seansla DRYRUN 14/14 geçti; geri alma sonrası tablo/migration/cron eski durumdaydı. Eşzamanlı profil kilidinde NOWAIT reddi ve veri/pending hedef içeren ters işlemin durması da yalnız izole ortamda kontrol edildi. SQL Editor rolü, canlı lock davranışı, gerçek ağ ve kullanıcı akışı bu yerel turla doğrulanmış değildir.
