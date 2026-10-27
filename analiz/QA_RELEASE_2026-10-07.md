# PomoSprint yayın QA — 7 Ekim 2026

Bu rapor mevcut çalışma ağacının baştan sona denetimidir. Sonuçlar gerçek koşu kanıtlarından alınır; geçmiş 5 Ekim raporlarının yerine yeni durumun kaydıdır. Üretim verisine test hesabı/seans eklenmedi, gerçek kullanıcılara mail gönderilmedi, mağazaya veya siteye yayın yapılmadı. Fiziksel cihazlar bu turda kapsam dışında.

**Sonuç:** Yerel mobil/backend testleri geçti; bulunan kod hataları düzeltildi. Android mağaza AAB imzası doğrulandı, iOS imzasız release derlendi. Uygulama henüz mağazaya tamamen hazır değil: iOS imzalama, Apple Auth, canlıya uygulanacak düzeltmeler ve gönderici/yasal kimlik açık. Android release sürümü emülatörde gerçek giriş/rapor/sekme/sayaç/bildirim ve soğuk açılış kontrollerinden geçti; bu koşuda çökme görülmedi.

## Koşulan testler

| Alan | Gerçek sonuç | Kanıt |
|---|---|---|
| Flutter analiz | Temiz | `qa_evidence_20261007/mobile/flutter_analyze_final.log` |
| Tüm birim/widget testleri | 1091/1091; ekran görüntüsü testleri açık, 0 atlanan | `mobile/flutter_test_final.log` |
| New York/DST rapor/gün hesabı | 93/93 | `mobile/dst_test.log` |
| Mobil değişiklik odaklı regresyonlar | 86/86 | `mobile/final_fix_regressions.log` |
| Backend | 9 süit, 466/466; izole yerel kopya | `backend/summary.json` |
| Canlı salt okuma | 409 katalog satırı kayıtla aynı; 14 ops fonksiyonu/yetkisi aynı | `backend/live_catalog_comparison.json`, `ops_catalog_comparison.json` |
| iOS 18.6 / iPhone 16 Plus | a–i, k–n gerçek UI; ilk silme çökmesi düzeltildi, e/m/n tekrar 3/3 geçti | `mobile/ios_base.log`, `ios_full.log`, `ios_fixes.log` |
| iOS OS süreç sonlandırma | Bitmeden terminate → süre dolunca yeniden aç → aynı UUID, 1 seans/50 dk/12 puan/20 kum; ikinci açılışta hâlâ 1 | `mobile/ios_process_result.json` |
| Android OS süreç sonlandırma | Force-stop sonrası aynı UUID, 1×50 dk/12 puan/20 kum; ikinci açılışta yine 1 | `mobile/android_process_result.json` |
| Android 16 / API36 ARM64 | a–e 6/6 + f/j/g/h/i/l/m/n 8/8 geçti; beş hesap, kesinti, native bildirim ve gerçek form dahil | `mobile/android_base.log` |
| Site + JS/Edge + e-posta | Son ağsız Node paketi 99/99; welcome15, unsubscribe24, delete-account25 | `node_final.log` |
| Site statik/Safari | 18 HTML, 674 yerel başvuru, 30 SRI ve partial senkronizasyonu temiz; sınırlı gerçek Safari sayfa kontrolü | `site/report.md` |
| Gerçek yerel Auth/Mailpit | 9/9: doğrulama, reset, eski/yeni şifre, tek kullanımlı link, olmayan hesap gizliliği | `backend/email/summary.json` |
| Resend canlı salt okuma | Alan adı/SPF/DKIM Verified; geçmiş tek reset Delivered, bounce/şikâyet 0 | `backend/email/summary.json` |
| Android mağaza AAB | 64,2 MB, gerçek pipeline ve JAR imza doğrulaması geçti; debug sertifikası değil | `mobile/release_android_aab.json`, `mobile/release_android_aab.log` |
| Android release çalışma kontrolü | Normal main, obfuscation/R8; gerçek yerel giriş, 75 dk rapor, sekmeler, 25/50 seçim, native alarm/ikon, duraklat/sıfırla ve soğuk açılış geçti; yeni seans eklenmedi | `mobile/android_release_smoke.json`, `mobile/android_release_native.json` |
| iOS release / IPA | Obfuscated imzasız release geçti (28,4 MB uygulama); imzalı IPA kişisel takım/provisioning engeliyle üretilemedi | `mobile/release_ios_build.json`, `mobile/release_ios_unsigned.log`, `mobile/release_ios_ipa.log` |

