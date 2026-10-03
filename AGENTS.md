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

- **Ne:** Oyunlaştırılmış Pomodoro uygulaması. 25 veya 50 dk seans (mola sayacı yok), kategoriler, raporlar, seri bonusu, 14 günlük ligler, avatarlar, arkadaşlar.
- **İstemci:** Flutter 3.44 / Dart ^3.12, yalnızca **Android ve iOS**. `macos/ linux/ windows/ web/` çalışmayan şablonlar (macOS bundle id hâlâ `com.example.pomodoro`).
- **Backend:** Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`. Postgres + RLS + SECURITY DEFINER RPC, Auth (e-posta, Google, Apple), pg_cron, Edge Functions.
- **Temel ilke:** Puan, kum (coins), seri ve lig **sunucuda** hesaplanır. İstemci seans meta verisini gönderir, RPC sonucunu gösterir.
- **Site:** `pomosprint.app`. `landing/` derleme adımı olmadan Cloudflare Workers static assets ile yayınlanır.
- **Varsayılanlar:** dil `tr`, tema sistem teması, varsayılan avatar `avatar_16_basic`.

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
| `flutter run --profile` / `--release` | Gerçek seans ve puan testi | Debug build'de sayaç 5/10 sn'dir, sunucu bu seansları reddeder |
| `supabase/tests/run_local.sh` | SQL değişikliği; **yalnızca yerel Postgres** | ASSERT'ler geçer. `live_audit_fixes` varsayılan olarak atlanır |
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
| `lib/app/main_shell.dart` | `MainNavigationShell`: 4 sekme (Pomo, Raporlar, Sıralama, Sosyal) IndexedStack + TickerMode, bekleyen seans banner'ı, bağlantı dinleyicisi, `PopScope` |
| `lib/app/` (diğer) | `theme_controller` (`theme_mode`), `session_feedback` (seans sonucu diyalogları), `category_cache` (`saved_categories_<email>`), `error_reporting` (Sentry, e-posta maskeleme) |
| `lib/screens/timer_screen.dart` | Sayaç durum makinesi (25/50 dk, tek duraklatma, 3-2-1 geri sayım) |
| `lib/screens/splash_screen.dart` | Önce yerel önbellek, sonra `SupabaseService.initialize` (süreçte tek kez), sonra profil ve kategori tazeleme |
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
| `test/` | Birim ve widget testleri (E2E yok). `test/support/fake_supabase_service.dart`: Raporlar ve Kategorilerim'e `service:` ile verilen sahte servis |
| `supabase/migrations/` | İleri migration'lar. Yalnızca `20261003150000_live_audit_fixes` canlıda (§4.6) |
| `supabase/rollbacks/` | Down betikleri; CLI uygulamaz |
| `supabase/proposed/` | Canlıya uygulanmamış öneriler (`01`–`11`). Her dosya `\quit` ile başlar |
| `supabase/tests/` | `run_local.sh` (yerel), `*_dryrun.sql` (canlıda, geri alınan transaction) |
| `supabase/functions/` | `unsubscribe`, `send-welcome-email` (repodaki sürümler canlıdan yeni, §10) |
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
- Seans her durum değişiminde diske yazılır. Açılışta: süre dolduysa hemen tamamlanıp gönderilir; 24 saatten eski duraklatılmış seans silinir.
- Debug build'de süre 5/10 sn (`timerDurationSeconds`, `kDebugMode`). Bilinçli; sunucu bu seansları reddeder.
- Duraklatma hakkı 1. Seans varken 25/50 değiştirilirse seans sıfırlanır.
- Bildirim izni açılışta değil, ilk BAŞLAT'ta (`ensurePermission`) istenir. Profil'deki anahtar `notifications_enabled`.
- Kilit ekranı sayacı (`LockScreenTimer`) her durum geçişinde çağrılır: başlat/devam/geri yükleme `showRunning`, duraklat `showPaused`, sıfırla/tamamla/çıkış/ekran kapanışı `clear`, ön plana dönüş `force: true`. Bildirim tercihi kapalıysa gösterilmez. Dart arka planda çalışmaz; geri sayımı sistem yürütür (Android kronometre + `timeoutAfter`, iOS `Text(timerInterval:)` + `staleDate`). Foreground service / background mode EKLEME.
- `start_study_session` / `cancel_study_session` çağrıları Shell'in `onTimerStateChanged` callback'inde yapılır.

**Tuzaklar**
- IndexedStack tüm sekmeleri açılışta kurar ve canlı tutar. Görünmeyen sekme `TickerMode(enabled: false)` alır; periyodik iş yapan ekran `TickerMode.valuesOf(context).enabled`'a bakmalı.
- Çıkışta süren seans cihazda kalır (aynı hesapla girişte sürer); Shell bildirimi iptal edip `cancel_study_session` çağırır.
- `onAuthStateChange` son olayı yeni aboneye yeniden verir.
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
- `updateCategoryOrders` aktif kategoriler için **paralel** `update(sort_order)` yapar; `reorder_categories` çağrılmaz (canlıda yok), upsert de yok. Kısmi başarısızlıkta sıra karışabilir: Kategorilerim hata olunca iyimser sırayı geri alır ve listeyi sessizce yeniden okur. `sort_order` canlıda çakışabilir (`create_category` aktif sayısını yazıyor); istemci `sort_order, created_at, id` ile sıralar. Kalıcı düzeltme `proposed/16`.
- Prefs anahtarları: `saved_user`, `saved_categories_<email>`, `pending_sessions_uid_<uid>` (eski `pending_sessions_<email>` ilk erişimde taşınır), `rejected_sessions_uid_<uid>`, `rejected_sessions_unseen_uid_<uid>`, `active_session_uid_<key>`, `avatar_catalog_v1`, `daily_pomo_goal` (eski, bir kez taşınır), `league_info_shown_<uid>`, `hidden_users_uid_<uid>` (gizlenen kullanıcılar), `app_language_code`, `theme_mode`, `notifications_enabled`, `notification_permission_asked`.
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
- Debug build'de istatistiklerin boş görünmesi beklenen durum.
- Gün kuralı istemcide de sunucuda da **profil diliminde** 04:00 (`studyDayOf`, `setStudyTimeZone`; `currentUser.timezone` değişince otomatik). `profiles.timezone` istemciden yazılmadığı için fiilen herkes `Europe/Istanbul`: cihazı başka dilimde olan kullanıcı günleri İstanbul'a göre görür (sunucuyla tutarlı, kullanıcının yerel günüyle değil; §10).
- Sıralama > Aylık (`get_public_monthly_leaderboard`) ayı canlıda `completed_at` + İstanbul gece yarısıyla sayıyor, Raporlar > Aylık `started_at` + 04:00 ile. Düzeltme `proposed/15`; uygulanınca `ranking_models.dart` `nextMonthlyLeaderboardReset` 04:00'e çekilmeli.
- Yenileme ve gün dönümü zamanlayıcısı TickerMode'a bağlı; sekme görünmezken durur. Üst çubuktaki seri `StudyDayBuilder` ile 04:00'te kendiliğinden tazelenir.
- Testler: `test/reports_correctness_test.dart` (sabit veri setiyle tüm metrikler), `test/reports_findings_test.dart`, `test/support/fake_supabase_service.dart` (ekranlara `service:` ile verilir).

### 4.4 SOCIAL: lig, sıralama, avatar, profil, arkadaşlar
**Dosyalar:** `ranking_screen.dart`, `widgets/social/*`, `league_info_sheet.dart`, `social_screen.dart`, `friends_sheet.dart`, `profile_screen.dart`, `character_collection_screen.dart`, `avatar_model.dart`

**Kurallar**
- Sekmeler: **Lig | Aylık | Arkadaşlar**. "Tüm zamanlar" sekmesi kaldırıldı (`getAllTimeRanking` ve `getLeagueZones` servis metodları çağrılmıyor).
- "Ben" satırı yalnızca `is_me` ile bulunur. İsimle eşleme yapma. Arkadaşlar sekmesinde kendi satırı yerel profilden eklenir.
- Lig verisi `get_my_league_ranking()` ile okunur; terfi/düşme bölgeleri satırla birlikte sunucudan gelir (`LeagueSnapshot`).
- Lig: 14 gün, 5 kademe (1 Bronz … 5 Elmas), en fazla 30 üye. Puan sabitleri `get_points_config`'ten okunur; `league_info_sheet`'teki sayılar yalnızca yedek.
- Avatar sahipliği = `avatar_unlocks` kaydı ya da ücretsiz (`isOwned`). Lig ödülü avatarları satın alınamaz.
- Profil ve Koleksiyon `currentUser`'ı dinler; kopya tutmaz.
- Başka kullanıcının verisi yalnızca RPC ile gelir.
- Kullanıcı içeriği (App Store 1.2): başkasının satırında uzun basma / "⋮" ile `showUserSafetySheet` (`widgets/social/user_safety.dart`). Sıralama ve canlı akışta "Bildir" + "Gizle", arkadaş listesi ve isteklerde yalnızca "Bildir"; kendi satırında menü yok. Bildirim `mailto:destek@pomosprint.app` (görünen ad, varsa genel kimlik, yer; bildirenin bilgisi URL'ye konmaz).
- Gizleme cihazda, hesaba bağlı (`HiddenUsersStore`, `hidden_users_uid_<uid>`). Lig/Aylık RPC'leri kimlik döndürmediği için orada adla eşlenir; sıralamada satır silinmez, ad/avatar "Gizlenen kullanıcı" olur (sıra ve lig bölgeleri bozulmaz). Profil > Gizlilik ve yasal'dan sıfırlanır.
- Görünen ad denetimi `utils/name_filter.dart` (kayıt, profil ad düzenleme, Google/Apple ilk adı). Sunucuda içerik denetimi yok (§10).

**Tuzaklar**
- Arkadaş silme ve giden isteği iptal UI'ı yok: `remove_friend`, `cancel_friend_request`, `get_outgoing_friend_requests` canlıda yok.
- `add_friend_by_code` / `respond_friend_request` yanıtında makine-okunur `code` yok (`proposed/07` E bölümü); İngilizce arayüzde metin eşlemesi zayıf.
- Sosyal ekran 30 sn'de bir poll yapar; görünmezken durur.
- Avatar görseli: uygulamada `assets/avatars/<asset_key>`, sitede `landing/avatars/<id>.webp`.

### 4.5 AUTH ve L10N: giriş, onboarding, kategoriler, yerelleştirme
**Dosyalar:** `app/app_gate.dart`, `login_screen.dart`, `register_screen.dart`, `post_auth_onboarding_screen.dart`, `categories_management_screen.dart`, `widgets/auth/*`, `language_service.dart`, `l10n/`

**Kurallar**
- Yönlendirme yalnızca `AppGate`'te. Ekranlar kendi aralarında Login/Onboarding/Shell'e geçiş yapmaz; `currentUser`'ı günceller.
- Onboarding `completeOnboarding()` ile biter (önce kategoriler, sonra profil). Profili `handle_new_user` trigger'ı oluşturur; istemci upsert'i yedektir ve avatar sunucuda varsayılana zorlanır.
- Kategori limiti ücretsiz 8, premium 15 (`categoryLimitFor`). Sunucu trigger'ı eklemede ve arşivden çıkarmada uygular; istemci kontrolü UX içindir. Kategori silinmez, arşivlenir.
- Yeni metin **yalnızca ARB'ye** (iki dosyaya da) eklenir, sonra `flutter gen-l10n`.
- Yasal sayfalar (`legal_links.dart`, `LegalPage`): TR `pomosprint.app/terms|privacy|kvkk|hesap-silme`, diğer diller `/en/terms|/en/privacy|/en/kvkk|/en/delete-account`. Metin sürümü tek sabit: `kLegalDocumentsVersion`; yasal metin değişince artır.
- Kayıt onayları: iki zorunlu (Kullanım Şartları kabulü; KVKK Aydınlatma Metni + Gizlilik Politikası okundu, rıza değil bilgilendirme teyidi), bir isteğe bağlı (ticari elektronik ileti, varsayılan kapalı). "Tümünü kabul et" yok. Zorunlular olmadan `registerUser` çağrılmaz; servis de `StateError` fırlatır. Metadata sözleşmesi §5.5.
- Google/Apple ile devam: giriş ekranındaki `SocialSignInNotice` (Kullanım Şartları + KVKK Aydınlatma Metni bağlantılı). Bu yolda onay metadata'sı yazılmıyor (§10).

**Tuzaklar**
- Üç çeviri yolu bir arada: ARB, `LanguageService.translate('key')` haritası (Timer, Raporlar, Profil, nav etiketleri) ve `isTurkish ? … : …`. Eski anahtarları taşımak ayrı bir iş; yeni `translate` anahtarı ekleme.
- Auth akışı **implicit** (`authFlowType: implicit`, `detectSessionInUri: false`). Sıfırlama/onay linkleri web sayfasında işlenir. Özel URL şeması (`io.supabase.pomosprint`) kaldırıldı.
- Google iOS: Supabase'de "skip nonce" bilinçli açık. iOS client id üç yerde aynı olmalı: `GIDClientID`, `CFBundleURLSchemes` (ters çevrilmiş), `supabase_service.dart`.
- Apple girişi iOS login ekranında var; Apple Developer capability ve Supabase Apple provider ayarı kullanıcıda.
- `AppGate`, onboarding ekranına `onSignedOut` vermiyor; onboarding'de Çıkış butonu gizli.
- Dil cihazdan okunmaz, varsayılan `tr`.
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

**Canlıda olmayan RPC'ler:** `reorder_categories`, `remove_friend`, `cancel_friend_request`, `get_outgoing_friend_requests`, `set_my_timezone`, `get_my_category_limit` (ayrıca `get_my_streak`, `study_day_of`, `my_friend_ids`, `synced_at` kolonu). Gerekirse `proposed/11`'den canlı gövdelere göre ayrı migration yaz.

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

**Tuzaklar**
- `google_sign_in` 6.x'te; 7.x'e geçiş (Credential Manager) yapılmadı.
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
| `get_my_league_ranking` | — | `name, avatar_id, weekly_points, tier, end_date, is_me, promotion_zone_end, demotion_zone_start, member_count` | Ranking, lig bilgi sayfası | Hayır |
| `get_league_ranking` | `p_user_id uuid` (yalnızca kendi id'si) | Yukarıdakiyle aynı | Kullanılmıyor | Hayır |
| `get_league_zones` | `p_member_count int` | `promotion_zone_end, demotion_zone_start` | Kullanılmıyor (servis metodu var) | Evet |
| `get_points_config` | — | jsonb (puan sabitleri) | Lig bilgi sayfası | Evet |
| `get_public_monthly_leaderboard` | `p_limit int` (vars. 10, en çok 100) | `name, avatar_id, total_points, total_minutes, is_me`. Ay: canlıda `completed_at >= İstanbul ay başı 00:00` (Raporlar'dan farklı; `proposed/15` çalışma ayına çeker) | Ranking Aylık (50), landing (10, anon) | Evet |
| `get_public_alltime_leaderboard` | `p_limit int` (vars. 50, en çok 100) | `name, avatar_id, total_minutes, lifetime_points, is_premium, is_me` | Kullanılmıyor | Evet |
| `get_my_friends` | — | `id, name, avatar_id, lifetime_points, total_minutes` | FriendsSheet, Ranking | Hayır |
| `get_incoming_friend_requests` | — | yukarıdaki + `created_at` (`id` = gönderen) | FriendsSheet | Hayır |
| `add_friend_by_code` | `p_code text` | jsonb | FriendsSheet | Hayır |
| `respond_friend_request` | `p_from_user_id uuid, p_accept bool` | jsonb | FriendsSheet | Hayır |
| `get_live_friends` | — | jsonb dizi `[{id, name, avatar_id, category_name, ends_at}]` | SocialScreen | Hayır |
| `create_category` | `p_name, p_color_hex, p_icon_name` | yeni id | Kategori yönetimi | Hayır |
| `setup_onboarding_categories` | `p_categories jsonb` | void (limitte sessizce durur) | Onboarding, `ensureServerCategories`, kuyruk | Hayır |
| `purchase_avatar` | `p_avatar_id text` | int (yeni bakiye) | Koleksiyon | Hayır |
| `set_equipped_avatar` | `p_avatar_id text` | void | Koleksiyon | Hayır |
| `delete_own_account` | — | void | Profil | Hayır |
| `cleanup_unconfirmed_duplicate_identity` | `p_email text` | — | Google/Apple girişi sonrası (kendi e-postası) | Hayır |
| `get_friends_feed` | `int` | — | Kullanılmıyor | Hayır |
| `process_weekly_leagues`, `ensure_user_in_league` | — | — | Yalnızca cron ve sunucu içi | Hayır |

İstemci `reorder_categories`'i çağırmaz (canlıda yok); sıralama satır başına paralel `update(sort_order)` ile yazılır (§4.2).

### 5.2 `complete_study_session` kuralları
- İlk kontrol idempotency: aynı `(user_id, client_uuid)` → `duplicate:true`, puan ve kum 0.
- Doğrulama sırası: süre 25/50 → `started_at` gelecekte değil (null da reddedilir) → 24 saatten eski değil → `started_at + süre <= now() + 5 dk` → kategori kullanıcıya ait → gerçek aralıkla çakışma (`{error:'overlap'}`).
- Puan: 25 dk = 5, 50 dk = 12. Duraklatma cezası `ceil(%20)` (25 dk → 4, 50 dk → 9). Seri bonusu 3/7/14 günde %10/%20/%30 (`ceil`). Kum: seans başına 20.
- Günlük tavan: aynı çalışma gününde 16 seans dolunca puan, kum ve lig puanı 0. `total_minutes` artmaya devam eder.
- Gün: `((started_at AT TIME ZONE profiles.timezone) - 4 saat)::date`. Daha eski güne ait geç gelen seans seriyi ve `last_study_date`'i geri almaz.
- `completed_at = started_at + süre`. `activity_feed` yalnızca `show_in_social_feed` açıksa yazılır.

### 5.3 Seans hata sözleşmesi (`classifySessionError` / `classifySessionResponse`)

| Sunucu yanıtı | İstemci davranışı |
|---|---|
| `duplicate:true` | Başarı, puan tekrar verilmez |
| `daily_limit_reached:true` | Başarı, 0 puan / 0 kum |
| `{error:'overlap'}` | Kuyrukta kalır; sunucu yaşı 24 saati geçince `overlap` ile reddedilir |
| `session_not_finished` | `not_elapsed`. Saat farkı açıklıyorsa ya da bilinmiyorsa geçici (`clock_skew`), aksi halde kalıcı |
| `started_at cannot be in the future` | `future_start`, aynı saat farkı kuralı |
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
| `categories` | Kendi satırlarında SELECT, UPDATE (ad/renk/ikon/arşiv/sıra). Canlıda DELETE politikası/yetkisi ve tüm kolonlarda UPDATE yetkisi hâlâ açık; `proposed/16` kapatır. İstemci silmez |
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

### 5.6 `delete_own_account` (canlı, 3 Ekim)
`auth.users` satırını siler; `profiles`, `study_sessions`, `friendships` (iki yön), `marketing_subscribers.user_id` auth.users'a, `categories`, `league_memberships`, `activity_feed`, `avatar_unlocks` profiles'a `ON DELETE CASCADE`. Açık: `waitlist` (e-posta, FK yok) ve `user_id`'si boş abonelik satırı kalır, `search_path`'te `pg_temp` yok → `proposed/12_delete_own_account.sql` (+ down, `tests/proposed_12_delete_own_account_dryrun.sql`).

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
- **Tetikleyiciler:** Shell açılışı, bağlantı geri gelince, banner'a dokunma, yeni seans.
- **Yer tutucu kategori:** isimle buluttaki kategoriye eşlenir; bulutta hiç kategori yoksa varsayılanlar oluşturulur.
- **Kimliksiz önbellek:** uid bilinmiyorsa `pending_sessions_<email>`'e yazılır, uid öğrenilince taşınır.
- Çıkışta kuyruk uid'e bağlı kalır, başka hesaba gönderilmez. Hesap silinince temizlenir.

### 6.3 Giriş ve onboarding
1. **Splash:** `restoreCachedUser` + kategori önbelleği + avatar kataloğu (ağsız) → `SupabaseService.initialize` (zaman aşımlı) → oturum varsa `fetchCurrentUserModel` + kategoriler → `AppGate`.
2. **Login:** e-posta `signInWithPassword`; Google/Apple native idToken → `signInWithIdToken` → `cleanup_unconfirmed_duplicate_identity`.
3. **Profil:** `handle_new_user` trigger'ı (varsayılan avatar, `friend_code`).
4. **Onboarding:** `completeOnboarding` → `setup_onboarding_categories` → `profiles.update(birth_year, user_segment, daily_goal_minutes, onboarding_completed_at)` → `currentUser` güncellenir → AppGate Shell'e geçer.
5. **Çıkış / oturum düşmesi:** `signOutFully` ya da `signedOut` olayı → `currentUser = null` → AppGate Login gösterir.

### 6.4 Lig döngüsü
1. `complete_study_session`, tavan aşılmadıysa `ensure_user_in_league(uid, puan)` → `league_memberships.weekly_points` artar.
2. Sıralama: `weekly_points DESC, joined_at ASC, user_id`.
3. Cron `weekly_leagues_job` `'1 21 * * 0'` (Pazar 21:01 UTC = Pazartesi 00:01 TR) → `process_weekly_leagues()`.
4. İşlenen: `end_date <= now() + 5 dk` olan aktif ligler. Aynı koşuda taşınan üye ikinci kez işlenmez.
   - **Ödül avatarı:** ilk 3 ve puanı > 0 → `league_award_avatar_id(tier, sıra)`.
   - **Terfi:** puan > 0, sıra ≤ terfi kotası, kademe < 5 → üst kademede 30'dan az üyeli lig (yoksa yeni).
   - **Düşme:** sıra ≥ düşme sınırı ve kademe > 1.
   - Herkesin `weekly_points` = 0; `end_date` + 14 gün. Yeni lig, 2 hafta sonraki Pazar 23:59:59 TR'de biter.
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
- `scripts/.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (son ikisi sır değil, e-posta altbilgisindeki hizmet sağlayıcı kimliği; boşsa bülten gönderilmez). İçeriğini okuma, hiçbir yere kopyalama.
- Edge secret: `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (`send-welcome-email`; kimlik eksikse e-posta gönderilmez). Abonelikten çıkma token'ı UUID olduğu için ek secret yok.

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
- Bekleme listesi formu: ayrı, önceden işaretsiz ticari ileti onay kutusu (`#notify-consent`); işaretlenmeden kayıt yok. Canlı `waitlist`'te onay kolonu olmadığı için gövde yalnızca `{email}`; sunucu tarafı `proposed/19`.

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
| Debug süre kısaltmasını kaldırmak, sunucu doğrulamasını gevşetmek | `--profile` / `--release` ile test |
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

## 10. Bilinen açık konular (3 Ekim 2026)

| Öncelik | Konu | Not |
|---|---|---|
| P0 | Migration geçmişi canlıyla uyumsuz, baseline yok | `supabase/README.md` → Baseline (`db dump` + `migration repair`). O zamana kadar CLI push yasak |
| P1 | `send-welcome-email` repodaki sürümü deploy edilmedi | 3 Ekim `list_edge_functions`: `unsubscribe` v9 ve `send-welcome-email` v7 canlıda, ikisi de JWT kapalı; `unsubscribe` v9 token-only isteği zaten kabul ediyor (repo farkı yalnızca yorum). Repodaki `send-welcome-email` (gönderen kimliği altbilgisi, yalnızca token'lı bağlantı) için sıra: site deploy → `supabase secrets set MAIL_SENDER_NAME=… MAIL_SENDER_ADDRESS=…` → `supabase functions deploy send-welcome-email --no-verify-jwt`. Secret'lar yoksa hoş geldin e-postası gönderilmez |
| P1 | Veri sorumlusu kimliği sitede yer tutucu (KVKK-15) | `/privacy`, `/kvkk` (iki dil) §1'de `data-fill-in` işaretli; kullanıcı gerçek bilgiyle doldurur (`grep -rn 'data-fill-in' landing/`) |
| P1 | `mail.pomosprint.app` Resend doğrulaması ve DNS kayıtları | Yapılmadan hoş geldin ve bülten gönderilemez |
| P1 | `cleanup_unconfirmed_duplicate_identity(p_email)` parametredeki e-postaya güveniyor | `proposed/04` |
| P1 | Hesap silme `waitlist` ve `user_id`'siz abonelik satırını silmiyor | `proposed/12` (DRYRUN → migration, SQL Editor'de kullanıcı) |
| P2 | Görünen ad için sunucu tarafı içerik denetimi yok | İstemci `NameFilter` doğrudan `profiles.name` UPDATE'iyle aşılabilir. Gerekirse `profiles` BEFORE INSERT/UPDATE trigger'ında küçük bir liste |
| P2 | Google/Apple ile ilk girişte onay sürümü kaydedilmiyor | Bildirim metni gösteriliyor; istenirse ilk girişte `auth.updateUser(data: {terms_version, privacy_version, terms_accepted_at})` |
| P2 | Kullanıcı engelleme sunucuda değil | Gizleme cihazda; arkadaşlıktan çıkarma RPC'si (`remove_friend`) canlıda yok |
| P1 | Supabase Auth panel ayarları repoda yok | Redirect URLs (`/reset-password`, `/confirmed`, `.html`'li hâlleri; `io.supabase.pomosprint://` silinmeli), Reset Password şablonu `token_hash`, Leaked password protection, Apple provider (Client ID `com.pomosprint.app`) |
| P2 | `proposed/11` RPC'leri canlıda yok | Arkadaş silme/iptal UI'ı ve toplu kategori sıralaması bunlara bağlı |
| P2 | `proposed/15` (aylık sıralama = çalışma ayı) ve `proposed/16` (kategori sırası, silme/kolon yetkileri) uygulanmadı | Her ikisinin DRYRUN'u yerel taklitte doğrulandı; kullanıcı SQL Editor'de önce DRYRUN, sonra dosyayı çalıştırır |
| P2 | `proposed/19` (bekleme listesi onay kaydı ve abonelikten çıkma token'ı) uygulanmadı | Yerel taklitte DRYRUN 12/12 `true`. A bölümü geriye uyumlu; B yalnızca site onay alanlarını gönderdikten sonra. Sonra `unsubscribe` waitlist token'ını da tanımalı ve lansman e-postası yalnızca `marketing_consent = true` satırlara gitmeli |
| P2 | `proposed/01`–`10` kalan maddeler | Puan sabitleri tek kaynak, `purchase_avatar` kilidi (05), `activity_feed` RLS ve `get_friends_feed` (07), `profiles` kolon bazlı SELECT (06), kategori ad kuralları (09), varsayılan yetkiler (08), veri temizliği (10) |
| P2 | Herkese açık sıralama oturum açıkken tam ad döndürüyor | Ürün kararı (`proposed/README.md`, 03 satırı) |
| P2 | `profiles.timezone` istemciden yazılmıyor | Yetki ve doğrulama canlıda hazır; `set_my_timezone` yok. Cihaz IANA adı için ek paket (`flutter_timezone`) gerekir |
| P2 | Bayat referanslar | `proposed/README.md` ve `scripts/security_regression_test.js` hâlâ `migrations/20261003120000_audit_fixes.sql` diyor; `run_local.sh` `audit_fixes_test.sql`'i çalıştırıyor; `supabase_service.dart`'ta "`is_me` DÖNMEZ" yorumları |
| P2 | Üç çeviri yolu (ARB, `translate()`, `isTurkish`) | Ekran ekran ARB'ye taşıma; cihaz dilinden ilk dil seçimi |
| P2 | DMARC kaydı yok | `_dmarc` TXT, `p=none` ile başla |
| P3 | Android derlemesi bu makinede doğrulanmadı | Gerçek cihaz test listesi: analiz raporu §10 |
| P3 | Ertelenen teknik işler | `google_sign_in` 7.x; `SupabaseService`'in bölünmesi (Auth → Category → Social); onboarding'de Çıkış butonu (`AppGate` `onSignedOut` vermiyor) |
| P3 | Waitlist bot koruması | Sitede honeypot + süre kontrolü var; Turnstile/çift onay backend ister |
| P3 | Repo hijyeni | `assets/league_award_avatars/` (9,6 MB), çalışmayan masaüstü/web şablonları, izlenen `settings.local.json` dosyaları |
| P3 | Test kapsamı | Widget ve E2E testi yok (`specs/001-e2e-test-plan`) |
