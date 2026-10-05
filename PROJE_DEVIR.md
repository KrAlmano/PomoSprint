# PomoSprint — proje ve AI oturum devir belgesi

**Güncelleme:** 5 Ekim 2026. **Proje kökü:** `/Users/almano/Desktop/Courses/Projects/Pomodoro`.

Bu dosya yeni bir konuşmaya başlayan yapay zekâ için proje haritası ve çalışma geçmişidir. Kod, mevcut `AGENTS.md`, Git geçmişi ve yerel QA raporları okunarak hazırlanmıştır. Bu belgeyi hazırlarken uygulama kodu değiştirilmedi, canlıya SQL veya yayın yapılmadı. Geçmiş test sonuçları aşağıda kanıt dosyalarıyla verilmiştir; bu belgeyi yazmak için testler yeniden çalıştırılmadı.

## 1. Yeni oturumda önce bunu bil

1. Önce bu belgeyi, sonra görevin alanı için [AGENTS.md](AGENTS.md) bölümünü oku. `git status --short` ve `git log -5 --oneline` çalıştır. Çok sayıda değişiklik henüz commit edilmedi; bunlar mevcut çalışmanın parçasıdır. `git reset`, toplu `git restore` veya temizlikle geri alma.
2. Kullanıcı Türkçe iletişim kuruyor. Yapılabilir işi tamamlamanı, uygulamayı gerçekten çalıştırmanı, hata bulursan düzeltmeni ve sonuçları raporlamanı istiyor. Sadece test kodu üretmek isteği karşılamıyor.
3. Şu an fiziksel cihaz kullanılmıyor. Kullanıcı fiziksel cihaz doğrulamasını sonraya bıraktı. iOS simülatörü ve Android emülatörü üzerinde çalış.
4. Test hesapları ve test seansları **yerel Supabase** içindir. Kök `.env` normal uygulamayı canlıya bağlayabilir. Test için URL ve anon anahtarı birlikte `--dart-define` ile ver; normal `flutter run` komutunu düşünmeden çalıştırma.
5. İstenen geçici davranış: **5 saniye bitince 25 dakika, 10 saniye bitince 50 dakika gibi kayıt, puan, kum, rapor ve lig işlemleri**. Bu yalnızca açıkça seçilen yerel debug QA modunda kuruludur. Normal uygulama 25/50 dakika kullanır. Canlı sunucunun süre doğrulaması gevşetilmedi.
6. Son simülatör görüntüsünde QA1 hesabı açık bırakıldı: 17 puan, 40 kum, `00:05`, TEST rozeti. Android emülatörü ve Gradle daemon kapatıldı. Bunlar oturum sonu durumudur; yeni oturumda süreçlerin hâlâ açık olduğunu varsayma.
7. “Testler geçti” mağazaya hazır demek değildir. Fiziksel bildirim/kilit ekranı, gerçek Google/Apple girişi ve ayrı operasyon/yayın işleri bekliyor.

### Kaynaklar ve çelişkileri çözme

- Canlı DB sözleşmesi için gerçeğin kaynağı canlı tanımdır; bu belgedeki geçmiş sonuç canlıya yeni bir doğrulama değildir.
- `AGENTS.md`: çalışma kuralları, detaylı RPC/kolon/hata sözleşmeleri, SQL değişiklik akışı.
- Bu belge: son oturumun devri, bağımlılıklar, çalıştırma ve sonuçların özeti.
- [QA_FOLLOWUP raporu](analiz/QA_FOLLOWUP_2026-10-05.json): en yeni saat dilimi/arkadaş yönetimi/yasal onay test sonuçları.
- [QA_FULL raporu](analiz/QA_FULL_2026-10-05.json): önceki geniş kapsamlı testler. Burada “saat dilimi eşleme yok” ve “silme/engelleme düğmeleri yok” ifadeleri tarihsel bulgulardır; takip turunda tamamlandı.
- `PROJECT_CONTEXT.md`, `analiz/` içindeki eski raporlar ve kod yorumları eski olabilir. Daha eski bir metne dayanarak düzeltilmiş özelliği geri alma.
- `supabase/proposed/` adı “hepsi uygulanmamış” anlamına gelmez: bazı paketler 5 Ekim'de canlıya uygulandı (§8).

## 2. Ürün ve teknoloji

PomoSprint, oyunlaştırılmış bir çalışma sayacı. Yalnızca 25 ve 50 dakikalık seanslar var; ayrı mola sayacı veya sanal kütüphane yok. Kullanıcı kategori seçiyor; seanslar raporlara, seriye, puana, sanal kuma, lig sıralamasına ve sosyal görünürlüğe bağlanıyor.

| Alan | Teknoloji / görev |
|---|---|
| Mobil | Flutter; desteklenen ürün platformları iOS ve Android |
| Kontrol edilen yerel araçlar | Flutter 3.44.8 / Dart 3.12.2; `pubspec.yaml` Dart `^3.12.2` |
| Paket / ürün | Dart paketi `pomodoro`, görünen ad `PomoSprint`, sürüm `1.0.0+1` |
| Platform kimliği | `com.pomosprint.app`; widget uzantısı `com.pomosprint.app.TimerWidget` |
| Sunucu | Supabase Auth + Postgres + RLS + SECURITY DEFINER RPC + cron + Edge Functions |
| Canlı proje | `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, `eu-north-1` |
| Site | `pomosprint.app`, `landing/`, Cloudflare Workers static assets |
| Yerel veri | SharedPreferences, aktif seans, kullanıcı/kategori önbelleği, kalıcı outbox |
| Hata raporu | Sentry; yerel URL/anon define verildiğinde DSN ayrıca verilmezse kapalı |
| UI / animasyon | Material, Lottie `assets/sand_timer.json`, avatar varlıkları |
| Auth | E-posta/parola, Google native idToken, iOS Apple native idToken |
| Bildirim | `flutter_local_notifications`, Android sistem kronometresi/alarm, iOS ActivityKit |
| Zaman | `timezone`, native IANA kanal, `ServerClock`, 04:00 çalışma günü |

Bağımlılık sürümleri `pubspec.yaml`'daki aralıklardır; çözülmüş gerçek paket sürümleri `pubspec.lock`'tadır. `google_sign_in` hâlâ 6.x API'sinde; 7.x göçü yapılmadı. Yeni saat dilimi okuması yeni paket gerektirmedi; Kotlin/Swift MethodChannel kullanıldı. `macos/`, `linux/`, `windows/`, `web/` ürün olarak doğrulanmış platformlar değil; mevcut şablonlara dayanıp masaüstü/web çalışıyor deme.

## 3. Mimari ve bağımlılık haritası

```mermaid
flowchart TD
  Main[main.dart: ayarlar, Sentry, dil, tema] --> Splash[Splash: cache ve ensureCloud]
  Splash --> Gate[AppGate]
  Gate --> Login[Giriş / kayıt / sıfırlama]
  Gate --> Onboard[Onboarding]
  Gate --> Shell[MainNavigationShell]
  Shell --> Timer[TimerScreen]
  Shell --> Reports[ReportsScreen]
  Shell --> Ranking[RankingScreen]
  Shell --> Social[SocialScreen / FriendsSheet]
  Login --> Service[SupabaseService]
  Onboard --> Service
  Timer --> Persist[TimerPersistence]
  Timer --> Queue[SessionQueue: kalıcı outbox]
  Queue --> RPC[complete_study_session / yerel QA RPC]
  RPC --> DB[(Postgres: seans, profil, lig)]
  Service --> DB
  Reports --> Service
  Reports --> Queue
  Reports --> Stats[StatsCalculator / study_day]
  Ranking --> Service
  Social --> Service
  Timer --> Native[Bildirim / LockScreenTimer]
  Service --> Zone[DeviceTimeZone native IANA]
  Zone --> Stats
