# PomoSprint: Mağaza ve KVKK Uyum Kontrol Listesi (3 Ekim 2026)

> **Bu bir hukuki görüş değildir.** Aşağıdaki maddeler mağaza yönergelerinin ve mevzuatın bilinen hâline göre hazırlanmış bir çalışma listesidir. Kesin karar için App Store Connect / Play Console'daki güncel metinlere ve bir avukata başvurun.
>
> **İşaretler:** ✅ repoda yapıldı · 👤 kullanıcı yapacak · ⚠️ kontrol edilmeli
>
> **Kapsam:** Bu dal yalnızca `landing/` ve `analiz/` altını değiştirdi. Uygulamadaki (a) kilit ekranı bildirimi / exact alarm, (b) Live Activity, (c) kayıt onayları, (d) bildir / gizle, (e) görünen ad filtresi değişiklikleri **paralel dallarda**. Onlarla ilgili maddeler "paralel dal" diye işaretlendi; birleştirmeden sonra uygulama koduyla tek tek doğrulanmalı.
>
> **Kaynaklar:** `lib/` (main dalı, 3 Ekim), canlı DB'den salt okuma (`pg_get_functiondef('delete_own_account')`, `pg_constraint` FK listesi, `information_schema.columns`), `android/`, `ios/`, yerel Flutter 3.44.8 kurulumu.

---

## 0. Yayın öncesi engelleyiciler (önce bunlar)

| # | Madde | Durum |
|---|---|---|
| 1 | **Siteyi deploy et.** Yeni sayfalar canlı olmadan Play Console'a hesap silme URL'si girilemez. `python3 landing/tools/sync_partials.py --check` → `cd landing && wrangler deploy` | 👤 |
| 2 | **Veri sorumlusunun kimliği eksik.** Gizlilik Politikası §1 ve KVKK Aydınlatma Metni §1 yalnızca e-posta veriyor; Aydınlatma Tebliği veri sorumlusunun kimliğini (ad-soyad veya unvan, adres) ister. Bilgi uydurulmadı; mevcut metin birebir kullanıldı. Kimliği iki dilde iki sayfaya da ekle | ⚠️ 👤 |
| 3 | **Yurt dışı aktarım.** Sayfalar aktarımların "KVKK m.9'a uygun ve uygun güvencelerle" yapıldığını söylüyor. Bu ifade, standart sözleşmeler imzalanıp Kurul'a bildirilene kadar fiilen doğru değil (bkz. §4.3) | 👤 ⚠️ |
| 4 | **Apple ile girişte hesap silme token iptali yok.** `delete_own_account` yalnızca `auth.users` satırını siliyor (canlı tanım okundu); Apple REST API `revoke` çağrısı yok (bkz. §2.3) | ⚠️ |
| 5 | **İnceleme için demo hesap(lar)** (App Store + Play "Uygulama erişimi"); e-posta onayı tamamlanmış olmalı | 👤 |
| 6 | **Exact alarm beyanı** (Play) ve kalıcı bildirimin foreground service olup olmadığı (bkz. §3.3) | 👤 ⚠️ |
| 7 | **`unsubscribe` Edge Function canlıda eski sürüm** (AGENTS §10, P1). Bülten çıkış bağlantısı, ticari ileti onayının geri alınma yolu olarak sayfalarda anlatılıyor; repodaki sürümü `--no-verify-jwt` ile deploy et | 👤 |

---

## 1. Bu dalda yayına hazırlanan sayfalar ✅

| TR | EN | Amaç |
|---|---|---|
| `https://pomosprint.app/kvkk` | `https://pomosprint.app/en/kvkk` | KVKK m.10 Aydınlatma Metni (yeni) |
| `https://pomosprint.app/hesap-silme` | `https://pomosprint.app/en/delete-account` | Google Play hesap silme URL'si (yeni) |
| `https://pomosprint.app/privacy` | `https://pomosprint.app/en/privacy` | Güncellendi: bildirim ve kilit ekranı, exact alarm, onay kayıtları, bildir/gizle, destek e-postasının Google'da barındırılması, KVKK ve hesap silme bağlantıları |
| `https://pomosprint.app/terms` | `https://pomosprint.app/en/terms` | Güncellendi: asgari yaş 13, 18 altı veli/vasi bilgisi, kullanıcı içeriği kuralları, sıfır tolerans, bildir/gizle, KVKK bağlantısı |