[Makine tarafından okunabilir özet](QA_RELEASE_2026-10-07.json) aynı sonuçları ve artifact hash’lerini içerir. QA emülatörü ve bu turdaki Gradle daemon’u iş sonunda durduruldu; yerel backend verisi korundu.

Kanıt yolları qa_evidence_20261007 (ham çıktı §37 temizliğinde kaldırıldı) altındadır. Süit toplamlarını birbirine ekleyip bağımsız kullanıcı senaryosu sayısı gibi sunmuyoruz; odaklı testler tam paketin alt kümesidir. DB fingerprint/hash karşılaştırması davranış testlerinin yerine geçmez.

## Mobil senaryo planı ve doğrulanan davranışlar

| Senaryo | İşlem ve beklenen sonuç |
|---|---|
| Kayıt/onboarding | Yeni hesap, gerekli alan/onay, YKS/KPSS, kategori limitleri; gerçek Auth/profil/kategori kaydı ve doğru kabuk |
| Sayaç/düzen | Dikey/yatay küçük telefon ve tablet, güvenli alan, büyütülmüş yazı, 25/50 seçim; taşma veya kaybolan başlat düğmesi yok |
| Seans/rapor/lig | Normal süresi dolmuş kalıcı seansın geri yüklenmesi; hızlı yerel 5/10 sn → 25/50 dk; sunucu ödülü, günlük/haftalık/aylık metrikler, lig ve kategori eşleşmesi |
| Beş hesap | Her hesapta gerçek UI girişi ve seans; toplam 6 seans/225 dk/51 puan/120 kum; arkadaşlık ve çalışan arkadaş görünümü, hesap izolasyonu |
| Kesinti/kuyruk | Yerel API gerçekten durur; seans kalıcı kuyruğa girer, raporda görünür; API gelince bir kez kaydolur, toplam çift sayılmaz |
| Duraklatma/geri açma | Tek hak, aynı client_uuid/started_at, duraklatılmış kaydın geri yüklenmesi ve puan kuralı; hesap değişiminde başka kullanıcıya geçmez |
| Arkadaş yönetimi | İstek, iptalden vazgeçme, gerçek iptal, kabul, karşı tarafta liste, çıkarma, engelleme/geri açma; canlı satır ve yetkiler tutarlı |
| Görünürlük | Profil tercihi, canlı akış ve dönüşte yenileme; eski/geç gelen yanıt yeni tercihi ezmez |
| Kullanıcı bildirimi | Arkadaş menüsü → zorunlu neden → isteğe bağlı açıklama → gerçek RPC; aynı hedefe tekrar yeni satır yaratmaz; iptal yazmaz |
| Kategori/rapor | Arşivle, ekle, 9. kategoriyi engelle, yeniden adlandır, seans, tekrar arşivle; çip çıkar ama geçmiş raporu kimlikle korunur |
| Profil/avatar | Türkçe/İngilizce, koyu tema kalıcılığı, dört sekme, yetersiz bakiye; sunucuda satın alma/kuşanma/yarış kuralları |
| Hesap silme/çıkış | Onay, gerçek yerel hesap/veri silme, açık profil/koleksiyon route'larının kapanması, Login; diğer hesabın verisi kalmaz |
| Saat dilimi/yasal kayıt | Gerçek IANA kanalı, profil/cache, New York DST, geçersiz dilimde koruma; onay ledger'ı idempotent |
| Bildirim/kilit ekranı | iOS provisional teslim ve ActivityKit kanal; Android sistem izni/alarm/teslim/iptal. Fiziksel banner/ses/kilit ekranı kalitesi ayrı |
| OS süreç ölümü | Gerçek terminate/force-stop ve yeniden başlatma; kalıcı seans aynı UUID ile bir kez gönderilir |