```

### Açılış ve kullanıcı durumu

`main.dart` `.env` yükler; `BackendConfig` bağlantı kaynağını çözer; Sentry, dil ve tema kurulur; bildirim servisi izin istemeden başlatılır; `SplashScreen` gösterilir. Splash önce cache'i, sonra `ensureCloud` ve profili yükler. Bulut kurulamazsa giriş/kabuk yeniden deneme yapabilir.

`SupabaseService.currentUser`, `ValueNotifier<UserModel?>`, kullanıcı durumunun tek kaynağıdır. `AppGate` bundan karar verir:

- Kullanıcı null → Login.
- `onboardingCompletedAt` null → PostAuthOnboarding.
- Tamamlanmış profil → MainNavigationShell.

Ekranlar kendi kopya kullanıcı durumunu tutup ayrı Login/Shell geçişi yapmamalı. Servis auth/async işlemlerde kullanıcı epoch/id kontrolüyle eski hesabın yanıtının yeni hesaba yazılmasını önler. Çıkış, Apple yetki iptali ve oturum düşmesi tam çıkış kancalarından geçer.

### Kabuk ve yenileme

Kabuk dört sekmeyi `IndexedStack` içinde yaşatır: Pomo, Raporlar, Sıralama, Sosyal. Gizli sekmede `TickerMode` kapalıdır; periyodik işleri durdur. Yerel `addStatsChangedListener` puan/arkadaş gibi değişikliklerde ekranları tazeler; global `ranking_updates` Realtime kanalı kullanılmıyor.

Sosyal veri normalde görünürken 30 saniyede bir okunur. Kayıtlı yerel kısa QA modunda 2 saniyedir; dönüşte hemen tazelenir. Bu **push üzerinden gerçek zamanlı yayın değildir**. 5 saniyelik seansı 30 saniyelik poll ile kaçırmamak için QA aralığı kısa tutuldu.

## 4. Klasör ve sorumluluk haritası

| Yer | Sorumluluk / ilk bakılacak dosya |
|---|---|
| `lib/main.dart`, `lib/theme.dart` | Başlatma, uygulama adı, görünüm |
| `lib/app/app_gate.dart` | Tek auth/onboarding yönlendirme kapısı |
| `lib/app/main_shell.dart` | Sekmeler, bağlantı, kuyruk banner'ı, odak RPC'si, ön plana dönüş |
| `lib/app/connection_watcher.dart` | Bağlantı değişikliği ve tekrar deneme |
| `lib/app/category_cache.dart`, `session_feedback.dart` | Kategori cache'i, seans sonuç diyalogları |
| `lib/screens/timer_screen.dart` | Sayaç/duraklatma/geri yükleme durum makinesi |
| `lib/services/timer_persistence.dart` | `ActiveTimerSession`, diske kayıt, saatten kalan süre hesabı |
| `lib/services/session_queue.dart` | `PendingSession`, kalıcı outbox, tekrar/idempotency/ret sınıflandırması |
| `lib/services/supabase_service.dart` | Auth, profil, seans, kategori, lig, arkadaş, avatar veri katmanı |
| `lib/services/backend_config.dart`, `local_test_mode.dart` | Canlı/yerel bağlantı çözümü ve QA sınırları |
| `lib/services/server_clock.dart`, `device_time_zone.dart` | Sunucu-cihaz saat farkı ve native IANA adı |
| `lib/services/notification_service.dart`, `lock_screen_timer.dart` | İzin, bitiş bildirimi, sistem geri sayımı |
| `lib/screens/reports_screen.dart` | Seans/kategori/outbox okuma ve raporların veri kaynağı |
| `history_screen.dart`, `monthly_tracking_screen.dart` | Haftalık ve aylık detay; history dosya adı yanıltıcıdır |
| `lib/utils/stats_calculator.dart`, `study_day.dart`, `category_names.dart` | Metrikler, 04:00/DST takvimi, TR/EN kategori eşlemesi |
| `ranking_screen.dart`, `lib/widgets/social/ranking_models.dart` | Lig/Aylık/Arkadaşlar sıralaması ve satır modelleri |
| `social_screen.dart`, `friends_sheet.dart`, `user_safety.dart` | Canlı arkadaş, gelen/giden istek, silme/engelleme/gizleme/bildirme |
| `profile_screen.dart`, `character_collection_screen.dart` | Ayarlar, şifre/hesap silme, avatar mağazası/kuşanma |
| `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart` | Giriş, kayıt, ayrı reset formu ve gönderildi ekranı |
| `post_auth_onboarding_screen.dart`, `services/onboarding_categories.dart` | Altı adım ve mevcut kategorilerle uzlaştırma |
| `categories_management_screen.dart`, `models/category_model.dart` | Kategori ekleme/ad/sıra/arşiv/limit |
| `lib/l10n/` | TR/EN ARB ve üretilen localization Dart dosyaları |
| `lib/utils/responsive.dart`, `test/responsive_*` | Telefon/tablet/yatay düzen ve taşma kontrolleri |
| `lib/dev/` | Girişsiz kilit ekranı önizlemesi, yerel QA başlatıcı, süreç ölüm fikstürü; normal main import etmez |
| `test/` | Birim/widget; `support/fake_supabase_service.dart` sahte servis |
| `integration_test/` | Yerel gerçek backend'e bağlı uygulama UI E2E |
| `android/`, `ios/` | Native ayarlar, kanal kodları, bildirim ve widget hedefleri |
| `supabase/` | Eski migration'lar, yeni paketler, dryrun/down, Edge Functions, Auth e-posta şablonları |
| `tool/local_supabase/` | İzole Docker Supabase, snapshot/seed, parite, test hesapları ve E2E araçları |
| `scripts/` | Ağsız JS testleri, güvenlik regresyonu, bülten, mağaza derleme/Sentry |
| `landing/` | Statik site, yasal/reset/onay/abonelikten çıkma sayfaları |
| `analiz/` | Geçmiş denetimler, QA raporları, kalıcı log ve ekran görüntüleri |
| `.vscode/launch.json` | Normal, profile, yerel, kayıtlı hızlı ve kaydetmeyen hızlı çalıştırma seçenekleri |
| `.claude/`, `.specify/`, `specs/` | Yardımcı ajan/spec yapılandırmaları; kaynak kodun yerine geçmez |

## 5. Kritik akışlar ve kurallar

### 5.1 Seans: sayaç → disk → outbox → sunucu → rapor

1. Başlatma sırasında `clientUuid` ve `startedAt` bir kez üretilir. Üç saniyelik hazırlık, çalışma, tek duraklatma ve devam boyunca seans kimliği korunur.
2. Kalan süre tick sayısını azaltarak değil `remainingSecondsAt(now)` ile hesaplanır. Durum geçişleri diske yazılır.
3. Shell sosyal görünürlük için `start_study_session`; duraklat/bitir/sıfırla/çıkış için `cancel_study_session` kullanır. Bu odak göstergesi, puan kazandıran kalıcı seans kaydı değildir.
4. Bitiş `submitCompletedSession` ile önce outbox'a yazar, sonra gönderir. RPC sonucu `Success`, `Queued`, `Rejected` olarak UI'ya gelir.
5. Sunucu kategori sahipliği, zaman, çakışma ve mükerrer kayıt kontrolünü yapar. Puan/kum/seri/lig yalnızca sunucudan alınır.
6. Yanıt kaybolursa aynı `client_uuid` ile yeniden gönderilir. Duplicate tekrar ödül vermez. Açılış sync'i ve timer submit'i yarışırsa `_settledOutcomes` ilk turun sonucunu korur.
7. Kalıcı ret sessiz silinmez: son 50 reddedilen kayıt ve tek seferlik kullanıcı bildirimi vardır. Geçici ağ/auth hatası kuyrukta kalır.
8. Uygulama kapalıyken biten seans açılışta tamamlanır. 24 saatten eski duraklatılmış aktif kayıt kaldırılır. Server gönderim penceresi ve outbox ret kuralları ayrıca `AGENTS.md` §5'te.
9. Duraklatma hakkı bir. Süren seans sırasında 25/50 seçimini değiştirmek sıfırlamaya bağlıdır. Çıkışta cihazda seans saklanabilir; aynı hesap yeniden girdiğinde devam eder, başka hesaba taşınmaz.

**Mevcut normal sunucu sözleşmesi:** 25/50 dk, baz puan 5/12; duraklatınca baz puan 4/9; seri bonusları 3/7/14 gün için %10/%20/%30, yukarı yuvarlama; seans başına 20 kum. Aynı çalışma günündeki 16 seans tavanından sonra puan/kum/lig artmaz ama dakika kaydı devam eder. `get_points_config` ve canlı RPC gerçek kaynaktır; formülü UI'ya kopyalama.

`complete_study_session` parametreleri: `p_client_uuid`, `p_category_id`, `p_duration_minutes`, `p_was_paused`, `p_is_verified` (ön planda geçen saniye; bool değil), `p_started_at`. Sonuçta `base_points`, `bonus_points`, `total_points`, `coins_earned`, `streak`, `bonus_pct`, `duplicate`, `daily_limit_reached` bulunur. Zaman kuralları arasında gelecekte başlama yasağı, 24 saatlik pencere ve normal gövdede bitiş toleransı vardır. Bunları “debug için” canlıda değiştirme.

### 5.2 Rapor ve çalışma günü

- Günün sınırı profil IANA diliminde **04:00**; hafta Pazartesi–Pazar. `studyDayOf`, `studyDayStart`, `mondayOf`, `addDays` ortak yardımcıları kullanılır. DST için `Duration(days: 1)` ile takvim ilerletme.
- `DeviceTimeZone` native `com.pomosprint.app/device_timezone` kanalında `getTimeZone` okur. iOS `TimeZone.current.identifier`, Android `TimeZone.getDefault().id`. Geçerli ad profil yüklenirken ve kabuk ön plana döndüğünde kendi `profiles.timezone` kolonuna yazılır; bilinmeyen ad/ağ hatasında eski profil korunur.
- Seanslar ve bekleyen outbox `mergeStatSessions` ile birleşir. Sunucuda aynı `client_uuid` varsa yerel kopya ayrıca sayılmaz. `overlap` bekleyenleri toplamı şişirmez. Sunucu saati düzeltmesi outbox gün hesabına uygulanır.
- Kategori toplamı UUID ile gruplanır; ad değişince geçmiş iki kategoriye bölünmez. Arşivli kategori geçmiş raporda kalır. 50 dk iki pomodoro sayılır.
- Günlük hedef profilde `daily_goal_minutes`, varsayılan 200. Dağılım yüzdeleri toplam 100'e yuvarlanır; hedef ilerleme etiketi 100'ü aşabilir, halka 100'de durur.
- Aylık sıralama ve aylık rapor, 5 Ekim'de uygulanan sunucu paketiyle `started_at`/profil dilimi/04:00 kuralını paylaşır.

### 5.3 Arkadaş, sosyal ve güvenlik

Kod ekleme → `add_friend_by_code`; kabul/ret → `respond_friend_request`; listeler → `get_my_friends`, `get_incoming_friend_requests`, `get_outgoing_friend_requests`; canlı odak → `get_live_friends`.

Takip turunda UI'ya bağlananlar: `remove_friend(p_friend_id)`, `cancel_friend_request(p_to_user_id)`, `block_user(p_user_id)`, `unblock_user(p_user_id)`, `get_my_blocks()`. İşlem onayı var; yanıt beklerken düğmeler kapalı, ağ hatasında kayıt korunur ve tekrar deneme mümkün. Başarı sosyal/sıralama verisini tazeler. Engeli kaldırmak arkadaşlığı otomatik kurmaz.

Yerel **Gizle** (`hidden_users_uid_<uid>`) ve sunucudaki **Engelle** ayrı işlevlerdir. Ranking model sunucunun `is_blocked` işaretini de okur; sıra/puan satırı bozulmadan maskelenir. Kendi satırında güvenlik menüsü olmaz. “Ben” eşlemesi isimle değil `is_me` ile yapılır.

Mevcut bildirme `mailto:destek@pomosprint.app`; sunucu `submit_user_report` RPC'si hazır fakat uygulamada rapor formu henüz bağlanmadı. Sunucuda ops operatör araçları mevcut; otomatik test için operatör/üretim değişikliği yapma.

### 5.4 Auth, reset ve yasal onay

- Kayıt zorunlu Kullanım Şartları kabulü ve KVKK/Gizlilik okuma teyidi ister. Pazarlama onayı isteğe bağlı, önceden işaretli değil. `RegistrationConsent` metadata üretir.
- “Şifremi Unuttum” artık ayrı e-posta formunu açar. Kullanıcı adresi girip doğrulama/sıfırlama maili gönderir; başarı ayrı “mailinize gönderildi” ekranına gider. Parola değiştirme linki web reset sayfasında tamamlanır; uygulamada kod girme akışı eklenmedi.
- Supabase auth implicit; özel eski uygulama URL şeması kaldırılmıştır. Web `/reset-password` `access_token`/recovery veya `token_hash` akışını işler; `/confirmed` onay dönüşüdür.
- Google/Apple: native idToken → Supabase auth → **`accept_legal_documents`** → duplicate identity temizliği/profil → AppGate. İki belge sürümü tek `kLegalDocumentsVersion` sabitinden (şu an `2026-10-03`) gider.
- Onay `consents` ledger'ına `terms`/`privacy_notice`, `source=app_legal_acceptance` olarak yazılır; tekrar çağrı çoğaltmaz. Kayıt başarısızsa sosyal girişten sonra tam çıkış yapılır. Restored eski oturumlara kullanıcı eylemi olmadan geriye dönük onay yazılmaz. Bu metadata yazımı veya pazarlama aboneliği değildir.
- Auth istekleri 25 saniye zaman aşımlı. Şifre en az 6 karakter, küçük/büyük harf ve rakam; uygulama, web ve Auth paneli uyumlu olmalı.
- Onboarding: yaş (13+), hedef/segment, kategoriler, sosyal görünürlük açık seçimi, oyun kuralları, günlük hedef. Segmentler `lgs/yks/kpss/language/university/work`; Diğer null. Kategori önerileri hedefe göre seçilir; kullanıcı seçimi ve taslak korunur.

### 5.5 Kategoriler, avatar ve lig

- Ücretsiz kategori limiti 8, premium 15; asıl kural sunucuda. Kategori silinmez, arşivlenir. `setup_onboarding_categories` mevcutlarla uzlaştırır; güncel JSON sayaçlı yanıt ve eski void yanıt istemcide desteklenir.
- UUID olmayan yer tutucu kategoriler RPC'ye gönderilmez; kuyruk ad eşlemesiyle gerçek kategori bulur. TR/EN ad eşlemesi `categoryMatchKey` üzerinden.
- Sıralama istemcide satır başına `sort_order` update ile; toplu `reorder_categories` çağrılmaz. Kısmi hata iyimser UI'yı geri alıp listeyi yeniden okur. Sunucuda `proposed/16` uygulanmış olduğundan eski yorumdaki sıra çakışması iddiasını yeniden doğrulamadan güncel hata sayma.
- Avatar katalog `avatars`; sahiplik `avatar_unlocks` veya ücretsiz kural; `purchase_avatar` ve `set_equipped_avatar` sunucu RPC. Lig ödülü avatarı satın alınmaz. Satın alma yarışında bakiye sunucuda korunur. Premium/IAP edinme yolu bu QA'da eklenmedi.
- Lig 5 kademe, oda en fazla 30 kişi, devreden dönem 14 gün. Yeni ilk oda dönemi açıldığı güne göre 7–14 gün olabilir. Sıra `weekly_points DESC, joined_at ASC, user_id`.
- Cron `process_weekly_leagues` ödül/terfi/düşme ve dönem geçişini yürütür. `carry_points` geç gelen seans puanını doğru döneme bağlar. Ödül/terfi `app_config` eşikleri şu an **1/1/1**; 3/25/25 alternatif yerel transaction'da test edildi, canlı ürün kararı değiştirilmedi.

### 5.6 Bildirim ve kilit ekranı

İzin açılışta değil ilk BAŞLAT/ayar eyleminde istenir. Tercih `notifications_enabled`; UI tercih ile sistem iznini birlikte gösterir. Android bitiş alarmı ve devam eden bildirim; iOS bitiş bildirimi ve ActivityKit canlı etkinliği kullanılır.

Android sistem kronometresi / `timeoutAfter`, iOS `Text(timerInterval:)` / `staleDate` sayacı sistemde yürütür. Dart'ı arka planda sürekli çalıştıracak foreground service/background mode eklenmedi. Başlat/devam/restore showRunning; pause showPaused; tamamla/sıfırla/çıkış clear çağırır. iOS kanal `com.pomosprint.app/live_activity`; Swift kanal ve widget/Shared ActivityAttributes beraber değişebilir. Widget iOS 16.2+, ana Runner minimum iOS 15.

Simülatör native kayıt/teslim/iptal ve ActivityKit çağrıları geçti. Bu, fiziksel kilit ekranının yerleşimini veya gerçek cihazda tam ses/banner izin akışını doğruladığımız anlamına gelmez.

## 6. Bu çalışma sürecinde neler yapıldı?

### Kullanıcı arayüzü ve kısa seans isteği

- Kum saati animasyonunun boyun/bitiş kısmındaki boşluk için `assets/sand_timer.json` düzeltildi.
- Timer'daki “DERS SEÇ” başlığı ve kalem kaldırıldı; kategoriler ve seçim çipleri korundu.
- Ayrı şifremi unuttum formu ve mail gönderildi ekranı eklendi, TR/EN metinler üretildi. Gerçek yerel mail/reset akışı test edildi.
- Kısa sayacın kayıtlı yerel QA modu kuruldu: yalnızca sayaç kısaltmakla kalmıyor, 25/50 dakikalık alan ve normal sunucu ödülleriyle rapor/sosyal/lig denenebiliyor.
- `record_accelerated` aktif seans ve outbox'ta opsiyonel işaret olarak taşındı. Eski JSON'da false.
- Profil bildirim ayarındaki mounted koruması ve sosyal dönüşte taze veri davranışı düzeltildi.

### Test altyapısı ve iki platform

- iPhone 16 Plus / iOS 18.6 test hedefi kullanıldı. Eski destination/SDK sorununda istenen platform Xcode sürümüyle simulator runtime arasındaki fark ayrıştırıldı; iOS 26 runtime indirilerek ürün test hedefi değiştirilmedi.
- Android SDK, JDK 17 ve tek ARM64 API36 emülatör ile Android debug, UI ve release doğrulandı. Eski “bu makinede Android SDK yok” bilgisi artık geçersiz.
- UI testlerinde iPhone 16 Pro'nun sabit ekran boyutu varsayımı kaldırıldı; Plus ve Android gerçek boyutlarıyla kontrol edildi.
- Debug Android yerel HTTP izinleri yalnızca debug manifest/network security config içinde eklendi.
- Beş hesaplı UI seans/sosyal/rapor senaryosu iki platformda çalıştırıldı; rapor ve DB değerleri karşılaştırıldı.
- Gerçek yerel API kesintisi, offline outbox, yeniden gönderme, hesap izolasyonu, pause/restore ve ikinci pause reddi test edildi.
- iOS'ta gerçekten OS süreç kapatıp yeniden açma: tek ilave 50 dk/12 puan/20 kum kaydı doğrulandı. Android'de pause/restore ve offline testleri var; ayrı Android OS kill sonucu iddia edilmedi.
- Auth mail, RLS/sosyal güvenlik, kategori/onboarding, avatar satın alma/kuşanma, lig/cron/sıra/dönem/yariş senaryoları yerelde çalıştırıldı. Eski test beklentileri yeni canlı sözleşmeyle uyumlu hâle getirildi; doğru ürün davranışı sırf eski test yeşil olsun diye geri alınmadı.
- Flutter analiz ve regression, JS/Edge ağsız testleri, Android ARM64 ve iOS imzasız release derlemeleri geçti.

### Son takip turu

- Native IANA okuma ve profil saat dilimi sync'i eklendi; New York DST/gün hesabı ve geçersiz ad fallback'i sınandı.
- Giden istek iptali, arkadaş silme, block/unblock ve engellenen kullanıcı UI bağlandı; beklerken tek işlem, hata ve altı ekran boyutu test edildi.
- Google/Apple girişine yasal ledger kayıt adımı bağlandı. Gerçek sağlayıcı girişi denenmeden, onay metadata'sız yerel hesaplarla ledger yazımı/idempotency doğrulandı.
- Tüm paket 1068 başarılı teste çıktı; son ek iOS seans sonucu/rapor/lig kontrolü de geçti.

Bu değişikliklerin büyük kısmı çalışma ağacında henüz commit edilmemiştir. Dokümanı okuyan ajan yalnızca HEAD'e bakarsa son işi kaçırır.

## 7. Normal ve QA çalışma modları — karıştırma

| Mod | Bayrak | Gerçek bekleme | Kalıcı sonuç |
|---|---|---|---|
| Normal | QUICK_TIMER yok/false | 25/50 dakika | Normal `complete_study_session`; gerçek kayıt ve ödül |
| Kaydetmeyen hızlı | `QUICK_TIMER=true` | 5/10 saniye | Test göstergesi; outbox/sunucu kaydı ve puan/kum yok |
| Kayıtlı yerel hızlı | Yukarıdaki + `QUICK_TIMER_SAVE=true`, açık yerel URL/anon, debug | 5/10 saniye | Yerel `complete_qa_study_session`: 25/50 dakika alanı + sunucu ödülü |

`localQuickRecordingAllowed` kayıt iznini `debug && requested && http && host in {127.0.0.1, localhost, ::1, 10.0.2.2}` olarak sınırlar. İzin helper'ı tek başına sayacı kısaltmaz; timer için QUICK_TIMER da gerekir. Release/canlı adres bu kısa **kayıt** modunu açamaz. QUICK_TIMER tek başına ayrı kaydetmeyen test modudur.

Yerel QA RPC kurulumu:

```sh
python3 tool/local_supabase/quick_recording.py
```

Bu araç yalnızca sabit yerel Docker Postgres konteynerindeki normal gövdeden QA klonu üretir. Gerçek zaman aralığı 5/10 saniye; `duration_minutes` 25/50 kalır. Kategori/çakışma/duplicate/puan/kum/lig korumaları normal mantıkla çalışır. Hızlandırılmış kayıtların zaman aralığı gerçek 25/50 dakikalık aralık değildir; rapor dakika alanını kullanır. Normal RPC değişmez.

Kaldırmak için `python3 tool/local_supabase/quick_recording.py --remove` ve normal launch seçimi. QA RPC açıkken parite `func 65/66 FARKLI` der; bu beklenen ek yardımcıdır. Normal baseline ile 13/13 kontrol önce helper kaldırılarak yapılmış, sonra yeniden kurulmuştur. Yerelde hoş geldin trigger'ı canlıya istek atmasın diye kapalıdır.

## 8. DB durumu, güvenlik ve yayın sınırları

Kök `supabase/migrations/` canlı şemanın tam/birebir migration geçmişi değildir. `supabase db push` veya kökte `db reset` yapma. `proposed` dosyaları ön koşullu tarihsel paketlerdir; tekrar olduğu gibi uygulamak güncel fonksiyonu geriletebilir.

**Mevcut repo/AGENTS geçmişine göre canlı:**

- `20261003150000_live_audit_fixes` 3 Ekim'de uygulandı.
- 5 Ekim sırası: **12 → 15 → 16 → 19 A → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25 → 26** uygulandı ve o işlemde DRYRUN/md5/katalog doğrulandı.
- 19 B (onay alanı zorunlu waitlist) uygulanmadı; önce site payload güncellenmeli.
- 01–11 paketlerinin tamamı uygulanmış sayılmaz. Bazı eski öneriler sonraki paketlerle geçersiz kaldı.
- Eski `20260928120000_security_hardening_up` uygulanmadı; `session_not_elapsed` canlı kuralı diye kabul etme.
- `reorder_categories`, `set_my_timezone`, `get_my_category_limit` canlıda yok. Son timezone işi doğrudan izinli kendi `profiles.timezone` UPDATE ile çalışıyor.

Bu belge/son QA sırasında yeniden canlı DB sorgusu yapılmadı; yerel parity mevcut kaydedilmiş canlı fingerprint ile karşılaştırmadır. Yeni DB işi için canlı `pg_get_functiondef`, kolon/yetki/RLS/trigger/cron/migration geçmişini **yeniden** salt okunarak doğrula.

SQL işi: `supabase/README.md` ve `AGENTS.md` §2.4 akışını izle; canlı gövdeye göre ileri migration, eski canlı gövdeli rollback, transaction içinde geri alınan DRYRUN üret. Belgede kullanıcı SQL Editor uygulama akışı var; geçmişteki izinli migration uygulamasını yeni canlı yazma izni sayma. Bu oturumdaki yetki yerel test/dokümantasyon içindir.

Korunan para/puan/seri kolonlarına istemciden yazılmaz. Başkasının `profiles` satırı doğrudan okunmaz; yetkili RPC kullanılır. `study_sessions` istemciden INSERT/UPDATE değil RPC ile yazılır. RLS ve SECURITY DEFINER yetkileri korunur; yeni kolon/RPC'de GRANT/REVOKE unutma.

**Sırlar:** kök `.env` uygulama asset'idir; yalnızca public Supabase değerleri ve Sentry DSN. `scripts/.env`, service role, Resend anahtarı, Sentry auth token, Apple `.p8` ve Edge secrets bu belgeye/loga/repoya kopyalanmaz. Yerel demo anon anahtarı sır değildir, fakat canlı ve yerel anahtarlar karıştırılmaz.

## 9. Yerel ortamı yeniden açmak

### 9.1 Supabase

```sh
open -a Docker
supabase start --workdir tool/local_supabase
supabase status --workdir tool/local_supabase
python3 tool/local_supabase/quick_recording.py
```

| Hizmet | Yerel adres |
|---|---|
| API | `http://127.0.0.1:54321` |
| Android emülatör API | `http://10.0.2.2:54321` |
| Postgres | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` — sadece yerel |
| Studio | `http://127.0.0.1:54323` |
| Mailpit | `http://127.0.0.1:54324` |
| Proje / DB konteyner | `pomosprint-local` / `supabase_db_pomosprint-local` |
| Ağ geçidi | `supabase_kong_pomosprint-local` |

