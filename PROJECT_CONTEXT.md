# PomoSprint — kısa proje bağlamı

**Güncel devam noktası — 28 Ekim 2026:** Aktif kök `/Users/almano/Desktop/Projects/Pomodoro`, dal `codex/gece-2026-10-27`; `Desktop/Courses/Projects/Pomodoro` ayrı kopyadır. Son commitler `b37899e` → `01bf20f` → `f2c6a7d`. Deneme, TUS, birleşik rapor ve aylık hedef ligleri yerelde hazırlanmıştır. **Canlı Supabase ve site bu gece değiştirilmedi; push/deploy yok.** Son `full32`: analyze temiz, **1416 PASS / 5 isteğe bağlı atlama**; Node **158 PASS**. Bu sayılar bitmemiş native koşuları içeriyormuş gibi yorumlanmaz. Güncel madde/test durumları [ISTEKLER](analiz/ISTEKLER.md) ve [CODEX_ILERLEME](analiz/CODEX_ILERLEME.md); detaylar [AGENTS](AGENTS.md), [PROJE_DEVIR §39](PROJE_DEVIR.md#39-2728-ekim-2026--yerel-deneme-tus-ve-aylık-lig-devri) ve [yeni API sözleşmesi](supabase/proposed/EXAM_API_CONTRACT.md). Eski bölümler tarihsel kayıttır.

**Native özet:** iOS 18.6 gerçek 25 finali tek kayıt/lig olayı, 5 puan, 20 kum ve 1 seriyle geçti. iOS 27 TUS 135 ara açılışı geçti; final **02:03 İstanbul** civarında bekleniyor. Android q/j/t/o1/o2 geçti; s25 gerçek Maraton sürüyor. w gerçek 25/HTTP503 **00:27:23→00:52:23 İstanbul** aralığında çalışıyor; final outbox/restart/senkron kanıtı henüz yok. Temiz site videosunun ikinci çekimi w sonrasını bekliyor. Başlangıç veya ara kontrol final başarı değildir.

## Ürün ve teknoloji

Flutter/Dart, yalnız Android/iOS. Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, `eu-north-1`: Postgres/RLS/Auth/RPC/Edge/pg_cron. Site `pomosprint.app`, Cloudflare static Worker; kaynak `landing/`. Bu tur yalnız izole yerel servis/hesap kullanır.

| Alan | Davranış ve sınır |
|---|---|
| Pomodoro | Gerçek 25/50 dk, bir duraklatma hakkı; kalan süre kalıcı zamanlardan hesaplanır |
| Maraton | 2/3/4 odak; 300 sn mola + 60 sn içinde ön planda Buradayım ve sunucu onayı; tamamlanmış odaklar korunur |
| Maraton bonusu | 25 dk için +2/+3/+5, 50 dk için +4/+6/+10; sunucuda bir kez |
| Deneme | TYT/AYT/YDT/LGS Sözel/LGS Sayısal/TUS Temel/TUS Klinik; sunucu başlangıcı, duraklatma/mola yok, yeniden açınca aynı bitiş zamanı |
| Netler | Ders başına doğru/yanlış/boş; YKS/TUS D−Y/4, LGS D−Y/3; negatif net geçerli, ekonomi etkisi yok |
| Vazgeçme | Deneme geçmişi ve sunucunun geçen süre kaydı kalır; çalışma toplamı/seri/ödül kazanmaz. Süresi dolmuş deneme tamamlamaya yönlenir |
| Rapor | Pomodoro + Maraton + yalnız tamamlanmış denemenin ortak süresi; Deneme ayrı kategori satırı, derslere süre dağıtılmaz. Çalışma günü profil diliminde 04:00 |
| Yeni lig sözleşmesi | Normal ve deneme ayrı; hedef kategorisi ve global. Ayın 1'i 00:00 Europe/Istanbul; 25 kişilik oda. Ay ortası hedef değişimi sonraki ay |
| Sosyal | Odaklanıyor/Molada/Denemede; Molada yalnız Maraton. Görünürken 30 sn polling; push değil |
| Avatar | Kayıtta 7 ücretsiz, 21 özel ×500 kum; ödüller satın alınmaz. Deneme avatarı gerçek görsel olmadan verilmez |
| Karşılama/dil | Kayıt sonrası hesaba bağlı TR/EN seçimi, özellik rehberi. Yaş adımı/13 altı engeli ve 13–17 politikası korunur |
| Erişilebilirlik | Yatay sayaç kontrolleri; mola dışında kahve yok. Hareket azaltma kum akışını ve kategori sallanmasını durdurur |

Süre/soru katalog dayanağı [resmî kaynak raporudur](analiz/SINAV_KAYNAKLARI_2026-10-28.md). TUS tek 270 dakikalık oturum değildir: iki ayrı 100 soru/135 dk. AYT 160 tüm kitapçıktır. TUS alt test dağılımı kılavuzdaki yaklaşık dağılımdır. Kişisel net, resmî yerleştirme puanı değildir.

## Kod ve veri akışı

```text
main.dart → SplashScreen → AppGate
                           ├─ Login/Register/Reset
                           ├─ OnboardingWelcomeGate → PostAuthOnboarding
                           └─ MainNavigationShell (IndexedStack/TickerMode)
                              ├─ TimerScreen → TimerPersistence
                              │                → SessionQueue → SupabaseService
                              ├─ ReportsScreen ← normal kayıt/outbox + ExamService
                              ├─ RankingScreen → sunucu lig sözleşmesi
                              ├─ SocialScreen → arkadaş/durum RPC
                              └─ ExamScreen → ExamService → ExamPersistence → RPC
```

- Normal kuyruk ve deneme günlüğü ayrıdır. `client_uuid` bir kez üretilip istekten önce saklanır. Yanıt kaybı aynı UUID ile yeniden denenir; ikinci ödül üretilmez. Owner/epoch kontrolleri geç yanıtın başka hesaba yazmasını engeller.
- Deneme: `lib/models/exam_model.dart`, `exam_catalog_defaults.dart`, `exam_insights.dart`; `lib/services/exam_service.dart`, `exam_persistence.dart`; `lib/screens/exam_screen.dart`, `lib/widgets/exam_results_dialog.dart`.
- `exam_journal_uid_<uid>` başlangıç/tamamlama/vazgeçme/net bekleyen işlemlerini tutar. Bozuk günlük sessizce temizlenip üzerine yazılmaz. Sunucu onayı olmadan ödüllü deneme başlamaz; cihaz tick sayısına güvenilmez.
- Raporlarda `combineStudyAndExamSessions` normal/deneme UUID alanlarını ayırır. `sessionTypeCounts` normal seans, Maraton odakları, tamamlanmış plan ve denemeyi ayrı sayar; 50 dk Pomodoro eşdeğeri iki olabilir ama tek seanstır. Maraton planı distinct UUID ile sayılır; eksik eski metaveriden kesin plan sayısı uydurulmaz.
- Süre–net içgörüsü son 21 günde aynı katalog sürümü/dersle en az iki tamamlanmış sonucu ve en az bir gün arayı karşılaştırır. Eşleme belirsizse ders süresi uydurmaz. Değişim gözlemseldir, nedensellik iddiası değildir.
- Yeni görünür metnin tek kaynağı iki ARB'dir. `LanguageService.translate` eski çağrıları ARB'ye köprüler; ayrı 174 satırlık sözlük kaldırıldı. Kategori TR/EN eşleme ve kullanıcı özel adları korunur. Bilinmeyen arkadaş sunucu hatası ham gösterilmez.

## Sunucu kurulumu ve uyumluluk

Yeni paketlerin **tamamı yereldir**. **D-06 yayın sırası: [27 TUS → 28 Deneme → 29 aylık lig](supabase/proposed/NIGHT_20261028_README.md) → yeni uygulama yayını → site yayını.** 30 başlangıç kota paketi bağımsızdır. Her SQL paketinin ileri/down/DRYRUN dosyası vardır. Canlı tanım parmak izi yeniden karşılaştırılmadan guard kaldırılmaz, toplu `db push/reset` çalıştırılmaz. Site metinleri, yeni uygulama/sunucu özellikleri kullanılabilir olmadan yayınlanmaz.

- `get_exam_config` katalog/uygunluk verir. `start_exam_attempt`, `complete_exam_attempt`, `abandon_exam_attempt`, `get_my_exam_attempts`, `save_exam_results` sahibi doğrular. Erken tamamlama, çakışma, başka sahip ve tekrarlı ödül sunucuda engellenir.
- Deneme puanı/kumu normal cüzdandan ayrıdır. Netleri kaydetmek ekonomi alanlarını değiştirmez. Tamamlanan deneme profil toplam süresi ve 04:00 seriye katkı verir.
- `get_monthly_league_ranking(kind,scope)` ve hedef RPC'leri yeni aylık sözleşmedir. `get_public_monthly_competition` yalnız maskeli genel site görünümüdür; ham kullanıcı kimliği vermez. Global sıralama ek ödül/cüzdan oluşturmaz.
- Kurulum ayının verisi hazırlanır; resmî yeni aylık yarış sonraki ay etkinleşir. Eski lig/ömür boyu puan/kum/avatar silinmez. Aktivasyon, kayıtlı deneme veya işlenmiş sonuç varsa veri kaybettiren down reddedilir; telafi migration gerekir.
- Eski sunucuda eksik RPC (`PGRST202`) Deneme'yi hazırlık durumunda tutar. Ağ/yetki hatası “eski sunucu” ya da başarı sayılmaz. Yeni RPC'ler canlıda varmış gibi demo/ödül gösterilmez.

## Site ve doğrulama

TR/EN home/features/FAQ; hero metni ilk boyamada görünür. Sayfa boyu sabit kum saati kaldırıldı, yalnız hero illüstrasyonu kaldı. Deneme/TUS/süre–net/aylık hedef ligleri açıklanır; güncel kullanılabilir avatar sayısı 42. Aylık tabloda boş/hata/kurulum bekliyor durumları vardır; üç kişi yok diye bölüm kaybolmaz. Sahte kullanıcı/sayaç/referans/tarih eklenmez. Yeni native ekranlar yalnız gerçek uygulamadan alınır; HTML'den sahte mobil ekran üretilmez. Ayrıntılar [landing/README](landing/README.md).

Site/gerçek ekranların ilk yerel paketi `6d2b9f0`, eksik 21 özel WebP düzeltmesi `f2c6a7d` içindedir; son Node sonucu 158 PASS, deploy/push yok. Derlenmiş katalog ve yerel aktif DB 47 ID'de eşleşti; normal erişimdeki koleksiyon 42'dir. [Avatar kanıtı](analiz/QA_SITE_AVATARLARI_2026-10-28.md). iOS 18.6 `o2_04` kontrollü TYT geçmişinde net/yatay/kayıt ve haftalık toplamı, `x_change`/`x_resume` hedef/Global durumunu ayrı OS sürecinde doğruladı; bu doğal 330 dakika veya ay değişimi değildir. Gerçek r25 finali geçti. TUS 135 finali, w ve s25 devam eder; güncel log ayrımı [native QA raporunda](analiz/QA_NATIVE_GECE_2026-10-28.md).

Kontroller: `flutter analyze`, `flutter test --concurrency=2`, `cd scripts && npm test`, `python3 landing/tools/sync_partials.py --check`. `localization_completeness_test`, `runtime_localization_test`, `exam_dialog_localization_test`, `onboarding_dialog_localization_test`, `notification_language_refresh_test`, `error_reporting_test`, `hourglass_lifecycle_test`, `exam_*` ve `unified_*` ilgili regresyonlardır. Native cihaz sonuçları, kontrollü fikstür, kısa katalog koşusu ve gerçek tam süreli koşular raporda ayrılır. Simülatör debug performansı fiziksel cihaz profile/release sonucu değildir.

Native `flutter test` cihaz koşusunun varsayılan uninstall kapanışı uygulama verisini silebilir. Çok aşamalı `r`/`w`/`x` için iOS/Android wrapper'larında **`--no-uninstall --no-pub` korunur**; aşamalar arasında uygulama verisi/tercihler temizlenmez, uygulama kaldırılmaz ve simülatör sıfırlanmaz. Container/kalıcı işaret doğrulanır. `r` başlangıcı tamamlanma kanıtı değildir; `w` gerçek 25 dakika, HTTP 503 ve OS süreç yeniden açılışı; `x` kontrollü geçmişle hedef/Global ve OS süreç yeniden açılışıdır. Normal tam turdaki 5 atlama yalnız `SCREENSHOTS=true` PNG üreticileridir (onboarding 1, kayıt 3, sayaç 1), işlevsel testler değildir.

Normal `flutter run` mevcut `.env` üzerinden canlıya bağlanabilir; yerel URL+anon birlikte verilmelidir. Eski BEA/HMV UUID'leri kullanılmaz; `flutter devices` ve güncel envanter kontrol edilir. Safari kullan, Chrome'a dokunma. Sırlar/sertifika/keystore/`.claude/settings.local.json` commit'e girmez.

## Hata ve dil sınırları

Kalıcı ekran hataları metin olarak dondurulmaz, güncel l10n ile üretilir. Deneme neti TR virgül/EN nokta kullanır. Sunucu katalog adları iki dilde boş olamaz; bilinen avatarın eksik adı yerel katalogdan tamamlanır. Dil değişimi bekleyen odak/mola bildirimlerini aynı mutlak zamanda yeniler; iptal edilmiş alarmı geri getirmez.

Sentry error/breadcrumb/transaction filtreleri iç içe veriyi sınırlı dolaşır; request body/header/cookie/query/fragment ve user bilgilerini çıkarır, token/e-posta/özel anahtar metnini temizler. Stack/line/operation/status korunur. Bu yalnız yerel kod/test doğrulamasıdır; HTTP500 otomatik event, canlı alert teslimi ve release sembolleri doğrulanmış sayılmaz.

## Kalan yayın işleri

Bu dalın yerel testleri genel yayın izni değildir. Bekleyen yeni SQL kurulumu/site deploy'u, fiziksel cihaz/gerçek sağlayıcı girişleri, ücretli Apple takım/imzalama, mağaza beyanları ve §33 operasyonel bulguları ayrı kapatılır. Gerçek geliştirici/veri sorumlusu/gönderen kimliği kullanıcıdan en son gelecek; yeniden istenmez. 9 Ekim Ronin temizliği ve dört gerçek hesabın korunması tarihsel kayıttır; gece test hesaplarıyla karıştırılmaz.
