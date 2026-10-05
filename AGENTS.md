# AGENTS.md — PomoSprint AI devir rehberi

> Son doğrulama: 3 Ekim 2026 (kod, `supabase/` dosyaları ve canlı Edge Function listesi okundu).
> **Çelişki olursa öncelik sırası: canlı DB > bu dosya > repodaki migration'lar > diğer dokümanlar** (`PROJECT_CONTEXT.md`, `analiz/`, kod yorumları).
> Sözleşme (RPC, kolon, hata metni) değiştiren her iş bu dosyayı da güncellemeli.

## Görev türüne göre nereye bak

| Görev | Önce bak | Sunucu tarafı | Bölüm |
|---|---|---|---|
| Seans kaydı, puan, kum, seri hatası | `lib/services/session_queue.dart`, `supabase_service.dart` (`submitCompletedSession`) | `complete_study_session` | §4.2, §5.2, §5.3 |
| Sayaç, duraklatma, uygulama kapanınca seans | `timer_screen.dart`, `services/timer_persistence.dart`, `app/main_shell.dart` | `start_/cancel_study_session` | §4.1, §6.1 |
| Bildirim gelmiyor, kilit ekranı sayacı | `services/notification_service.dart`, `services/lock_screen_timer.dart`, `AndroidManifest.xml`, `ios/Runner/LiveActivityChannel.swift`, `ios/PomoSprintTimerWidget/` | — | §4.1, §4.7 |
| Çevrimdışı kuyruk | `session_queue.dart`, `server_clock.dart`, `test/session_queue_test.dart` | `complete_study_session` | §6.2 |
| Raporlar, gün/hafta hesabı | `reports_screen.dart`, `utils/stats_calculator.dart`, `utils/study_day.dart` | gün kuralı RPC'de | §4.3 |
| Sıralama / lig | `ranking_screen.dart`, `widgets/social/ranking_models.dart`, `widgets/league_info_sheet.dart` | `get_my_league_ranking`, `get_public_*_leaderboard`, `process_weekly_leagues` | §4.4, §6.4 |
| Arkadaşlar, canlı çalışanlar | `friends_sheet.dart`, `social_screen.dart` | `get_my_friends`, `get_incoming_friend_requests`, `add_friend_by_code`, `get_live_friends` | §4.4 |
| Avatar satın alma / kuşanma | `character_collection_screen.dart`, `models/avatar_model.dart` | `purchase_avatar`, `set_equipped_avatar`, `avatar_unlocks` | §4.4 |
| Giriş, kayıt, onboarding, yönlendirme | `app/app_gate.dart`, `login_/register_/post_auth_onboarding_screen.dart` | `handle_new_user` trigger | §4.5, §6.3 |
| Kategoriler | `categories_management_screen.dart`, `models/category_model.dart` | `create_category`, `enforce_category_limit` | §4.5 |
| Çeviri / metin | `lib/l10n/app_tr.arb` + `app_en.arb`, `services/language_service.dart` | — | §4.5 |
| Site (pomosprint.app) | `landing/`, `landing/README.md`, `wrangler.jsonc`, `_headers` | `waitlist`, `unsubscribe` | §8 |
| DB değişikliği | `supabase/README.md` akışı, `migrations/20261003150000_live_audit_fixes.sql` | canlı tanımlar | §2.3, §2.4, §4.6 |
| E-posta (hoş geldin, bülten, abonelikten çıkma) | `supabase/functions/`, `scripts/send_newsletter.js` | `marketing_subscribers` | §8 |
| Yatay telefon / tablet düzeni | `lib/utils/responsive.dart` (Responsive, ContentWidth), `widgets/shell_navigation.dart`, `test/responsive_*_test.dart` | — | Yeni ekranda `Responsive.of(context)` kullan; 6 boyutta taşma testi ekle |
| Derleme, imzalama, platform ayarı | `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `pubspec.yaml` | — | §4.7 |

## 1. Proje bir bakışta

- **Ne:** Oyunlaştırılmış Pomodoro uygulaması. 25 veya 50 dk seans (mola sayacı yok), kategoriler, raporlar, seri bonusu, 14 günlük ligler (yeni açılan odanın ilk dönemi 7–14 gün, §6.4), avatarlar, arkadaşlar.
- **İstemci:** Flutter 3.44 / Dart ^3.12, yalnızca **Android ve iOS**. `macos/ linux/ windows/ web/` çalışmayan şablonlar (macOS bundle id hâlâ `com.example.pomodoro`).
- **Backend:** Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`. Postgres + RLS + SECURITY DEFINER RPC, Auth (e-posta, Google, Apple), pg_cron, Edge Functions.
- **Temel ilke:** Puan, kum (coins), seri ve lig **sunucuda** hesaplanır. İstemci seans meta verisini gönderir, RPC sonucunu gösterir.
- **Site:** `pomosprint.app`. `landing/` derleme adımı olmadan Cloudflare Workers static assets ile yayınlanır.
- **Varsayılanlar:** dil cihazdan (Türkçe ise `tr`, değilse `en`), tema sistem teması, varsayılan avatar `avatar_16_basic`.

## 2. Bir göreve başlamadan önce

### 2.1 Oku
1. Yukarıdaki tablodan işin bölümünü ve §5 sözleşmesini.
2. `git status` ve `git log -5`. Çalışma ağacında başka oturumların commit edilmemiş işleri olabilir; başkasının yarım işini geri alma.
3. Dokunacağın dosyanın tamamını (`supabase_service.dart` için ilgili bölge yeterli).
4. DB işi: `supabase/README.md`, `supabase/proposed/README.md`, `migrations/20261003150000_live_audit_fixes.sql` (canlı gövdelere en yakın kaynak).
5. Site işi: `landing/README.md`.

### 2.2 Çalıştır