Yerel başlangıç snapshot'ı `tool/local_supabase/supabase/migrations/20261004120000_live_snapshot.sql`; reference avatar seed'i 27 satır. Mevcut kopyanın 5 Ekim paketleri sonrasındaki paritesi kontrol edildi. Yerel `db reset` 4 Ekim başlangıç snapshot'ını yeniden kurar; mevcut yeni şema/helper/test verisini kaybedebilir. **Sadece başlatmak için reset gerekmez.** Ayrıntılı yeniden kurma için yerel README ve zincir aracı okunmalı. Bu workdir'i canlı projeye `supabase link` ile bağlama.

`BackendConfig`: URL ve anon define ikisi verilirse `.env` yerine kullanılır; sadece biri verilirse bulut kapalıdır. Yerel Sentry, ayrıca DSN verilmezse kapalı. Public yerel ANON_KEY'i `supabase status` veya `.vscode/launch.json` içinden al.

### 9.2 iOS 18.6

Doğrulanan Plus UDID: `BEA55019-D5C3-420F-90F2-0B0CBD5690CF`. Build/simctl için kullanılan `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` bu makinede Xcode 27'ye aittir. Simulator UI `/Applications/Xcode-26.6.app/Contents/Developer/Applications/Simulator.app` ile açılmıştır; seçilen runtime **iOS 18.6**. Xcode uygulama sürümü ile simulator runtime aynı şey değildir.

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcrun simctl list devices available
xcrun simctl boot BEA55019-D5C3-420F-90F2-0B0CBD5690CF # zaten açıksa tekrar gerekmez
open /Applications/Xcode-26.6.app/Contents/Developer/Applications/Simulator.app
```

VS Code: **PomoSprint (kayıtlı hızlı yerel test, iOS)**. Bu normal main'i yerel backend'e bağlar; hesapla elle girilir. Hazır hesapla açmak için:

```sh
flutter run -d BEA55019-D5C3-420F-90F2-0B0CBD5690CF \
  -t lib/dev/local_qa_launcher.dart \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY='<yerel-demo-anon-key>' \
  --dart-define=QUICK_TIMER=true \
  --dart-define=QUICK_TIMER_SAVE=true \
  --dart-define=LOCAL_QA_EMAIL=e2e-sim-qa1-1005qa@pomosprint.local \
  --dart-define=LOCAL_QA_PASSWORD=SimE2e-Yerel2026
