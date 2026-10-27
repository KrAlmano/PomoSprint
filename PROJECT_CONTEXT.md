# PomoSprint — kısa proje bağlamı

**Güncel: 9 Ekim 2026 / §37.** Proje kökü `/Users/almano/Desktop/Projects/Pomodoro`. [Temizlik QA](analiz/QA_RELEASE_CLEANUP_2026-10-09.md), [detaylı devir](PROJE_DEVIR.md) ve [sözleşmeler](AGENTS.md) okunmalı. Önceki tarihli ortam notları, güncel çalışan cihaz veya veritabanı anlamına gelmez.

## Ürün ve teknoloji

Flutter/Dart mobil uygulaması yalnız Android ve iOS içindir. Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`; Postgres, RLS, Auth, RPC, Edge ve pg_cron kullanılır. Site `pomosprint.app`, Cloudflare static Worker ile yayınlanır; kaynak `landing/` altındadır.

| Alan | Davranış |
|---|---|
| Sayaç | Gerçek 25/50 dk, 1 duraklatma hakkı; kalan süre kalıcı bitiş zamanından hesaplanır |
| Maraton | Planlama penceresinde 2/3/4 odak ve ortak 25/50 dk seçilir. Arada 300 sn mola, ardından 60 sn içinde ön planda Buradayım ve sunucu onayı gerekir; tamamlanan odaklar normal ödülle korunur |
| Bonus | Geçerli plan tamamlandığında 25 dk için +2/+3/+5, 50 dk için +4/+6/+10; sunucu bir kez hesaplar |
| Rapor | Günlük, haftalık, aylık, kategori ve hedef takibi; IANA saat diliminde 04:00 çalışma günü sınırı |
| Lig | Bronz/Gümüş/Altın/Safir/Elmas; ilk puanlı seansla uygun, en fazla 25 kişilik odaya yerleşilir. Hazırlık → 25 farklı aktif kullanıcı → tam 14 günlük dönem; terfi ve ödül aktiflik/yeterliliğe bağlıdır |
| Sosyal | Tek liste: Odaklanıyor; yalnız Maraton molasında Molada. 30 sn aralıkla yenilenir; push yoktur |
| Avatar | Kayıtta 7 ücretsiz avatar; 21 özel avatarın her biri 500 kum. Ronin istemci kataloğundan ve canlıdan kaldırıldı; eski profilde güvenli varsayılan görsel kullanılır. Ödül avatarları satın alınamaz |
| Onboarding | 7 adım; son adım tüm sekmeleri anlatır. Onboarding kaydı son adımda Bitir ile yapılır |
| Dil/tema | TR/EN, sistem/açık/koyu; ARB → gen-l10n |
| Bildirim | Android yerel bildirim, exact alarm ve kalıcı sayaç; iOS yerel bildirim ve LiveActivity |
| Yatay | Animasyon, sayaç, duraklatma hakkı ve uygun kontroller; mola/onayda hak gösterilmez, kahve yalnız moladadır |

## Bağımlılıklar ve veri akışı

```text
main.dart → SplashScreen → AppGate
                           ├─ Login/Register/Reset
                           ├─ PostAuthOnboarding
                           └─ MainNavigationShell (IndexedStack)
                              ├─ TimerScreen → TimerPersistence
                              │                → SessionQueue → SupabaseService → RPC
                              ├─ ReportsScreen ← own remote sessions + outbox
                              ├─ RankingScreen ← league_backend / LeagueRules
                              └─ SocialScreen ← friends/live RPC