| Komut | Ne zaman | Beklenen |
|---|---|---|
| `flutter pub get` | İlk kurulum | Hata yok |
| `flutter gen-l10n` | Her `.arb` değişikliğinden sonra | `lib/l10n/app_localizations*.dart` yeniden üretilir |
| `flutter analyze` | Her değişiklikten sonra | `No issues found!` |
| `flutter test` | Her değişiklikten sonra | Hepsi yeşil (birim + widget testleri; raporlar için `reports_correctness_test`, `reports_findings_test`, kategoriler için `categories_findings_test`). Gün hesabına dokunduysan `TZ=America/New_York flutter test` ile de çalıştır |
| `flutter run` (debug dahil) / `--profile` / `--release` | Gerçek seans ve puan testi | Her derlemede sayaç gerçek süreli (25/50 dk). Hızlı deneme: `--dart-define=QUICK_TIMER=true` (VS Code: "PomoSprint (hızlı test sayacı, kaydedilmez)"): 5/10 sn, TEST rozeti, seans sunucuya ve kuyruğa gitmez |
| `supabase/tests/run_local.sh` | SQL değişikliği; **yalnızca yerel Postgres** | ASSERT'ler geçer. `live_audit_fixes` varsayılan olarak atlanır |
| `supabase start --workdir tool/local_supabase` | Test hesabıyla deneme (canlının Docker'daki birebir kopyası; uygulama `--dart-define` / VS Code "PomoSprint (yerel Supabase)") | `tool/local_supabase/parity_check.sh` → hepsi `aynı`. Test hesapları yalnızca burada; ayrıntı `tool/local_supabase/README.md` |
| `tool/local_supabase/proposed_chain_check.sh` | `supabase/proposed/` dosyası yazınca ya da değiştirince (yerel kopya açıkken) | Kopya veritabanında (ana kopyaya dokunmaz) zincir 12 → … → 14 ve 20–26: her DRYRUN maddesi `true`, DRYRUN'daki gövde = ana dosya, `_down`'lar şemayı birebir geri getirir; `SONUÇ: tüm adımlar beklendiği gibi` |
| `CHAIN_DB=pomosprint_chain_client NO_DOWN=1 KEEP_DB=1 REST_PORT=54331 tool/local_supabase/proposed_chain_check.sh` → `flutter test tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart` → `CHAIN_DB=pomosprint_chain_client DROP_ONLY=1 tool/local_supabase/proposed_chain_check.sh` | İstemcinin canlıda olmayan sunucu davranışına dokunan değişikliği | Aynı istemci kodu ESKİ (ana kopya = canlı) ve YENİ (zincir + 20–25; kopyaya bağlı PostgREST) sunucuda yeşil |
| `tool/local_supabase/e2e/sim/run_sim_e2e.sh [a b c d e]` | Kayıt/onboarding, sayaç, seans/kuyruk, sosyal, profil/silme akışına dokunan değişiklik (yerel kopya + iOS simülatörü açıkken) | Gerçek `main()` ile simülatörde (`integration_test/`) senaryolar yeşil; ekran görüntüleri `analiz/ekranlar/e2e-*.png`, psql doğrulamaları `build/e2e_sim/psql.log`. Ayrıntı ve elle koşulan bildirim / kesinti / kilit ekranı senaryoları: `tool/local_supabase/README.md` "Simülatörde uçtan uca test" |
| `python3 landing/tools/sync_partials.py --check` | Site değişikliğinden sonra | Çıkış kodu 0 |
| `cd scripts && npm test` | `landing/js`, `supabase/functions`, `scripts/send_newsletter.js` değişikliğinden sonra | Hepsi yeşil. Ağsız: Edge Function'lar sahte Supabase ile, site betikleri sahte DOM ile (`scripts/test/`); Node 22.18+ ya da 23.6+ (bayraksız TypeScript ayıklama ve `module.registerHooks`) |
| `cd scripts && node security_regression_test.js` | **Yalnızca kullanıcı onayıyla.** Gerçek hesap açar ve siler | Bazı senaryolar canlıda olmayan `proposed/11` yüzünden bilinçli kırmızı |

### 2.3 Canlı DB'yi kontrol et (salt okuma; Supabase MCP `execute_sql` ya da SQL Editor)

```sql
-- Fonksiyonun canlı gövdesi (tüm overload'lar)
select p.oid::regprocedure, pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'complete_study_session';
-- RLS, tablo / kolon / RPC yetkileri
select tablename, policyname, cmd, roles, qual, with_check from pg_policies where schemaname = 'public' order by 1, 2;
select table_name, grantee, privilege_type from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon','authenticated') order by 1, 2, 3;
select column_name, privilege_type from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles' and grantee = 'authenticated';
select routine_name, grantee from information_schema.routine_privileges
where routine_schema = 'public' and grantee in ('anon','authenticated','PUBLIC') order by 1, 2;
-- Trigger, cron, migration geçmişi
select tgname, tgrelid::regclass from pg_trigger where not tgisinternal and tgrelid::regclass::text like 'public.%';
select jobname, schedule, command from cron.job;
select version, name from supabase_migrations.schema_migrations order by version desc limit 15;
```
Canlı DB okumaları otomatik izin denetimine takılabilir. Takılırsa sorguyu kullanıcıya ver, SQL Editor'de çalıştırsın.

### 2.4 Canlıya SQL yazma akışı
MCP ile yıkıcı SQL çalıştırma. Canlıya yazan SQL'i **kullanıcı Supabase SQL Editor'de çalıştırır**.
1. §2.3 sorgularıyla canlı tanımları oku. Repodaki eski gövdeyi kullanma.
2. `supabase/migrations/<YYYYMMDDHHMMSS>_<ad>.sql` yaz; gövdeyi canlı tanımdan al. Sona `schema_migrations` kaydını ekle (kalıp: `live_audit_fixes`, bölüm 11).
3. `supabase/rollbacks/<sürüm>_<ad>_down.sql` yaz; içinde canlıdaki eski gövdeler olsun.
4. `supabase/tests/<tarih>_<ad>_dryrun.sql` yaz: `BEGIN` → migration → senaryolar → bilinçli `DRYRUN_RESULT` hatası → otomatik geri alma. Örnek: `20261003_live_audit_fixes_dryrun.sql`.
5. Kullanıcı önce DRYRUN'u çalıştırır (her satır `true`), sonra migration'ı.
6. §2.3 sorgularıyla sonucu doğrula; bu dosyada §5 ve §7'yi güncelle.

### 2.5 Görevi bitirirken
- `flutter analyze` temiz, `flutter test` yeşil.
- Yeni metin iki ARB dosyasına da eklendi, `flutter gen-l10n` çalıştırıldı.
- Sözleşme değiştiyse §5 güncellendi.

## 3. Klasör haritası

| Yol | Sorumluluk |
|---|---|
| `lib/main.dart` | Açılış: `.env` → Sentry → `LanguageService` → `ThemeController` → `NotificationService` (beklenmez) → `runApp`. `home: SplashScreen` → `AppGate` |
| `lib/app/app_gate.dart` | **Tek yönlendirme kapısı**: `currentUser` null → Login; `onboardingCompletedAt` null → PostAuthOnboarding; aksi halde Shell |
| `lib/app/main_shell.dart` | `MainNavigationShell`: 4 sekme (Pomo, Raporlar, Sıralama, Sosyal) IndexedStack + TickerMode, bekleyen seans banner'ı, bağlantı dinleyicisi (`app/connection_watcher.dart`), bulutun yeniden denenmesi, `PopScope` |
| `lib/app/` (diğer) | `theme_controller` (`theme_mode`), `session_feedback` (seans sonucu diyalogları), `category_cache` (`saved_categories_uid_<uid>`; eski `saved_categories_<email>` ilk okumada taşınır), `error_reporting` (Sentry, e-posta maskeleme) |
| `lib/screens/timer_screen.dart` | Sayaç durum makinesi (25/50 dk, tek duraklatma, 3-2-1 geri sayım) |
| `lib/screens/splash_screen.dart` | Önce yerel önbellek, sonra `SupabaseService.ensureCloud` (5 sn bekler; başlatma süreçte bir kez başarır, başarısızsa kabuk/giriş yeniden dener), sonra profil ve kategori tazeleme |
| `lib/screens/login_ / register_ / post_auth_onboarding_screen.dart` | Giriş (e-posta, Google, iOS'ta Apple), kayıt, onboarding |
| `lib/screens/categories_management_screen.dart` | Kategori yönetimi (Profil'den açılır) |
| `lib/screens/reports_screen.dart` | Raporlar sekmesi; `history_screen` (**Haftalık**, dosya adı yanıltıcı) ve `monthly_tracking_screen`'e veri verir |
| `lib/screens/ranking_ / social_screen.dart`, `friends_sheet.dart` | Lig/Aylık/Arkadaşlar sıralaması, canlı çalışanlar, arkadaş kodu ve istekleri |
| `lib/screens/profile_ / character_collection_screen.dart` | Ayarlar, hesap silme, avatar satın alma ve kuşanma |
| `lib/services/supabase_service.dart` | Singleton veri katmanı (auth, profil, seans, kategori, lig, arkadaş, avatar). `service_errors` ve `session_queue` tiplerini export eder |
| `lib/services/session_queue.dart` | Kalıcı seans outbox'ı ve hata sınıflandırması (`classifySessionError`) |
| `lib/services/timer_persistence.dart` | Süren seansın cihazdaki kaydı (`active_session_uid_<key>`), `timerDurationSeconds` |
| `lib/services/server_clock.dart` | HTTP `date` başlığından sunucu-cihaz saat farkı |
| `lib/services/service_errors.dart` | `AuthErrorCode`, `ServiceErrorCode`, `ServiceException`. Servis metin üretmez |
| `lib/services/notification_service.dart` | Seans bitiş bildirimi (Android'de exact alarm), Android kalıcı sayaç bildirimi, izin akışı, açma/kapama tercihi |
| `lib/services/lock_screen_timer.dart` | Kilit ekranı sayacı cephesi: Android kalıcı bildirim / iOS Canlı Etkinlik (MethodChannel `com.pomosprint.app/live_activity`), testte no-op |
| `lib/dev/lock_screen_preview.dart` | Kilit ekranı sayacını girişsiz deneme ekranı (`flutter run -t lib/dev/lock_screen_preview.dart`); uygulamadan import edilmez |
| `lib/services/language_service.dart` | Dil seçimi (`app_language_code`), eski `translate()` haritası, `translateCatName` |
| `lib/utils/` | `study_day` (04:00 kuralı), `stats_calculator`, `stats_format`, `async_lock`, `auth_error_text`, `color_hex`, `text_util` |
| `lib/models/` | `UserModel`, `CourseCategory`, `StudySession`, `AvatarCharacter` (gömülü yedek katalog dahil) |
| `lib/widgets/` | `stats/`, `social/`, `auth/` alt klasörleri; kum saati, avatar, lig bilgi sayfası, shell rozetleri |
| `lib/l10n/` | `app_tr.arb` (şablon), `app_en.arb` ve **üretilen** `app_localizations*.dart` (elle düzenlenmez) |
| `test/` | Birim ve widget testleri. Simülatörde uçtan uca testler `integration_test/` (yerel kopyaya bağlı; `tool/local_supabase/e2e/sim/`). `test/support/fake_supabase_service.dart`: Raporlar ve Kategorilerim'e `service:` ile verilen sahte servis |
| `supabase/migrations/` | İleri migration'lar. Yalnızca `20261003150000_live_audit_fixes` canlıda (§4.6) |
| `supabase/rollbacks/` | Down betikleri; CLI uygulamaz |
| `supabase/proposed/` | Öneriler (`01`–`26`). 12, 15, 16, 19 (A), 13, 14, 20–26 canlıda (5 Ekim 2026); 01–11 ve 19 B uygulanmadı. Sıra `proposed/README.md`. Her dosya `\quit` ile başlar |
| `supabase/tests/` | `run_local.sh` (yerel), `*_dryrun.sql` (canlıda, geri alınan transaction) |
| `supabase/functions/` | `unsubscribe`, `send-welcome-email` (repodaki sürümler canlıdan yeni, §10), `delete-account` (canlıda yok; istemci 404/5xx'te `delete_own_account`'a düşer, §5.6) |
| `scripts/` | `security_regression_test.js` (canlı), `send_newsletter.js` (+ `lib/newsletter_mail.js`), `templates/`, `test/` (`npm test`, ağsız). Sırlar `scripts/.env` (şablon `.env.example`) |
| `landing/` | Site: `_partials/`, `tools/sync_partials.py`, `js/config.js`, `_headers`, `worker.js`, `wrangler.jsonc`, `en/` |
| `android/`, `ios/` | Platform yapılandırması (`com.pomosprint.app`). `ios/PomoSprintTimerWidget/` Canlı Etkinlik uzantısı, `ios/Shared/` iki hedefte derlenen ActivityAttributes |
| `tool/ios/add_live_activity_target.rb` | Widget uzantı hedefini `project.pbxproj`'a ekleyen idempotent betik (xcodeproj gem) |
| `analiz/` | 3 Ekim denetim raporu (`PomoSprint_Analiz_Raporu_2026-10-03.md`) ve 245 maddelik bulgu listesi |
| `specs/`, `.specify/`, `.claude/` | spec-kit, proje ajanı `qa-tester`, skill'ler |

## 4. Alan alan rehber

### 4.1 TIMER ve SHELL: sayaç, kabuk, bildirim
**Dosyalar:** `timer_screen.dart`, `timer_persistence.dart`, `app/main_shell.dart`, `notification_service.dart`, `AndroidManifest.xml`

**Kurallar**
- Kalan süre her tick'te ve `resumed`'da `ActiveTimerSession.remainingSecondsAt(now)` ile hesaplanır. Azaltarak sayan koda dönme.
- `clientUuid` ve `startedAt` seans başına **bir kez** üretilir, duraklat/devam boyunca korunur. `client_uuid` sunucudaki idempotency anahtarıdır.
- Seans her durum değişiminde diske yazılır. Açılışta: süre dolduysa hemen tamamlanıp gönderilir. Duraklatılmış seans, devam ettirilse bile bitişi başlangıçtan 24 saat sonraya kalacaksa (`isAbandonedAt`; sunucu `too_old` ile reddeder) silinir ve `pausedSessionExpired` gösterilir: açılışta, BAŞLAT'ta (3-2-1'den önce ve sonra) ve ön plana dönüşte (`test/timer_paused_expiry_test.dart`).
- Sayaç her derlemede (debug dahil) gerçek süreli. Kısaltma yalnızca `--dart-define=QUICK_TIMER=true` ile (`kQuickTimer`, `timerDurationSeconds`): 5/10 sn ve TEST rozeti. Kısaltılmış seans (`ActiveTimerSession.isQuickTest`; derleme bayrağına değil seansa bakılır) `onSessionCompleted`'e verilmez, sonuç diyaloğu "Test seansı — kaydedilmez" der; bu modda Shell `start_/cancel_study_session` çağırmaz. Eskiden debug derlemede kendiliğinden kısalıyordu: 5 sn'lik seans 25 dk diye gidip `session_not_finished` ile reddediliyordu.
- Duraklatma hakkı 1. Seans varken 25/50 değiştirilirse seans sıfırlanır.
- Bildirim izni açılışta değil, ilk BAŞLAT'ta (`ensurePermission`) istenir. Profil'deki anahtar `notifications_enabled` (bitiş bildirimi + kilit ekranı sayacı); "tercih açık VE izin var"ı gösterir (`permissionStatus`: `granted` / `denied` / `notDetermined` / `unknown`, `resumed`'da yeniden okunur). iOS `checkPermissions` hiç sorulmamışla reddedilmişi ayırmaz (ikisi de `isEnabled: false`; `isProvisionalEnabled` izin sayılır); ayrım `notification_permission_asked` ile yapılır. Hiç sorulmamışsa anahtar kapalı, uyarısız; açınca sistem penceresi çıkar. Reddedilirse tercih AÇIK kalır: anahtar kapalı + "Ayarları aç" (Profil'de ve ilk BAŞLAT'ta; `openSystemSettings`: eklentinin `openAppNotificationSettings`'i, iOS'ta yedek `app-settings:`), ayarlardan izin verilip dönülünce anahtar kendiliğinden açılır. İzin platformu testte `debugPermissionPlatform` ile değiştirilir (`test/support/fake_notification_permissions.dart`).
- Kilit ekranı sayacı (`LockScreenTimer`) her durum geçişinde çağrılır: başlat/devam/geri yükleme `showRunning`, duraklat `showPaused`, sıfırla/tamamla/çıkış/ekran kapanışı `clear`, ön plana dönüş `force: true`. Bildirim tercihi kapalıysa gösterilmez; kapatınca `preferenceRevision` ile kaldırılır. iOS Canlı Etkinlik bildirim izni istemez: izin reddedilmiş ama tercih açıksa (anahtar kapalı + "Ayarları aç") sayaç yine görünür. Dart arka planda çalışmaz; geri sayımı sistem yürütür (Android kronometre + `timeoutAfter`, iOS `Text(timerInterval:)` + `staleDate`). Foreground service / background mode EKLEME.
- `start_study_session` / `cancel_study_session` çağrıları Shell'in `onTimerStateChanged` callback'inde yapılır.

**Tuzaklar**
- IndexedStack tüm sekmeleri açılışta kurar ve canlı tutar. Görünmeyen sekme `TickerMode(enabled: false)` alır; periyodik iş yapan ekran `TickerMode.valuesOf(context).enabled`'a bakmalı.
- `ShellNavigationScaffold` gövdesinin MediaQuery'si Scaffold'un gövdeye verdiğinden türetilir (`Builder`). Dış context'le `MediaQuery.removePadding` üst/alt güvenli alanı geri getiriyordu: sekmelerin `SafeArea`'sı iPhone'da üstte ve altta ikinci kez boşluk bırakıyor, sayaçta BAŞLAT alt gezinmenin altına kayıyordu. `responsive_shell_test` güvenli alanlı iPhone boyutlarıyla (402x874, 393x852, 390x844, 375x667) denetler.
- Sayaç düzeni (`_TimerLayout`): dikey telefonda kum saati (en çok 275, eskisinin 1,25 katı) kontrol sütununun tahmini yüksekliğinden (`phoneControlsHeight`; yazı satırları `TextPainter` ile ölçülür, seans varken görünen Sıfırla dahil) kalan alana sığdırılır. Kontrollere öğe ya da aralık eklersen tahmini de güncelle, yoksa BAŞLAT kaydırmaya kalır. 25/50 tek satırda eşit genişlikte (`Row` + `Expanded`); `Wrap` içinde hizalı `Container` satırın tamamını alıp 50'yi alt satıra düşürüyordu.
- Çıkışta süren seans cihazda kalır (aynı hesapla girişte sürer); Shell bildirimi iptal edip `cancel_study_session` çağırır.
- `onAuthStateChange` son olayı yeni aboneye yeniden verir.
- connectivity_plus yalnızca ipucu (`ConnectionWatcher`): iOS'ta dinleme başında ve `checkConnectivity`'de yeni NWPathMonitor'ün ilk yolu sahte `none` olabilir, simülatörde geri geliş olayı gelmeyebilir. `none` hiçbir isteği engellemez ve çevrimdışı göstergesi üretmez; kuyruk zamanlayıcı, ön plana dönüş ve banner ile de denenir.
- Bulut başlatması (`SupabaseService.ensureCloud`) kalıcı olarak düşmez: açılışta hata ya da splash zaman aşımı olursa kabuk (kuyruk turu, ön plana dönüş, bağlantı olayı) ve her giriş denemesi yeniden dener; eşzamanlı çağrılar tek denemede birleşir. Bulut sonradan gelirse kabuk auth dinleyicisini bağlar, profil/kategori/kataloğu okur ve veri ekranlarını yeniler (`notifyConnectionRestored`). Test ortamında `debugCloudInitializer` verilmezse denenmez (gerçek `.env` ile canlıya bağlanılmasın).
- Android bildirim ikonu `@drawable/ic_stat_notification` (`res/raw/keep.xml` R8'den korur). Bu makinede Android SDK yok; Android derlemesi doğrulanmadı.
- Android 14+ kullanıcı kalıcı bildirimi kaydırıp kapatabilir; uygulama ön plana dönünce yeniden gösterilir. Bildirim kimlikleri: 0 bitiş, 1 süren seans (`pomodoro_running_channel`).
- iOS Canlı Etkinlik bitişte "eskir" ("Seans tamamlandı" görünümü); uygulama açılınca seans tamamlanır ve etkinlik kaldırılır. Sistem etkinliği ~8 saatte bitirir.

### 4.2 DATA: veri katmanı ve modeller
**Dosyalar:** `supabase_service.dart`, `session_queue.dart`, `server_clock.dart`, `service_errors.dart`, `models/`

| Parça | Rol |
|---|---|
| `currentUser` (`ValueNotifier<UserModel?>`) | Kullanıcı için **tek kaynak**. Her güncelleme `saved_user` önbelleğini yazar; `signedOut`'ta null olur |
| `fetchCurrentUserModel()` | Profil + `avatar_unlocks` okur, profil yoksa oluşturur, `currentUser`'ı günceller |
| `setCurrentUser()` / `restoreCachedUser()` | Yerel değişikliği servise yazar / çevrimdışı açılışta önbellekten yükler |
| `submitCompletedSession()` | Önce kuyruğa yazar, sonra kuyruğun tamamını gönderir. Sonuç: `SessionSubmitSuccess / Queued / Rejected` (Dart 3 `switch`) |
| `syncPendingSessions()`, `pendingSessionCount` | Kuyruğu gönderir / bekleyen sayısı |
| `takeRejectedSessionNoticeCount()`, `getRejectedSessions()` | Arka planda reddedilen seansların tek seferlik bildirimi / son 50 kayıt |
| `categoriesRevision` (`ValueNotifier<int>`) | Her kategori mutasyonunda artar; Shell ve yönetim ekranı dinler |
| `addStatsChangedListener` | Yalnızca bu cihazdaki olay. Uzak `ranking_updates` yayını **kaldırıldı** |
| `fetchStudySessions({since})` | Yalnızca kendi seansları, 1000'lik sayfalama |

**Kurallar**
- Puan, kum ve seri yalnızca RPC sonucundan okunur. İstemcide formül yazılmaz.
- Kategori kimliği yalnızca UUID ise sunucuya gider (`isUuidCategoryId`). `'1'..'5'` yerel yer tutucudur; kuyruk isimle eşler.
- Seans **hiçbir durumda sessizce silinmez**. Kalıcı ret `rejected_sessions_uid_<uid>` listesine gider.
- `classifySessionError` testlerle kilitli (`session_sync_test`, `session_queue_test`). Değiştirirsen testleri de güncelle.
- Servis metodları hata yutmaz: `ServiceException` / `AuthFailure` fırlatır. UI `serviceErrorCodeOf(e)` ve `authErrorText(l10n, code)` ile metne çevirir.
- `ownProfileColumns` `email` içermez; e-posta oturumdan gelir. `profiles`'ı e-postayla filtreleme, `id` ile güncelle.

**Tuzaklar**
- PGRST202 yedekleri: `fetchFriends` / `fetchPendingFriendRequests` (RPC canlıda var, yedek ölü kod).
- Uygulama kapalıyken biten seans açılışta tamamlanınca kabuğun açılış senkronu (`sync`) ile sayacın `submit`'i yarışır: seansı önceki tur gönderirse `submit`'in kendi turunda seans yoktur. Sonuç o turdan (`SessionQueue._settledOutcomes`, son 50 kabul/ret) okunur; eskiden diyalog, sunucu puanı yazmışken "bağlantı gelince gönderilecek" diyordu (simülatör e2e c, `test/session_queue_test.dart` "eşzamanlı başka tur").
- `updateCategoryOrders` aktif kategoriler için **paralel** `update(sort_order)` yapar; `reorder_categories` çağrılmaz (canlıda yok), upsert de yok. Kısmi başarısızlıkta sıra karışabilir: Kategorilerim hata olunca iyimser sırayı geri alır ve listeyi sessizce yeniden okur. `sort_order` canlıda çakışabilir (`create_category` aktif sayısını yazıyor); istemci `sort_order, created_at, id` ile sıralar. Kalıcı düzeltme `proposed/16`.
- Prefs anahtarları: `saved_user`, `saved_categories_<email>`, `pending_sessions_uid_<uid>` (eski `pending_sessions_<email>` ilk erişimde taşınır), `rejected_sessions_uid_<uid>`, `rejected_sessions_unseen_uid_<uid>`, `active_session_uid_<key>`, `avatar_catalog_v1`, `daily_pomo_goal` (eski, bir kez taşınır), `league_info_shown_<uid>`, `hidden_users_uid_<uid>` (gizlenen kullanıcılar), `onboarding_draft_uid_<uid>` (yarım onboarding), `apple_sign_in_identity` (bu cihazda Apple ile girilen oturumun Apple kimliği; her çıkışta silinir), `app_language_code` + `app_language_device_code` (seçim anındaki cihaz dili), `theme_mode`, `notifications_enabled`, `notification_permission_asked`.
- Hesap silme (`deleteUserAccount` → `clearDeletedAccountLocalData`) kullanıcıya bağlı tüm anahtarları siler ve `TimerPersistence.retireOwner(uid)` ile sayaç ekranının dispose'da seansı yeniden yazmasını engeller. Yeni kullanıcıya bağlı anahtar eklersen oraya da ekle (`test/user_safety_test.dart`).
- Avatar: `AvatarCharacter.byId` ve `allAvatars()` asla fırlatmaz / boş dönmez. Yine de listelerde korumasız `.first` kullanma.
- `supabase_service.dart` içinde "public leaderboard `is_me` DÖNMEZ" yorumu bayat; canlı RPC `is_me` döndürüyor.

### 4.3 STATS: Raporlar sekmesi
**Dosyalar:** `reports_screen.dart`, `history_screen.dart` (Haftalık), `monthly_tracking_screen.dart`, `utils/stats_calculator.dart`, `widgets/stats/`

**Kurallar**
- Veriyi yalnızca `ReportsScreen` çeker; Haftalık ve Aylık ekranlar parametre alır.
- Gün = çalışma günü, sınır yerel 04:00 (`studyDayOf`). Üçüncü bir gün kuralı icat etme.
- Hafta Pazartesi-Pazar (`mondayOf`). Takvim adımı `DateTime(y, m, d + n)` / `addDays`; `Duration(days:)` kullanma (DST).
- Sunucu ve kuyruk seansları yalnızca `mergeStatSessions(remote, pendingStatSessions(queue), categories)` ile birleşir:
  - `client_uuid`'si sunucu listesinde olan bekleyen seans atılır (yanıtı kaybolmuş seans iki kez sayılmaz). `_studySessionColumns` bu yüzden `client_uuid` içerir.
  - `lastError == 'overlap'` olan bekleyen seans sayılmaz (sunucu onu hiç kabul etmez); kuyrukta ve bantta kalır.
  - Bekleyen seansın günü kuyruğun gönderdiği düzeltilmiş saatle: `startedAt + clockOffsetMs` (yoksa o anki fark). Raporların "bugün"ü de sunucu saatiyle.
  - Bekleyen seansın kategorisi kimlikle (yer tutucuda dilden bağımsız adla, `categoryMatchKey`) çözülür; ad, renk, ikon sunucu birleşiminden (arşivlenmiş dahil), yoksa aktif listeden.
- Kategori toplamları **kimlikle** gruplanır (`statGroupKey`); yeniden adlandırma satırı bölmez. Kimliksiz kayıtlar adla.
- Kuyruk sunucu okumasından önce ve ondan bağımsız okunur: çevrimdışıyken de bekleyenler görünür. Uzak okuma başarısız olunca, kuyruktan çıkmış (reddedilmemiş) seanslar sunucu seansı olarak tutulur; toplam düşmez.
- `ReportsScreen` `categoriesRevision`'ı dinler (görünürse hemen, değilse dönüşte yenilenir).
- Günlük hedefin kaynağı `profiles.daily_goal_minutes` (`showDailyGoalSheet` → `updateDailyGoalMinutes`). Varsayılan 200 dk. Hedef sayfasındaki pomodoro sayısı yukarı yuvarlanır (hedefe ulaşmak için gereken).
- Yüzde gösterimi: dağılım lejantı `roundedPercents` (toplam 100); verimlilik kartı `goalProgressPercent` (kırpılmaz), halkalar `goalPercent` (en çok 100). Haftalık verimlilik etiketi geçen günlerin hedefine göre (`elapsedWeekGoalPercent`).
- Kategori adları DB'de çoğunlukla Türkçe, İngilizce onboarding'de İngilizce saklanır; gösterirken `translateCatName`, eşlemede `categoryMatchKey` (tablo: `utils/category_names.dart`). 50 dk = 2 pomodoro.

**Tuzaklar**
- Hızlı test sayacıyla (QUICK_TIMER) istatistiklerin değişmemesi beklenen durum: test seansları kaydedilmez.
- Gün kuralı istemcide de sunucuda da **profil diliminde** 04:00 (`studyDayOf`, `setStudyTimeZone`; `currentUser.timezone` değişince otomatik). `profiles.timezone` istemciden yazılmadığı için fiilen herkes `Europe/Istanbul`: cihazı başka dilimde olan kullanıcı günleri İstanbul'a göre görür (sunucuyla tutarlı, kullanıcının yerel günüyle değil; §10).
- Sıralama > Aylık (`get_public_monthly_leaderboard`) ve Raporlar > Aylık aynı çalışma ayı kuralını kullanır: `started_at`, profil dilimi, 04:00 (`proposed/15`, 5 Ekim 2026'dan beri canlıda). Geri sayım `nextMonthlyLeaderboardReset` (`ranking_models.dart`) `studyDayOf`/`studyDayStart` ile ayın 1'i 04:00.
- Yenileme ve gün dönümü zamanlayıcısı TickerMode'a bağlı; sekme görünmezken durur. Üst çubuktaki seri `StudyDayBuilder` ile 04:00'te kendiliğinden tazelenir.
- Testler: `test/reports_correctness_test.dart` (sabit veri setiyle tüm metrikler), `test/reports_findings_test.dart`, `test/support/fake_supabase_service.dart` (ekranlara `service:` ile verilir).

### 4.4 SOCIAL: lig, sıralama, avatar, profil, arkadaşlar
**Dosyalar:** `ranking_screen.dart`, `widgets/social/*`, `league_info_sheet.dart`, `social_screen.dart`, `friends_sheet.dart`, `profile_screen.dart`, `character_collection_screen.dart`, `avatar_model.dart`

**Kurallar**
- Sekmeler: **Lig | Aylık | Arkadaşlar**. "Tüm zamanlar" sekmesi kaldırıldı (`getAllTimeRanking` ve `getLeagueZones` servis metodları çağrılmıyor).
- "Ben" satırı yalnızca `is_me` ile bulunur. İsimle eşleme yapma. Arkadaşlar sekmesinde kendi satırı yerel profilden eklenir.
- Lig verisi `get_my_league_ranking()` ile okunur; terfi/düşme bölgeleri satırla birlikte sunucudan gelir (`LeagueSnapshot`).
- Ligsiz satır: `member_count` 0 (`proposed/20`, canlıda; öncesinde 1'di, tek kişilik gerçek odayla aynı). `LeagueSnapshot.fromRows` sırasıyla `has_league` → `member_count` 0 → birden çok üye/puan → kural sunucudan geldiyse (20) gerçek oda → canlıda `hasLeagueHistory` (ömür boyu puan > 0: puan kazandıran her seans odaya yerleştirir, üyelik silinmez). "Henüz bir lig odasında değilsin" yalnızca `awaitingPlacement`; odasında tek ve puansız kalan (terfi sonrası, t4-F6) "Odanda şimdilik yalnızsın" (`isAloneInRoom`).
- Lig ödül/terfi kuralı `LeagueRules` (`models/league_rules.dart`): `SupabaseService.getLeagueRules()` `get_app_config()`'ten (`league_award_min_members`, `league_award_min_points`, `league_promotion_min_points`; `proposed/20`) okur, süreç boyunca saklar; RPC yok (PGRST202, 20 öncesi sunucu) ya da anahtar yoksa bugünkü kural 1/1/1; canlıda anahtarlar var (bugün 1/1/1). `isPromotionRank`, `zoneOf`, `earnsAward` (podyum madalyası) ve metinler (`widgets/social/league_rule_texts.dart`: `leagueInfoPromote*`, `leagueAwardsSub*`, `leagueAwardLocked*`, `rankingZoneNeeds*`) aynı kuralla; 1/1/1'de eski metinler birebir.
- Lig: 14 gün (yeni açılan odanın ilk dönemi 7–14 gün, §6.4), 5 kademe (1 Bronz … 5 Elmas), en fazla 30 üye. Puan sabitleri `get_points_config`'ten okunur; `league_info_sheet`'teki sayılar yalnızca yedek.
- Avatar sahipliği = `avatar_unlocks` kaydı ya da ücretsiz (`isOwned`). Kaydı olmayan varsayılan avatar (kataloğa sonradan eklenen, t4-F9): canlı `set_equipped_avatar` 'Bu avatar kilitli.' der; `setEquippedAvatar` (`services/avatar_equip.dart`) yalnızca katalogda varsayılan ve bedelsizse kaydı `purchase_avatar` ile (0 kum) açıp bir kez yeniden dener (`proposed/22` sonrası ilk deneme başarılı). Lig ödülü avatarları satın alınamaz. Premium'a özel avatarlar (edinme yolu / IAP yok, App Store 2.3.1) yalnızca sahibine ya da Premium kullanıcıya listelenir (`isListedInShop`).
- Profil ve Koleksiyon `currentUser`'ı dinler; kopya tutmaz.
- Başka kullanıcının verisi yalnızca RPC ile gelir.
- Kullanıcı içeriği (App Store 1.2): başkasının satırında uzun basma / "⋮" ile `showUserSafetySheet` (`widgets/social/user_safety.dart`). Sıralama ve canlı akışta "Bildir" + "Gizle", arkadaş listesi ve isteklerde yalnızca "Bildir"; kendi satırında menü yok. Bildirim `mailto:destek@pomosprint.app` (görünen ad, varsa genel kimlik, yer; bildirenin bilgisi URL'ye konmaz).
- Gizleme cihazda, hesaba bağlı (`HiddenUsersStore`, `hidden_users_uid_<uid>`). Lig/Aylık RPC'leri kimlik döndürmediği için orada adla eşlenir; sıralamada satır silinmez, ad/avatar "Gizlenen kullanıcı" olur (sıra ve lig bölgeleri bozulmaz). Profil > Gizlilik ve yasal'dan sıfırlanır.
- Görünen ad denetimi `utils/name_filter.dart` (kayıt, profil ad düzenleme, Google/Apple ilk adı). Sunucuda içerik denetimi yok (§10).
- Profil adı e-postadan türetilmez: sağlayıcı ad vermezse (Apple adı yalnızca ilk yetkilendirmede verir) ya da ad kullanılamazsa (küfür, tek harf) ad `SupabaseService.neutralProfileName` olur: `'Pomo ' + kimliğin ilk 4 karakteri`. `handle_new_user` canlıda hâlâ e-postanın yerel kısmını yazıyor; istemci (`providerFirstNameUpdate`) bunu Google/Apple girişinde nötr ada çeker, nötr adı da sunucu tohumu sayar (sağlayıcı adı gelirse onunla değişir). Sunucu bu biçime geçerse ikisi uyumlu kalır.

**Tuzaklar**
- Arkadaş silme, giden isteği iptal ve engelleme UI'ı yok. Sunucu hazır (`proposed/14`, canlıda): `remove_friend`, `cancel_friend_request`, `get_outgoing_friend_requests`, `block_user`, `unblock_user`, `get_my_blocks`, `submit_user_report` (sözleşme `proposed/README.md` "Öneri 14"). Gizleme şimdilik cihazda.
- `add_friend_by_code` / `respond_friend_request` yanıtında makine-okunur `code` var (`proposed/13`–`14`, canlıda: `request_sent`, `accepted`, `rejected`, `rate_limited`, `cooldown`, `blocked`, …). İstemci `friendResponseCode` ile önce `code`'a, yoksa sunucunun sabit Türkçe mesajına bakar (`bulunamad` → `not_found`, `kendini`, `zaten arkadaş`, `zaten istek`); mesaj metni değişirse `test/friends_sheet_test.dart`'ı güncelle. Kod girişi `utils/friend_code.dart`: sunucudaki `normalize_friend_code` (13) ile aynı normalize (boşluk/tire/alt çizgi/nokta atılır, büyük harf, O→0, I/L→1; sunucu da aynısını yapar), 6–8 karakter Crockford alfabesi (eski 6 hex alt kümesi); biçimce geçersiz kod gönderilmez (13 her denemeyi saatlik sınıra sayar). Yanıtlanamayan istekte (sunucu cevap verdiyse) liste her zaman tazelenir, bayat kart kalmaz.
- Podyumda madalya yalnızca puanı > 0 olan koltukta (sunucu lig ödülünü puanı > 0 olan ilk 3'e verir); sıra rozeti (#1–#3) her zaman.
- Sosyal ekran 30 sn'de bir poll yapar; görünmezken durur.
- Avatar görseli: uygulamada `assets/avatars/<asset_key>`, sitede `landing/avatars/<id>.webp`.

### 4.5 AUTH ve L10N: giriş, onboarding, kategoriler, yerelleştirme
**Dosyalar:** `app/app_gate.dart`, `login_screen.dart`, `register_screen.dart`, `post_auth_onboarding_screen.dart`, `categories_management_screen.dart`, `widgets/auth/*`, `language_service.dart`, `l10n/`

**Kurallar**
- Yönlendirme yalnızca `AppGate`'te. Ekranlar kendi aralarında Login/Onboarding/Shell'e geçiş yapmaz; `currentUser`'ı günceller.
- Onboarding `completeOnboarding()` ile biter (önce kategoriler, sonra profil). Profili `handle_new_user` trigger'ı oluşturur; istemci upsert'i yedektir ve avatar sunucuda varsayılana zorlanır. `showInSocialFeed` zorunlu ve her zaman yazılır (gönderilmezse sunucu varsayılanı TRUE kalır).
- Kategoriler `planOnboardingCategories` (`services/onboarding_categories.dart`) ile mevcut kategorilerle uzlaştırılır: ad eşlemesi dilden bağımsız (`categoryMatchKey`), zaten olan yeniden gönderilmez, önceki denemede arşivlenen geri açılır. Onboarding'i bitmemiş, sunucuda ve kuyrukta hiç seansı olmayan hesapta yeni seçimde olmayan aktif kategoriler arşivlenir (önceki deneme yarıda kaldıysa yeni seçim limite takılmaz, TR/EN çifti oluşmaz). Sıra `reconcileOnboardingCategories`; RPC yükü eksikler + aktif kalacaklar (`OnboardingCategoryPlan.rpcPayload`): `proposed/23` onboarding bitmemişken yükte olmayan seansız aktif kategoriyi arşivliyor, yalnız eksikler gönderilirse seçimdeki kategori arşive giderdi (canlıda birebir aynı ad atlandığı için zararsız). 23'ün jsonb sonucu `OnboardingCategoriesResult` (canlıda void → null); `skipped_limit` > 0 ise onboarding sonunda `onboardingCategoriesSkippedLimit`. Sunucu 13 yaş sınırı (`proposed/24`, `birth_year_under_minimum_age`) → `ServiceErrorCode.underMinimumAge`: yaş adımına dönülür, yıl kilitlenir. Öneri tablosu (`kRecommendedCategoriesBySegment`) ekranla ortak; hiç kategorisi olmayan hesabın varsayılanı (`ensureServerCategories`, kuyruk `createDefaultCategories`) segmentin ilk 5 önerisi, arayüz dilinde (`defaultCategorySeed`).
- Onboarding 6 adım: yaş (tekerlek önceden ayarlı değil, "Devam"da değerlendirilir; 13 altı yanıttan sonra yıl kilitlenir, çıkış / hesap silme kalır), segment (isteğe bağlı; sıra LGS, YKS, KPSS (`kpss`), Dil sınavı (`language`: YDS/YÖKDİL/IELTS/TOEFL), Üniversite, İş, Diğer; "Diğer" → `user_segment` null), kategoriler, sıralamalarda görünürlük (varsayılansız açık seçim → `show_in_social_feed`), oyun kuralları (`GameRulesList`, `get_points_config`), hedef.
- Hedefe göre kategori ataması: segment seçilince o segmentin önerileri limite kadar (`categoryLimitFor`; YKS'de ücretsiz 8/9) **seçili gelir** (`autoSelectedCategoryNames`), başlık "Hedefine göre hazırladık" (`onboardingCategoryStepPrepared*`; "Diğer"de genel öneriler seçili, eski başlık). Ekran otomatik gelenleri ayrı tutar (`_autoCategoryNames`): segment değişince yalnızca onlar yeni segmentinkilerle değişir; elle seçilen öneriler (başka segmentinki olsa da çip olarak görünür kalır) ve özel kategoriler korunur. Tüm öneri adları `utils/category_names.dart`'ta TR/EN eşli olmalı (`test/onboarding_categories_test.dart` denetler).
- Segment sunucusu: `profiles_user_segment_check` `lgs, yks, kpss, language, university, work` (`proposed/26`, canlıda). Eski sunucu için yedek yol kodda duruyor: İstemci (`validUserSegments`) yeni hedefleri gönderir; 23514 + `user_segment` gelirse `completeOnboarding` aynı PATCH'i `user_segment = null` ile bir kez daha yazar (`writeOnboardingProfileWithSegmentFallback`): onboarding tamamlanır, kategoriler önceden kurulmuştur, kullanıcı hata görmez. Birim: `test/onboarding_goal_categories_test.dart`; yerel kopyada uçtan uca (ekran dahil): `tool/local_supabase/e2e/t2_onboarding_categories/segment_fallback_e2e_test.dart`.
- Taslak (`OnboardingDraft`) görünürlük yanıtını (`show`) ve otomatik gelen kategorileri (`auto`) da tutar. Geri yüklemede "Diğer" ve segmentsiz seçimler korunur (izinli adlar: herhangi bir segmentin ya da genel öneriler + özel adlar); `auto` olmayan (eski sürüm) taslakta segment seçili ama kategori yoksa öneriler seçilir ve kategori adımı gösterilir; adım yaş, kategori ve görünürlük yanıtı eksikse o adıma çekilir. "Bitir" görünürlük yanıtı yoksa görünürlük adımına döner (`test/account_session_test.dart` "Onboarding taslağı").
- Kategori limiti ücretsiz 8, premium 15 (`categoryLimitFor`). Sunucu trigger'ı eklemede ve arşivden çıkarmada uygular; istemci kontrolü UX içindir. Kategori silinmez, arşivlenir.
- Yeni metin **yalnızca ARB'ye** (iki dosyaya da) eklenir, sonra `flutter gen-l10n`.
- Yasal sayfalar (`legal_links.dart`, `LegalPage`): TR `pomosprint.app/terms|privacy|kvkk`, diğer diller `/en/terms|/en/privacy|/en/kvkk`. Metin sürümü tek sabit: `kLegalDocumentsVersion`; yasal metin değişince artır.
- Profil > "Gizlilik ve yasal": Gizlenen kullanıcıları göster, Kullanım Şartları, Gizlilik Politikası, KVKK Aydınlatma Metni, Hesabımı Sil. Uygulama içi silme Apple 5.1.1(v) için yeterli; hesap silme web sayfası (`/hesap-silme`, `/en/delete-account`) Play Console'daki silme URL'sidir, uygulamada bağlanmaz. Veri kopyası (KVKK m.11 erişim hakkı) Aydınlatma Metni'ndeki e-posta yoluyla istenir; silme onayı bunu `destek@pomosprint.app` ile hatırlatır.
- Kayıt onayları: iki zorunlu (Kullanım Şartları kabulü; KVKK Aydınlatma Metni + Gizlilik Politikası okundu, rıza değil bilgilendirme teyidi), bir isteğe bağlı (ticari elektronik ileti, varsayılan kapalı). "Tümünü kabul et" yok. Zorunlular olmadan `registerUser` çağrılmaz; servis de `StateError` fırlatır. Metadata sözleşmesi §5.5.
- Google/Apple ile devam: giriş ekranındaki `SocialSignInNotice` (Kullanım Şartları + KVKK Aydınlatma Metni bağlantılı). Bu yolda onay metadata'sı yazılmıyor (§10).

**Tuzaklar**
- Üç çeviri yolu bir arada: ARB, `LanguageService.translate('key')` haritası (Timer, Raporlar, Profil, nav etiketleri) ve `isTurkish ? … : …`. Eski anahtarları taşımak ayrı bir iş; yeni `translate` anahtarı ekleme.
- Auth akışı **implicit** (`authFlowType: implicit`, `detectSessionInUri: false`). Sıfırlama/onay linkleri web sayfasında işlenir. Özel URL şeması (`io.supabase.pomosprint`) kaldırıldı.
- Auth istekleri (giriş, kayıt, sıfırlama, yeniden gönderme, sosyal giriş, şifre değiştirme) `runAuthRequest` ile 25 sn zaman aşımlı; kayıtta zaman aşımı ayrı metin (`signUpTimedOut`: "kayıt tamamlanmış olabilir").
- Oturum kapanışı tek kancadan: `signOutFully({notice})` (çıkış, silme, Apple izni) ve `handleAuthStateChange` (`signOutReason == sessionExpired`: şifre değişti / başka cihazdan kapatıldı). Kanca Google oturumunu, bitiş bildirimini ve kilit ekranı sayacını kapatır; `signOutNotice` giriş ekranında bir kez açıklanır (kullanıcının kendi çıkışında açıklama yok).
- Şifre kuralı (`widgets/auth/password_rules.dart`): en az 6 karakter + küçük/büyük harf + rakam; Supabase panel ayarı, `authErrWeakPassword` ve `landing/js/reset-password.js` ile aynı tutulmalı. Kayıt ve Profil > Şifreyi değiştir (yalnızca `email` sağlayıcısı; mevcut şifreyle yeniden doğrulama + `updateUser`) canlı kural listesi gösterir.
- Kayıt ekranı `RegisterResult` döndürür (`RegisterSignedIn` / `RegisterAwaitingConfirmation`); onay bekleniyorsa giriş ekranı e-postayı doldurur ve "yeniden gönder"i doğrudan gösterir.
- Apple: iOS'ta Apple ile girilen oturum için açılışta ve ön plana dönüşte `getCredentialState` (revoked/notFound → tam çıkış). Android'de Apple girişi yok; giriş ekranındaki "Apple ile mi kaydoldun?" yardımı "Şifremi Unuttum" ile şifre belirlemeyi anlatır.
- Google iOS: Supabase'de "skip nonce" bilinçli açık. iOS client id üç yerde aynı olmalı: `GIDClientID`, `CFBundleURLSchemes` (ters çevrilmiş), `supabase_service.dart`.
- Apple girişi iOS login ekranında var; Apple Developer capability ve Supabase Apple provider ayarı kullanıcıda.
- `AppGate`, onboarding ekranına `onSignedOut` vermiyor; onboarding'de Çıkış butonu gizli.
- Dil: kayıtlı seçim yoksa cihaz dili (`PlatformDispatcher.locale`; iOS ve Android 13+ uygulama başına dil dahil, `locales_config.xml`). Giriş ekranında TR/EN seçici var. Seçim, o anki cihaz diliyle saklanır; cihaz dili sonradan değişirse cihaz izlenir (`test/language_service_test.dart`).
- `onboarding_screen.dart` ve `categories_screen.dart` silindi; geri getirme.

### 4.6 BACKEND: Supabase
**Dosyalar:** `supabase/README.md`, `supabase/proposed/README.md`, `migrations/20261003150000_live_audit_fixes.sql`, `tests/20261003_live_audit_fixes_dryrun.sql`

**Migration durumu**

| Dosya | Canlıda |
|---|---|
| `migrations/20260809*` … `20260809033000` | **Yok.** Canlı geçmişte farklı isimli ~36 migration var; içerik farklı. Tarihçe |
| `migrations/20260928120000_security_hardening_up` | **Hiç uygulanmadı.** `validate_study_session_timing` ve `session_not_elapsed` canlıda yok |
| `migrations/20261003150000_live_audit_fixes` | **Uygulandı** (3 Ekim, DRYRUN 28/28), geçmişe kayıtlı. Geri alma: `rollbacks/20261003150000_live_audit_fixes_down.sql` |
| `proposed/11_audit_fixes_unapplied.sql` (eski `20261003120000_audit_fixes`) | **Uygulanmadı**, `migrations/`'tan taşındı. Başındaki durum notu hangi parçanın gereksiz olduğunu söyler |
| `proposed/01`–`10` | Uygulanmadı. Sıra ve kapsam `proposed/README.md`'de |
| `proposed/12`, `15`, `16`, `19` (A), `13`, `14`, `20`–`26` (+ `_down`, `tests/proposed_*_dryrun.sql`) | **Uygulandı** (5 Ekim 2026, bu sırayla; kullanıcı onayıyla `supabase db query --linked --project-ref`, `postgres` rolü). Her adımda önce DRYRUN (hepsi `true`: 14/14, 6/6, 13/13, 12/12, 50/50, 67/67, 15/15, 10/10, 9/9, 13/13, 9/9, 9/9, 9/9), sonra dosya (`\echo`/`\quit` satırları çıkarılarak), sonra md5/katalog doğrulaması. Uygulama öncesi canlı parmak izi 4 Ekim kopyasıyla 13/13 aynıydı; sonrası yerel zincirle satır satır aynı (fark yalnızca bilinçli: 19 B yok, kopyaya özgü eklentiler, yerelde kapalı hoş geldin trigger'ı). Ürün düğmeleri varsayılanda: `unverified_session_daily_cap` null, lig ödül/terfi 1/1/1, geç seans kendi gününün serisiyle. Geri alma ters sırayla `_down` dosyaları (`proposed/README.md`) |
| `proposed/19` B (yalnızca onaylı bekleme listesi kaydı) | **Uygulanmadı.** Önce site onay alanlarını göndermeli (§ landing); yoksa kayıt tamamen durur |
| `proposed/13` KVKK-20 2. aşama (`profiles.email` kolonunu kaldırma, dosya sonunda yorum) | **Uygulanmadı.** Ön koşul: istemci yedek profil upsert'ünden `email` çıkmış ve o sürüm `min_supported_version` |

**Canlıda olmayan RPC'ler:** `reorder_categories`, `set_my_timezone`, `get_my_category_limit` (ayrıca `get_my_streak`, `study_day_of`, `my_friend_ids`, `synced_at` kolonu). Gerekirse `proposed/11`'den canlı gövdelere göre ayrı migration yaz.

**Kurallar**
- Canlı tanım gerçeğin kaynağı. Repodaki eski gövdeden `CREATE OR REPLACE` yazma.
- Her SECURITY DEFINER fonksiyon: `SET search_path TO 'public','pg_temp'`; kullanıcı `auth.uid()`'den; `REVOKE ALL … FROM PUBLIC, anon` + `GRANT EXECUTE … TO authenticated`.
- `DROP` + `CREATE` yetkileri sıfırlar ve PUBLIC'e EXECUTE verir. Yetkileri her seferinde yeniden yaz.
- `RAISE EXCEPTION` P0001 üretir; istemci **mesaj metniyle** sınıflandırır. Mesaj değiştirirsen `classifySessionError`'ı ve testleri de değiştir.
- Puan sabitleri üç yerde: `complete_study_session`, `get_points_config`, `league_info_sheet` yedeği. Birlikte değiştir.
- İstemcinin yeni bir `profiles` kolonuna yazması gerekiyorsa önce `GRANT UPDATE (kolon)`.

**Tuzaklar**
- `supabase db push` / `db reset` **çalıştırma**: geçmiş uyuşmadığı için eski dosyaları canlıya uygulamaya çalışır. Önce baseline (`supabase/README.md`).
- `run_local.sh` stub'ı canlıyı birebir modellemez; `audit_fixes_test.sql` artık `migrations/`'ta olmayan nesneleri test ediyor.
- `security_regression_test.js` canlıda gerçek hesap açıp siler. Kullanıcıya sormadan çalıştırma.

### 4.7 PLATFORM: derleme, yapılandırma
**Dosyalar:** `pubspec.yaml`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `Runner.entitlements`, `project.pbxproj`, `l10n.yaml`

**Kurallar**
- `applicationId`, `namespace` ve iOS bundle id: `com.pomosprint.app`. Google, Apple ve Supabase ayarları buna bağlı. Activity: `kotlin/com/pomosprint/app/MainActivity.kt`.
- Kök `.env` APK/IPA'ya düz metin gömülür. Yalnızca `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`.
- Release AAB için `android/key.properties` + upload keystore (ikisi de gitignore'da). Yoksa `bundleRelease` hata verir; `assembleRelease` uyarıyla debug imzası kullanır.
- iOS: min 15.0, UIScene yaşam döngüsü, SPM (Podfile yok), team `AQGX8BJMYJ`. Entitlements: Sign in with Apple, time-sensitive bildirim.
- iOS Canlı Etkinlik: `PomoSprintTimerWidget` uzantısı (iOS 16.2, `com.pomosprint.app.TimerWidget`, App Group yok), Runner'da `NSSupportsLiveActivities`, ActivityKit zayıf bağlı. "Embed Foundation Extensions" aşaması "Thin Binary"den önce kalmalı (yoksa "Cycle inside Runner"). Hedefi elle değil `tool/ios/add_live_activity_target.rb` ile düzelt.
- `ios/Runner/PrivacyInfo.xcprivacy`: izleme yok; toplanan veri türleri App Store Connect gizlilik etiketleriyle aynı tutulmalı.
- Android: `allowBackup=false` + `data_extraction_rules.xml`; bildirim receiver'ları manifest'te. Exact alarm: `USE_EXACT_ALARM` (13+) ve `SCHEDULE_EXACT_ALARM` (`maxSdkVersion=32`); Play Console'da exact alarm beyanı gerekir.
- Sentry: `enablePrintBreadcrumbs=false`, e-postalar maskelenir. Yine de `debugPrint`'e kişisel veri yazma.
- Mağaza derlemesi yalnızca `scripts/build_release.sh` ile (`--obfuscate --split-debug-info`; Dart sembolleri, obfuscation haritası, R8 mapping Sentry'ye; README > Mağaza derlemesi). Sentry kimlikleri `scripts/.env`'de (`SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`); `pubspec.yaml`'daki `sentry:` bloğuna org/proje/token yazma.
- R8: ek `proguard-rules.pro` gerekmiyor. `sentry_flutter` kendi consumer kurallarını getiriyor (`io.sentry.**`), `flutter_local_notifications` 22.x modellerinde `@Keep` var ve GSON 2.12 kendi kurallarını taşıyor; bildirim ikonu `res/raw/keep.xml` ile korunuyor. Gerekirse `android/app/proguard-rules.pro` açın; Flutter Gradle eklentisi onu kendisi ekler, `build.gradle.kts`'e bağlamak gerekmez.
- Uygulama adı her yerde `PomoSprint`: `kAppDisplayName` (MaterialApp.title, Android son uygulamalar), `android:label`, `CFBundleDisplayName`. `test/platform_config_test.dart` denetler.
- İkon ve açılış ekranı üretilir, elle düzenlenmez: `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create` (ayar `pubspec.yaml`). Monochrome (Android 13+ temalı ikon) `assets/icon/monochrome.png`: `foreground.png`'nin alfa kanalı, beyaz. Android 12+ splash simgesi `assets/icon/splash_android12.png` (daire maskesine sığacak kadar küçültülmüş logo). Açılış renkleri `AppColors.surface` / `darkSurface` ile aynı; tema rengi değişirse `platform_config_test` kırılır.

**Tuzaklar**
- `google_sign_in` 6.x'te; 7.x'e geçiş (Credential Manager) yapılmadı. Yapılacaklar: `GoogleSignIn.instance.initialize(serverClientId, clientId)` tek sefer; `signInSilently() ?? signIn()` yerine `attemptLightweightAuthentication()` ve `authenticate()`; `idToken` `account.authentication`'dan, `accessToken` yalnızca `authorizationClient.authorizationForScopes` ile (Supabase `signInWithIdToken` için idToken yeterli); `signOut`/`disconnect` yeni API; iOS'ta nonce (idToken'da nonce varsa Supabase aynısını ister) ve `GIDClientID` yeniden doğrulanmalı; Android'de Credential Manager için gerçek cihazda test. Android derlemesi doğrulanamadığı için ertelendi.
- iOS'ta Supabase oturumu (refresh token) ve `saved_user` önbelleği SharedPreferences'ta, yani NSUserDefaults'ta; cihaz yedeğine girer. `flutter_secure_storage` + özel `LocalStorage` ertelendi: yeni native eklenti Android'de derlenip denenemiyor; Keychain kilitliyken (ilk kilit açmadan önce arka plan açılışı) okuma hatası oturumu sessizce kapatır; Keychain kaydı uygulama silinince kalır. Göç yazılırken eski anahtar ancak yeni depoya yazma doğrulanınca silinmeli.
- `assets/league_award_avatars/` (9,6 MB) kullanılmıyor, pubspec'te yok.
- `.claude/settings.local.json` ve `landing/.claude/settings.local.json` gitignore'da ama git'te izleniyor olabilir (`git rm --cached` kullanıcıda).

### 4.8 LANDING: pomosprint.app
§8'e bak. Özet: uç sayfa adlarını değiştirme, inline `<script>`/`style=""` yazma, ortak parçaları `_partials/` içinde düzenleyip `sync_partials.py` çalıştır, Supabase URL ve anon key yalnızca `js/config.js`'te.

## 5. İstemci ↔ sunucu sözleşmesi

### 5.1 RPC'ler (canlı)

| RPC | Parametreler | Döndürdüğü | Çağıran | anon |
|---|---|---|---|---|
| `complete_study_session` | `p_client_uuid uuid, p_category_id uuid, p_duration_minutes int (25\|50), p_was_paused bool, p_is_verified int (ön planda geçen sn), p_started_at timestamptz` | jsonb `{base_points, bonus_points, total_points, coins_earned, streak, bonus_pct, duplicate, daily_limit_reached}` veya `{error:'overlap'}` | `SessionQueue` | Hayır |
| `start_study_session` | `p_duration_minutes int, p_category_name text` | void (`profiles.active_session_*`) | Shell (sosyal görünürlük açıksa) | Hayır |
| `cancel_study_session` | — | void | Shell (duraklat, bitiş, sıfırla, çıkış) | Hayır |
| `get_my_league_ranking` | — | `name, avatar_id, weekly_points, tier, end_date, is_me, promotion_zone_end, demotion_zone_start, member_count` (ligsiz satır `member_count` 0; `proposed/20`) | Ranking, lig bilgi sayfası | Hayır |
| `get_league_ranking` | `p_user_id uuid` (yalnızca kendi id'si) | Yukarıdakiyle aynı | Kullanılmıyor | Hayır |
| `get_league_zones` | `p_member_count int` | `promotion_zone_end, demotion_zone_start` | Kullanılmıyor (servis metodu var) | Evet |
| `get_points_config` | — | jsonb (puan sabitleri) | Lig bilgi sayfası | Evet |
| `get_public_monthly_leaderboard` | `p_limit int` (vars. 10, en çok 100) | `name, avatar_id, total_points, total_minutes, is_me`. Ay: çalışma ayı (`started_at`, profil dilimi, 04:00; `proposed/15`). `proposed/14` sonrası ayrıca `id`, `is_blocked`; oturumsuz en çok 10 satır, maskeli ad | Ranking Aylık (50), landing (10, anon) | Evet |
| `get_public_alltime_leaderboard` | `p_limit int` (vars. 50, en çok 100) | `name, avatar_id, total_minutes, lifetime_points, is_premium, is_me` | Kullanılmıyor | Evet |
| `get_my_friends` | — | `id, name, avatar_id, lifetime_points, total_minutes` | FriendsSheet, Ranking | Hayır |
| `get_incoming_friend_requests` | — | yukarıdaki + `created_at` (`id` = gönderen) | FriendsSheet | Hayır |
| `add_friend_by_code` | `p_code text` | jsonb | FriendsSheet | Hayır |
| `respond_friend_request` | `p_from_user_id uuid, p_accept bool` | jsonb | FriendsSheet | Hayır |
| `get_live_friends` | — | jsonb dizi `[{id, name, avatar_id, category_name, ends_at}]` | SocialScreen | Hayır |
| `create_category` | `p_name, p_color_hex, p_icon_name` | yeni id | Kategori yönetimi | Hayır |
| `setup_onboarding_categories` | `p_categories jsonb` | jsonb `{created, restored, skipped_existing, skipped_limit, skipped_invalid, archived}` (`proposed/23`; öncesinde void). İstemci ikisini de kabul eder (`OnboardingCategoriesResult`) | Onboarding (önce `planOnboardingCategories`), `ensureServerCategories`, kuyruk | Hayır |
| `get_app_config` | — | jsonb (`proposed/13`, canlıda; anon da çağırır). İstemci yalnızca `proposed/20` lig anahtarlarını okur (`getLeagueRules`; PGRST202 yedeği eski sunucu için) | Ranking, lig bilgi sayfası, Koleksiyon | Evet (13) |
| `purchase_avatar` | `p_avatar_id text` | int (yeni bakiye) | Koleksiyon | Hayır |
| `set_equipped_avatar` | `p_avatar_id text` | void | Koleksiyon | Hayır |
| `delete_own_account` | — | void | Profil | Hayır |
| `cleanup_unconfirmed_duplicate_identity` | `p_email text` | void. Canlı gövde `p_email`'i JWT'deki e-postayla karşılaştırır, değilse `not authorized` (5 Ekim'de okundu; `proposed/04` gereksiz) | Google/Apple girişi sonrası (kendi e-postası) | Hayır |
| `get_friends_feed` | `int` | — | Kullanılmıyor | Hayır |
| `process_weekly_leagues`, `ensure_user_in_league` | — | — | Yalnızca cron ve sunucu içi | Hayır |

İstemci `reorder_categories`'i çağırmaz (canlıda yok); sıralama satır başına paralel `update(sort_order)` ile yazılır (§4.2).

### 5.2 `complete_study_session` kuralları
- İlk kontrol idempotency: aynı `(user_id, client_uuid)` → `duplicate:true`; yanıtta **ilk kaydın** `base_points`, `bonus_points`, `total_points`'i döner, `coins_earned` 0. `bonus_pct` her zaman 0 ve `daily_limit_reached` her zaman `false` gelir (ilk kaydın değeri değil); duplicate yanıtında bu ikisine güvenme. İstemci duplicate'te kullanıcıya delta eklemez (`_onSessionAccepted`), diyalog yalnızca "zaten kaydedilmişti" der.
- Doğrulama sırası: süre 25/50 → `started_at` gelecekte değil (null da reddedilir) → 24 saatten eski değil → `started_at + süre <= now() + 5 dk` → kategori kullanıcıya ait → gerçek aralıkla çakışma (`{error:'overlap'}`).
- Puan: 25 dk = 5, 50 dk = 12. Duraklatma cezası `ceil(%20)` (25 dk → 4, 50 dk → 9). Seri bonusu 3/7/14 günde %10/%20/%30 (`ceil`). Kum: seans başına 20.
- Günlük tavan: aynı çalışma gününde 16 seans dolunca puan, kum ve lig puanı 0. `total_minutes` artmaya devam eder.
- Gün: `((started_at AT TIME ZONE profiles.timezone) - 4 saat)::date`. Daha eski güne ait geç gelen seans seriyi ve `last_study_date`'i geri almaz.
- `completed_at = started_at + süre`. `activity_feed` yalnızca `show_in_social_feed` açıksa yazılır.

### 5.3 Seans hata sözleşmesi (`classifySessionError` / `classifySessionResponse`)

| Sunucu yanıtı | İstemci davranışı |
|---|---|
| `duplicate:true` | Başarı; yanıttaki puan ilk kaydınkidir, kum 0. Delta eklenmez, puan/kum gösterilmez |
| `daily_limit_reached:true` | Başarı, 0 puan / 0 kum |
| `{error:'overlap'}` | Kuyrukta kalır; sunucu yaşı 24 saati geçince `overlap` ile reddedilir |
| `session_not_finished` | Ölçülen düzeltilmemiş fark eşiği aşıyorsa geçici, neden `clock_skew` ("cihazının saati farklı/ileri" metni YALNIZCA bu nedende). Fark ölçülemediyse geçici, neden `not_elapsed` ("süre sunucuyla henüz doğrulanamadı"). Aksi halde kalıcı `not_elapsed` ("sunucuya göre seans süresi henüz dolmamıştı") |
| `started_at cannot be in the future` | `future_start`, aynı saat farkı kuralı (kalıcı retteki metin saat suçlamaz) |
| `started_at is older than 24 hours` | Kalıcı (`too_old`). İstemci 48 saati geçen seansı göndermeden reddeder |
| `invalid duration…` | Kalıcı (`invalid_duration`) |
| `category does not belong…`, 22P02 uuid, 23503 kategori | `category_invalid`: bir kez isimle yeniden eşlenir, sonra kalıcı |
| `not authenticated`, 42501, PGRST301, `AuthException` | Çevrimdışı (`auth`); tur durur, seans kalır |
| Ağ hatası, 15 sn zaman aşımı | Çevrimdışı (`network` / `timeout`); tur durur |
| Diğer P0001 | Kalıcı (`server_rejected`) |

`session_not_elapsed` metni yalnızca uyumluluk için tanınır; canlıda yok. Saat farkı eşiği `ServerClock.significantSkew` = 60 sn.

### 5.4 İstemcinin doğrudan tablo erişimi

| Tablo | İstemcinin yapabildiği |
|---|---|
| `profiles` | Kendi satırını SELECT. UPDATE yalnızca 7 kolon (§7). INSERT yalnızca yedek akışta `(id, email, name, avatar_id)` |
| `categories` | Kendi satırlarında SELECT, UPDATE yalnız 5 kolonda (ad/renk/ikon/arşiv/sıra). DELETE politikası/yetkisi yok (`proposed/16`). Ad/renk/ikon ve tekil ad trigger'la denetlenir (`proposed/13`, `23`). İstemci silmez |
| `study_sessions` | Kendi satırlarında SELECT. Yazma yalnızca RPC ile |
| `avatars`, `avatar_unlocks` | SELECT |
| `friendships` | Yalnızca PGRST202 yedek yolunda SELECT (ölü kod) |

### 5.5 Kayıt metadata'sı (`auth.signUp` `data` → `auth.users.raw_user_meta_data`)

| Anahtar | Okuyan | Not |
|---|---|---|
| `name`, `avatar_id` | `handle_new_user` (`full_name` de okunur) | Ad 1..50 (CHECK); avatar yalnızca `is_default` |
| `newsletter` (bool) | `handle_newsletter_subscription` (e-posta onaylanınca `= 'true'` ise `marketing_subscribers`) | Mevcut sözleşme, korunur; `marketing_consent` ile aynı değer |
| `marketing_consent` (bool), `terms_version`, `privacy_version` (`kLegalDocumentsVersion`), `terms_accepted_at` (UTC ISO-8601) | Yalnızca kayıt (KVKK ispat) | 3 Ekim'de canlı `handle_new_user` okundu; ek anahtarlar onu etkilemiyor |

Üretici: `SupabaseService.signUpMetadata` + `RegistrationConsent.toMetadata` (`test/registration_consent_test.dart`).

### 5.6 Hesap silme: `delete-account` Edge Function (canlıda yok) → `delete_own_account` (canlı, 3 Ekim)
İstemci (`deleteUserAccount`) önce `functions.invoke('delete-account', {apple_authorization_code?})` çağırır: Apple token iptali (`APPLE_*` secret'ları), doğrulanmış e-postaya bağlı `waitlist` / `user_id`'siz abonelik satırları, `admin.deleteUser`. Yanıt `{deleted, apple: {status: revoked|skipped|not_applicable}}`; fonksiyon 404 döndürmez; istemci 404'ü ("deploy edilmemiş") ve 5xx'i (çalışamadı; gövdedeki `apple` durumu korunur) görünce aşağıdaki RPC'ye düşer, 401/4xx'te düşmez (`shouldFallBackToDeleteRpc`). Yanıt kaybolursa `GET /user` `user_not_found`/404 ise silinmiş sayılır. Ayrıntı: `supabase/functions/delete-account/README.md`.

`delete_own_account`:
`auth.users` satırını siler; `profiles`, `study_sessions`, `friendships` (iki yön), `marketing_subscribers.user_id` auth.users'a, `categories`, `league_memberships`, `activity_feed`, `avatar_unlocks` profiles'a `ON DELETE CASCADE`. `waitlist` (e-posta, FK yok) ve `user_id`'si boş abonelik satırı da (yalnızca doğrulanmış e-postada) silinir, `search_path`'te `pg_temp` var (`proposed/12`, canlıda; geri alma `proposed/12_delete_own_account_down.sql`).

## 6. Veri akışları

### 6.1 Seans yaşam döngüsü
1. **Başlat:** bildirim izni (bir kez) → 3-2-1 → `ActiveTimerSession.start` (`clientUuid`, `startedAt`, `endsAt`) diske yazılır → bitiş bildirimi zamanlanır → Shell `start_study_session` çağırır.
2. **Tick:** `kalan = endsAt - now`; ön planda geçen saniye sayılır (`p_is_verified`).
3. **Duraklat:** bildirim iptal, `cancel_study_session`, seans `pausedRemainingSeconds` ile diske. `clientUuid`/`startedAt` korunur.
4. **Uygulama öldürülürse:** açılışta kayıt yüklenir; süre dolduysa doğrudan 5. adıma geçilir.
5. **Bitiş:** `cancel_study_session` → `submitCompletedSession()` → seans `pending_sessions_uid_<uid>`'e yazılır (cihaz saat farkı `clockOffsetMs` ile).
6. **Gönderim:** kuyruğun tamamı `started_at` sırasıyla, `AsyncLock` ile tek tur. `started_at`'e saat farkı düzeltmesi eklenir.
7. **Sonuç:** Başarı → `currentUser` güncellenir, seans kuyruktan silinir, `statsChanged`. Kalıcı ret → reddedilenler listesi + tek seferlik bildirim. Geçici → kuyrukta kalır, banner.

### 6.2 Çevrimdışı kuyruk
- **Tetikleyiciler:** Shell açılışı, bağlı görünen her bağlantı olayı, ön plana dönüş, artan aralıklı zamanlayıcı (30 sn → 15 dk; bulut başlatılamadıysa da kurulur), banner'a dokunma, yeni seans.
- **Yer tutucu kategori:** isimle buluttaki kategoriye eşlenir (yoksa ilk aktif kategoriye); bulutta hiç kategori yoksa kullanıcının segmentine ve diline göre varsayılanlar oluşturulur.
- **Kimliksiz önbellek:** uid bilinmiyorsa `pending_sessions_<email>`'e yazılır, uid öğrenilince taşınır.
- Çıkışta kuyruk uid'e bağlı kalır, başka hesaba gönderilmez. Hesap silinince temizlenir.

### 6.3 Giriş ve onboarding
1. **Splash:** `restoreCachedUser` + kategori önbelleği + avatar kataloğu (ağsız) → `SupabaseService.ensureCloud` (5 sn; bitmezse ya da hata verirse kabuk ve giriş yeniden dener) → oturum varsa `fetchCurrentUserModel` + kategoriler → `AppGate`.
2. **Login:** e-posta `signInWithPassword`; Google/Apple native idToken → `signInWithIdToken` → `cleanup_unconfirmed_duplicate_identity`.
3. **Profil:** `handle_new_user` trigger'ı (varsayılan avatar, `friend_code`).
4. **Onboarding:** `completeOnboarding` → mevcut kategorilerle uzlaştırma (arşivle / arşivden aç) → `setup_onboarding_categories` (yalnızca eksikler) → `profiles.update(birth_year, user_segment, daily_goal_minutes, show_in_social_feed, onboarding_completed_at)` → `currentUser` güncellenir → AppGate Shell'e geçer.
5. **Çıkış / oturum düşmesi:** `signOutFully` ya da `signedOut` olayı → `currentUser = null` → AppGate Login gösterir.

### 6.4 Lig döngüsü
1. `complete_study_session`, tavan aşılmadıysa `ensure_user_in_league(uid, puan)` → `league_memberships.weekly_points` artar.
2. Sıralama: `weekly_points DESC, joined_at ASC, user_id`.
3. Cron `weekly_leagues_job` `'1 21 * * 0'` (Pazar 21:01 UTC = Pazartesi 00:01 TR) → `process_weekly_leagues()`.
4. İşlenen: `end_date <= now() + 5 dk` olan aktif ligler. Aynı koşuda taşınan üye ikinci kez işlenmez.
   - **Ödül avatarı:** ilk 3 ve puanı > 0 → `league_award_avatar_id(tier, sıra)`.
   - **Terfi:** puan > 0, sıra ≤ terfi kotası, kademe < 5 → üst kademede 30'dan az üyeli lig (yoksa yeni).
   - **Düşme:** sıra ≥ düşme sınırı ve kademe > 1.
   - Herkesin `weekly_points` = 0; `end_date` + 14 gün. Dönem devrinde açılan oda 2 hafta sonraki Pazar 23:59:59 TR'de biter (14 gün).
   - `ensure_user_in_league`'in (ilk seans) açtığı oda **bu haftanın Pazartesi'si + 13 gün** biter: ilk dönem açılış gününe göre 7–14 gün (Pazar açılan oda 7 gün). Odalar bu yüzden iki hafta paritesinde; sabit 14 gün ürün kararı (t1-06). `proposed/20` terfi/düşme hedefini aynı dönem sonlu odayla sınırlar.
5. Bölgeler (`get_league_zones`):

| Üye sayısı | Terfi | Düşme |
|---|---|---|
| < 10 | `ceil(n/2)`, en çok 3 | Yok |
| 10–19 | İlk 3 | Son 3 |
| 20+ | İlk 7 | Son 7 |

## 7. Güvenlik modeli

### 7.1 Tablolar (canlı, `live_audit_fixes` sonrası)

| Tablo | anon | authenticated okuma | authenticated yazma | Not |
|---|---|---|---|---|
| `profiles` | Yok | RLS: kendi satırı (tablo düzeyinde SELECT) | INSERT `(id, email, name, avatar_id)` + `sanitize_profile_insert`. UPDATE yalnızca `name, show_in_social_feed, user_segment, daily_goal_minutes, birth_year, onboarding_completed_at, timezone`. DELETE yok | `coins, lifetime_points, is_premium, league_tier`, seri yalnızca RPC ile. CHECK: ad 1-50, hedef 5-1440, doğum yılı 1900-2100, `timezone` `pg_timezone_names`'te |
| `study_sessions` | Yok | SELECT (RLS) | Yok | Yalnızca `complete_study_session` yazar |
| `categories` | Yok | Kendi satırları | RLS + limit trigger (ekleme ve arşivden çıkarma) | Silinmez, arşivlenir |
| `friendships`, `leagues`, `league_memberships`, `activity_feed`, `avatar_unlocks` | Yok | SELECT (RLS) | Yok | Yazma yalnızca RPC, trigger veya cron |
| `avatars` | SELECT | SELECT | Yok | Katalog |
| `marketing_subscribers` | Yok | Kendi satırı | INSERT/UPDATE yok | Satırı `handle_newsletter_subscription` trigger'ı ekler. `unsubscribe_token uuid`, `welcome_sent_at` |
| `waitlist` | INSERT (landing) | — | — | RLS migration'da yok; canlıda doğrula |

### 7.2 Anon'a açık olanlar
- RPC: `get_public_monthly_leaderboard`, `get_public_alltime_leaderboard`, `get_points_config`, `get_league_zones`, `league_award_avatar_id`.
- Tablo: `avatars` SELECT, `waitlist` INSERT.
- Edge Function: `unsubscribe` ve `send-welcome-email` JWT'siz çalışacak şekilde yazıldı; ikisi de isteği DB'den doğrular.
- Herkese açık sıralamalarda oturumsuz çağrı adı `Ad S.` biçiminde maskeler (`mask_public_name`). Oturum açıkken tam ad döner. `show_in_social_feed = false` olan kimse listelenmez.

### 7.3 Sırlar
- Kök `.env`: yalnızca public değerler (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`).
- `scripts/.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (son ikisi sır değil, e-posta altbilgisindeki hizmet sağlayıcı kimliği; boşsa bülten gönderilmez); mağaza derlemesi için `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`. İçeriğini okuma, hiçbir yere kopyalama.
- Edge secret: `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (`send-welcome-email`; kimlik eksikse e-posta gönderilmez). Abonelikten çıkma token'ı UUID olduğu için ek secret yok. `delete-account` için `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`, `APPLE_PRIVATE_KEY` (.p8 PEM); yoksa Apple iptali atlanır.

## 8. Landing sitesi ve deploy

**Yapı**
- Statik site, build yok. `_partials/` tek kaynak → `python3 landing/tools/sync_partials.py`. `en/` İngilizce yasal sayfalar ve destek sayfası.
- Yazı tipleri (`fonts/`, `css/fonts.css`) ve GSAP (`vendor/gsap-3.13.0/`, jsDelivr'deki dosyayla birebir, SRI aynı) kendi alan adımızdan sunulur; dış CDN yok (KVKK-19).
- `js/config.js` Supabase URL ve anon key'in tek yeri. Site supabase-js yüklemez, düz `fetch` kullanır: `POST /rest/v1/waitlist`, `rpc/get_public_monthly_leaderboard` (p_limit 10), `functions/v1/unsubscribe`.
- `worker.js` (`run_worker_first`): http → https ve `www` → apex 301 (yol ve sorgu korunur). Diğer her istek statik varlıklara gider.
- `wrangler.jsonc`: `html_handling: auto-trailing-slash` (`.html` → uzantısız adrese 307), `not_found_handling: 404-page`, `pomosprint.app` ve `www` custom domain route'ları.
- `.assetsignore`'da olmayan **her dosya herkese açık yayınlanır** (`_partials`, `tools`, `*.md`, `worker.js`, `wrangler.jsonc` hariç tutulur; `_headers` Workers tarafından okunur).

**Deploy**
```sh
python3 landing/tools/sync_partials.py --check
cd landing && wrangler deploy          # wrangler bu makinede oturum açık (yoksa npx wrangler)
curl -sI https://pomosprint.app/ | grep -i content-security-policy
curl -sI https://pomosprint.app/reset-password | grep -i cache-control   # no-store
```
- CSS/JS değişince `?v=` değerini `_partials/head.html`, `_partials/scripts.html` ve yardımcı sayfalarda artır (1 saat önbellek).

**`_headers`**
- CSP: inline `<script>`/`style=""` yok (JSON-LD hariç). `script-src` yalnızca `'self'` + Cloudflare Web Analytics; `style-src` ve `font-src` yalnızca `'self'`. `connect-src` Supabase + Cloudflare Insights. Yeni dış kaynak → önce CSP'ye ve gizlilik metinlerindeki sağlayıcı listesine ekle.
- Token taşıyan sayfalar (`/reset-password`, `/confirmed`, `/unsubscribe`): `no-store`, `noindex`, `no-referrer`.

**Dokunulmaz URL'ler:** `/privacy`, `/terms`, `/kvkk`, `/hesap-silme`, `/destek` ve `/en/` karşılıkları (`/en/delete-account`, `/en/support`), `/reset-password`, `/confirmed`, `/unsubscribe`. Uygulama sürümleri, mağaza kayıtları, Auth redirect allowlist'i ve gönderilmiş e-postalar bunlara bağlı.

**Yardımcı sayfa sözleşmeleri**
- `reset-password`: `#access_token=…&type=recovery` (implicit) ya da `?token_hash=…&type=recovery` (form gönderilince doğrulanır). `?code=` eski sürüm mesajı verir.
- `confirmed`: onay dönüşü; parametresiz açılınca "onaylandı" demez; uygulamayı açma deep link'i yok.
- `unsubscribe`: `?token=<uuid>` (yeni e-postalar; e-posta adresi URL'de yok). Eski `?email=…&token=<uuid>` bağlantıları da çalışır: sayfa adresi adres çubuğundan siler, istekte yalnızca gövdeye koyar. Sayfa açılınca bir şey silmez, butonla POST atar.
- Bekleme listesi formu: ayrı, önceden işaretsiz ticari ileti onay kutusu (`#notify-consent`); işaretlenmeden kayıt yok. Gövde hâlâ yalnızca `{email}`: `waitlist`'te onay kolonları ve `unsubscribe_token` var (`proposed/19` A, canlıda), ama site onay alanlarını göndermiyor; yeni satırlarda `marketing_consent` NULL. Site `{email, marketing_consent: true, consent_text_version}` gönderecek şekilde deploy edilince `proposed/19` B (yalnızca onaylı kayıt) uygulanır.

**E-posta**
- Email Routing: `destek@pomosprint.app` → kullanıcının Gmail'i. MX, SPF, DKIM var.
- `send-welcome-email`: `marketing_subscribers` INSERT trigger'ı `net.http_post` ile çağırır. Resend, gönderici `noreply@mail.pomosprint.app`. Satır son 1 saatte eklenmiş ve `welcome_sent_at` boş olmalı. Altbilgide hizmet sağlayıcı kimliği (`MAIL_SENDER_*` secret'ları), destek adresi, Gizlilik ve KVKK bağlantıları; abonelikten çıkma bağlantıları yalnızca `?token=`.
- `unsubscribe`: yalnızca POST siler (GET 405), token yok/biçimsiz 400, e-posta-token uyuşmazlığı 403, bilinmeyen token 200. Aboneyi `waitlist`'ten de çıkarır. Deploy: `supabase functions deploy unsubscribe --no-verify-jwt`.
- Bülten: `node scripts/send_newsletter.js --dry-run`, sonra gerçek gönderim. `List-Unsubscribe` + tek tık başlıkları üretir; bağlantılar yalnızca token taşır. Şablonda `{{unsubscribe_url}}`, `{{sender_name}}`, `{{sender_address}}` zorunlu.

**İçerik tutarlılığı (uygulamayla aynı olmalı):** yalnızca 25/50 dk seans, mola sayacı yok, sanal kütüphane yok, lig 14 gün / 30 kişi / 5 kademe, puan 5/12, seri %10/%20/%30, günde en fazla 16 seans sayılır, varsayılan dil TR.

## 9. Yapma listesi

| Yapma | Yerine |
|---|---|
| İstemcide puan, kum, seri veya lig hesaplamak | RPC sonucunu göster; sabitleri `get_points_config`'ten oku |
| "Ben" satırını isimle bulmak | `is_me` |
| Repodaki eski migration'dan `CREATE OR REPLACE` | Canlı `pg_get_functiondef` (§2.4) |
| `supabase db push` / `db reset`; MCP ile yıkıcı SQL | DRYRUN → migration dosyası; kullanıcı SQL Editor'de çalıştırır |
| `proposed/` dosyasını olduğu gibi çalıştırmak | Canlı gövdeye uyarlayıp yeni migration yaz |
| Kök `.env`'e veya `landing/`'e service role / Resend anahtarı | Yalnızca `scripts/.env` ve Edge secrets |
| Sayacı derleme moduna göre (`kDebugMode`) kısaltmak; sunucu doğrulamasını gevşetmek | Hızlı deneme yalnızca `QUICK_TIMER` ile ve kaydedilmeden; gerçek seans her derlemede |
| Yer tutucu kategori id'sini (`'1'..'5'`) RPC'ye göndermek | `isUuidCategoryId` + isimle eşleme |
| Yeniden denemede yeni `client_uuid` | Kuyruktaki kimliği koru |
| Seansı sessizce silmek; hata sınıfını testsiz değiştirmek | Reddedilenler listesi + test güncellemesi |
| Ekrandan doğrudan `Supabase.instance.client.from(...)` | `SupabaseService`'e metod ekle |
| Ekranda `UserModel` kopyası tutmak | `currentUser`'ı dinle, değişikliği servise yaz |
| Başka kullanıcının `profiles` satırını okumak | SECURITY DEFINER RPC |
| `GRANT` eklemeden yeni `profiles` kolonuna yazmak | Kolon bazlı `GRANT UPDATE` |
| Global Realtime kanalı (`ranking_updates`) | `addStatsChangedListener` |
| `Duration(days:)` ile gün atlamak; yeni gün kuralı | `DateTime(y, m, d + n)`, `study_day.dart` |
| `app_localizations*.dart`'ı elle düzenlemek; yeni `translate` anahtarı | ARB → `flutter gen-l10n` |
| Yönlendirmeyi ekranda yapmak; `Supabase.initialize`'ı ikinci kez çağırmak | `AppGate`; Splash'teki tek çağrı |
| `debugPrint`'e e-posta veya kişisel veri | Kimliksiz log |
| Landing'de inline script/style, uç sayfa yeniden adlandırma | CSP'ye uy, URL'leri koru |
| Silinmiş ekranları (`onboarding_screen`, `categories_screen`) geri getirmek | `PostAuthOnboardingScreen`, `CategoriesManagementScreen` |

## 10. Bilinen açık konular (3 Ekim 2026; sunucu satırları 5 Ekim'de güncellendi)

| Öncelik | Konu | Not |
|---|---|---|
| P0 | Migration geçmişi canlıyla uyumsuz, baseline yok | `supabase/README.md` → Baseline (`db dump` + `migration repair`). O zamana kadar CLI push yasak |
| P1 | `send-welcome-email` repodaki sürümü deploy edilmedi | 3 Ekim `list_edge_functions`: `unsubscribe` v9 ve `send-welcome-email` v7 canlıda, ikisi de JWT kapalı; `unsubscribe` v9 token-only isteği zaten kabul ediyor (repo farkı yalnızca yorum). Repodaki `send-welcome-email` (gönderen kimliği altbilgisi, yalnızca token'lı bağlantı) için sıra: site deploy → `supabase secrets set MAIL_SENDER_NAME=… MAIL_SENDER_ADDRESS=…` → `supabase functions deploy send-welcome-email --no-verify-jwt`. Secret'lar yoksa hoş geldin e-postası gönderilmez |
| P1 | Veri sorumlusu kimliği sitede yer tutucu (KVKK-15) | `/privacy`, `/kvkk` (iki dil) §1'de `data-fill-in` işaretli; kullanıcı gerçek bilgiyle doldurur (`grep -rn 'data-fill-in' landing/`) |
| P1 | `mail.pomosprint.app` Resend doğrulaması ve DNS kayıtları | Yapılmadan hoş geldin ve bülten gönderilemez |
| P1 | `delete-account` Edge Function deploy edilmedi | Deploy (`verify_jwt` açık) + `APPLE_*` secret'ları; o zamana kadar silme `delete_own_account` ile yapılır ve Apple token'ı iptal edilmez (kullanıcıya Ayarlar talimatı gösterilir). Apple Developer'da `pomosprint.app` / `mail.pomosprint.app` gönderici alan adları "Sign in with Apple for Email Communication"a kaydedilmeli (gizli röle adreslerine sıfırlama e-postası) |
| P2 | E-posta değiştirme yok | Uygulama içi şifre değiştirme var; e-posta değişikliği eklenirse `handle_new_user` yalnızca INSERT'te çalıştığı için `profiles.email` ve `marketing_subscribers.email`'i güncelleyen bir trigger gerekir |
| P2 | Başka cihazda silinen hesabın kuyruğu | Silinen uid'in `pending_/rejected_sessions_uid_<uid>` anahtarları diğer cihazda kalır (gönderilemez). "Seans sessizce silinmez" kuralı yüzünden otomatik temizlik yok |
| P2 | Google/Apple ile ilk girişte onay sürümü kaydedilmiyor | Bildirim metni gösteriliyor; sunucu `accept_legal_documents(p_terms_version, p_privacy_version)` hazır (`proposed/14`, canlıda), istemciden çağrılmıyor |
| P2 | Engelleme, bildirim, arkadaş silme ve giden isteği iptal UI'ı yok | Sunucu hazır (`proposed/14`, 5 Ekim'den beri canlıda; sözleşme `proposed/README.md` "Öneri 14"). Gizleme şimdilik cihazda. Operatör: `ops.open_user_reports`, `ops.reset_display_name`, `ops.resolve_user_report` (SQL Editor) |
| P1 | Supabase Auth panel ayarları repoda yok | Redirect URLs (`/reset-password`, `/confirmed`, `.html`'li hâlleri; `io.supabase.pomosprint://` silinmeli), Reset Password şablonu `token_hash`, Leaked password protection, Apple provider (Client ID `com.pomosprint.app`) |
| P2 | `reorder_categories` (`proposed/11`) canlıda yok | Toplu kategori sıralaması paralel `update(sort_order)` ile (§4) |
| P2 | `proposed/19` B uygulanmadı (A canlıda) | Site bekleme listesine `{email, marketing_consent: true, consent_text_version: "waitlist-2026-10-03"}` göndermeli (`landing/js/main.js`), deploy, sonra 19 B. Ayrıca `unsubscribe` waitlist token'ını da tanımalı ve lansman e-postası yalnızca `marketing_consent = true` satırlara gitmeli |
| P2 | Ürün kararları (sunucu düğmeleri hazır, 5 Ekim'den beri canlıda) | Lig ödül/terfi eşikleri `app_config.league_award_min_members`, `league_award_min_points`, `league_promotion_min_points` (bugün 1/1/1; önerilen 3/25/25, istemci metinleri kurala göre kendiliğinden değişir); `unverified_session_daily_cap` (null); yeni oda ilk dönemi 7–14 gün (t1-06); 24 saat penceresi (t1-07) |
| P2 | `proposed/01`–`10` kalan maddeler | 03 ve 07 `proposed/14`, 05 `proposed/22` ile geçersiz (UYGULAMAYIN, `proposed/README.md`). Kalan: puan sabitleri tek kaynak, `profiles` kolon bazlı SELECT (06), varsayılan yetkiler (08), veri temizliği (10); canlı gövdelere göre yeniden yazılmalı |
| P2 | Herkese açık sıralama oturum açıkken tam ad döndürüyor | Ürün kararı (`proposed/README.md`, 03 satırı) |
| P2 | `profiles.timezone` istemciden yazılmıyor | Yetki ve doğrulama canlıda hazır; `set_my_timezone` yok. Cihaz IANA adı için ek paket (`flutter_timezone`) gerekir |
| P2 | Bayat referanslar | `proposed/README.md` ve `scripts/security_regression_test.js` hâlâ `migrations/20261003120000_audit_fixes.sql` diyor; `run_local.sh` `audit_fixes_test.sql`'i çalıştırıyor; `supabase_service.dart`'ta "`is_me` DÖNMEZ" yorumları |
| P2 | Üç çeviri yolu (ARB, `translate()`, `isTurkish`) | Ekran ekran ARB'ye taşıma |
| P2 | DMARC kaydı yok | `_dmarc` TXT, `p=none` ile başla |
| P3 | Android derlemesi bu makinede doğrulanmadı | Gerçek cihaz test listesi: analiz raporu §10 |
| P3 | Ertelenen teknik işler | `google_sign_in` 7.x; `SupabaseService`'in bölünmesi (Auth → Category → Social); onboarding'de Çıkış butonu (`AppGate` `onSignedOut` vermiyor) |
| P3 | Waitlist bot koruması | Sitede honeypot + süre kontrolü var; Turnstile/çift onay backend ister |
| P3 | Repo hijyeni | `assets/league_award_avatars/` (9,6 MB), çalışmayan masaüstü/web şablonları, izlenen `settings.local.json` dosyaları |
| P3 | Test kapsamı | Simülatör E2E (`integration_test/`, a–f) var; Android emülatöründe koşulmadı, bildirim izni / sunucu kesintisi / kilit ekranı senaryoları elle (`tool/local_supabase/README.md`) |
