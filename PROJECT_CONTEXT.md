# PomoSprint — Proje Bağlamı

> **Ayrıntılı ve güncel AI rehberi: [AGENTS.md](AGENTS.md).** Bu dosya kısa ürün ve mimari özetidir. Çelişki olursa AGENTS.md (ve ondan önce canlı DB) geçerlidir.
> Son güncelleme: 3 Ekim 2026.

## 1. Ürün

Oyunlaştırılmış Pomodoro çalışma uygulaması (Android ve iOS).

| Özellik | Gerçek davranış |
|---|---|
| Seans | Yalnızca 25 veya 50 dk odak; mola sayacı yok. Seans başına 1 duraklatma hakkı. Uygulama kapansa da seans sürer |
| Puan | 25 dk = 5, 50 dk = 12. Duraklatılan seansta %20 kesinti. 3/7/14 günlük seride %10/%20/%30 bonus |
| Kum (coins) | Seans başına 20. Avatar satın almak için |
| Günlük tavan | Aynı çalışma gününde 16 seanstan sonra puan ve kum verilmez; süre yine sayılır |
| Çalışma günü | Yerel 04:00'te başlar |
| Lig | 14 günlük dönemler, 5 kademe (Bronz → Elmas), odada en fazla 30 kişi. Dönem sonunda terfi/düşme ve ilk 3'e ödül avatarı |
| Sıralama | Lig, Aylık (herkese açık, ayın 1'inde sıfırlanır), Arkadaşlar |
| Sosyal | Arkadaşlık kodu, gelen istekler, şu an çalışan arkadaşlar |
| Raporlar | Günlük, Haftalık, Aylık; kategori dağılımı ve günlük hedef |
| Kategoriler | Ücretsiz 8, Premium 15 aktif kategori. Silinmez, arşivlenir |
| Dil / tema | Türkçe (varsayılan) ve İngilizce; açık, koyu, sistem teması |
| Çevrimdışı | Tamamlanan seans önce cihaza yazılır, bağlantı gelince sırayla gönderilir |

## 2. Teknoloji

- **İstemci:** Flutter (Dart ^3.12). `macos/ linux/ windows/ web/` klasörleri çalışmayan şablonlardır.
- **Backend:** Supabase (`eoosnyakvxmifmexpgxa`, eu-north-1): Postgres + RLS, SECURITY DEFINER RPC'ler, Auth (e-posta, Google, Apple), pg_cron, Edge Functions (`unsubscribe`, `send-welcome-email`).
- **Site:** `pomosprint.app`, statik; Cloudflare Workers static assets (`landing/`).
- **Hata izleme:** Sentry (kişisel veri maskeli).

## 3. Mimari

```
main.dart → SplashScreen → AppGate ─┬─ LoginScreen / RegisterScreen
                                    ├─ PostAuthOnboardingScreen
                                    └─ MainNavigationShell (4 sekme, IndexedStack)
                                         ├─ TimerScreen      (Pomo)
                                         ├─ ReportsScreen    (Raporlar → Haftalık, Aylık)
                                         ├─ RankingScreen    (Sıralama)
                                         └─ SocialScreen     (Sosyal)
                                       Üst çubuk: FriendsSheet, ProfileScreen → Kategoriler, Koleksiyon
```

| Katman | Dosyalar | Not |
|---|---|---|
| Uygulama kabuğu | `lib/app/` | `app_gate` tek yönlendirme kapısı; `main_shell` sekmeler ve senkron tetikleyicileri |
| Ekranlar | `lib/screens/` | Supabase'e doğrudan erişmez; servisi çağırır |
| Veri katmanı | `lib/services/supabase_service.dart` | Singleton. `currentUser` (ValueNotifier) kullanıcı için tek kaynak |
| Seans kuyruğu | `lib/services/session_queue.dart` | Kalıcı outbox, hata sınıflandırması, saat farkı düzeltmesi (`server_clock.dart`) |
| Süren seans | `lib/services/timer_persistence.dart` | Sayaç durumu cihazda saklanır |
| Bildirim | `lib/services/notification_service.dart` | Seans bitiş bildirimi; izin ilk Başlat'ta |
| Yardımcılar | `lib/utils/` | `study_day` (04:00 kuralı), `stats_calculator`, renk, kilit |
| Modeller | `lib/models/` | `UserModel`, `CourseCategory`, `StudySession`, `AvatarCharacter` |
| Widget'lar | `lib/widgets/` (`stats/`, `social/`, `auth/`) | Ekranlardan ayrılmış parçalar |
| Yerelleştirme | `lib/l10n/*.arb` + `LanguageService` | Yeni metin yalnızca ARB'ye |

## 4. Sunucu tarafı kısaca

- Seans kaydı tek RPC'dir: `complete_study_session`. Süre, başlangıç zamanı, kategori sahipliği ve çakışma sunucuda doğrulanır; puan, kum, seri ve lig puanı orada hesaplanır.
- İstemci `profiles` tablosunda yalnızca 7 kolonu yazabilir (ad, sosyal görünürlük, segment, günlük hedef, doğum yılı, onboarding, saat dilimi). Ekonomi alanları yalnızca RPC ile değişir.
- Başka kullanıcıların verisi yalnızca RPC'lerden gelir (`get_my_friends`, `get_live_friends`, sıralama RPC'leri).
- Lig devri haftalık cron'la (`process_weekly_leagues`) yapılır; dönem 14 gündür.
- Canlıya uygulanan son migration: `supabase/migrations/20261003150000_live_audit_fixes.sql`. Repodaki eski migration'lar canlı geçmişle eşleşmez; ayrıntı `supabase/README.md`.

## 5. Geliştirirken

- Debug build'de sayaç 5/10 sn'dir ve sunucu bu seansları reddeder. Gerçek seans testi için `flutter run --profile` ya da `--release`.
- Yeni veri ihtiyacı → `SupabaseService`'e metod; yeni sunucu mantığı → canlı tanımdan yazılmış migration (AGENTS.md §2.4).
- Test hesabında oluşturduğun sahte veriyi iş bitince temizle.
- Kullanıcı modern, akıcı ve "premium" hissiyatlı arayüz bekliyor; yer tutucu ya da kaba tasarım bırakma.
- Denetim geçmişi ve kullanıcıya kalan işler: `analiz/PomoSprint_Analiz_Raporu_2026-10-03.md`.