```

Anahtar placeholder'ını gerçek **yerel demo anon** ile değiştir. Helper yalnızca korumalı yerel debug modunda açılır; açıkça verilen e-posta mevcut yerel kullanıcıdan farklıysa yerel oturumu kapatıp o hesaba girer. İlk kurulumda bildirim tercihi yoksa kapalı yapar; native bildirim denemesinde Profil'den aç. Flutter terminalinde `d` detach uygulamayı açık bırakır; `q` kapatır.

### 9.3 Android

SDK: `/Users/almano/Library/Android/sdk`; AVD: `PomoSprint_QA_API36`, seri `emulator-5554`, Android 16 ARM64. Host localhost emülatörde `10.0.2.2`.

JDK 17: `/Users/almano/Library/Java/pomosprint-qa/zulu17.62.17-ca-jdk17.0.17-macosx_aarch64/zulu-17.jdk/Contents/Home`. Native Java/Kotlin target 17. Ağır işleri iki platformda aynı anda yapma: emülatör 2 çekirdek/1536 MB; Gradle 2 işçi/2 GB, paralellik kapalı kullanıldı.

```sh
export JAVA_HOME=/Users/almano/Library/Java/pomosprint-qa/zulu17.62.17-ca-jdk17.0.17-macosx_aarch64/zulu-17.jdk/Contents/Home
export GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false'
```

VS Code: **PomoSprint (kayıtlı hızlı yerel test, Android)**. Android debug yerel HTTP config'i release ağına taşınmaz. İş bitince gerekiyorsa `adb -s emulator-5554 emu kill` ve `android/` içinde `./gradlew --stop`. Mevcut kullanıcının fiziksel cihazını bu komutlara hedef yapma.

### 9.4 Hazır test hesapları

| Grup | Hesaplar | Yerel parola |
|---|---|---|
| iOS beşli | `e2e-sim-qa1-1005qa@pomosprint.local` … `qa5-1005qa` | `SimE2e-Yerel2026` |
| Android beşli | `e2e-sim-qa1-1005android@pomosprint.local` … `qa5-1005android` | `SimE2e-Yerel2026` |

Bu şifre yalnızca disposable **yerel** fikstür şifresidir; canlı kullanıcı şifresi değildir. Her grupta başlangıç sonucu 6 seans, 225 dakika, 51 puan, 120 kum; her hesap iki karşılıklı arkadaş. QA1 iki seansla 75 dakika/17 puan/40 kum, QA2–5 sırasıyla 25/50/25/50 dakika. QA1'in arkadaşları QA2 ve QA5. DB'de iki yönlü ilişki satırları nedeniyle rapordaki `friend_rows=4`, dört ayrı arkadaş anlamına gelmez. Elle denemeler sonrası bu sayılar değişebilir.

141 geçici T1/T2 hesabı temizlendi; bu iki beşli grup korunmuştur. Takip senaryoları ayrıca kendi yerel hesaplarını açtı. Temizleme yaparken yalnızca belirli kendi run ID hesaplarını sil; toplu canlı veya bütün yerel kullanıcılara DELETE uygulama.

## 10. Test senaryoları, komutlar ve son sonuçlar

### En son kanıtlanmış sonuç

| Kontrol | Sonuç / kapsam |
|---|---|
| `flutter analyze` | No issues found |
| Tüm birim/widget | **1068 geçti**, 5 isteğe bağlı screenshot testi atlandı |
| New York DST rapor/gün | **93 geçti** |
| Yeni timezone/arkadaş widget | 9 geçti; iptal, ağ hatası, çift işlem, 6 boyut |
| Odaklı eski arkadaş/güvenlik/uyumluluk | 66 geçti |
| iOS ve Android `l` UI | İkisi geçti; native IANA, gerçek yerel DB/cache, arkadaş yönetimi, onay ledger |
| Son iOS `c` | Tek 25 dk, 5 puan, 20 kum; DB/sonuç/rapor/lig geçti |
| Android ARM64 release | `app-release.apk` 29.5 MB derlendi |
| iOS release | İmzasız `Runner.app` 30.4 MB derlendi; cihaza yükleme/archive değil |
| Önceki JS/Edge ağsız | 35 geçti |
| Önceki server seans / kategori | 101 / 164 geçti |
| Önceki avatar / sosyal güvenlik / gerçek yerel mail | 26 / 26 / 9 geçti |
| Önceki lig SQL / istemci çapraz | 98 / 23 geçti; oda ve satın alma yarışları da sınandı |
| Parite | QA helper kaldırılınca kayıtlı baseline ile 13/13 ve 27 avatar; helper açıkken beklenen ek fonksiyon |

9, 66 ve 93 sayıları 1068'in üstüne eklenip bağımsız toplam gibi sunulmamalı; bazı testler ayrıca tekrar çalıştırılmış alt kümelerdir. Eski tüm paket 1059'dan yeni 1068'e çıktı.

### Tekrar çalıştırma

```sh
flutter analyze
flutter test --concurrency=2
TZ=America/New_York flutter test \
  test/reports_correctness_test.dart test/reports_findings_test.dart \
  test/stats_calculator_test.dart test/study_day_test.dart --concurrency=2
