# Sunucu, rapor ve ödül kontrolü — 1 Kasım 2026

Bu kontrol üretime yazmadan yapıldı. Kullanıcı hesabı açılmadı, e-posta gönderilmedi, veritabanı kaydı veya sunucu yapılandırması değiştirilmedi. API anahtarı ve kişisel bilgi bu rapora kaydedilmedi.

## Canlı servis

- Supabase Auth health ve settings HTTP 200, lig yapılandırması HTTP 200; `pomosprint.app` HTTP 200. Avatar API'si HTTP 206, 48 katalog kaydı ve 47 aktif avatar bildirdi.
- Yönetim API'siyle `BEGIN READ ONLY` işleminde 4 kullanıcı, 4 profil ve 9 seans görüldü. Eksik profil ilişkili seans, tekrar eden istemci UUID'si, 25/50 dakika dışı seans, negatif puan/kum, 25 kişiyi aşan lig odası ve RLS kapalı public tablo sayıları sıfırdı. Bu kontroller kapsamlı güvenlik veya veri doğruluğu sertifikası değildir.
- Son yedi günde 3 aktif zamanlanmış işe ait 15 çalıştırmanın 15'i başarılıydı. Bu yalnızca sorgunun yapıldığı andaki kayıtlardır.
- `complete_study_session` fonksiyonunun canlı gövdesi salt okunur incelendi: başlangıcı 24 saatten eski seansı reddeder. Günlük/diğer sınırlar dolmadığında 25 ve 50 dakikalık normal seansların her biri 20 kum verir; temel puanlar sırasıyla 5 ve 12'dir. Duraklatma kesintisi ve seri bonusu ayrıca uygulanabilir. Bu, canlıda yeni bir seans veya ödül oluşturularak sınanmadı.
- **Ödül bütünlüğü riski:** Sunucuda eşleşen başlangıç bulunmadığında normal seansın başlangıç zamanı istemci beyanından alınabiliyor; doğrulanmamış seanslar için ayrı günlük ödül limiti canlıda NULL. Bu nedenle değiştirilmiş bir istemcinin geçmiş seans beyanıyla puan/kum alma riski vardır. Genel günlük 16 ödüllü seans sınırı ve bitişte 5 dakikalık tolerans bulunur; canlıda istismar veya yazma denenmedi.
- Önerilen 30 paketi başlangıç kaydı kotasının yarışını düzeltir; bu ödül riskini çözmez. İstemci şu anda o başlangıç kayıt RPC'sini kullanmadığından, doğrulanmamış ödül limitini aniden sıfırlamak veya düşürmek dürüst mevcut kullanıcıları da etkiler. Çözüm için çevrimiçi başlangıç doğrulaması ve idempotent makbuz, eski sürümlere geçiş, çevrimdışı başlangıçların süre/seri/ödül politikası ve ayrı yerel güvenlik/rollback testleri birlikte tasarlanmalıdır. Bu turda politika veya canlı yapılandırma değiştirilmedi.
- **Canlıda Deneme şeması henüz yok:** `public.get_exam_config` fonksiyonu ve `public.exam_attempts` tablosu salt okunur şema sorgusunda bulunmadı. Dolayısıyla bu daldaki Deneme akışı, raporları ve ödülleri canlıda kullanılabilir veya doğrulanmış sayılamaz. Önerilen 27 → 28 → 29 → 30 → 32 paketleri kullanıcı kararı ve ilgili yayın incelemesi olmadan canlıya uygulanmadı; 31 ayrıca kullanıcı kararı bekler.
- Gerçek seans bitirme, gerçek e-posta teslimi, canlı kullanıcı girişi, canlı Deneme ve gerçek cihaz testleri bu sunucu kontrolünün kapsamında değildir.

## Resend ve e-posta bağlantısı

- `smtp.resend.com:587` karşılama/EHLO 250 ve STARTTLS 220 döndürdü; sertifika ve sunucu adı doğrulamasıyla TLS 1.3 bağlantısı kuruldu. Sertifika sonu 2 Aralık 2026. SMTP AUTH, DATA veya e-posta gönderimi yapılmadı; bu kontrol gerçek teslimi doğrulamaz.
- DNS'te Resend gönderim alanı için SPF/MX ve ana alan adı için DMARC (`p=none`) kayıtları var. Bu DNS sorgusu sağlayıcı panelindeki güncel domain doğrulama durumunu kanıtlamaz.
- Supabase Edge secret **adları** salt okunur listelendi: `RESEND_API_KEY` mevcut, `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` yok. Hoş geldin/bülten gönderen kimliği eksikliği sürüyor; kullanıcının daha sonra vereceği resmî bilgiler uydurulmadı. Secret değerleri okunmadı.
- Safari'de açık Resend oturum sekmesi ve süreç ortamında Resend anahtarı bulunamadı. Proje yönergesi `scripts/.env` içeriğinin okunmasını yasakladığı için sağlayıcı panelinin şu anki domain verified, kota ve teslim durumları bu tur doğrulanamadı. 27 Ekim'deki sonuçlar güncel sonuç olarak sunulamaz.

