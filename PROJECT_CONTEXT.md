# PomoSprint — kısa proje bağlamı

> Son güncelleme: 5 Ekim 2026. En kapsamlı çalışma/devir belgesi: [PROJE_DEVIR.md](PROJE_DEVIR.md). Ayrıntılı kodlama ve sunucu sözleşmeleri: [AGENTS.md](AGENTS.md). Canlı veritabanı doğrulaması canlı kaynaktan yapılır; bu dosyadaki tarihli kayıt yeni canlı sorgusu değildir.

## 1. Ürün

Android ve iOS için oyunlaştırılmış çalışma/Pomodoro uygulaması. 25 veya 50 dakikalık odak seansı, ders kategorileri, raporlar, seri, puan/kum, lig, avatar, arkadaş ve sosyal çalışma akışı.

| Özellik | Davranış |
|---|---|
| Seans | 25/50 dakika; tek duraklatma; seans cihazda sürer ve offline tamamlanmış seans kalıcı outbox'ta bekler |
| Ödül | Puan, kum, seri ve lig sunucu RPC sonucudur; istemci formül üretmez |
| Rapor | Günlük/haftalık/aylık, kategori ve hedef; çalışma günü profil IANA diliminde 04:00 |
| Kategori | Ücretsiz 8, premium 15; silinmez, arşivlenir |
| Lig | 5 kademe, en fazla 30 kişi, 14 günlük dönem; yeni ilk oda 7–14 günlük döneme denk gelebilir |
| Arkadaş | Kod, gelen/giden istek, arkadaşlıktan çıkarma, engelle/geri aç, canlı odak ve sıralama |
| Auth | E-posta/parola, Google; Apple iOS'ta. Parola sıfırlama bağlantısı web reset ekranında tamamlanır |
| Yerel test | Yalnızca debug + yerel backend seçilirse 5/10 saniye 25/50 dakika diye kaydedilebilir; canlıya kısa kayıt yok |
| Dil/tema | Türkçe/İngilizce, sistem/açık/koyu tema |
| Bildirim | Android yerel bildirim/kalıcı sayaç; iOS bildirim/Live Activity |

## 2. Teknoloji ve çalıştırma

- Flutter, Dart `^3.12.2`; ürün platformları `android/`, `ios/`.
- Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`.
- `pomosprint.app`: statik Cloudflare Workers site (`landing/`).
- Sentry: DSN boşsa veya açık yerel `--dart-define` bağlantısında ayrıca verilmezse kapalı.
- Google plugin kodu 6.x API'sinde. Gerçek Google/Apple sağlayıcı girişi son QA'da doğrulanmadı.

Kurulum ve komutlar kök [README.md](README.md)'de; yerel backend/test hesapları [tool/local_supabase/README.md](tool/local_supabase/README.md)'de. Yerel projeyi canlıya `supabase link` ile bağlama. Canlı migration geçmişiyle repo kök migration'ları farklı olduğundan kökte `supabase db push/reset` kullanma.

## 3. Mimari

```text
main.dart → SplashScreen → AppGate
                           ├─ Login / Register / Password reset
                           ├─ PostAuthOnboardingScreen
                           └─ MainNavigationShell (IndexedStack, 4 sekme)
                              ├─ TimerScreen
                              ├─ ReportsScreen → stats_calculator / study_day
                              ├─ RankingScreen
                              └─ SocialScreen / FriendsSheet

TimerScreen → TimerPersistence → SessionQueue → SupabaseService → RPC/Postgres
ReportsScreen ← remote sessions + pending outbox
DeviceTimeZone native IANA → own profiles.timezone → çalışma günü / rapor
```

`AppGate` tek yönlendirme kapısıdır. `SupabaseService.currentUser` tek kullanıcı kaynağıdır. Tamamlanan seans önce diskteki `SessionQueue`'ya yazılır; `client_uuid` idempotency sağlar. Raporlar uzak kayıtları ve pending seansları `mergeStatSessions` ile birleştirir. Profil, ekonomi veya başka kullanıcının verisine ekrandan rastgele doğrudan erişme; [AGENTS.md](AGENTS.md)'deki RLS/RPC sözleşmesini izle.

## 4. Çalışma günü, arkadaşlık ve yasal kayıt

- `study_day.dart`: 04:00 çalışma günü, Pazartesi başlayan hafta ve DST güvenli takvim. Yerel IANA saat dilimi iOS/Android MethodChannel'ından (`device_time_zone.dart`) okunur. Profil açılışında ve uygulama ön plana dönünce eşitlenir. Geçersiz dilim veya ağ hatası eski profil değerini korur.
- Sosyal sekmenin görünür tazelemesi normalde 30 saniye; kısa kayıtlı yerel testte 2 saniye. Bu push realtime yayını değil.
- Arkadaş sheet: gelen/giden, iptal, remove, block/unblock. Gizle cihazda saklanan ayrı davranış. Bildirme şu an destek e-postası; `submit_user_report` form UI'si bağlanmadı.
- SocialSignInNotice sonrasında başarıyla Google/Apple girişi yapılırsa `accept_legal_documents` terms/privacy sürümünü `consents` ledger'ına yazar. Hata durumunda Shell'e ilerlenmez. Bu yeni provider adımı gerçek provider login testi değildir.
- Şifre unuttum formu adres alır ve reset mailinden sonra “gönderildi” ekranını gösterir; reset bağlantısı web'de tamamlanır.

## 5. Son QA ve kapsam sınırı

5 Ekim 2026'da iPhone 16 Plus / iOS 18.6 simülatör ve Android 16 API36 ARM64 emülatörde uygulama/UI test edildi. Son takip: `flutter analyze` temiz; toplam birim/widget **1068 geçti**, 5 isteğe bağlı ekran görüntüsü testi atlandı; New York DST seçili kümesi 93 geçti; iOS/Android saat dilimi ve arkadaş yönetimi E2E, Android ARM64 APK ve iOS imzasız release derlemesi geçti. Detay/senaryo/kısıtlar [QA_FOLLOWUP](analiz/QA_FOLLOWUP_2026-10-05.txt) ve [QA_FULL](analiz/QA_FULL_2026-10-05.txt) raporlarında.

Doğrulanmamışlar: fiziksel Android/iOS; gerçek Google/Apple giriş; fiziksel tam bildirim/ses/kilit ekranı sunumu; gerçek cihazda saat dilimini seyahat ederek değiştirme; mağaza imzası ve yayın. iOS native süreç sonlandırma ayrıca geçti; Android OS süreç kill'i iddia edilmemeli.

## 6. Backend durumu

5 Ekim kaydına göre `12 → 15 → 16 → 19 A → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25 → 26` canlıya uygulandı ve o gün doğrulandı. 19 B uygulanmadı. Bu özet yeni canlı DB sorgusu değildir; yeni SQL işi için [supabase/README.md](supabase/README.md) ve `AGENTS.md` §2.3–2.4'ü izle.