Hızlı seans testleri sadece yerel debug `QUICK_TIMER=true` + `QUICK_TIMER_SAVE=true` ile koşuldu. Üretim `complete_study_session` değişmedi; normal debug/profile/release 25/50 dk. OS fikstürü, iOS tercih dosyasının yazılmasını bekleyip bitmeden kapatabilmek için **30 sn** kullanır; tek seans için 25/50 dk beklenmedi. Sosyal görünürlük normalde 30 sn polling, yerel kısa QA'da 2 sn; push realtime iddiası yok.

## Bulunan ve düzeltilen hatalar

- Hesap çıkışı/değişiminde üstteki profil/koleksiyon ekranları eski hesaba bağlı kalabiliyordu. AppGate sahip değişiminde route'ları kapatır; yeni kabuk/onboarding sahibi UID ile anahtarlanır.
- Silme işlemi yeni merkezî yönlendirmeyle aynı ekranı iki kez kapatıyordu; gerçek iOS E2E Navigator çökmesini yakaladı. Başarı yönlendirmesi AppGate'e bırakıldı, hata sadece kendi ilerleme route'unu kaldırır. Son gerçek silme tekrar geçti.
- Görünürlük anahtarının ilk okuması/yazma yarışı, eski arkadaş yenilemesi ve gizlenen kullanıcı yüklemesi yeni durumu ezebiliyordu. Sahip/sıra denetimi, bekleyen işlem kilidi ve doğru geri alma eklendi.
- Kayıt/şifre değişiminde istek sürerken geri çıkma ve dispose sonrası mesaj gösterme yolları korundu.
- Kullanıcı bildirme, mevcut sunucu RPC'sine küçük bir form ile bağlandı. UI/servis/yerelleştirme ve iOS gizlilik veri türü birlikte güncellendi.
- Canlı Auth minimum 8 iken istemci/web 6 diyordu. Kurallar, TR/EN metinler ve sınır testleri 8'e hizalandı; sunucu zayıflatılmadı.
- Bekleme listesi formundaki açık pazarlama onayı sözleşmesi düzeltildi. Ortak İstanbul aylık geri sayımı yerine profil diliminde ayın 1'i 04:00 kuralı açıklandı.
- Site HTTP gövdesi takıldığında zaman aşımı erken kapanıyordu; artık yanıt gövdesi okunana kadar korunuyor.
- Abonelikten çıkma yalnız waitlist token'ını başarı döndürüp silmiyordu; iki liste/token yolu desteklendi. DELETE hataları görünür ve aynı linkle yeniden deneme mümkün; yalnız case farkıyla çoğalmış waitlist satırları da çıkarılır, başka adresler jokerle eşleşip silinmez.
- Welcome yanlış e-posta payload'ında satırı sahiplenebiliyor, ağ hatasında gönderildi işareti kalabiliyordu. E-posta koşulu atomik sahiplenmede, 10 sn sınır, hata sonrası geri alma ve sabit Resend idempotency anahtarı eklendi. PostgREST yıldız karakterini ILIKE jokerine çevirdiği için eşleme kaçışlı/sabit uçlu imatch ile yapılıyor; gerçek yerel REST kontrolü geçti.
- Rapor RPC'sinde paralel aynı-hedef istekleri 2 satır, günlük 9 kayıt +2 istek 11 satır yaratabiliyordu. Bildirici başına transaction kilidiyle hazırlanmış SQL gerçek HTTP7/7, sözleşme21/21 ve DRYRUN23/23 geçti; **canlıya uygulanmadı**.
- Hesap-silme Edge kaynağı e-posta listesi temizliği hatasında Auth'u silip yeniden denemeyi imkânsız kılabiliyordu. Temizlik hatası önce500 döner; literal/case eşleme ve 25 ağsız JWT/Apple/gerçek geçici ES256 testleri eklendi. **Function canlıda hâlâ yok.**
- İki backend test fikstürü takvim gününe bağlı kırılıyordu; ürün SQL'i değiştirmeden her gün aynı senaryoyu sınayacak şekilde düzeltildi.

