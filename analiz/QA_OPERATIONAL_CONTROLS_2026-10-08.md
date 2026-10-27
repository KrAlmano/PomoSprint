# PomoSprint — mevcut operasyonel kontrollerin testi

**8 Ekim 2026.** Kullanıcının son açıklaması esas alındı: verilen beş başlık genel bir kontrol listesi; mevcut uygulamaya uygun olanlar test edilecek. Yeni PostHog/Upstash, ücretli plan, feature flag servisi veya staging projesi kurulmadı. Ürün kodu, canlı ayarlar, veritabanı ve kişisel simülatör değiştirilmedi.

**Sonuç: mevcut temel kontrollerin önemli bölümü çalışıyor; bu beş başlığın tamamına “hazır” denemez.** Arkadaş/şikâyet limitleri ve yerel ortam ayrımı geçti. Sentry'nin hata yakalaması çalışıyor, maskeleme ve otomatik request takibinde eksikler var. Site bekleme listesinin sunucu koruması yetersiz; bir API kotasında eşzamanlılık hatası yeniden üretildi. PostHog ve satın alma funnel'ı mevcut üründe yok ve bu tur için kapsam dışı.

## 1. Beş başlığın sonucu

| Başlık | Durum | Gerçek sonuç |
|---|---|---|
| Error tracking + alerting | **Kısmi** | Sentry SDK hatayı stack trace ve breadcrumb ile yakalıyor. Üst seviye e-posta maskeleniyor; iç içe veri/request maskelemesi eksik. Mevcut Dart HTTP katmanı 500 için otomatik event üretmiyor. Canlı alarm kuralı ve teslimi doğrulanmadı. |
| Product analytics | **Bu üründe kapsam dışı** | PostHog SDK/event katmanı ve gerçek ücretli satın alma yok. Mevcut kayıt/onboarding testleri geçti; bunlar bir analitik funnel kurulmuş olduğu anlamına gelmez. |
| Rate limiting | **Kısmi; üç başarısız güvenlik koşulu** | Arkadaş kodu, kod yenileme ve şikâyet sınırları doğru. Bekleme listesi doğrudan API'de onay zorunluluğu ve uygulamaya ait sunucu limiter'i olmadan kayıt kabul ediyor. `register_session_start` kotası eşzamanlı aşılabiliyor. |
| Feature flags | **Başlangıç uyumluluk kapısı var** | Maraton uyumsuz/kapalı sözleşmede yeni planı engelliyor. Sunucuda `available:true` sabit; operasyonel bir anahtarla tam kapatma yok. Geri yüklenen aktif plan devam ediyor. |
| Staging / production | **Yerel ayrım çalışıyor** | Ayrı Docker verisi ve URL/anahtar çiftiyle seçim güvenli. İncelenen uygulama yapılandırmasında ayrı hosted staging/flavor/yayın hattı bulunmadı. Taranan uygulama varlıklarında ayrıcalıklı sır yok. |

## 2. Koşulan senaryolar ve kanıt

| Test grubu | Sayı | Ne denendi? |
|---|---:|---|
| Kayıt ve onboarding Flutter | **42/42 geçti** | Kayıt onayı, rehber ve kategori/onboarding davranışı |
| Ortam/Maraton Flutter | **21/21 geçti** | Backend override, eksik çiftte güvenli kapanma, yerel hızlı kayıt sınırı, onay makbuzu, restore ve yeni plan kapısı |
| Sentry yerel audit harness | **5/5 tamamlandı** | SDK event/stack/breadcrumb, maskeleme sınırı ve HTTP500 davranışı; iki senaryo mevcut eksikleri yeniden üretir |
| Site/reset/video Node | **39/39 geçti** | Site onay akışı, 429 reset davranışı, Worker yönlendirme ve video Range |
| İzole gerçek HTTP/API denetimi | **17/20 geçti; 3 koşul başarısız** | Saatlik/günlük kota, kullanıcı ayrımı, idempotency, eşzamanlılık, RLS ve doğrudan anon bekleme listesi |
| Yeni `flutter analyze` | **Temiz** | Ürün ve bu tur eklenen audit harness |

Bu farklı gruplar tek bir “uygulamanın bütün testleri geçti” toplamına çevrilmedi. Sentry harness'indeki başarılı çalışma, yeniden ürettiği veri maskeleme açığının güvenli kabul edildiği anlamına gelmez. Önceki tam **1222/1222** Flutter koşusu [son uygulama QA](QA_APP_FINAL_2026-10-08.md) içindedir; bu tur tekrar koşulmadı.