```

ARB değişirse önce `flutter gen-l10n`. JS/Edge/site betiği değişirse `scripts/` içinde `npm test`. Site ortak parçası değişirse `python3 landing/tools/sync_partials.py --check`.

UI E2E normal main + yerel gerçek API kullanır. Yeni run ID seç; eski run ID tekrar kayıt çakışmasına neden olabilir. Sim runner varsayılanı başka iPhone 16 Pro UDID'sidir; **Plus için SIM_UDID açık ver**.

```sh
QUICK_TIMER=true QUICK_TIMER_SAVE=true \
SIM_UDID=BEA55019-D5C3-420F-90F2-0B0CBD5690CF \
E2E_RUN_ID=yeni_kosu E2E_SHOT_DIR=/tmp/pomosprint-ios-qa \
tool/local_supabase/e2e/sim/run_sim_e2e.sh f l

QUICK_TIMER=true QUICK_TIMER_SAVE=true \
E2E_RUN_ID=yeni_android_kosu E2E_SHOT_DIR=/tmp/pomosprint-android-qa \
tool/local_supabase/e2e/sim/run_android_e2e.sh f l
```

| Harf / test | Senaryo |
|---|---|
| `a_register_onboarding` | UI kayıt, zorunlu onay, yaş/hedef/kategori/görünürlük/hedef |
| `b_timer_layout` | Gerçek ekran boyutunda timer, kategori, süre/başlat/gezinti |
| `c_session_points` | Önceden süresi dolmuş normal kayıt restore; tek seans/puan/kum/rapor/lig |
| `d_friends_visibility` | Arkadaş isteği/kabul ve görünürlük |
| `e_settings_delete` | Profil/yasal/yerel hesap silme |
| `f_quick_multi_account` | 5 hesap, UI BAŞLAT, gerçek 5/10 sn bekleme, 25/50 dk kayıt, sosyal/rapor/lig |
| `g_review_flows` | Reset ve diğer gözden geçirme UI akışları |
| `h_offline_lifecycle` | Gerçek yerel Kong kesintisi, disk outbox, retry, hesap izolasyonu |
| `i_pause_resume` | Tek duraklatma, restore/devam, UUID korunması, 50 dk/9 puan/20 kum |
| `j_android_notifications` | Android gerçek sistem izni/bildirim/alarm teslimi/iptal |
| `k_ios_native` | iOS provisional bildirim ve gerçek ActivityKit kanal çağrıları |
| `l_followup_management` | Saat dilimi, DST/cache/DB, cancel/remove/block/unblock UI, onay idempotency |

`h` için `E2E_ALLOW_OUTAGE=true` gerekir; sadece yerel API geçici durdurulur ve finally açılır. Native `j` yalnızca Android, `k` yalnızca iOS'ta çalıştır. Cihaz screenshot'ı macOS proje klasörüne yazamıyorsa `/tmp` E2E_SHOT_DIR kullanıp sonradan proje içine kopyala. Test hostu `e2e_host.py` loopback'tedir; Android erişimi ayrı host define ile ayarlanır.

Diğer gerçek yerel kontroller:

```sh
python3 tool/local_supabase/e2e/auth_mail_test.py
python3 tool/local_supabase/e2e/social_safety_test.py
```

`tool/local_supabase/e2e/t1_seans_puan`, `t2_onboarding_categories`, `t3_visibility`, `t4_league_avatar` alan testlerini içerir. Öneri zinciri `proposed_chain_check.sh` ayrı kopya DB'de dryrun/uygula/down kontrolüdür; ana kopyada körlemesine migration çalıştırma. `scripts/security_regression_test.js` **gerçek/canlı hesap açıp silebilir**; yerel testlerle karıştırma, çalıştırma koşulu `AGENTS.md`'de ayrı.

### Kanıt dosyaları

- [En yeni okunabilir rapor](analiz/QA_FOLLOWUP_2026-10-05.txt) / [JSON](analiz/QA_FOLLOWUP_2026-10-05.json).
- [Önceki kapsamlı okunabilir rapor](analiz/QA_FULL_2026-10-05.txt) / [JSON](analiz/QA_FULL_2026-10-05.json).
- Son loglar `analiz/qa_followup_evidence_20261005/`; önceki `analiz/qa_evidence_20261005/`.
- Son ekranlar `analiz/ekranlar/20261005_followup/ios`, `android`, `session`; önceki `20261005_full_qa/`.
- Son elle test görüntüsü `analiz/ekranlar/20261005_followup/ios/elle-test-hazir.png`.
- `build/e2e_sim/` ve `/tmp` geçici, silinebilir/üstüne yazılabilir; kalıcı rapor linki için `analiz/` kanıtlarını tercih et.

### Doğrulanmayanı doğrulanmış sayma

- Gerçek Google/Apple login yerel provider kapalı olduğundan denenmedi. Ledger'ın gerçek yerel RPC'yle yazılması provider auth'un testi değildir.
- New York IANA yanıtı testte kontrollü MethodChannel taklidi; iki platformun gerçek native kanalı Istanbul döndürdü. Sistem ayarından fiziksel seyahat/saat dilimi değişimi yapılmadı.
- iOS provisional bildirim teslimi, tam banner/ses/kilit ekranı kullanıcı onayıyla eşdeğer değildir.
- `c` restore fikstürü gerçek OS kill değildir; ayrı iOS süreç ölümü testi bunu tamamlıyor. Android için aynı OS kill kanıtı yok.
- Unsigned iOS release / APK derlemesi, mağaza imzası/dağıtım/gerçek cihaz başarısı değildir. Test APK'sı keystore yoksa debug imzalı olabilir; mağaza pipeline ayrı.
- Yerel Mailpit başarıları üretim SMTP, DNS, deliverability veya Auth panel redirect ayarlarının testi değildir.

## 11. Site, e-posta ve mağaza bağlantıları

`landing/` statik; build yok. Ortak `_partials/` değişince `sync_partials.py` ile sayfalara işler. `_headers` CSP, token sayfalarında no-store/no-referrer. Fontlar ve GSAP self-hosted. CSS/JS değişince ilgili `?v=` cache sürümü artırılır. `.assetsignore` dışındaki dosyalar yayınlanabilir; sır veya test verisi landing içine konmaz.

Dokunulmaz URL'ler: `/terms`, `/privacy`, `/kvkk`, `/hesap-silme`, `/destek`, `/reset-password`, `/confirmed`, `/unsubscribe` ve EN eşleri. Mağaza kayıtları, eski mobil sürümler, Auth allowlist ve gönderilmiş e-postalar bunlara bağlı.

Auth mail şablonları `supabase/auth-email-templates/`; reset token_hash ve TR/EN bağlantıları burada belgeli. Bunların repo kopyası Auth paneline uygulanmış sayılmaz.

E-posta: Auth mail ve pazarlama hoş geldin/bülteni ayrı akışlar. `send-welcome-email`, `marketing_subscribers` insert trigger'ı, Resend ve gönderici kimliğine bağlı. `unsubscribe` token-only POST; bülten `send_newsletter.js`, önce dry-run. 5 Ekim `supabase/auth-email-templates/README.md` kaydı: Resend doğrulandı, Auth maili Delivered, DMARC `p=none` mevcut; welcome repo sürümü v9 yayında. `MAIL_SENDER_NAME` / `MAIL_SENDER_ADDRESS` kullanıcı tercihiyle tanımlı değil, bu yüzden welcome 500 döner/satır sahiplenmez ve bülten gönderilmez. Auth kayıt/reset maili bu kimlik şartından etkilenmez. Kullanıcı kimlik bilgisi verince secret tanımı yeterli; yeniden deploy gerekmez. Bunlar kayıtlı durumdur; yeni e-posta işinde gerçek panel/secret/deploy durumu ayrıca kontrol edilmeli, bu devir turunda canlı kontrol edilmedi.

Mağaza pipeline `scripts/build_release.sh android|ios|all`: obfuscation, split-debug-info, Sentry sembolleri, keystore/provisioning. QA'daki sade release derlemeleri bu yayın pipeline'ını tamamlamadı; deploy/publish otomatik yapılmadı.

## 12. Kalan işler ve sonraki oturum için önerilen sıra

### Kullanıcı fiziksel cihazı verdiğinde

1. Gerçek iOS ve Android'de tam bildirim izni (kabul/ret/ayar dönüşü), ses/banner, arka plan bitiş ve iptal.
2. Fiziksel kilit ekranı/Live Activity/Dynamic Island ve Android ongoing sayaç davranışı.
3. Google ve Apple gerçek sağlayıcı girişi, yeni/mevcut hesap, onboarding yönlendirmesi, onay ledger'ı, çıkış/Apple yetki iptali.
4. Sistem saat dilimini değiştirip resume sync, günlük/haftalık/aylık rapor ve sınır günlerinin tutarlılığı.
5. İki cihaz/iki hesapla sosyal görünürlük gecikmesi, arkadaş yönetimi, offline retry ve normal gerçek süreli seans. Yerel hızlandırılmış test sonucu bu son normal süre testi yerine geçmez.

### Ayrı yayın/operasyon işleri

- Canlı migration geçmişi/baseline düzeni; kök CLI push güvenli hâle getirilmeden kullanılmamalı.
- Veri sorumlusu ve gönderici kimlik bilgileri gerçek kullanıcı/kurum bilgisiyle doldurulmalı; AI uydurmaz.
- Welcome sender kimliği hâlâ bekliyor; repo kaydına göre v9 deploy, Resend/Auth SMTP ve DMARC tamamlandı. Yeni operasyon işinde panel/secret/DNS ve redirect durumunu yeniden doğrula; eski rapordaki “Resend/DMARC yok” ifadesini güncel açık iş sayma.
- `delete-account` Edge Function deploy + Apple token revoke secrets/capability; SQL fallback çalışıyor fakat Apple revoke farklı adım.
- Waitlist consent payload, site deploy ve sonra `proposed/19` B; sıralama bozulursa yeni kayıtlar durabilir.
- Gerçek report formunu `submit_user_report`'a bağlama; şu an mailto.
- Lig eşikleri 1/1/1 mi 3/25/25 mi, ilk oda 7–14 gün, 24 saat pencere ve unverified cap ürün kararları; test bulgusu diye otomatik değiştirilmez.
- Google plugin 7.x göçü, güvenli token depolama, servis katmanını bölme, eski çeviri yollarını ARB'ye taşıma ayrı teknik işler.
- Git çalışma ağacının gözden geçirilip commit edilmesi ve repo hijyeni; mevcut işi silerek “temiz” hâle getirme.

Kullanıcı sadece doküman istediğinde bu işleri kendiliğinden deploy ederek yapma. “Her şey hazır mı?” sorusuna test kapsamı ve bekleyen yayın maddeleriyle yanıt ver.

## 13. Devir belgesini güncel tutma

Bir özellik/sözleşme/test değiştiğinde ilgili `AGENTS.md` bölümünü ve bu belgedeki güncel durumu birlikte güncelle. En az şunları kaydet:

- Tarih, kullanıcı hedefi, değişen dosyalar ve sonuç davranışı.
- Yerel / canlı / fiziksel kapsamı; gerçekten çalıştırılan test ve kanıt yolu.
- Geçti/kaldı/atlandı/denenmedi ayrımı ve kalan belirsizlik.
- Yeni RPC/kolon/hata metni, migration/down/dryrun durumu.
- Hangi önceki bulgu tamamlandı; eski raporu silmek yerine takip kaydıyla ilişkilendir.
- Elle test için kalan hesap/cihaz/helper ve normal moda geri dönüş komutu.

Yeni sohbete verilebilecek kısa başlangıç talimatı: **“Önce kökteki PROJE_DEVIR.md ve AGENTS.md dosyalarını oku; git status ile commit edilmemiş işleri koru. Son kapsam QA_FOLLOWUP_2026-10-05'tir. Yalnızca yerel Supabase ile test et; fiziksel cihaz testleri ayrıca bekliyor.”**


## 14. Git / bilgisayarlar arası devir

5 Ekim 2026'da mevcut `KrAlmano/PomoSprint` GitHub deposunun gizli olduğu doğrulandı. Yerel `main` dalı uzaktaki `origin/main`'e göre 57 commit ilerideydi; bu 57 commit ile o tarihteki 132 dosya/README/QA değişikliği, sır kalıbı taraması ve `.env` dışlama kontrolünden sonra `8a98dab` commit'iyle `origin/main`'e gönderildi. Push sonrasında yerel `main` ve özel GitHub `main` aynı commit'e geldi, çalışma ağacı temizdi.

Bu bölümün eski 5 Ekim çalışma ağacı listesini saklamıyorum; artık güncel gerçek değil. Sonraki oturumda yine `git status --short` ve `git log -5 --oneline` çalıştır. Yeni doküman değişiklikleri veya başka makinelerdeki commit'ler bu commit'ten sonra gelmiş olabilir. `.env`, `scripts/.env` ve `.claude/settings.local.json` ignore edilir; başka makineye taşıma için secrets olmayan kaynakları push etmek yeterli, yerel secret/settings dosyaları ayrıca güvenli şekilde kurulur. GitHub deposunu başka bilgisayarda clone et ve yeni sohbetten önce `PROJE_DEVIR.md` ile `AGENTS.md`'yi aç.