İlk başarısız koşular saklandı. OS yardımcı denemelerinde native iOS konsolundan Dart logu okunamaması, yanlış test kolon adı ve 10 sn gözlem penceresi sorunları ürün hatası olarak sayılmadı; sonunda diskteki aktif kayıt, kapanma zamanı ve gerçek DB UUID/ödülü ile doğrulandı.

## E-posta nasıl çalışıyor ve bugün ne kanıtlandı?

1. **Kayıt/doğrulama ve parola reset:** Supabase Auth → ayrı SMTP → doğrulama/reset sayfası. Yerel gerçek Mailpit akışı 9/9 geçti. Resend panelinde 2 gün önceki tek reset `Delivered`; bu bugün yeni gönderim veya inbox/spam kanıtı değil. Kullanıcının test alıcısı yanıtı bekliyor; yeni üretim maili gönderilmedi.
2. **Hoş geldin:** Pazarlama onaylı abonelik insert'i → Edge Function → Resend. Canlı v9; `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` eksik olduğu için gönderimden önce 500 ile durur. Kullanıcı kimlik bilgilerini en son sağlayacak. Düzeltmeler kaynakta; yeni deploy gerekir.
3. **Bülten:** CLI, açık onaylı abone kuyruğu, kişisel unsubscribe linki; önce dry-run. Bu turda bülten gönderilmedi. Gönderen kimliği tamamlanmadan çalıştırılmamalı.
4. **Abonelikten çıkma:** Token'lı sayfa, açık kullanıcı POST'u, iki listeden çıkma; kaynak düzeltildi ve hata/retry testleri geçti. Canlı v10 yeni kaynakla henüz aynı değil.

Canlı SMTP host/port/kullanıcı alanları CLI çıktısında redakte/eksik olduğundan birebir SMTP yapılandırmasını bu turda doğrulanmış saymıyoruz. Resend geçmiş teslimi ve yerel Auth akışı ayrı kanıtlardır.

SPF/DKIM Verified ve DMARC mevcut; alan adı ayarı değiştirilmedi. Kanıtlara gerçek alıcı, mail gövdesi, reset token'ı veya anahtar konmadı. Provider hata + DB geri alma hatası aynı anda olursa welcome sahiplenmesi kalabilir; artık 500 ile görünür olur, otomatik retry scheduler yok. Bunu gizli bir başarı saymıyoruz.

## Yayından önce kalan somut işler