Kayıt/onboarding ve mevcut analitik bağımlılık incelemesi alt raporda (ham çıktı §37 temizliğinde kaldırıldı) kayıtlıdır. Sonuçlar ve kapsam ayrıca bağımsız ajan incelemesinde (ham çıktı §37 temizliğinde kaldırıldı) kanıtlarla karşılaştırıldı.

## 3. Sentry: hata yakalanıyor, tüm veriler korunmuyor

Mevcut `configureSentry` kullanılarak gerçek SDK event pipeline'ı bellekteki test transport'una bağlandı. Canlı DSN kullanılmadı; panel, e-posta veya başka kanala test alarmı gönderilmedi.

Kontrollü hata için bir event üretildi; **8 stack frame**, dosya adı, satır bilgisi ve güvenli operasyon breadcrumb'ı korundu. Hata mesajındaki sahte e-posta maskelendi. Varsayılan PII ve print breadcrumb kapalı; screenshot/view hierarchy kapalı bulundu.

İkinci denemede breadcrumb içinde iç içe bir harita ve request URL/header/body içine **yalnız sahte** e-posta/token kondu. Mevcut maskeleme bunları korumuyor: derin breadcrumb verisi ve request alanları çıktıda kaldı. Bu, gerçek kullanıcı verisinin Sentry'ye sızdığını gözlemlediğimiz anlamına gelmez; mevcut filtreye böyle veri girerse temizlenmediğinin tekrar üretimidir.

