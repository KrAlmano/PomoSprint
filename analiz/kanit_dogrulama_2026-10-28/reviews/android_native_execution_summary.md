# Android native doğrulama — 28 Ekim 2026

Çalışan kopya `.`; tek Android cihaz `emulator-5554` (PomoSprint_QA_API36). JDK17 Zulu, Gradle 2 GB / 2 worker. Canlı servis, `.env`, fiziksel cihaz,31 paketi veya R lifecycle driver çalıştırılmadı. Bütün işlemler yerel QA.

| Senaryo | Sonuç | Günlük/kanıt |
|---|---|---|
| İlk AD kısa deneme matrisi | KALDI: TR TYT + AYT geçti; YDT 85 sn bekleme sınırında kaldı | `external/tmp/pomosprint_verify_android_short.log`; `build/verification_20261028/android_short_run.json` |
| YDT başarısızlığının tanısı | Diskte `pending_action=complete`, `error_code=exam_not_elapsed`; server aktif, gerçek 60 sn bitişi geçmiş. Proxy açıktı;503 / ağ kesintisi değildi | `build/verification_20261028/android_short_pending_ydt_diagnostic.json` |
| İlk AH kurtarma harness derlemesi | KALDI: eksik debugPrint import; uygulama başlamadı. Import düzeltildi, analyze temiz | `external/tmp/pomosprint_verify-android-short-recovery.log` |
| AH aynı sahip/kurulum/journal kurtarma | GEÇTİ 1/1: otomatik uygulama sync aynı YDT UUID'sini kabul etti; süre2 → 3 dk, tek event, sıfır ödül, diğer geçmiş aynı; pending temiz, tekrar RPC duplicate | `external/tmp/pomosprint_verify-android-short-recovery2.log`; `analiz/ekran_dogrulama_2026-10-28/verify-android-short-recovery2/` |
| AD kısa matris tekrarı | GEÇTİ 1/1:7 tür × TR/EN = 14 doğal60 sn; her ders net girişi, kısmi giriş, düzenleme, negatif/taşan değer reddi, otomatik/elle boş ve TR/EN çevrimdışı kuyruk | `external/tmp/pomosprint_verify_android_short_retry.log`; `android_short_retry_run.json`; `android-short-retry/` |
| AD tekrar bağımsız DB oracle | GEÇTİ 738 kontrol, 0 uyarı;14 tamamlanmış deneme, toplam 14 dk; normal / Maraton / pending 0 | `build/verification_20261028/android_short_retry_independent.json` |
| AA olumlu süre–net içgörüsü | GEÇTİ 1/1:TR/EN gerçek paragraf ve uyarı, ilişkili 25 dk,19.25 → 27.50; ekonomi aynı. İki TYT + 25 dk geçmişi kontrollü fixture | `external/tmp/pomosprint_verify-android-insight-a6.log`; `verify-android-insight-a6/` |
| AE izole eski sunucu | GEÇTİ 2/2:TR/EN; TUS niyeti korunur, Deneme kullanılamaz, normal sayaç başlat/iptal, günlük/aylık 25 dk; 5 puan / 20 kum, 1 çalışma satırı. Ortak Auth kullanılmadı | `external/tmp/pomosprint_verify-android-old-a8.log`; `verify-android-old-a8/` |
| AD karışık W raporları | GEÇTİ 1/1:iki dilde günlük 0 / haftalık 265 / aylık 430 dk; normal 2, Maraton 1 / odak 2, haftalık deneme 1 / aylık deneme 2, kategori/yüzde/hedef/verimlilik/aylık günler bağımsız DB ile eşleşti | `external/tmp/pomosprint_verify-android-reports-a4.log`; `verify-android-reports-a4/`; W preflight oracle 211 kontrol / 0 uyarı |
| AF ligler | GEÇTİ 1/1:24 TR/EN×normal/deneme×kategori/global×açık/gizli/engelli görünüm. SQL/RPC/UI sırası, puan, rank, maskeler ve global dışlama aynı; ekonomi aynı | `external/tmp/pomosprint_verify-android-leagues-a5.log`; `verify-android-leagues-a5/`24 benzersiz ekran |
| AF sosyal | GEÇTİ 1/1:bir native gözlemci + 8 kimliği doğrulanmış API arkadaşı;TR/EN odak/mola/deneme bitişi, gizlilik kapatma, engelleme doğal 30 sn poll ile kayboldu; aktörler ve arkadaşlıklar geri kuruldu | `external/tmp/pomosprint_verify-android-social-a7.log`; `verify-android-social-a7/`10 ekran |
| AD pozitif TUS günlük karışımı | GEÇTİ 1/1:TR/EN günlük 160 / haftalık 260 / aylık 260 dk; günlük 1 normal + 1 TUS;%133 verimlilik ve %100 hedef halkası; kategori %84 Deneme / %16 Matematik | `external/tmp/pomosprint_verify-android-reports-positive.log`; `verify-android-reports-positive/`; `android_positive_reports_summary.json` |

Kısa matris yalnız yerel katalogda 60 sn/0 puan / 0 kum kullanır; resmî sınavların gerçek tam süreyle tamamlandığı iddia edilmez. Her koşuda katalog tam olarak geri alındı, R75 orijinal satırı değişmedi, reviewed parity2 geçti. İlk başarısız koşu silinmedi. Hatalı YDT journal'ı silinmeden aynı sahip üzerinde uygulamanın gerçek otomatik sync'iyle kurtarıldı; ardından yeni hesapta matris tekrarlandı. Süre/tarih hızlandırılmadı.

Kod farkı: AD net ekran adında alt çizgi yerine tire; doğal 60 tamamlama beklemesi85 → 120 sn (HTTP Date hassasiyeti/30 sn tekrar aralığına izin veren test sınırı); yeni `integration_test/ah_pending_exam_recovery_test.dart`. Ürün kodu değiştirilmedi. AH ilk derleme hatası düzeltildi ve AD+AH analyze temiz geçti.

Android 10:21:02Z'de root'a teslim edildi. Yalnız bu ajanın 54321 / 54398 / 54341 adb reverse eşlemeleri kaldırıldı; kalan eşleme yok, host 54398 boş, aktif sayaç/pending/aktif deneme/outbox yok. `build/verification_20261028/android_handback.json`. Root R driver'ını bundan sonra başlatabilir; bu ajan başka adb/native işlem yapmayacak. Commit/stage/push yapılmadı.

Not: tablo günlükleri `/tmp`, JSON durumları `build/verification_20261028`, ekran klasörleri `analiz/ekran_dogrulama_2026-10-28` altındadır. Nihai raporda dosya adları bu köklerle açılmalıdır. AG medya hazırlığı artık verify_net_entry/root mülkiyetindedir; bu ajan B çekimi çalıştırmadı.