- [Rapor kilidi SQL paketi](../supabase/tests/20261007_report_submission_lock_README.md) kullanıcı SQL Editor'de önce DRYRUN (23 sonucun tamamı true), ardından migration gerektirir. Repo AGENTS §2.4 bu canlı adımı kullanıcıya bırakır; canlı eski/yetersiz eşzamanlılık gövdesindedir. Rollback de hazırdır.
- iOS imzalı IPA kişisel takım nedeniyle üretilemedi: Sign In with Apple ve Time Sensitive Notifications için ücretli Apple Developer takımı ve uygun provisioning gerekiyor. Yetenekler kaldırılarak hata gizlenmedi.
- Sentry sembol yükleme kimlikleri eksik; Android/iOS sembolleri `release_symbols/1.0.0+1/` altında saklandı, Sentry’ye yüklenmedi.
- Canlı Apple Auth disabled/client_id boş. Apple yapılandırması ve gerçek sağlayıcı oturumu tamamlanmalı; Google açık fakat gerçek native giriş bu turda sınanmadı.
- `delete-account` Edge Function canlıda yok; e-posta hesabı silme RPC yedeği geçti, Apple token revoke bu yedekle yapılmaz. Apple ayar/secrets/deploy ve fiziksel doğrulama gerekir.
- Yasal geliştirici kimliği/başvuru adresi ve welcome/bülten gönderen kimliği kullanıcı tarafından son aşamada verilecek. Kaynak yasal metinler teknik davranışa hizalı; bu alanlar tamamlanmış sayılmıyor.
- Site, welcome ve unsubscribe kaynakları henüz deploy edilmedi. Yeni yasal sürüm `2026-10-07`; landing yeni metni yayımlandıktan sonra bu sürümü kullanan uygulama dağıtılmalı.
- Gerçek yeni mail teslimi ve inbox/spam kontrolü, seçilmiş kullanıcı adresiyle yapılmalı.
- Fiziksel iOS/Android'de izin kabul/ret/ayar dönüşü, ses/banner/kilit ekranı, arka plan ve native OAuth; mağaza gizlilik/Data Safety etiketleri, moderasyon/screenshot/inceleme bilgileri tamamlanmalı.
- Yeni ortam migration baseline ve canlıya uygulanmamış 19 B ayrı operasyon işi. Bu QA CLI push/reset veya ürün kuralı değişikliği yapmadı. Lig eşikleri 1/1/1 bilinçli mevcut karar; testler bunu doğruladı.

## Derleme çıktıları

Normal üretim ayarlı, 25/50 dk süreli imzalı Android paketi yerelde [PomoSprint-1.0.0-1.aab](../release_artifacts/20261007/PomoSprint-1.0.0-1.aab) olarak saklandı. Obfuscation, R8 mapping ve native debug metadata doğrulandı; semboller ayrı dizinde korunuyor. Store’a yükleme yapılmadı.

[iOS imzasız uygulama arşivi](../release_artifacts/20261007/PomoSprint-1.0.0-1-ios-unsigned.app.tar.gz) yalnızca derleme kanıtıdır; mağazaya yüklenebilir IPA değildir. [Yerel QA release APK](../release_artifacts/20261007/PomoSprint-1.0.0-1-local-qa-release.apk) yalnız emülatör/local backend içindir; normal mağaza AAB’sinden ayrı tutulur. Sayaç 25/50 dk, test rozeti yoktur.

İkili çıktılar ve `release_symbols/` Git dışında yerelde saklanır; başka bilgisayarda `.env`, imzalama dosyaları ve araç kurulumu ayrıca gerekir. Bu makinede derlemeler `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ile yapıldı; sistem Xcode seçimi değiştirilmedi.

Bağımsız son statik inceleme yeni ürün/güvenlik regresyonu bulmadı; migration, down, DRYRUN hash önkoşulları ve ACL ayrıca okundu. Bu bulgu canlı dağıtım ve fiziksel doğrulama yerine geçmez.

## Tekrar koşma

```sh
flutter analyze
flutter test --concurrency=2 --dart-define=SCREENSHOTS=true
TZ=America/New_York flutter test test/reports_correctness_test.dart test/reports_findings_test.dart test/stats_calculator_test.dart test/study_day_test.dart --concurrency=2
cd scripts && npm test
```

Gerçek UI komutları ve hesap kısıtları [yerel Supabase rehberinde](../tool/local_supabase/README.md). Yeni `m_release_journey` ve `n_user_report` senaryoları kalıcı; bu turda PC yükünü azaltan o/q/r toplu import dosyaları geçiciydi ve kaldırıldı. Ana kanıtlar ve cihaz ekranları 20261007_release_qa (ham çıktı §37 temizliğinde kaldırıldı) altında seçili olarak saklanır.