Mevcut `ServerClockHttpClient` ile kontrollü 500 yanıtı denendi. Sunucu saati güncellendi, fakat otomatik Sentry hata eventi oluşmadı. Doğrudan SDK capture çalışırken bütün yakalanıp işlenen API hatalarının raporlandığı söylenemez. Native platform ağ takibi bu senaryoda sınanmadı. [Sentry HTTP entegrasyonu](https://docs.sentry.io/platforms/dart/guides/flutter/integrations/http-integration/) özel istemci kullanımını açıklıyor; [veri temizleme rehberi](https://docs.sentry.io/platforms/dart/guides/flutter/data-management/sensitive-data/) event/transaction/breadcrumb filtrelerini ayırıyor.

Canlı alarm kuralları DSN ile okunamaz. Bu tur yönetim erişimi kullanılmadı; bir alert'in gerçekten tetiklenip geliştiriciye ulaştığı doğrulanmadı. Sembol upload kimlikleri `scripts/.env` içinde yok; önceki release sembolleri yerelde saklanmıştı. Bu nedenle mevcut debug stack deneyi release/native sembol çözümleme ve alarm tesliminin yerine geçmez. [Sentry alert yapılandırması](https://docs.sentry.io/product/alerts/create-alerts/issue-alert-config/).

Kanıtlar: SDK bulguları (ham çıktı §37 temizliğinde kaldırıldı), güvenli örnek event (ham çıktı §37 temizliğinde kaldırıldı), test logu (ham çıktı §37 temizliğinde kaldırıldı), [yeniden koşulabilir harness](../tool/operational_qa/sentry_audit_test.dart).

## 4. Sunucu limitleri: çalışanlar ve açıklar

Gerçek istekler canlıya veya ana yerel veritabanına gönderilmedi. Ayrı geçici veritabanı ve yalnız loopback PostgREST kullanıldı; test bitince ikisi de kaldırıldı. Yerel şema paritesi repo referansıyla **498 satır / 13 kategoride aynı**, avatar kataloğu27 aynı kaldı. Bu tur canlı katalog yeniden okunmadı.

| Senaryo | Sonuç |
|---|---|
| Arkadaş kodu 20/saat; 21. deneme | `rate_limited` |
| Arkadaş kodu 19 denemeden sonra iki eşzamanlı istek | Yalnız biri kabul edildi |
| Başka kullanıcı ve süresi dolan saatlik pencere | Sayaçlar ayrı; yeni pencere doğru başladı |
| Kod yenileme iki eşzamanlı istek | Günde bir sınırı korundu |
| Şikâyet 9 kayıt + iki eşzamanlı farklı hedef | Toplam10; ikinci istek sınırlanıyor |
| Şikâyet/başlangıç aynı client UUID veya aynı kayıt tekrarı | Yeni kayıt/ek kota tüketimi yok |
| Özel sayaç veya bekleme listesini anon/authenticated okumak | Yetki/RLS engeli çalışıyor |
| Geçersiz e-posta ile bekleme listesi | Sunucu format kısıtı reddediyor |
| `register_session_start`: 99 + iki eşzamanlı istek | **101 kayıt oluştu; iki200 yanıt** |
| Bekleme listesine `consent` olmadan doğrudan anon POST | **201 kabul** |
| JS çalıştırmadan12 küçük bekleme listesi POST'u | **12×201; sunucu limiter/CAPTCHA yok** |

`register_session_start` mevcut mobil istemci tarafından çağrılmıyor; normal sosyal başlangıç başka RPC kullanıyor. Bu bulgu mevcut sayacın çökmesi veya puanın çoğalması olarak sunulmamalı. Kimliği doğrulanmış doğrudan API kullanımı için kotanın atomik olmadığını gösteriyor.

Bekleme listesi honeypot/etkileşim/süre kontrolü tarayıcıda kalıyor. Doğrudan Supabase INSERT yolu bunları atlıyor. Onaysız kayıt kabul edilmesi otomatik pazarlama maili gittiği anlamına gelmez; bu tur posta gönderimi denenmedi.

Cloudflare site Worker'ı mobil/waitlist Supabase origin API çağrılarını işlemiyor. Bu yüzden sitenin Cloudflare'da bulunması genel API abuse/fatura limiti var demek değil. Auth limitleri de tüm REST/RPC'lere uygulanmış genel limit değildir. Yeni Cloudflare dashboard/WAF/fatura gözlemi yapılmadı. Ayrıntılar ve resmi kaynaklar: rate limit alt raporu (ham çıktı §37 temizliğinde kaldırıldı), 20 kontrolün ham sonucu (ham çıktı §37 temizliğinde kaldırıldı), temizlik/parite (ham çıktı §37 temizliğinde kaldırıldı).

## 5. Maraton ve ortam ayrımı

Maraton yeni plan kapısı sözleşmeyi, 300 sn molayı, 60 sn onayı ve bonus matrisini doğruluyor. Testte kapalı/uyumsuz capability yeni planı engelledi. Ancak sunucuda `available` bir ayar tablosuna bağlı değil ve completion/onay yollarında operasyonel `enabled` kararı yok. Mevcut davranış geri yüklenen aktif planı sürdürür. Bu nedenle mevcut kapıyı tam kill switch saymadım; özelliği deploy beklemeden kapatma tatbikatı yapılmış değildir.

Yerel Supabase URL+anon birlikte verilince üretim ayarlarının yerine geçiyor. Yalnız biri verilince bulut kapalı kalıyor; yerel seçimde Sentry ayrıca verilmedikçe üretim DSN'ine düşmüyor. Kısa kayıt canlı/release veya yanıltıcı localhost adresinde açılamıyor. Bunlar geçti.

**22 derlenmiş `.env` varlığında ayrıcalıklı sır bulunmadı**: service-role/secret/Resend/admin token yok. Üretim public URL/anon/DSN yerel QA paketinde de var; doğru runtime override kullanılınca aktif backend yerel kalıyor. Bu ayrıcalıklı anahtar sızıntısı değildir. İki override tamamen unutulursa varsayılan üretime düşme riski ve aynı bundle/cache ile ortamlar arası karışma riski kaynak incelemesinde mevcut. Kişisel verilerle kurulum değiştirme denemesi yapılmadı.

Ayrı hosted staging, staging bundle/flavor ve bağımsız cloud secrets hattı incelenen yapılandırmada doğrulanmadı. Yerel izolasyonun iyi çalışması bu katmanların kurulmuş olması anlamına gelmez. Ortam ve Maraton alt raporu (ham çıktı §37 temizliğinde kaldırıldı), maskeli varlık denetimi (ham çıktı §37 temizliğinde kaldırıldı).

## 6. Bu tur değişiklik ve takip sınırı

Kullanıcının son isteğine uygun olarak yalnız denetim/test yapıldı. Yeni araç veya uygulama özelliği eklenmedi; bu bulgular düzeltilmiş olarak raporlanmıyor. Eklenen kod yalnız ayrı `tool/operational_qa/` test harness'idir; ürün tarafından import edilmez. Dokümanlar ve kanıtlar kaydedildi. `.env`, üretim verisi, planlar, site, ürün kaynakları ve kişisel simülatör korundu.

Öncelikli takip sırası: **bekleme listesi sunucu girişini korumak → Sentry derin maskeleme ve API hata takibi → başlangıç kotası atomikliği → alarm teslimi/semboller → gerçek kill switch ve gerektiğinde hosted staging**. PostHog ve satın alma gelecekte ayrı ürün kararıdır; mevcut satın alma olmayan sürüm için bugün kurulum gerektirmiyor.

Genel değerlendirme: mevcut işlev testleri iyi sonuç verdi; bulunan operasyonel eksikler varken “beş kontrol de eksiksiz, tüm yayın güvenceleri tamam” sonucu çıkarılamaz. Gerçek cihaz/native crash, canlı alert teslimi, canlı yük/fatura ve mağaza incelemesi bu tur kapsamı değildir.

Son belge/kaynak kontrolü ve değişiklik sınırı kapanış kaydındadır (ham çıktı §37 temizliğinde kaldırıldı).