- ✅ Footer (TR "Destek", EN "Legal") sütunlarına KVKK ve Hesap Silme bağlantıları; ana sayfadaki bekleme listesi formunun altına KVKK bağlantısı.
- ✅ `sitemap.xml`: 4 yeni URL, TR↔EN `hreflang` çiftleri; sayfalarda `canonical`, `hreflang` (tr, en, x-default=TR) ve OG etiketleri mevcut sayfalarla aynı düzende.
- ✅ Yeni CSS (`.prose h3`, `.prose ol`, `.prose .data-table`): dar ekranda tablo satırları karta dönüşür (`data-label`). `style.css?v=20261003c` (head partial + reset-password, confirmed, unsubscribe).
- ✅ Site yalnızca açık temalı (`color-scheme: light`); yeni sayfalar mevcut yasal sayfalarla aynı.
- ⚠️ Uygulamadaki `_openLegalUrl(page)` `https://pomosprint.app/` + (`en/` ) + `page` kurar. Kayıt ekranı KVKK için `kvkk` kullanırsa iki dilde de doğru sayfa açılır; hesap silme sayfası farklı adlı (`hesap-silme` / `en/delete-account`), uygulamadan açılacaksa ayrı eşleme gerekir.
- 👤 `AGENTS.md` §8 "Dokunulmaz URL'ler" listesine bu 4 adres eklenmeli (bu dal `AGENTS.md`'ye dokunmadı).

---

## 2. App Store

### 2.1 App Privacy (Uygulama Gizliliği) yanıtları

**Takip (tracking): Hayır.** Reklam SDK'sı, IDFA, veri broker'ı yok (`pubspec.yaml`: supabase_flutter, sentry_flutter, google_sign_in, sign_in_with_apple, flutter_local_notifications, shared_preferences, connectivity_plus, url_launcher). App Tracking Transparency istemi gerekmez. ✅

| Apple veri türü | Toplanıyor | Kullanıcıya bağlı | Amaç | Not |
|---|---|---|---|---|
| Contact Info → Email Address | Evet | Evet | App Functionality; bülten onayı verenler için ayrıca Developer's Advertising or Marketing | Apple gizli aktarım adresi de olabilir |
| Contact Info → Name | Evet | Evet | App Functionality | Görünen ad; Google/Apple'ın ilettiği ad |
| Identifiers → User ID | Evet | Evet | App Functionality | Hesap UUID'si, arkadaşlık kodu |
| User Content → Other User Content | Evet | Evet | App Functionality | Kategori (ders) adları arkadaşlara görünebiliyor |
| Other Data → Other Data Types | Evet | Evet | App Functionality | Çalışma seansları, puan/kum/seri/lig, doğum yılı, çalışma durumu, günlük hedef, onay kayıtları. ⚠️ Seans/puan için "Gameplay Content" da savunulabilir; birini seçip tutarlı kal |
| Diagnostics → Crash Data | Evet | Hayır | App Functionality | Sentry; `sendDefaultPii=false`, `setUser` yok, e-postalar maskeleniyor (`lib/app/error_reporting.dart`) |
| Diagnostics → Performance Data | Evet | Hayır | App Functionality | `tracesSampleRate = 0.2` |
| Diagnostics → Other Diagnostic Data | Evet | Hayır | App Functionality | Cihaz modeli, OS sürümü, breadcrumb |

**Toplanmıyor:** Location, Contacts, Health & Fitness, Financial Info, Sensitive Info, Browsing/Search History, Purchases, Photos/Videos, Audio, Device ID (IDFA), Advertising Data, Customer Support (bildirim e-postası kullanıcının kendi e-posta uygulamasından gider, uygulama toplamaz).

- ✅ Cihazda kalanlar App Privacy'ye girmez: gizlenen kullanıcılar listesi, bildirim/dil/tema tercihi, Live Activity, kilit ekranı bildirimi (paralel dal: sunucuya veri gitmediği doğrulanmalı).
- ⚠️ Sentry iOS SDK'sı anonim bir kurulum kimliği üretir; hesapla ilişkilendirilmediği sürece "bağlı değil" yanıtı tutarlı. İleride `Sentry.configureScope(user: ...)` eklenirse yanıt "bağlı" olmalı.
- ⚠️ Supabase/Cloudflare sunucu erişim kayıtları IP içerir; konum çıkarmak için kullanılmadığından ayrı bir Apple kategorisine karşılık gelmez. Kullanım değişirse yeniden değerlendir.

### 2.2 PrivacyInfo.xcprivacy

- ⚠️ `ios/Runner` altında uygulama düzeyinde `PrivacyInfo.xcprivacy` **yok** (`find ios -name '*.xcprivacy'` boş). Flutter ve eklentilerin güncel sürümleri kendi manifestlerini getirir; yine de uygulama hedefine bir manifest önerilir:
  - `NSPrivacyTracking = false`, `NSPrivacyTrackingDomains` boş,
  - `NSPrivacyCollectedDataTypes`: §2.1 tablosuyla aynı,
  - `NSPrivacyAccessedAPITypes`: uygulamanın kendi Swift kodu `UserDefaults` kullanıyorsa `CA92.1`.
- ⚠️ Paralel dal (b): Live Activity widget extension'ı App Group üzerinden `UserDefaults` paylaşıyorsa extension hedefine ayrı bir manifest ve `1C8F.1` gerekebilir.
- 👤 Archive → Organizer → "Generate Privacy Report" ile birleşik raporu kontrol et.

### 2.3 Sign in with Apple (Yönerge 4.8 ve 5.1.1(v))

- ✅ iOS giriş ekranında Apple ile giriş var; `Runner.entitlements` `com.apple.developer.applesignin` içeriyor (Google girişi olduğu için gerekli).
- 👤 Apple Developer'da capability, Services ID ve Key; Supabase Apple provider (Client ID `com.pomosprint.app`), AGENTS §10 P1.
- ⚠️ **Token iptali:** Apple, Apple ile girişi destekleyen uygulamaların hesap silinirken Sign in with Apple REST API ile kullanıcı token'larını iptal etmesini bekler. Canlı `delete_own_account` yalnızca `delete from auth.users where id = auth.uid()` yapıyor. Seçenekler: (1) silmeden önce Apple `revoke` çağıran bir Edge Function (Apple client secret JWT ve kullanıcının refresh token'ı gerekir); (2) en azından inceleme notunda durumu açıkla. Hesap silme sayfası kullanıcıya Apple Kimliği ayarlarından bağlantıyı kaldırabileceğini söylüyor ✅.