## Yerel kopya ve testler

- Docker yeniden açılınca mevcut `pomosprint_review32_kpss` yerel DB'si salt okunur kontrol edildi; şema, migration, katalog, mail trigger ve policy paritesi **5/5** geçti. 31 kurulu değildir.
- 15 yerel QA hesabının mevcut verileri üzerinde bağımsız rapor/cüzdan oracle'ı **681/681**, ek olarak bir QA hesabının sınav ve ders sonuçlarına ikinci bir QA hesabının erişememesi dahil **61/61** kontrolü geçti. Kontroller mevcut kayıtların tutarlılığıdır; yeni bir sınav tamamlama akışı değildir.
- Model ve kontrol regresyonları: `test_verify_reports_and_exams.py` **35/35**, izole servis güvenlik kontrolleri `test_isolated32_stack.py` **10/10** geçti. İlk grup karışık çalışma, vazgeçme, 04.00 ve ay sınırı, saat dilimi, AYT erken bitişi, eski ödül snapshot'ı ve ayrı cüzdanları kapsar; Python model testleri native ya da gerçek zamanlı uçtan uca test değildir.
- Yerel KPSS kopyasında ayrıca tek işlem içinde sentetik hesaplarla SQL RPC turu yapıldı ve işlem **ROLLBACK** edildi: 20 türün tam kum/puanı, tekrar tamamlama ve normal cüzdan ayrımı (20×3 kontrol); AYT dışı 19 türde erken bitişin reddi ve durumun korunması; AYT 90 dakika 72 kum/18 puan; 35 doğru 4 yanlışta 34 net; başka kullanıcıdan deneme ve ders sonucunu gizleyen RLS. **83/83** kontrol geçti. Süreleri sınamak için yalnız işlem içindeki sentetik denemelerin başlangıç saatleri geriye alındı; gerçek süre beklenmedi. Ardından salt okunur sorguda oluşturulan sentetik isimlerin sayısı 0 idi; mevcut veriler korunmuştur.
- Yerel KPSS API'si mevcut veritabanını yeniden kurmadan başlatıldı: `127.0.0.1:54401/health` doğru veritabanını doğruladı. REST 54402, Auth 54403'tür. Android emülatörü API'ye `10.0.2.2:54401` ile erişir. iOS native kanıt host'u `exam32_host.py --profile kpss --device ios` ile 54409 portunda ayrıca başlatılabilir. Eski genel iOS wrapper'ı 54401'i desteklemez ve normal uygulamanın kimliğini kullanabilir; paylaşılan cihazdaki normal uygulamalar ve taslaklar yerine ayrı QA uygulama kimliği kullanılmalıdır.

## Ürün politikası ve sınırlar

Normal odak kumu `profiles.coins`, Deneme kumu `exam_wallets` içinde ayrıdır. Bu, önceki açık ayrı cüzdan kararını korur; Deneme kumu ile normal avatar satın alındığı iddia edilmemelidir. Sunucunun kabul ettiği ve başlangıçta dondurduğu ödül snapshot'ı esas alınır; yerel katalog tek başına bakiye vermez. Yerel ödemeler önerilen 32 politikasındadır, canlıya uygulanmış değildir.

Geç gelen çevrimdışı kayıtların geçmiş seriyi geriye dönük yeniden hesaplamaması ve saat dilimi değişiminde çalışma günü yorumlarının farklılaşabilmesi bilinen politika sınırlarıdır; bu inceleme geçmiş veriyi değiştirmedi. Birincil kaynak: `tool/local_supabase/e2e/VERIFY_REPORTS_AND_EXAMS_README.md`.

Canlı sunucudaki 24 saat sınırı nedeniyle günlerce çevrimdışı çalışmanın tamamının daha sonra kaydedileceği söylenemez. İstemci 48 saatten eski bekleyen normal seansı göndermeden reddedilenlere taşır; 24–48 saat arasındaki seans sunucudan eski olma hatası alabilir. Sosyal ekran görünürken yaklaşık 30 saniyede bir yenilenir; bu sürekli gerçek zamanlı akış değildir.