```

Puan, kum, seri ve lig sunucu sonucudur. `client_uuid` bir kez üretilir, tekrar kaydı önler ve yeniden denemede değişmez. Owner ve epoch kontrolleri geç yanıtların başka hesaba yazılmasını engeller. Yerel kategori, önbellek ve outbox UID’ye bağlıdır; başkasının verisi yalnız güvenli RPC ile gelir. Auth kullanıcılarını Supabase yönetir; istemcide parola veritabanı yoktur.

## Son temizlik ve doğrulama

Ronin görseli kaldırıldı; Ronin’e ait manifest, mağaza ve yedek katalog kayıtları temizlendi. Eski önbellekteki Ronin görünmez; kuşanılmış eski kimlik temel görselle gösterilir. Kartın dış `StackFit.expand` düzeni, görsel ile kısa ve uzun TR/EN adları aynı merkeze hizalar. Fiyat ve kilit ayrı avatar alanında kalır.

Kullanıcı `20261009233000_remove_unowned_ronin` SQL’ini uyguladı; 20/20 salt okuma kontrolü PASS. Canlı katalogda toplam 48 avatar, 47 aktif, 21 özel ve 7 ücretsiz avatar var; MD5 `9ad12fc8edb016c69eb45a24f4ac1e11`. Dört Auth kullanıcısı/profil, dokuz seans, on bir kategori ve 42 avatar sahipliği kaydı aynı. Ekonomi ve seans hash’leri 8 Ekim’deki özgün kayıtla eşleşir. Kesin biçimde QA hesabı olduğu belirlenen silinebilir bir hesap bulunmadı; mevcut hesaplar korundu.

Flutter testlerinde 1291 PASS var; isteğe bağlı 5 ekran görüntüsü testi atlandı. Analiz temiz. Avatar ve eski kayıt odaklı 114 PASS bu toplamın alt kümesidir; toplama eklenmez. Ronin SQL’i için 24 kontrol, ayrı 12 DRYRUN ve bağımsız 17 statik inceleme vardır; canlıdaki 20 kontrol ayrı kapsamdır. Native görsel ve fiziksel cihaz testleri bu tur çalıştırılmadı; simülatör/runtime sayısı 0.

`pomosprint-local` Docker projesi `stop --no-backup` ile veri hacimleri dahil temizlendi; başka Docker projelerine dokunulmadı. Eski fixture, ekran görüntüsü, ham log, hızlı demo/gece başlatma kaynakları ve macos/linux/windows/web şablonları kaldırıldı. Anlamlı regresyon ve SQL kaynakları korunur. Normal giriş noktası `lib/main.dart`; QUICK/SAVE define’ları etkisizdir, QA tamamlama RPC’si seçimi yoktur. Eski hızlandırılmış aktif kayıt temizlenir; outbox kaydı `invalid_data` ile ret geçmişine alınır. Normal kayıtlar korunur.

## Çalıştırma ve devam

`flutter pub get`, `flutter gen-l10n`, `flutter analyze`, `flutter test --concurrency=2`. Kullanıcı daha sonra cihaz istediğinde tek yeni runtime/cihaz kur ve `flutter devices` ile güncel ID seç. Açık normal veya QA uygulaması yok; eski BEA/HMV UUID’leri silindi. `.env` canlı bağlantısı ve imzalama korunur. Yerel ortam için URL ve anon define’ları birlikte, açıkça verilmelidir.

Canlı veritabanı önceliklidir; migration klasörü canlı geçmişi temsil etmez. Kör `db push/reset` yapılmaz. Yeni SQL akışı: güncel canlı tanım/ACL okuması → izole test → DRYRUN → kullanıcının SQL Editor’de uygulaması → kontrol. Ronin ileri SQL’i yeniden uygulanmaz. Güncel yerel snapshot’ın canlıyla eşit olduğu varsayılmaz; [yerel rehber](tool/local_supabase/README.md).

§33 güvenlik ve operasyon eksikleri halen açıktır: derin Sentry maskelemesi ve HTTP 500 hata yakalama, bekleme listesi onayı ve istek limiti, başlangıç API’sindeki yarış, operasyonel Maraton kill switch’i ve hosted staging. Apple Auth/imzalama, gerçek Google/Apple sağlayıcı ve fiziksel cihaz testleri, mağaza beyanları ve yasal/gönderen kimliği ayrıca tamamlanacak. Kullanıcı kimlik bilgilerini en son verecek; tekrar sorma. Bu temizlik genel yayın onayı değildir; GitHub push veya site yayını yapılmadı.