### 2.4 Uygulama içi hesap silme (5.1.1(v))

- ✅ Yol: sağ üstteki profil karakteri → **Profil ve Ayarlar** → en altta kırmızı **Hesabımı Sil** → onay diyaloğunda **Hesabımı Sil** (`profile_screen.dart`, `l10n.deleteAccount`: TR "Hesabımı Sil", EN "Delete Account"; ekran başlığı `profile_title`: "Profil ve Ayarlar" / "Profile & Settings"). Site metinleri bu etiketlere göre düzeltildi (eskiden "Profil → Hesabımı Sil").
- ✅ Gerçek silme, devre dışı bırakma değil. Canlı FK'lar (3 Ekim okundu): `auth.users` silinince `profiles`, `study_sessions`, `friendships` (iki yön), `marketing_subscribers` CASCADE; `profiles` üzerinden `categories`, `league_memberships`, `activity_feed`, `avatar_unlocks` CASCADE. `auth.audit_log_entries` boş (Auth kayıtları Supabase log altyapısında).
- ✅ `waitlist` yalnızca e-posta tutuyor, hesaba bağlı değil; hesap silmeyle silinmediği sayfalarda açıkça yazıldı.
- ⚠️ "En geç 30 gün" ifadesi (mevcut gizlilik politikasıyla aynı) yedekleri de kapsıyor. Supabase planındaki yedek / PITR saklama süresinin 30 günü aşmadığını Dashboard → Database → Backups'tan doğrula.

### 2.5 Yönerge 1.2: kullanıcı içeriği

Kullanıcı içeriği: görünen ad ve (Sosyal Listede Görün açıkken) arkadaşlara görünen kategori adları. Sohbet yok.

| Apple beklentisi | Durum |
|---|---|
| Uygunsuz içerik filtresi | Paralel dal (e): görünen ad filtresi. ⚠️ Google/Apple girişinde sağlayıcıdan gelen ad (`handle_new_user` trigger'ı filtresiz yazar) ve kategori adları da filtreden geçiyor mu? |
| İçerik/kullanıcı bildirme | Paralel dal (d): "Kullanıcıyı bildir" → `destek@pomosprint.app` e-postası |
| Kötüye kullanan kullanıcıyı engelleme | Paralel dal (d): "Kullanıcıyı gizle" (yalnızca cihazda). ⚠️ Gizlenen kullanıcının arkadaşlık isteği, "Şu an çalışanlar" ve sıralama satırları da gizleniyor mu? Yalnızca bir listede gizleniyorsa inceleme ekibi "block" saymayabilir |
| Yayımlanmış iletişim bilgisi | ✅ Site, Şartlar, Gizlilik Politikası: `destek@pomosprint.app` |
| Sıfır tolerans içeren kullanım şartları ve kabulü | ✅ Şartlar §3–4 güncellendi. Paralel dal (c): kayıtta zorunlu kabul. ⚠️ Google/Apple ile ilk girişte de kabul alınıyor mu? |
| Bildirimlere zamanında yanıt | 👤 Şartlar "en kısa sürede" diyor. Bir iç hedef belirle (ör. 24 saat), inceleme notunda yaz, destek kutusunu takip et |

- 👤 Moderasyon prosedürü: uygunsuz adı değiştirmek için SQL Editor'de `profiles.name` güncellemesi; hesabı askıya almak için Supabase Auth'ta kullanıcıyı yasaklama (Admin API `ban_duration`). Bir sayfalık iç not hazırla.

### 2.6 App Review notu şablonu (App Store Connect → App Review Information → Notes)

Kimlik bilgilerini **repoya yazma**, yalnızca App Store Connect'teki alanlara gir.

```text
PomoSprint is a gamified Pomodoro focus timer (25- or 50-minute sessions).

DEMO ACCOUNT (email sign-in, already verified)
  Email:    <DEMO_EMAIL_1>
  Password: <entered in the Sign-In Information fields>
  This account already has completed sessions, so Reports, League and
  Ranking screens show data. A second demo account (<DEMO_EMAIL_2>,
  friend code <FRIEND_CODE_2>) can be used to test friend requests.
  You can also create a new account; a confirmation email is sent.

LOCK SCREEN / LIVE ACTIVITY
  1. On the Pomo tab choose 25 or 50 min and tap START.
     Notification permission is requested on the first start.
  2. Lock the device: the remaining time is shown as a Live Activity on
     the lock screen (and in the Dynamic Island on supported iPhones).
  3. The end-of-session notification is scheduled locally. Points are
     awarded only when a full session completes, so you do not need to
     wait for the timer to finish to review the app.
  All of this is generated on the device; no push server is used.

SOCIAL FEATURES / USER-GENERATED CONTENT
  - The only user-generated content is the display name and the category
    (subject) names visible to friends. There is no chat.
  - Display names pass through an automatic profanity filter.
  - Report a user: <WHERE IN THE APP>. Opens an email to
    destek@pomosprint.app; reports are reviewed within <TARGET TIME>.
  - Hide a user: <WHERE IN THE APP>. Hidden users are no longer shown.
  - Terms of Use with zero tolerance for objectionable content are
    accepted at sign-up: https://pomosprint.app/en/terms

ACCOUNT DELETION
  Tap the profile character (top right) > Profile & Settings > scroll to
  the bottom > Delete Account > confirm. Web: https://pomosprint.app/en/delete-account

OTHER
  No in-app purchases, no ads, no tracking. Sign in with Apple is offered
  alongside Google Sign-In.
  Contact: destek@pomosprint.app
```

- ⚠️ Şablondaki `<WHERE IN THE APP>` alanlarını paralel dal (d) birleştikten sonra gerçek ekran adıyla doldur.

### 2.7 Yaş derecelendirmesi

- 👤 App Store Connect'teki güncel yaş derecelendirme anketini dürüstçe doldur: şiddet, cinsellik, kumar, tıbbi içerik yok; kullanıcı içeriği var (görünen ad); mesajlaşma yok; sınırsız web erişimi yok.
- ⚠️ Öneri: Şartlardaki asgari yaş 13 olduğundan, hesaplanan derece daha düşük çıkarsa tutarlılık için daha yüksek bir derece seçmeyi (ör. 13+) değerlendir. Anketteki seçenekleri ve "daha yüksek derece seçme" imkânını App Store Connect'te kontrol et.

### 2.8 Export compliance

- ✅ `ios/Runner/Info.plist`: `ITSAppUsesNonExemptEncryption = false` (yalnızca HTTPS/TLS ve işletim sisteminin şifrelemesi).
- 👤 App Store Connect'te aynı yanıt.

### 2.9 Gerekli URL'ler (deploy'dan sonra gir)

| Alan | URL |
|---|---|
| Privacy Policy URL (TR) | `https://pomosprint.app/privacy` |
| Privacy Policy URL (EN yerelleştirme) | `https://pomosprint.app/en/privacy` |
| Support URL | `https://pomosprint.app/faq` (sayfanın sonunda destek e-postası var) ⚠️ ayrı bir destek sayfası daha net olur |
| Marketing URL (isteğe bağlı) | `https://pomosprint.app/` |
| User Privacy Choices URL (isteğe bağlı) | `https://pomosprint.app/hesap-silme` (EN: `/en/delete-account`) |

### 2.10 Bildirim ve Live Activity teknik notları (paralel dal b)

- ✅ `Runner.entitlements`: time-sensitive bildirim (seans bitişi bunun için uygun bir kullanım).
- ⚠️ `Info.plist` → `NSSupportsLiveActivities = YES`; Live Activity iOS 16.1+ ister, uygulamanın en düşük sürümü iOS 15.0 → kullanım `@available` ile korunmalı.
- ⚠️ Uzak push ile güncellenmiyorsa `aps-environment` gerekmez; ActivityKit push token'ı sunucuya gönderiliyorsa gizlilik metni "sunucuya veri gitmez" ifadesiyle çelişir.

---

## 3. Google Play

### 3.1 Data safety yanıtları

**Genel:** Veri aktarımda şifrelenir: **Evet** (TLS). Kullanıcı veri silme isteyebilir: **Evet** (uygulama içi + `https://pomosprint.app/hesap-silme`). Bağımsız güvenlik incelemesi: Hayır. Hizmet sağlayıcılara (Supabase, Sentry, Resend, Cloudflare) aktarım Google tanımında "paylaşım" sayılmaz → **Paylaşılan veri: Yok.**

| Play veri türü | Toplanıyor | Zorunlu / isteğe bağlı | Amaç |
|---|---|---|---|
| Kişisel bilgiler → E-posta adresi | Evet | Zorunlu | Hesap yönetimi, Uygulama işlevi; bülten onayı verenler için Geliştirici iletişimi |
| Kişisel bilgiler → Ad | Evet | Zorunlu | Uygulama işlevi, Hesap yönetimi |
| Kişisel bilgiler → Kullanıcı kimlikleri | Evet | Zorunlu | Hesap yönetimi, Uygulama işlevi |
| Kişisel bilgiler → Diğer bilgiler | Evet | Zorunlu | Uygulama işlevi (doğum yılı: 13 yaş sınırı; çalışma durumu: kategori önerisi) |
| Uygulama etkinliği → Diğer kullanıcı içeriği | Evet | Zorunlu | Uygulama işlevi (kategori adları) |
| Uygulama etkinliği → Diğer işlemler | Evet | Zorunlu | Uygulama işlevi (seanslar, puan, seri, lig) ⚠️ "Uygulama etkileşimleri" de seçilebilir |
| Uygulama bilgileri ve performans → Kilitlenme günlükleri | Evet | Zorunlu | Analiz |
| Uygulama bilgileri ve performans → Teşhis | Evet | Zorunlu | Analiz |
| Cihaz veya diğer kimlikler | ⚠️ | — | Sentry Android SDK'sı rastgele bir kurulum kimliği üretir; Google'ın tanımına girebilir, beyan etmek güvenli taraftır |

**Toplanmıyor:** Konum, Kişiler, Fotoğraf/Video, Ses, Dosyalar, Takvim, Mesajlar, Finans, Sağlık, Web geçmişi, Reklam kimliği.

- ⚠️ Görevde doğum yılı ve kullanıcı segmenti "isteğe bağlı" denmişti; kod ikisini de **zorunlu** tutuyor (`post_auth_onboarding_screen.dart`: `_isUnderMinimumAge`, segment seçilmeden ilerlenemiyor). Site metinleri ve bu tablo koda göre yazıldı; ürün kararı değişirse bu satırlar da değişmeli.

### 3.2 Hesap silme URL'si

- ✅ `/hesap-silme` ve `/en/delete-account`: uygulama adı ve paket adı, uygulama içi 4 adım, uygulamaya erişemeyenler için kayıtlı adresten "Hesap silme talebi" e-postası (30 gün), silinen veriler, tutulan veriler ve süreleri, hesabı silmeden veri silme (bülten çıkış bağlantısı, "Veri silme talebi").
- ⚠️ Sayfalarda geliştirici adı "PomoSprint" yazıyor; Play mağaza kaydındaki geliştirici adı farklıysa iki sayfada da düzelt (Google uygulama **veya** geliştirici adının görünmesini istiyor; uygulama adı zaten belirgin).
- 👤 Play Console → Uygulama içeriği → Veri güvenliği → "Hesap silme URL'si": `https://pomosprint.app/hesap-silme` (sayfa EN sürüme bağlantı veriyor).

### 3.3 Exact alarm beyanı (paralel dal a)

- ⚠️ Main dalında manifest bilinçli olarak exact alarm kullanmıyor (`inexactAllowWhileIdle`); paralel dal `USE_EXACT_ALARM` (API 33+) ve `SCHEDULE_EXACT_ALARM` (eski sürümler, `maxSdkVersion="32"` olmalı) ekliyor. Site metinleri bu duruma göre yazıldı.
- 👤 Play Console'da exact alarm izni beyanı istenirse gerekçe taslağı:

  ```text
  PomoSprint is a Pomodoro focus timer. Its core function is a countdown
  timer that the user starts (25 or 50 minutes). USE_EXACT_ALARM is used
  only to show the end-of-session alert at the exact moment the user's
  timer finishes, including when the device is idle or locked. The app
  sets no other alarms and collects no data through this permission.
  ```

- ⚠️ Google `USE_EXACT_ALARM`'ı yalnızca temel işlevi alarm/zamanlayıcı veya takvim olan uygulamalara izin veriyor. Kabul edilmezse yalnızca `SCHEDULE_EXACT_ALARM`'a geçilmeli (Android 14+ varsayılan kapalı; kullanıcı "Alarmlar ve hatırlatıcılar" ayarından açar) ve izin yoksa inexact zamanlamaya düşülmeli. O durumda site metnindeki izin adları da güncellenmeli.
- ⚠️ Kilit ekranındaki kalıcı geri sayım bir **foreground service** ile yapılıyorsa `FOREGROUND_SERVICE` + uygun tip izni ve Play Console "Ön plan hizmeti" beyanı (video dahil) gerekir. Yalnızca `ongoing` bildirim + geri sayan kronometre ise gerekmez.

### 3.4 Bildirim izni

- ✅ `POST_NOTIFICATIONS` manifestte; izin açılışta değil ilk BAŞLAT'ta isteniyor (AGENTS §4.1). Play'de ayrı beyan yok.
- ⚠️ İzin reddedilirse kilit ekranı geri sayımı da görünmez; uygulamada bunun açıklandığını kontrol et.

### 3.5 Hedef API

- ✅ Bu makinedeki Flutter 3.44.8 `FlutterExtension.kt`: `compileSdkVersion = 36`, `targetSdkVersion = 36`, `minSdkVersion = 24`, `ndkVersion = 28.2.13676358`. `android/app/build.gradle.kts` bunları `flutter.*` üzerinden kullanıyor.
- ⚠️ Play'in güncel hedef API şartını Play Console uyarılarından teyit et.

### 3.6 16 KB sayfa boyutu

- ⚠️ Android 15+ hedefleyen yeni uygulama ve güncellemelerin 16 KB sayfa boyutunu desteklemesi gerekiyor.
- ✅ NDK r28 varsayılan olarak 16 KB hizalı derler; Flutter 3.44 engine'i destekliyor.
- ⚠️ Native kütüphane getiren eklenti: `sentry_flutter` (Android NDK entegrasyonu). Doğrulama: Play Console → App bundle explorer'daki 16 KB uyumluluk bilgisi ya da `zipalign -c -P 16 -v 4 app-release.apk`. Bu makinede Android SDK yok; **doğrulanmadı**.

### 3.7 İçerik derecelendirmesi (IARC)

- 👤 Anket: kategori "Yardımcı program, Üretkenlik, İletişim veya Diğer". Şiddet, cinsellik, kumar, uyuşturucu yok. Kullanıcılar etkileşime giriyor mu: **Evet** (arkadaşlık, sıralamada görünen ad; sohbet yok). Kullanıcının kişisel bilgisi paylaşılıyor mu: görünen ad diğer kullanıcılara görünüyor. Dijital satın alma: Hayır. Konum paylaşımı: Hayır.
- ⚠️ Beklenen sonuç düşük bir derece ve "Kullanıcılar Etkileşimde Bulunur" ibaresi; kesin sonuç yanıtlara bağlı.

### 3.8 Hedef kitle ve içerik

- 👤 Hedef yaş grupları: 13-15, 16-17, 18+. **13 yaş altı seçilmemeli** (Aileler politikası devreye girer, Şartlarla çelişir).
- ⚠️ "Uygulama istemeden çocukların ilgisini çekebilir mi?" sorusu: sevimli karakterler nedeniyle Google ek inceleme isteyebilir. Mağaza görsellerinde ve açıklamada çocuklara yönelik dil kullanma.
- ✅ Reklam yok → "Uygulamanızda reklam var mı?" Hayır.
- ✅ Kullanıcı içeriği politikası (Play UGC): şartların kabulü, uygulama içi bildirme ve engelleme. §2.5'teki ⚠️ maddeler Play için de geçerli.

### 3.9 Uygulama erişimi (inceleme)

- 👤 Play Console → Uygulama içeriği → Uygulama erişimi: "Bazı işlevler kısıtlı" → demo hesap e-postası/şifresi ve §2.6'daki talimatların kısa hâli.
- 👤 Google ile giriş: Play App Signing anahtarının SHA-1/SHA-256 parmak izleri Google Cloud OAuth Android istemcisine eklenmeli; yoksa Play'den indirilen sürümde Google girişi çalışmaz.

---

## 4. KVKK ve Türkiye mevzuatı

### 4.1 Aydınlatma

- ✅ `/kvkk` (+ `/en/kvkk`): veri sorumlusu (privacy §1'deki ifade birebir), 7 veri kategorisi tablosu (kimlik, iletişim, müşteri işlem, başlangıç bilgileri, işlem güvenliği, hukuki işlem, pazarlama), amaçlar, hukuki sebepler (m.5/2-c, ç, f; açık rıza yalnızca ticari elektronik ileti), yalnızca cihazda kalan veriler, toplama yöntemi, yurt içi/yurt dışı aktarım, saklama süreleri (privacy ile aynı), m.11 hakları, başvuru usulü (kayıtlı e-posta, 30 gün, kural olarak ücretsiz, m.14 Kurul'a şikâyet süreleri).
- ✅ Bağlantılar: footer, Gizlilik Politikası (§1, §3, §9, §14), Şartlar (giriş), hesap silme sayfası, bekleme listesi formu.
- ⚠️ Veri sorumlusu kimliği (bkz. §0/2).
- ⚠️ Paralel dal (c): kayıt ekranında aydınlatma teyidi ile bülten onayı **ayrı** kutular olmalı; bülten kutusu önceden işaretli olmamalı; aydınlatma kutusunda "rıza veriyorum" dili kullanılmamalı ("okudum" dili). Şartlar kabulü de ayrı.
- ⚠️ Doğum yılı onboarding'de, kayıttan **sonra** soruluyor. 18 yaş altı kullanıcının kayıtta verdiği bülten onayı (açık rıza) için ehliyet tartışmalı olabilir; 18 altında bülten onayını sonradan geçersiz saymayı ya da istememeyi avukatla değerlendir.

### 4.2 VERBİS

- ⚠️ Kurul'un muafiyet kararlarına göre yurt içinde yerleşik, yıllık çalışan sayısı 50'den az **ve** yıllık mali bilanço toplamı Kurul'un belirlediği eşiğin altında olan, ana faaliyeti özel nitelikli kişisel veri işlemek olmayan veri sorumluları kayıttan muaf. Güncel eşiği ve geliştiricinin (gerçek kişi / şirket) durumunu Kurul'un güncel kararından teyit et.
- ⚠️ Muaf olunsa da aydınlatma, veri güvenliği, başvurulara yanıt ve ihlal bildirimi yükümlülükleri sürer.
- ⚠️ Kişisel Veri Saklama ve İmha Politikası, VERBİS'e kayıt yükümlüsü olanlar için zorunlu; muafsan zorunlu olmayabilir.

### 4.3 Yurt dışına aktarım (KVKK m.9)

- ⚠️ Alıcılar: Supabase (veriler AB'de, Stockholm; yine de Türkiye dışı), Sentry, Resend, Cloudflare (site + e-posta yönlendirme), Google (Google ile Giriş, destek kutusu Gmail, Google Fonts), Apple (Apple ile Giriş), jsDelivr.
- 👤 Yeterlilik kararı yoksa (⚠️ güncel durumu teyit et) uygun güvence olarak Kurul'un ilan ettiği **standart sözleşme** her alıcıyla, metin değiştirilmeden imzalanmalı ve imzadan sonra **5 iş günü içinde Kurul'a bildirilmeli**.
- ⚠️ Büyük sağlayıcılar Türk standart sözleşmesini imzalamayabilir. Alternatifler (bağlayıcı şirket kuralları, taahhütname + Kurul izni, m.9'daki arızi aktarım istisnaları) sınırlı; avukatla değerlendir. Bu yapılana kadar sitedeki "m.9'a uygun olarak" ifadesi fiilen doğru değil; gerekirse ifadeyi yumuşat.

### 4.4 Ticari elektronik ileti ve İYS (6563 sayılı Kanun)

- ✅ Bülten onayı isteğe bağlı ve ayrı (paralel dal c); onay zamanı ve tercihi hesapla saklanıyor (`marketing_consent`, paralel dal). Her bültende çıkış bağlantısı ve `List-Unsubscribe` var (`scripts/send_newsletter.js`).
- ⚠️ İYS'ye (İleti Yönetim Sistemi) hizmet sağlayıcı kaydı ve onayların İYS'ye yüklenmesi yükümlülüğünü ve olası muafiyetleri güncel yönetmelikten teyit et. Şu an onaylar İYS'ye aktarılmıyor. 👤
- ⚠️ Sitedeki bekleme listesi formunda ayrı bir onay kutusu yok; "Yayınlanınca haber ver" lansman duyurusu ticari ileti sayılabilir. Formun açık bir onay beyanı içermesini değerlendir.
- ⚠️ Canlı `unsubscribe` fonksiyonu eski sürüm (bkz. §0/7). Sayfalarda bülten çıkış bağlantısının yalnızca bülten aboneliğini sildiği yazıldı; bekleme listesinden çıkış e-postayla istenebilir (repodaki yeni sürüm bekleme listesini de siliyor, canlıda doğrulanamadı).

### 4.5 Diğer

- 👤 Veri ihlali prosedürü: ihlal öğrenildiğinde Kurul'a en kısa sürede (Kurul kararıyla 72 saat) bildirim ve ilgili kişilere bildirim. Bir sayfalık iç prosedür hazırla.
- ⚠️ 5651 sayılı Kanun: kullanıcı içeriği barındırma nedeniyle "yer sağlayıcı" sayılıp sayılmadığı ve trafik bilgisi saklama yükümlülüğü avukatla değerlendirilmeli. Sitede böyle bir saklama süresi **yazılmadı** (uydurulmadı).
- ⚠️ Sentry'nin veri bölgesi (ABD / AB): DSN alanından anlaşılır; `.env` okunmadığı için doğrulanmadı. AB bölgesi seçiliyse metinler yine doğru (ABD dahil "farklı ülkeler" deniyor).
- 👤 **Avukat incelemesi:** KVKK Aydınlatma Metni, Gizlilik Politikası, Kullanım Şartları, aktarım mekanizması, İYS ve 5651 maddeleri.

---

## 5. Metin ↔ uygulama tutarlılık kontrolü (paralel dallar birleşince)

| Site metninde | Uygulamada kontrol et |
|---|---|
| "Kullanıcıyı bildir" / "Report user", "Kullanıcıyı gizle" / "Hide user" | ARB etiketleri birebir aynı mı? Farklıysa sitede (4 sayfa: privacy, terms × 2 dil) düzelt |
| Bildirme e-posta uygulamasında hazır bir e-posta açar, kullanıcı gönderir | `mailto:` mı, uygulama içi gönderim mi? E-posta uygulaması yoksa ne oluyor? |
| Gizleme yalnızca cihazda, gizlenen kullanıcıya bildirilmez | Liste `SharedPreferences`'ta mı, sunucuya gidiyor mu? |
| Görünen adlar otomatik filtreden geçer | Sağlayıcı adı, profil düzenleme ve onboarding yolları |
| Kayıtta 3 onay (2 zorunlu, 1 isteğe bağlı); sürüm ve zaman hesapla saklanır, hesapla silinir | `terms_version`, `privacy_version`, `terms_accepted_at`, `marketing_consent` `profiles`'ta mı (CASCADE ile silinir)? Sürüm değeri sayfalardaki "Son güncelleme: 3 Ekim 2026" ile eşleşiyor mu? |
| Android: kilit ekranında kalıcı geri sayım; USE_EXACT_ALARM (13+), SCHEDULE_EXACT_ALARM (daha eski) | Manifest, `maxSdkVersion`, foreground service var mı? |
| iPhone: Live Activity kilit ekranı + Dynamic Island, cihazda üretilir | Push token sunucuya gidiyor mu? |
| Kilit ekranında kategori ve kalan süre görünebilir | Bildirim / Live Activity içeriği |
| Hesap silme: Profil ve Ayarlar → Hesabımı Sil | Paralel dallar bu etiketi değiştirdiyse 6 sayfayı güncelle |

---

## 6. Bu dalın doğrulaması

- ✅ `python3 landing/tools/sync_partials.py`: ilk koşu 13 sayfayı güncelledi; ikinci koşu ve `--check` değişiklik bulmadı (çıkış 0, idempotent).
- ✅ html5lib 1.1 ile 16 sayfa ayrıştırıldı + etiket dengesi, yinelenen `id`, 381 iç bağlantı ve çapa hedefi, `hreflang` karşılıklılığı, `canonical`, satır içi `<script>` / `style=""` / `<style>` / `on*=` kontrolü: **sorun yok**. Tek bulgu her sayfada 2 kez çıkan `expected-named-entity`: ortak head partial'daki Google Fonts URL'sinde `&family=` / `&display=` (önceden de vardı; güncel HTML standardında hata değil, html5lib 1.1 eski kuralı uyguluyor).
- ✅ Doğrulayıcı, bilinçli bozulmuş kopyada kırık bağlantıyı, olmayan çapayı, kapanmamış etiketi ve satır içi stili yakaladı.
- ✅ Tarayıcıda 1280 px ve 375 px: tablo masaüstünde 4 sütun, telefonda kart düzeni; yatay taşma yok (`scrollWidth = 375`); Türkçe büyük harf etiketleri doğru ("İŞLENEN VERİLER").
- ✅ `sitemap.xml` XML olarak ayrıştı (12 URL).
- 👤 Deploy **yapılmadı**.
