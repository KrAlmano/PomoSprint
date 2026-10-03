# PomoSprint: Mağaza ve KVKK Uyum Kontrol Listesi (3 Ekim 2026, akşam güncellemesi)

> **Bu bir hukuki görüş değildir.** Maddeler mağaza yönergelerinin, Supabase dokümanının ve mevzuatın bilinen hâline göre hazırlanmış bir çalışma listesidir. "Gerekir", "yeterli" gibi ifadeler kesin hukuki sonuç değil, kontrol edilecek bir varsayımdır. Kesin karar için App Store Connect / Play Console'daki güncel metinlere ve bir avukata başvurun.
>
> **İşaretler:** ✅ repoda yapıldı · 👤 kullanıcı yapacak · ⚖️ hukukçuyla karar · ⚠️ kontrol edilmeli
>
> **Öncelik:** **P0** yayından (ilk gönderimden) önce şart · **P1** yayından önce yapılmalı · **P2** ilk haftalarda · **P3** fırsat buldukça. Süreler tek kişinin kesintisiz çalışmasıyla kabaca tahmindir; bekleme süreleri (DNS, inceleme, 14 günlük test) ayrıca yazıldı.
>
> **Bu güncelleme:** 3 Ekim analizindeki (`blindspot`) sahibi **kullanıcı** ya da **hukuk** olan tüm maddeler (ACC-01, ACC-03, ACC-04, PLAY-01, PLAY-02, PLAY-03, PLAY-06, PLAY-07, PLAY-10, PLAY-19, KVKK-07, KVKK-15, AS-09, AS-17), "eksik mercekler"deki kullanıcı işleri (yedekleme, Auth panel ayarları, Sentry bölgesi, Resend, bekleme listesi kötüye kullanımı, mağaza metadata'sı) ve `site-eposta` dalında yapılanlar (AS-13, KVKK-19, KVKK-11, PLAY-11, bekleme listesi onay kutusu). Sabahki ilk sürümün hâlâ geçerli tabloları §3-§6'da güncellenerek korundu.
>
> **Kaynaklar:** `lib/`, `android/`, `ios/`, `landing/` (main + bu dal), canlı DB'den yalnızca metaveri (`information_schema`, `pg_policies`, `pg_constraint`), canlı Edge Function listesi ve kodu (`unsubscribe` v9, `send-welcome-email` v7), herkese açık `GET /auth/v1/settings` (3 Ekim akşamı: `apple: false`, `google: true`, `email: true`, `mailer_autoconfirm: false`), Supabase dokümanı (Sign in with Apple, Custom SMTP, Password security, Database Backups; 3 Ekim'de okundu).

---

## 0. Önce bunlar (sıralı)

| # | Madde | ID | Öncelik | Süre | Durum |
|---|---|---|---|---|---|
| 1 | Veri sorumlusunun kimliğini sitedeki yer tutuculara yaz | KVKK-15 | P0 | 30 dk (+ gerçek kişi / şirket kararı) | 👤 ⚖️ |
| 2 | Siteyi deploy et (bu dal: destek sayfaları, yerel yazı tipleri, onay kutusu, token'lı çıkış sayfası) | AS-13, KVKK-19, PLAY-11 | P0 | 15 dk | ✅ 3 Ekim akşamı yayında |
| 3 | Supabase'de Apple sağlayıcısını aç | ACC-01 | **P0 (engelleyici)** | 30-60 dk | 👤 |
| 4 | Auth e-postaları için özel SMTP (Resend) | ACC-03 | P0 | 1-2 saat + DNS yayılımı | 👤 |
| 5 | Play geliştirici hesap türünü kontrol et; kişiselse kapalı testi hemen başlat | PLAY-01 | P0 (takvim) | 1 saat + **14 gün** | 👤 |
| 6 | Android release derlemesi ve gerçek cihaz testi | PLAY-02 | P0 | 0,5-1 gün | 👤 |
| 7 | Play App Signing SHA-1'leri ve OAuth izin ekranı | PLAY-03 | P0 | 1 saat (ilk AAB'den sonra) | 👤 |
| 8 | Dağıtım ülkeleri ve cihazlar kararı | AS-09 | P0 (karar) | 30 dk + hukuk görüşü | 👤 ⚖️ |
| 9 | Demo hesaplar, inceleme notları, Play "Uygulama erişimi", IARC | ACC-04 | P0 | 2-3 saat | 👤 |
| 10 | App Privacy, Data safety, yaş derecelendirmesi formları | PLAY-07 | P0 | 1-2 saat | 👤 |
| 11 | Exact alarm beyanı (Play) | PLAY-06 | P0 | 20 dk | 👤 |
| 12 | Apple gizli aktarım (relay) için gönderici alan adları | PLAY-10 | P1 (Apple açılınca) | 30 dk | 👤 |
| 13 | `send-welcome-email` secret'ları ve deploy | KVKK-11 | P1 | 15 dk | 👤 |
| 14 | Yurt dışı aktarım: KVKK standart sözleşmeleri ve bildirim | KVKK-07 | P1 | günler-haftalar | ⚖️ 👤 |
| 15 | Canlı DB yedeği (Free planda otomatik yedek yok) | eksik mercek | P1 | 30 dk ilk kurulum | 👤 |
| 16 | Auth panel ayarları (şifre kuralı, redirect URL'leri, CAPTCHA, rate limit) | eksik mercek | P1 | 45 dk | 👤 |
| 17 | Sentry veri bölgesi, IP saklama, saklama süresi | eksik mercek, KVKK-07 | P1 | 20 dk | 👤 |
| 18 | Upload keystore'u yedekle | PLAY-19 | P1 | 20 dk | 👤 |
| 19 | Mağaza adı ve görsellerde "Pomodoro" markası | AS-17 | P2 | 15 dk | 👤 ⚖️ |
| 20 | `proposed/19` (bekleme listesi onay kaydı) ve İYS kararı | 6563 | P2 | 1 saat + hukuk | 👤 ⚖️ |

Kod tarafında açık kalan ve bu listeyle bağlantılı maddeler (başka dallar): ACC-02 (hesap silmede Apple token iptali), AS-01 (Premium görünürlüğü), ACC-03'ün kod kısmı (SMTP hata metinleri), PLAY-10'un kod kısmı (Android'de Apple hesabı bilgisi), KVKK-09/KVKK-10 (onay geri alma ve ispat kaydı, `proposed/14`).

---

## 1. Kullanıcı ve hukuk maddeleri: adım adım

### 1.1 KVKK-15 · Veri sorumlusunun kimliği (P0 · 30 dk · ⚖️ 👤)

**Neden:** Gizlilik Politikası ve KVKK Aydınlatma Metni veri sorumlusunu yalnızca "PomoSprint'i işleten geliştirici" diye tanımlıyordu. Aydınlatma yükümlülüğü ve Play User Data politikası kimlik ve iletişim bilgisi istiyor. Bilgi **uydurulmadı**; yerine açıkça işaretli yer tutucu kondu.

**Nerede:** `landing/privacy.html`, `landing/kvkk.html`, `landing/en/privacy.html`, `landing/en/kvkk.html` §1 (`<mark data-fill-in="KVKK-15">`).

**Adımlar**
1. Karar: uygulamayı gerçek kişi olarak mı, şirket olarak mı yayınlayacaksın? (Mağaza hesabı türüyle aynı olmalı; bkz. PLAY-01.)
2. Gerçek kişi: ad-soyad ve tebligat adresi (varsa KEP adresi). Şirket: unvan, MERSİS numarası ve adres. Hangisinin yeterli olduğunu hukukçuna teyit ettir.
3. Dört sayfada iki `<span data-fill-in="KVKK-15">…</span>` öğesindeki geçici ifadeyi gerçek bilgiyle değiştir (etiketi ve önündeki `<!-- KVKK-15 … -->` yorumunu da kaldır). Canlı sitede görünür "[DOLDURULACAK]" metni kalmasın diye geçici olarak nötr bir ifade kondu.
4. Aynı bilgiyi şuralara da yaz: `scripts/.env` → `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS`; Supabase Edge secret'ları (bkz. 1.13); App Store Connect ve Play Console'daki geliştirici adı/adresi.
5. `landing/hesap-silme.html` ve `landing/en/delete-account.html` girişinde "geliştirici: PomoSprint" yazıyor; Play kaydındaki geliştirici adı farklıysa iki sayfada da düzelt (PLAY-11: ad mağazayla birebir olmalı).
6. Metin değiştiği için gerekirse "Son güncelleme" tarihini ve uygulamadaki `kLegalDocumentsVersion`'ı birlikte güncelle (`landing/README.md` → Yasal sayfalar).

**Doğrulama:** `grep -rn 'data-fill-in' landing/` boş dönmeli; `python3 landing/tools/sync_partials.py --check` çıkış 0.

### 1.2 ACC-01 · Supabase'de Apple sağlayıcısı (P0, engelleyici · 30-60 dk · 👤)

**Durum (3 Ekim akşamı, `GET /auth/v1/settings`):** `apple: false`. iOS release derlemesinde "Apple ile Giriş" düğmesi görünüyor (`login_screen.dart`, yalnızca iOS ve release). Sağlayıcı kapalıyken düğme hata verir; Google girişi sunan uygulamada eşdeğer bir giriş seçeneği beklendiği için (Yönerge 4.8) bu durumda **derleme gönderilmemeli**.

**Supabase dokümanından doğrulandı (Sign in with Apple → Flutter):** iOS'taki native akış (`sign_in_with_apple` + `signInWithIdToken`) için Apple Developer'da App ID'de Sign in with Apple yeteneğinin açık olması ve bu App ID'nin (bundle id) Supabase Apple sağlayıcısında **Client IDs** alanına yazılması yeterli. Services ID, `.p8` imzalama anahtarı ve 6 ayda bir yenilenen secret yalnızca OAuth (web, Android) akışı için gerekiyor; doküman "Native-only implementations don't require secret key rotation" diyor. ACC-02'deki hesap silmede token iptali yapılacaksa `.p8` anahtarı (Key ID, Team ID `AQGX8BJMYJ`) o iş için ayrıca gerekecek.

**Adımlar**
1. developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → `com.pomosprint.app` → Capabilities: **Sign In with Apple** işaretli mi? Değilse aç, kaydet (provisioning profilleri yeniden üretilir).
2. Supabase Dashboard → Authentication → Sign In / Providers → **Apple** → Enable.
3. **Client IDs:** `com.pomosprint.app`. "Secret Key (for OAuth)" alanı yalnızca OAuth (web/Android) akışı içindir; native iOS akışı için boş bırakılabilir. Panel boş alanla kaydetmene izin vermezse dokümandaki "Configuration (web OAuth)" adımlarını (Services ID, `.p8`, 6 ayda bir yenileme) uygula ve yenileme tarihini takvime yaz.
4. Kaydet. Terminalde: `curl -s -H "apikey: <anon key>" https://eoosnyakvxmifmexpgxa.supabase.co/auth/v1/settings` → `"apple": true`.
5. TestFlight'ta gerçek iPhone'da dene: ilk giriş, çıkış ve tekrar giriş, "E-postamı Gizle" seçeneği, hesap silme. Apple ad bilgisini yalnızca ilk girişte verir; ilk girişte adın profile geldiğini kontrol et.
6. Bundan sonra PLAY-10 (1.12) adımları.

### 1.3 ACC-03 · Auth e-postaları için özel SMTP (P0 · 1-2 saat + DNS · 👤)

**Neden (Supabase dokümanı, Custom SMTP):** Özel SMTP yoksa Supabase'in varsayılan sunucusu yalnızca proje ekibindeki adreslere gönderir; diğer adresler "Email address not authorized" hatası alır ve saatlik limit çok düşüktür. Canlıda `mailer_autoconfirm: false`, yani her e-posta kaydı onay e-postası bekliyor. SMTP ayarı API'den okunamadığı için mevcut durum panelden kontrol edilmeli.

**Adımlar**
1. resend.com → Domains: `mail.pomosprint.app` doğrulanmış mı (SPF, DKIM yeşil)? Değilse Cloudflare DNS'e Resend'in verdiği kayıtları ekle; doğrulanmasını bekle (dakikalar-saatler). (AGENTS §10 P1 ile aynı iş.)
2. DMARC yoksa Cloudflare DNS → `_dmarc` TXT, `v=DMARC1; p=none; rua=mailto:destek@pomosprint.app` ile başla (AGENTS §10 P2).
3. Supabase Dashboard → Authentication → Emails → **SMTP Settings** → Enable custom SMTP:
   - Host `smtp.resend.com`, port `465` (SSL), kullanıcı `resend`, şifre: Resend API anahtarı (yalnızca panele yaz, repoya ya da sohbete değil),
   - Gönderen: `noreply@mail.pomosprint.app`, ad `PomoSprint`.
4. Authentication → Rate Limits: doküman özel SMTP açılınca e-posta limitinin saatte 30 ile başladığını söylüyor; lansman beklentine göre yükselt.
5. Authentication → Emails → Templates: **Confirm signup**, **Reset password**, **Change email address** şablonlarını Türkçe/İngilizce, kısa ve pazarlama içermeden düzenle; Reset password bağlantısı `token_hash` biçiminde olmalı (AGENTS §8, `reset-password` sözleşmesi).
6. Authentication → URL Configuration: Site URL `https://pomosprint.app`; Redirect URLs: `https://pomosprint.app/confirmed`, `https://pomosprint.app/reset-password` ve `.html`'li hâlleri; eski `io.supabase.pomosprint://` girdisini sil (AGENTS §10).
7. Ekip dışı bir adresle (ör. ikinci bir Gmail) uygulamadan kayıt ol, onay e-postası gelsin; şifre sıfırlamayı uçtan uca dene; spam klasörüne düşüp düşmediğine bak.
8. İsteğe bağlı (doküman önerisi): Auth e-postalarını pazarlama e-postalarından ayrı bir gönderici alt alan adından gönder (ör. `auth.pomosprint.app`); bir alanın itibarı düşerse diğeri etkilenmez.

**Kod tarafı (başka dal):** `service_errors.dart` "email address not authorized" ve "error sending confirmation email" metinlerini ayrı koda eşlemeli.

### 1.4 PLAY-01 · Kişisel Play hesabında 12 test kullanıcısıyla 14 gün kapalı test (P0 takvim · 1 saat + 14 gün · 👤)

**Neden:** Play Console kuralına göre 13 Kasım 2023'ten sonra açılan **kişisel** geliştirici hesaplarında üretim erişimi istemeden önce en az 12 test kullanıcısının kapalı teste 14 gün kesintisiz kayıtlı kalması gerekiyor. Kuruluş hesabında bu şart yok. Repoda Play'e yüklenmiş bir sürüm izi yok (`pubspec.yaml` `1.0.0+1`).

**Adımlar**
1. Play Console → Ayarlar → Geliştirici hesabı → Hesap ayrıntıları: hesap türü kişisel mi kuruluş mu? Açılış tarihi?
2. Kişiselse: PLAY-02'deki ilk AAB'yi **hemen** Test → Kapalı test kanalına yükle; ayrılan olabileceği için 15+ Google hesabı ekle (e-posta listesi ya da Google Grubu).
3. Test kullanıcılarına katılım bağlantısını gönder; 14 günün bitiş tarihini takvime yaz. Bu süre PLAY-02 ve PLAY-03 testleriyle aynı anda kullanılabilir.
4. Üretim erişimi başvurusundaki test sorularına (kaç kişi, ne geri bildirim aldın, ne düzelttin) not tut.

### 1.5 PLAY-02 · Android release derlemesi ve gerçek cihaz testi (P0 · 0,5-1 gün · 👤)

**Durum:** Bu makinede Android SDK yok (`android/local.properties`'teki yol mevcut değil), `build/` altında AAB/APK yok; AGENTS §4.1 "Android derlemesi doğrulanmadı". Kilit ekranı sayacı, `USE_EXACT_ALARM` ve R8 kaynak küçültmesi ilk kez release derlemesinde denenecek.

**Adımlar**
1. Android Studio'yu kur → SDK Manager: Android SDK Platform 36, Build-Tools, Platform-Tools, NDK 28.2. `flutter doctor` temiz olmalı.
2. `android/key.properties` ve upload keystore yerinde mi kontrol et (bkz. 1.18'deki yedek).
3. `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.
4. Play Console → Test → Dahili test'e yükle; Android 13, 14 ve mümkünse 15/16 cihazda (tablet varsa onu da) kur.
5. Denenecekler: ilk BAŞLAT'ta bildirim izni; kilitliyken ve uygulama arka plandayken seans bitişi bildirimi; kalıcı geri sayım bildirimi; cihaz yeniden başladıktan sonra bildirim; Google girişi (PLAY-03 bitmeden Play sürümünde çalışmayabilir); çevrimdışı seans ve bağlantı gelince gönderim; hesap silme.
6. Play Console → ön lansman raporu ve App bundle explorer'daki **16 KB sayfa boyutu** satırı.

### 1.6 PLAY-03 · Play App Signing SHA-1 ve OAuth izin ekranı (P0 · 1 saat · 👤)

**Neden:** Google girişi Android'de paket adı + imza SHA-1'iyle tanınır. Play App Signing anahtarı ilk AAB yüklenince Google tarafından üretilir; kayıtlı değilse Play'den kurulan sürümde Google girişi `ApiException 10` (DEVELOPER_ERROR) verir. OAuth izin ekranı "Testing" durumundaysa test listesinde olmayan herkes engellenir.

**Adımlar**
1. İlk AAB'den sonra Play Console → Test ve yayınla → Uygulama bütünlüğü → **Uygulama imzalama**: "Uygulama imzalama anahtarı sertifikası" ve "Yükleme anahtarı sertifikası"nın SHA-1 ve SHA-256 değerlerini kopyala.
2. Yükleme anahtarını yerelde de doğrula: `keytool -list -v -keystore android/app/pomosprint-upload-key.jks` (parolayı yalnızca terminale yaz).
3. Google Cloud Console → `722417205043` projesi → Google Auth Platform → Clients (eski adıyla APIs & Services → Credentials): paket adı `com.pomosprint.app` olan Android istemcisine **iki** SHA-1'i de ekle (gerekirse ikinci bir Android istemcisi aç).
4. Google Auth Platform → Audience (OAuth izin ekranı): uygulamayı **In production** durumuna al; uygulama adı, destek e-postası, gizlilik politikası (`https://pomosprint.app/privacy`), ana sayfa ve yetkili alan adı `pomosprint.app` dolu olsun.
5. Supabase → Authentication → Sign In / Providers → Google: web ve iOS client id'leri "Authorized Client IDs"te olmalı (iOS'ta "Skip nonce check" bilinçli açık, AGENTS §4.5).
6. Dahili testten kurulan sürümle Google girişini dene.

### 1.7 ACC-04 · Demo hesaplar, inceleme notları, IARC (P0 · 2-3 saat · 👤)

**Neden:** Giriş zorunlu ve e-posta onayı açık; yeni hesapta lig, arkadaş ve kum boş görünür. Release derlemede seans 25/50 dakika ve yalnızca tamamlanınca puan verilir; inceleme ekibi bunu beklemez. Yönerge 2.1(a) demo hesap bilgisi istiyor; Play "Uygulama erişimi" bölümü giriş bilgisi istiyor.

**Adımlar**
1. Ekip dışı iki e-posta adresiyle (ör. `pomosprint.review1@…`, `…review2@…`) uygulamadan iki hesap aç, e-postaları onayla, onboarding'i **yetişkin** doğum yılıyla bitir.
2. İki hesabı birbirine arkadaş ekle. Release ya da `--profile` derlemesiyle her hesapta birkaç gerçek seans tamamla (lig üyeliği, kum, seri, rapor verisi oluşsun).
3. Kimlik bilgilerini **repoya yazma**; parola yöneticisinde sakla.
4. App Store Connect → Sürüm → App Review Information: Sign-In Information alanlarına birinci hesabı yaz; Notes'a §3.6'daki şablonu doldurarak yapıştır.
5. Play Console → Uygulama içeriği → **Uygulama erişimi**: "Bazı işlevler kısıtlı" → aynı bilgiler ve kısa talimat.
6. İnceleme notuna ekle: hesap silmeyi lütfen ikinci hesapla ya da yeni bir hesapla denesinler (silinen demo hesap sonraki gönderimde olmaz). Her gönderimden önce iki hesabın hâlâ var ve onaylı olduğunu kontrol et.
7. Play Console → Uygulama içeriği → **İçerik derecelendirmesi (IARC)**: kullanıcılar etkileşime giriyor **evet** (arkadaşlık, sıralamada görünen ad; sohbet yok), kullanıcı içeriği evet (görünen ad, ders adları), dijital satın alma **hayır**, reklam **hayır**, konum paylaşımı hayır. Uygulama içeriği'ndeki Sağlık, Finans, Devlet, Haber beyanları: **yok**.

### 1.8 PLAY-07 · App Privacy, Data safety, yaş derecelendirmesi (P0 · 1-2 saat · 👤)

Ayrıntılı tablolar §3.1 (Apple) ve §4.1 (Play). Özet:

1. **App Store Connect → App Privacy:** hesapla bağlantılı: Email Address, Name, User ID, Other User Content (ders adları), Product Interaction (seans, puan, lig), Other Data Types (doğum yılı, çalışma durumu, onay kayıtları). Bağlantısız: Crash Data, Performance Data, Other Diagnostic Data, **Device ID** (Sentry'nin rastgele kurulum kimliği). İzleme (tracking) **yok**. Bülten onayı verenler için Email'de "Developer's Advertising or Marketing" amacı da işaretlenmeli.
2. **Play Console → Veri güvenliği:** Kişisel bilgiler (Ad, E-posta, Kullanıcı kimlikleri, Diğer bilgiler), Uygulama etkinliği, Uygulama bilgileri ve performans (Kilitlenme günlükleri, Teşhis), **Cihaz veya diğer kimlikler**; amaçlara "Geliştirici iletişimi" de eklenmeli; aktarımda şifreleme evet; silme isteği evet (`https://pomosprint.app/hesap-silme`).
3. ⚠️ `ios/Runner/PrivacyInfo.xcprivacy` şu an Email, Name, UserID, ProductInteraction, OtherDataTypes, CrashData, PerformanceData beyan ediyor; **Other User Content, Other Diagnostic Data ve Device ID yok**. App Store Connect yanıtları ile manifest aynı olmalı: manifesti güncelle (kod işi) ya da yanıtları gerekçesiyle daralt. Xcode → Archive → Organizer → "Generate Privacy Report" ile birleşik raporu kontrol et.
4. **Yaş derecelendirmesi:** kullanıcı etkileşimi ve kullanıcı içeriği soruları "evet"; Şartlar'daki asgari yaş 13 olduğu için en az 13+ derece hedefle. Sentry ve sosyal özellikler nedeniyle Kids kategorisi seçilmemeli.
5. ✅ Gizlilik Politikası'nın (TR/EN) Sentry maddesine rastgele kurulum kimliği eklendi (bu dal).

### 1.9 PLAY-06 · Exact alarm beyanı ve kilit ekranı sayacı (P0 · 20 dk · 👤)

**Durum (main):** `AndroidManifest.xml`'de `USE_EXACT_ALARM` ve `SCHEDULE_EXACT_ALARM` (`maxSdkVersion="32"`) var. Kalıcı geri sayım bildirimi foreground service **kullanmıyor** (`usesChronometer` + `chronometerCountDown` + `timeoutAfter`, AGENTS §4.1); FGS beyanı gerekmez. `res/raw/keep.xml` yalnızca `ic_stat_notification`'ı koruyor; şu an Dart'tan isimle çağrılan başka bir drawable yok.

**Adımlar**
1. Play Console → Uygulama içeriği → izin beyanları (exact alarm / hassas izin formu; adı Console'da değişebilir) → gerekçe olarak §4.3'teki metni kullan.
2. Mağaza açıklamasında zamanlayıcıyı uygulamanın **ana işlevi** olarak anlat (Play `USE_EXACT_ALARM`'ı alarm, zamanlayıcı ve takvim uygulamalarıyla sınırlıyor).
3. Beyan reddedilirse (kod işi): yalnızca `SCHEDULE_EXACT_ALARM` + izin yoksa inexact zamanlamaya düşen yedek yol; site metnindeki izin adları da güncellenmeli.
4. Yeni bildirim eylem ikonları eklenirse `keep.xml`'e eklenmeli (R8).

### 1.10 AS-09 · Dağıtım bölgesi ve reşit olmayanlar (P0 karar · 30 dk + ⚖️)

**Neden:** Uygulama 13-17 yaşı da hedefliyor (LGS segmenti), Declared Age Range / Play Age Signals entegrasyonu yok. App Store ve Play varsayılanı tüm ülkeler; Apple'da ayrıca Mac (Designed for iPad) ve Vision Pro. ABD'deki eyalet yaş yasalarının yürürlük tarihleri bu analizde doğrulanamadı. AB'de rızaya dayalı işlemede yaş eşiği ülkeye göre 13-16.

**Adımlar**
1. App Store Connect → Uygulama → **Pricing and Availability**: ilk sürümde yalnızca Türkiye'yi (ve bilinçli seçtiğin ülkeleri) işaretle. Aynı sayfada "iPhone and iPad Apps on Apple Silicon Macs" ve "Apple Vision Pro" kullanılabilirliğini test edilene kadar kapat.
2. Play Console → Test ve yayınla → Üretim → **Ülkeler / bölgeler**: aynı liste.
3. ABD'yi Declared Age Range / Play Age Signals işi bitene kadar açma (⚖️ güncel durumu hukukçuyla doğrula).
4. AB'de yayın planlıyorsan: App Store Connect → Business → **DSA trader status** ve Play Console → hesap ayrıntılarındaki tacir (trader) beyanı; GDPR m.27 temsilcisi ve m.8 yaş eşiği için hukuk görüşü.
5. ⚖️ 18 yaş altına ticari ileti (bülten) onay kutusunun gösterilip gösterilmeyeceğine karar ver; karar "gösterme" ise kod işi (onay kayıtta, yaş onboarding'de soruluyor).

### 1.11 KVKK-07 · Yurt dışına aktarım (P1 · günler-haftalar · ⚖️ 👤)

**Neden:** Supabase bölgesi `eu-north-1` (Stockholm); AB de KVKK açısından yurt dışı. Gerçek alıcılar: Supabase, Sentry (bölgesi doğrulanmadı), Resend, Cloudflare, Google ve Apple ile giriş, destek kutusu (Gmail). ✅ Google Fonts ve jsDelivr bu dalda listeden çıktı (KVKK-19, §2). 7499 sayılı Kanunla değişen KVKK m.9'a göre yeterlilik kararı yoksa Kurul'un ilan ettiği standart sözleşmenin imzalanması ve imzadan sonra 5 iş günü içinde Kurum'a bildirilmesi gerektiği değerlendiriliyor; GDPR SCC'lerinin bunun yerine geçmediği görüşü yaygın. Sözleşmelerin imzalanıp imzalanmadığı buradan doğrulanamıyor.

**Adımlar**
1. Alıcı listesini kesinleştir (yukarıdaki liste + Sentry bölgesi, 1.17).
2. Her sağlayıcının Türkiye için KVKK standart sözleşmesi (veri sorumlusundan veri işleyene modülü) sunup sunmadığını araştır; sunmayanlar için hukukçuyla alternatifleri (m.9'daki diğer yollar, arızi aktarım istisnaları) değerlendir.
3. İmzalanan her sözleşmeyi süresi içinde Kurum'a bildir (⚖️ süre ve usulü güncel mevzuattan teyit et).
4. Sonra metinleri güncelle: Gizlilik Politikası §9 ve KVKK Aydınlatma Metni "Aktarım" bölümü şu an aktarımların "KVKK'nın 9. maddesinde öngörülen usullere uygun" yapıldığını ve "AB Standart Sözleşme Hükümleri"ni anıyor. Bu ifadeler sözleşmeler imzalanana kadar fiilen doğru olmayabilir; metni hukukçunun onayladığı gerçek dayanağa göre (ör. "KVKK m.9 kapsamında standart sözleşmeye dayalı") yeniden yaz. Bu dal metni **bilerek değiştirmedi** (hukuki dayanak iddiası kullanıcı/hukukçu kararı).

### 1.12 PLAY-10 · Apple gizli aktarım adresine e-posta (P1, Apple açılınca · 30 dk · 👤)

**Neden:** "E-postamı Gizle" seçen kullanıcıların `@privaterelay.appleid.com` adresleri yalnızca Apple Developer'da kayıtlı gönderici alan adlarından/adreslerinden posta kabul eder. Göndericiler: Supabase Auth SMTP (`noreply@mail.pomosprint.app`), Resend (`noreply@mail.pomosprint.app`), destek (`destek@pomosprint.app`). Hesap silme sayfası bu kullanıcılara aktarım adresine doğrulama e-postası gönderebileceğimizi söylüyor; kayıt yapılmadan bu e-posta ulaşmaz.

**Adımlar**
1. developer.apple.com → Certificates, Identifiers & Profiles → **Services** → Sign in with Apple for Email Communication → Configure.
2. Alan adları: `pomosprint.app`, `mail.pomosprint.app`. E-posta adresleri: `noreply@mail.pomosprint.app`, `destek@pomosprint.app`.
3. Apple'ın SPF (ve DKIM) kontrolünün geçtiğini panelde doğrula; `destek@` Cloudflare Email Routing → Gmail üzerinden yanıtlanıyorsa yanıtların hangi adresten çıktığını kontrol et (Gmail'in "farklı adres olarak gönder" ayarı + SPF).
4. Apple ile açılmış bir test hesabına şifre sıfırlama e-postası gönderip ulaştığını dene.
5. Kod tarafı (başka dal): Android giriş ekranına "Apple ile kaydolduysan Şifremi Unuttum ile şifre belirle" bilgisi.

### 1.13 KVKK-11 · E-posta altbilgisi ve deploy (P1 · 15 dk · 👤)

✅ Kod bu dalda hazır (§2). Kalan kullanıcı işleri, **bu sırayla**:

1. Siteyi deploy et (yeni `unsubscribe` sayfası `?token=` bağlantılarını tanıyor; eski sayfa token'lı bağlantıda "Bağlantı eksik" der):
   ```sh
   python3 landing/tools/sync_partials.py --check
   cd landing && wrangler deploy
   curl -sI https://pomosprint.app/ | grep -i content-security-policy   # googleapis/jsdelivr geçmemeli
   curl -sI https://pomosprint.app/fonts/nunito-v32-latin.woff2 | head -1  # 200
   ```
2. Edge secret'ları (1.1'deki bilgiyle; uydurma değer yazma):
   ```sh
   supabase secrets set MAIL_SENDER_NAME="<ad-soyad ya da unvan>" MAIL_SENDER_ADDRESS="<adres>" --project-ref eoosnyakvxmifmexpgxa
   ```
3. Hoş geldin fonksiyonunu deploy et (secret'lar olmadan deploy edilirse e-posta **gönderilmez**, 500 döner):
   ```sh
   supabase functions deploy send-welcome-email --no-verify-jwt --project-ref eoosnyakvxmifmexpgxa
   ```
4. `unsubscribe`: canlı v9 token-only isteği zaten kabul ediyor; repodaki fark yalnızca yorum satırları. Deploy isteğe bağlı: `supabase functions deploy unsubscribe --no-verify-jwt --project-ref eoosnyakvxmifmexpgxa`.
5. `scripts/.env`'e `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` ekle (şablon `scripts/.env.example`); `node scripts/send_newsletter.js --dry-run` uyarısız çalışmalı.
6. Resend → Domains → `mail.pomosprint.app` → Configuration: **open tracking** ve **click tracking** kapalı olsun (kişiye özel izleme pikseli ve yönlendirilmiş bağlantı olmasın).
7. Kendi adresinle bülten onayı vererek kayıt ol: hoş geldin e-postasının altbilgisinde gönderen kimliği, destek adresi, Gizlilik/KVKK bağlantıları ve yalnızca `token=` taşıyan çıkış bağlantısı olmalı; Gmail'in "Abonelikten çık" düğmesi çalışmalı.

### 1.14 Yedekleme ve geri dönüş noktası (P1 · 30 dk ilk kurulum · 👤)

**Neden (Supabase dokümanı, Database Backups):** Günlük otomatik yedek yalnızca Pro ve üstünde (Pro: son 7 gün). Free planda doküman `supabase db dump` ile düzenli dışa aktarma ve site dışı yedek öneriyor. Organizasyon planı `free`; canlıya yazan SQL'i elle çalıştırıyorsun ve elde geri dönüş noktası yok. Yanlış bir migration puan, seri, kum ve lig verisini kalıcı bozabilir.

**Adımlar**
1. Supabase Dashboard → Project Settings → Database → Connection string (session pooler) — parolayı yalnızca kendi terminalinde kullan, repoya ve sohbete yazma.
2. Kendi makinende, repo dışında bir klasörde:
   ```sh
   supabase db dump --db-url "$DB_URL" -f pomosprint_schema_$(date +%F).sql
   supabase db dump --db-url "$DB_URL" --data-only -f pomosprint_data_$(date +%F).sql
   supabase db dump --db-url "$DB_URL" --role-only -f pomosprint_roles_$(date +%F).sql
   ```
3. Dosyaları şifreli bir yere (ör. şifreli disk imajı ya da parola yöneticisi eki) kopyala; içinde kullanıcı e-postaları var (KVKK: erişimi sınırla, eski yedekleri sil).
4. **Her canlı migration'dan önce** bu dump'ı al; haftalık bir takvim hatırlatıcısı kur.
5. Lansmandan önce Pro plana geçmeyi değerlendir (günlük yedek, PITR seçeneği, sızdırılmış şifre koruması). Free projelerin uzun süre hareketsiz kalınca duraklatılabildiğini panelde ve fiyat sayfasında kontrol et.
6. Bir kez geri yükleme provası yap: dump'ı yerel bir Postgres'e (`supabase start` ya da Homebrew) yükle.

### 1.15 Auth panel ayarları (P1 · 45 dk · 👤)

1. **Sızdırılmış şifre koruması:** Supabase dokümanına göre (Password security) "Leaked password protection is available on the Pro Plan and above". Free planda **açılamaz**; AGENTS §10'daki "aç" önerisi Pro'ya geçince geçerli. Advisor uyarısı Free'de kalır.
2. Free'de yapılabilecek: Authentication → Sign In / Providers → Email → en az 8 karakter ve karakter sınıfı şartı. Uygulamadaki `authErrWeakPassword` metni ve (varsa) kayıt ekranındaki ipucu bu kuralla aynı olmalı (ACC-19, kod).
3. **Redirect URLs ve Site URL:** 1.3 adım 6.
4. **CAPTCHA:** Authentication → Attack Protection → CAPTCHA (hCaptcha ya da Turnstile). Açarsan uygulama kayıt/giriş isteklerine captcha token'ı göndermeli; aksi hâlde girişler kırılır. Bu yüzden önce kod işi, sonra panel (P2).
5. **E-posta OTP / magic link:** kullanılmıyorsa kapat; `/auth/v1/signup` ve OTP uçları onay alanı olmadan hesap açabilir (eksik mercek: zorunlu şart kabulü sunucuda doğrulanmıyor; `proposed/14` ile birlikte değerlendir).
6. **Rate limits:** 1.3 adım 4; "Token refresh" ve "Sign up / sign in" limitlerini lansman trafiğine göre gözden geçir.

### 1.16 Bekleme listesi ve ticari ileti (P2 · 1 saat + ⚖️)

✅ Sitede ayrı ve önceden işaretsiz onay kutusu var; JS işaretlenmeden kaydetmiyor (§2). Canlı `waitlist` tablosunda yalnızca `id, email, created_at` var (3 Ekim metaveri), bu yüzden onay **sunucuda kaydedilmiyor** ve doğrudan REST çağrısı onaysız satır ekleyebiliyor.

1. `supabase/tests/proposed_19_waitlist_consent_token_dryrun.sql`'i SQL Editor'de çalıştır: her satır `true` olmalı (yerel taklitte 12/12 `true`).
2. `supabase/proposed/19_waitlist_consent_token.sql` → A bölümünü migration olarak çalıştır (geriye uyumlu; site yalnızca e-posta gönderse de çalışır).
3. Sonra (kod işi, ayrı dal) site isteği `{ email, marketing_consent: true, consent_text_version: "waitlist-2026-10-03" }` olacak; o deploy edildikten **sonra** B bölümü (onaysız anon INSERT'i kapatır). B'yi önce çalıştırırsan bekleme listesi kaydı tamamen durur.
4. Lansman e-postası: yalnızca `marketing_consent = true` satırlara, `waitlist.unsubscribe_token`'lı çıkış bağlantısıyla (unsubscribe fonksiyonu o token'ı da tanıyacak şekilde güncellenmeli, kod işi). ⚖️ Onay kutusundan **önceki** kayıtlara (marketing_consent NULL) lansman e-postası gönderilip gönderilmeyeceği hukuki karar.
5. ⚖️ İYS (İleti Yönetim Sistemi): hizmet sağlayıcı kaydı ve onayların İYS'ye yüklenmesi yükümlülüğünü ve olası istisnaları güncel yönetmelikten teyit et. Şu an onaylar İYS'ye aktarılmıyor.
6. Bot/kötüye kullanım: form yalnızca tuzak alan + süre kontrolüyle korunuyor; başkasının adresini yazmak mümkün. Turnstile ya da çift onay (onay bağlantılı e-posta) için backend gerekir (P3, AGENTS §10).

### 1.17 Sentry veri bölgesi ve saklama (P1 · 20 dk · 👤)

DSN kök `.env`'de ve kural gereği okunmadı; bölge bilinmiyor.

1. sentry.io → Organization Settings → General: veri depolama konumu (US / EU) ne? (DSN'deki alan adı da ipucu verir: `*.de.sentry.io` AB.)
2. Organization / Project Settings → Security & Privacy: **"Prevent Storing of IP Addresses"** açık; Data Scrubber açık.
3. Planındaki olay saklama süresini not et; hesap silme sayfasındaki "Hizmet sağlayıcının saklama süresi dolduğunda" ifadesiyle tutarlı.
4. Sonucu KVKK-07 alıcı listesine ve gerekirse Gizlilik Politikası §8-9'a işle (ABD ise "ABD dahil farklı ülkeler" ifadesi zaten kapsıyor).

### 1.18 PLAY-19 · Upload keystore yedeği (P1 · 20 dk · 👤)

`android/app/pomosprint-upload-key.jks` ve `android/key.properties` yalnızca bu makinede (gitignore'da). Kaybolursa Play destek talebiyle yükleme anahtarı sıfırlaması günler sürebilir.

1. `.jks` dosyasını ve parolalarını parola yöneticisine (dosya eki) ya da şifreli bir yedeğe koy; ikinci bir fiziksel konumda da tut.
2. Yedekten geri dönüşü dene: başka bir klasöre kopyalayıp `keytool -list -v -keystore <kopya>` ile aç.
3. İlk yüklemede Play App Signing'i Google'ın ürettiği anahtarla etkinleştir (varsayılan); SHA-1'leri 1.6'ya göre kaydet.

### 1.19 AS-17 · "Pomodoro" markası (P2 · 15 dk · 👤 ⚖️)

"Pomodoro Technique®" Francesco Cirillo / Cirillo Company'nin markası. Yaptırım ancak şikâyetle gelir; olasılık düşük.

1. Mağaza adı **PomoSprint** olsun (uygulamada son uygulamalar ekranında "PomoSprint - Pomodoro" görünüyor, PLAY-15 kod işi).
2. "Pomodoro" kelimesini yalnızca açıklama ve anahtar kelimelerde betimleyici kullan; görsellerde markanın logosu ya da domates kullanma.
3. İstersen açıklamaya "Cirillo Company ile bağlantılı değildir" ibaresini ekle (sitedeki `/pomodoro-nedir` için de değerlendir).

### 1.20 Mağaza metadata'sı ve yasal metin tutarlılığı (P1 · 1-2 saat · 👤 ⚖️)

1. **iPad ekran görüntüleri:** `TARGETED_DEVICE_FAMILY = "1,2"` olduğu için iPhone'a ek olarak 13 inç iPad ekran görüntüleri de zorunlu; repoda mağaza görseli klasörü yok.
2. **Support URL:** TR `https://pomosprint.app/destek`, EN yerelleştirme `https://pomosprint.app/en/support` (bu dal, §2). Marketing URL `https://pomosprint.app/`.
3. **Yayın günü:** ana sayfadaki "Yayınlanınca haber ver" bandını (`#yakinda`) ve `/features`, `/pomodoro-nedir` CTA'larını mağaza bağlantılarıyla değiştir; `landing/features.html`'deki "Premium yakında" satırı AS-01 kararıyla birlikte güncellenmeli (Premium uygulamadan kaldırılırsa sitedeki Premium ifadeleri de: `faq`, `features`, Şartlar §6).
4. ⚠️ **Metin çelişkileri:** Kullanım Şartları §4 sitede adın "kısaltılarak" gösterildiğini, Gizlilik Politikası §4 tek kelimelik adın "olduğu gibi" gösterildiğini söylüyor; ACC-06 (`proposed/14`) uygulanınca ikisini aynı kurala göre düzelt. Şartlar §6 "ücretli bir özellik bulunmaz" derken uygulama "Premium üyelere özel" gösteriyor (AS-01).

---

## 2. Bu dalda (`site-eposta`) yapılanlar ✅

| Bulgu | Yapılan | Dosyalar |
|---|---|---|
| AS-13 | Geçici "Yakında / henüz mağazalarda değil / görsel yakında" metinleri kaldırıldı (ana sayfa, özellikler, pomodoro-nedir). Yeni destek sayfaları: `/destek` ve `/en/support` (iletişim, yanıt süresi, giriş/onay e-postası, seanslar, bildirme/gizleme, hesap ve veri, yasal metinler); footer ve EN menüde bağlantı, `sitemap.xml`'de `hreflang` çifti | `landing/destek.html`, `landing/en/support.html`, `_partials/footer*.html`, `_partials/header.en.html` |
| KVKK-19 | Yazı tipleri (`fonts/`, `css/fonts.css`, Baloo 2 + Nunito, latin/latin-ext, OFL) ve GSAP 3.13.0 (`vendor/gsap-3.13.0/`, SRI değerleri jsDelivr'dekiyle aynı, `openssl` ile doğrulandı) kendi alan adımızda. CSP: `font-src 'self'`, `style-src 'self'`, `script-src 'self'` + Cloudflare Insights. Gizlilik ve KVKK metinlerinden (iki dil) Google Fonts ve jsDelivr çıkarıldı. `sync_partials` çalıştırıldı | `_partials/head.html`, `_partials/scripts.html`, `_headers`, `privacy`, `kvkk`, `en/*` |
| KVKK-11 | Hoş geldin e-postası ve bülten: altbilgide hizmet sağlayıcı kimliği (`MAIL_SENDER_NAME/ADDRESS`, yoksa gönderim yok), destek adresi, Gizlilik ve KVKK bağlantıları, "neden alıyorsun" cümlesi. Abonelikten çıkma bağlantıları (sayfa ve RFC 8058 tek tık) yalnızca `?token=`. Çıkış sayfası token-only bağlantıyı destekliyor; eski `email+token` bağlantıları çalışıyor, e-posta adres çubuğundan siliniyor ve istekte yalnızca gövdede. `unsubscribe` fonksiyonu (canlı v9) token-only isteği zaten kabul ediyor; testle kilitlendi | `supabase/functions/*`, `scripts/send_newsletter.js`, `scripts/lib/newsletter_mail.js`, `scripts/templates/newsletter.html`, `landing/js/unsubscribe.js` |
| PLAY-11 | Hesap silme sayfaları (TR/EN): uygulamayı yeniden kurmadan silme; Google/Apple ile girmiş (şifresiz) hesaplar için ayrı bölüm (uygulamadan, Google adresinden, Apple aktarım adresini bulma ve doğrulama yolu); bağlantıyı kaldırmanın hesabı silmediği; Resend gönderim kayıtları ve sitedeki sıralamanın güncellenmesi | `landing/hesap-silme.html`, `landing/en/delete-account.html` |
| 6563 | Bekleme listesi formunda e-posta alanından ayrı, önceden işaretsiz ticari elektronik ileti onay kutusu; JS onaysız kaydı engelliyor (bekleme sırasında kutu kaldırılırsa da). İstek gövdesi canlı tabloya uygun olarak yalnızca `{email}`; sunucu önerisi `proposed/19` (A/B aşamalı, down ve DRYRUN ile) | `landing/index.html`, `landing/js/main.js`, `css/style.css`, `supabase/proposed/19_*`, `supabase/tests/proposed_19_*` |
| KVKK-15 | Veri sorumlusu kimliği için dört sayfada açıkça işaretli yer tutucu (`data-fill-in`); "kimlik doğrulamadan sonra iletilir" cümlesi kaldırıldı. Bilgi uydurulmadı | `privacy`, `kvkk`, `en/privacy`, `en/kvkk` |
| PLAY-07 (site kısmı) | Gizlilik Politikası Sentry maddesine rastgele kurulum kimliği | `privacy.html`, `en/privacy.html` |

Testler: `cd scripts && npm test` → 35/35 (Edge Function'lar sahte Supabase ile; bekleme listesi formu ve çıkış sayfası sahte DOM ile; eski `main.js`/`unsubscribe.js` ile 7 test kırmızı, yani testler gerileme yakalıyor). `python3 landing/tools/sync_partials.py --check` çıkış 0. **Deploy yapılmadı** (komutlar 1.13'te).

---

## 3. App Store

### 3.1 App Privacy yanıtları

**Takip (tracking): Hayır.** Reklam SDK'sı, IDFA, veri broker'ı yok. App Tracking Transparency istemi gerekmez. ✅

| Apple veri türü | Toplanıyor | Kullanıcıya bağlı | Amaç | Not |
|---|---|---|---|---|
| Contact Info → Email Address | Evet | Evet | App Functionality; bülten onayı verenler için ayrıca Developer's Advertising or Marketing | Apple gizli aktarım adresi de olabilir |
| Contact Info → Name | Evet | Evet | App Functionality | Görünen ad; Google/Apple'ın ilettiği ad |
| Identifiers → User ID | Evet | Evet | App Functionality | Hesap UUID'si, arkadaşlık kodu |
| Identifiers → Device ID | Evet | Hayır | App Functionality | Sentry'nin rastgele kurulum kimliği (PLAY-07) |
| User Content → Other User Content | Evet | Evet | App Functionality | Ders (kategori) adları arkadaşlara görünebiliyor |
| Usage Data → Product Interaction | Evet | Evet | App Functionality | Seanslar, puan/kum/seri/lig |
| Other Data → Other Data Types | Evet | Evet | App Functionality | Doğum yılı, çalışma durumu, günlük hedef, onay kayıtları |
| Diagnostics → Crash Data | Evet | Hayır | App Functionality | Sentry; `sendDefaultPii=false`, kullanıcı atanmıyor, e-postalar maskeleniyor (`lib/app/error_reporting.dart`) |
| Diagnostics → Performance Data | Evet | Hayır | App Functionality | `tracesSampleRate = 0.2` |
| Diagnostics → Other Diagnostic Data | Evet | Hayır | App Functionality | Cihaz modeli, OS sürümü, breadcrumb |

**Toplanmıyor:** Location, Contacts, Health & Fitness, Financial Info, Sensitive Info, Browsing/Search History, Purchases, Photos/Videos, Audio, Advertising Data, Customer Support (bildirim e-postası kullanıcının kendi e-posta uygulamasından gider).

- ⚠️ `PrivacyInfo.xcprivacy` ile tutarlılık: 1.8 madde 3.
- ✅ Cihazda kalanlar App Privacy'ye girmez: gizlenen kullanıcılar listesi, bildirim/dil/tema tercihi, Live Activity, kilit ekranı bildirimi.
- ⚠️ İleride Sentry'ye kullanıcı kimliği atanırsa crash/performance/diagnostic ve Device ID yanıtları "bağlı" olmalı.

### 3.2 Sign in with Apple (Yönerge 4.8 ve 5.1.1(v))

- ✅ iOS giriş ekranında Apple ile giriş var; `Runner.entitlements` `com.apple.developer.applesignin` içeriyor.
- 👤 **Supabase'de sağlayıcı kapalı** → 1.2 (ACC-01, P0).
- ⚠️ **Token iptali (ACC-02, kod):** canlı `delete_own_account` yalnızca `auth.users` satırını siliyor; Apple REST API `revoke` çağrısı yok. Yapılana kadar inceleme notunda durumu açıklamayı değerlendir. Hesap silme sayfası Apple Kimliği ayarlarından bağlantının ayrıca kaldırılabileceğini ve bunun tek başına hesabı silmediğini söylüyor ✅.

### 3.3 Uygulama içi hesap silme (5.1.1(v))

- ✅ Yol: sağ üstteki profil karakteri → **Profil ve Ayarlar** → en altta **Hesabımı Sil** → onay (`deleteAccount`: TR "Hesabımı Sil", EN "Delete Account").
- ✅ Gerçek silme; canlı FK'larla cascade (AGENTS §5.6). `waitlist` ve `user_id`'siz abonelik satırı için `proposed/12` (uygulanmadı).
- ⚠️ Sayfalardaki "en geç 30 gün" ifadesi yedekleri de kapsıyor; Pro'ya geçersen yedek/PITR saklama süresinin 30 günü aşmadığını kontrol et (1.14).

### 3.4 Yönerge 1.2: kullanıcı içeriği

| Apple beklentisi | Durum |
|---|---|
| Uygunsuz içerik filtresi | ✅ İstemcide `utils/name_filter.dart` (kayıt, profil, Google/Apple adı). ⚠️ Sunucuda yok (AGENTS §10 P2): `profiles.name` doğrudan UPDATE ile filtre aşılabilir |
| Kullanıcı bildirme | ✅ Başkasının satırında uzun basma ya da "⋮" → **Kullanıcıyı bildir** → `mailto:destek@pomosprint.app` |
| Kullanıcıyı engelleme | ✅ Aynı menü → **Bu kullanıcıyı gizle** (cihazda; sıralamada ad gizlenir, canlı akışta görünmez). ⚠️ Sunucuda engelleme ve arkadaşlıktan çıkarma yok (PLAY-04, `proposed/14`) |
| Yayımlanmış iletişim bilgisi | ✅ `/destek`, `/en/support`, Şartlar, Gizlilik Politikası: `destek@pomosprint.app` |
| Sıfır tolerans içeren şartlar ve kabulü | ✅ Şartlar §3-4; kayıtta zorunlu kabul. ⚠️ Google/Apple ile ilk girişte yalnızca bilgilendirme metni var, onay sürümü kaydedilmiyor (AGENTS §10 P2) |
| Bildirimlere zamanında yanıt | 👤 Bir iç hedef belirle (ör. 24 saat), inceleme notuna yaz, destek kutusunu takip et |

- 👤 Moderasyon prosedürü: uygunsuz adı SQL Editor'de `profiles.name` güncellemesiyle değiştirme; hesabı askıya almak için Supabase Auth'ta kullanıcıyı yasaklama. Bir sayfalık iç not hazırla.

### 3.5 Gerekli URL'ler (site deploy edildikten sonra)

| Alan | URL |
|---|---|
| Privacy Policy URL (TR / EN) | `https://pomosprint.app/privacy` / `https://pomosprint.app/en/privacy` |
| Support URL (TR / EN) | `https://pomosprint.app/destek` / `https://pomosprint.app/en/support` ✅ |
| Marketing URL (isteğe bağlı) | `https://pomosprint.app/` (yayın günü bekleme listesi bandını değiştir, 1.20) |
| User Privacy Choices URL (isteğe bağlı) | `https://pomosprint.app/hesap-silme` (EN: `/en/delete-account`) |

### 3.6 App Review notu şablonu (App Store Connect → App Review Information → Notes)

Kimlik bilgilerini **repoya yazma**; yalnızca App Store Connect'teki alanlara gir. Yer tutucuları demo hesapları açınca doldur (1.7).

```text
PomoSprint is a gamified Pomodoro focus timer (25- or 50-minute sessions).

DEMO ACCOUNT (email sign-in, already verified)
  Email:    <DEMO_EMAIL_1>
  Password: <entered in the Sign-In Information fields>
  This account already has completed sessions, so Reports, League and
  Ranking screens show data. A second demo account (<DEMO_EMAIL_2>,
  friend code <FRIEND_CODE_2>) is its friend and can be used to test
  friend features. Points are awarded only when a full 25/50-minute
  session completes and are verified on our server, so you do not need
  to wait for a timer to finish to review the app.
  To test account deletion, please use the second account or a new
  account so the first demo account stays available for later reviews.

LOCK SCREEN / LIVE ACTIVITY
  1. On the Pomo tab choose 25 or 50 min and tap START.
     Notification permission is requested on the first start.
  2. Lock the device: the remaining time is shown as a Live Activity on
     the lock screen (and in the Dynamic Island on supported iPhones).
  All of this is generated on the device; no push server is used.

SOCIAL FEATURES / USER-GENERATED CONTENT
  - The only user-generated content is the display name and the subject
    (category) names visible to friends. There is no chat.
  - Display names pass through an automatic profanity filter.
  - Report a user: long-press another user's row (or tap its ⋮ menu) in
    Ranking (League / Monthly / Friends), in the Social tab's
    "Focusing now" list or in the friends list, then choose "Report user".
    This opens an email to destek@pomosprint.app; reports are reviewed
    within <TARGET TIME>.
  - Hide a user: same menu > "Hide this user". Hidden users' names are
    hidden in rankings and they no longer appear in the live feed
    (reset in Profile & Settings > Show hidden users).
  - Terms of Use with zero tolerance for objectionable content are
    accepted at sign-up: https://pomosprint.app/en/terms

ACCOUNT DELETION
  Tap the profile character (top right) > Profile & Settings > scroll to
  the bottom > Delete Account > confirm.
  Web: https://pomosprint.app/en/delete-account

OTHER
  No in-app purchases, no ads, no tracking. Sign in with Apple is offered
  alongside Google Sign-In.
  Support: https://pomosprint.app/en/support (destek@pomosprint.app)
```

- ⚠️ Menü yolu ve etiketler kod okunarak yazıldı (`user_safety.dart`, ARB); göndermeden önce release derlemede bir kez doğrula.

### 3.7 Yaş derecelendirmesi ve export compliance

- 👤 App Store Connect'teki güncel yaş derecelendirme anketini dürüstçe doldur: şiddet, cinsellik, kumar, tıbbi içerik yok; kullanıcı içeriği ve kullanıcılar arası etkileşim var; mesajlaşma yok; sınırsız web erişimi yok. Hedef en az 13+ (1.8).
- ✅ `Info.plist`: `ITSAppUsesNonExemptEncryption = false`; 👤 App Store Connect'te aynı yanıt.

### 3.8 PrivacyInfo ve Live Activity teknik notları

- ✅ `ios/Runner/PrivacyInfo.xcprivacy` var (izleme yok, `UserDefaults` gerekçesi). ⚠️ Veri türleri eksik: 1.8 madde 3.
- ✅ Live Activity uzantısı App Group kullanmıyor (AGENTS §4.7); uzak push yok.

---

## 4. Google Play

### 4.1 Data safety yanıtları

**Genel:** Aktarımda şifreleme: **Evet** (TLS). Kullanıcı silme isteyebilir: **Evet** (uygulama içi + `https://pomosprint.app/hesap-silme`). Hizmet sağlayıcılara (Supabase, Sentry, Resend, Cloudflare) aktarım Google'ın tanımında "paylaşım" sayılmıyor → **Paylaşılan veri: Yok** (⚠️ formdaki güncel tanımı kontrol et).

| Play veri türü | Toplanıyor | Zorunlu / isteğe bağlı | Amaç |
|---|---|---|---|
| Kişisel bilgiler → E-posta adresi | Evet | Zorunlu | Hesap yönetimi, Uygulama işlevi; bülten onayı verenler için **Geliştirici iletişimi** |
| Kişisel bilgiler → Ad | Evet | Zorunlu | Uygulama işlevi, Hesap yönetimi |
| Kişisel bilgiler → Kullanıcı kimlikleri | Evet | Zorunlu | Hesap yönetimi, Uygulama işlevi |
| Kişisel bilgiler → Diğer bilgiler | Evet | Zorunlu | Uygulama işlevi (doğum yılı: 13 yaş sınırı; çalışma durumu: ders önerisi) |
| Uygulama etkinliği → Diğer kullanıcı içeriği | Evet | Zorunlu | Uygulama işlevi (ders adları) |
| Uygulama etkinliği → Uygulama etkileşimleri / Diğer işlemler | Evet | Zorunlu | Uygulama işlevi (seanslar, puan, seri, lig); birini seçip Apple yanıtıyla tutarlı kal |
| Uygulama bilgileri ve performans → Kilitlenme günlükleri | Evet | Zorunlu | Analiz |
| Uygulama bilgileri ve performans → Teşhis | Evet | Zorunlu | Analiz |
| Cihaz veya diğer kimlikler | Evet | Zorunlu | Analiz (Sentry'nin rastgele kurulum kimliği; PLAY-07) |

**Toplanmıyor:** Konum, Kişiler, Fotoğraf/Video, Ses, Dosyalar, Takvim, Mesajlar, Finans, Sağlık, Web geçmişi, Reklam kimliği.

- ✅ Doğum yılı ve çalışma durumu kodda **zorunlu** (`post_auth_onboarding_screen.dart`); tablo buna göre.

### 4.2 Hesap silme URL'si

- ✅ `/hesap-silme` ve `/en/delete-account`: uygulama ve paket adı, uygulama içi adımlar, uygulamayı yeniden kurmadan e-postayla silme (30 gün), **Google/Apple ile girmiş hesaplar için ayrı bölüm** (PLAY-11), silinen ve tutulan veriler ile süreleri (Sentry, sunucu erişim kayıtları, Resend gönderim kayıtları, bekleme listesi, destek e-postaları), hesabı silmeden veri silme.
- ⚠️ Sayfalarda geliştirici adı "PomoSprint"; Play kaydındaki geliştirici adı farklıysa düzelt (1.1 adım 5).
- 👤 Play Console → Uygulama içeriği → Veri güvenliği → "Hesap silme URL'si": `https://pomosprint.app/hesap-silme` (sayfa EN sürüme bağlantı veriyor).

### 4.3 Exact alarm beyanı (PLAY-06) gerekçe taslağı

```text
PomoSprint is a Pomodoro focus timer. Its core function is a countdown
timer that the user starts (25 or 50 minutes). USE_EXACT_ALARM is used
only to show the end-of-session alert at the exact moment the user's
timer finishes, including when the device is idle or locked. The app
sets no other alarms and collects no data through this permission.
```

### 4.4 Bildirim izni, hedef API, 16 KB

- ✅ `POST_NOTIFICATIONS` manifestte; izin açılışta değil ilk BAŞLAT'ta isteniyor (AGENTS §4.1). ⚠️ İzin reddedilince Profil'deki anahtarın durumu ve kullanıcıya açıklama (UX-07, kod).
- ✅ Flutter 3.44.8: `compileSdk`/`targetSdk` 36, `minSdk` 24, NDK 28.2. ⚠️ Play'in güncel hedef API şartını Console uyarılarından teyit et.
- ⚠️ 16 KB sayfa boyutu: NDK r28 ve Flutter 3.44 destekliyor; native kütüphane getiren `sentry_flutter` için App bundle explorer'dan doğrula (PLAY-02 adım 6). Bu makinede **doğrulanmadı**.

### 4.5 İçerik derecelendirmesi, hedef kitle, uygulama erişimi

- 👤 IARC: 1.7 adım 7.
- 👤 Hedef yaş grupları: 13-15, 16-17, 18+. **13 yaş altı seçilmemeli** (Aileler politikası devreye girer, Şartlarla çelişir).
- ⚠️ "Uygulama istemeden çocukların ilgisini çekebilir mi?" sorusu: sevimli karakterler nedeniyle ek inceleme istenebilir; mağaza görsellerinde ve açıklamada çocuklara yönelik dil kullanma.
- ✅ Reklam yok.
- 👤 Uygulama erişimi: 1.7 adım 5. Google girişi: 1.6.

---

## 5. KVKK ve Türkiye mevzuatı

### 5.1 Aydınlatma

- ✅ `/kvkk` (+ `/en/kvkk`): veri kategorileri tablosu, amaçlar, hukuki sebepler (açık rıza yalnızca ticari elektronik ileti), yalnızca cihazda kalan veriler, aktarım, saklama süreleri, m.11 hakları, başvuru usulü.
- ⚠️ Veri sorumlusu kimliği: 1.1 (KVKK-15).
- ✅ Kayıt ekranında aydınlatma teyidi, şartlar kabulü ve bülten onayı ayrı; bülten kutusu önceden işaretsiz (AGENTS §4.5).
- ⚖️ Doğum yılı kayıttan sonra soruluyor; 18 yaş altının bülten onayı için 1.10 adım 5.

### 5.2 VERBİS

- ⚖️ Kurul'un muafiyet kararlarındaki çalışan sayısı ve mali bilanço eşiklerini ve geliştiricinin (gerçek kişi / şirket) durumunu güncel karardan teyit et. Muaf olunsa da aydınlatma, veri güvenliği, başvurulara yanıt ve ihlal bildirimi yükümlülükleri sürer; saklama ve imha politikası zorunluluğu kayıt yükümlülüğüne bağlı olabilir.

### 5.3 Yurt dışına aktarım

- 1.11 (KVKK-07). ✅ Google Fonts ve jsDelivr artık alıcı değil (KVKK-19).

### 5.4 Ticari elektronik ileti ve İYS (6563)

- ✅ Uygulamada bülten onayı isteğe bağlı ve ayrı; her bültende ve hoş geldin e-postasında yalnızca token taşıyan çıkış bağlantısı ve `List-Unsubscribe` tek tık; altbilgide hizmet sağlayıcı kimliği (secret'lar doldurulunca, 1.13).
- ✅ Sitedeki bekleme listesi formunda ayrı, önceden işaretsiz onay kutusu; sunucu kaydı için 1.16.
- ⚠️ Onayın ispat kaydı istemcinin değiştirebildiği metadata'da (KVKK-10, `proposed/14`); uygulamadan onayı geri alma/sonradan verme yok (KVKK-09, kod).
- ⚖️ İYS: 1.16 adım 5.

### 5.5 Diğer

- 👤 Veri ihlali prosedürü: ihlal öğrenildiğinde Kurul'a ve ilgili kişilere bildirim (Kurul kararındaki 72 saat); bir sayfalık iç prosedür hazırla.
- ⚖️ 5651 sayılı Kanun: kullanıcı içeriği nedeniyle "yer sağlayıcı" sayılıp sayılmadığı ve trafik bilgisi saklama yükümlülüğü. Sitede böyle bir saklama süresi **yazılmadı** (uydurulmadı).
- 👤 ⚖️ **Avukat incelemesi:** KVKK Aydınlatma Metni, Gizlilik Politikası, Kullanım Şartları, aktarım mekanizması, İYS, 5651, yaş ve dağıtım bölgesi.

---

## 6. Metin ↔ uygulama tutarlılığı (her sürümden önce)

| Site metninde | Uygulamada kontrol et |
|---|---|
| "Kullanıcıyı bildir" / "Report user", "Bu kullanıcıyı gizle" / "Hide this user" (`/destek`, `/en/support`, Gizlilik, Şartlar) | ARB'deki `reportUserAction`, `hideUserAction` ile birebir mi? |
| "Şifremi Unuttum", "Doğrulama E-postasını Tekrar Gönder" / "Forgot Password?", "Resend Verification Email" (destek sayfaları) | `forgotPassword`, `resendVerificationLink` |
| Hesap silme: Profil ve Ayarlar → Hesabımı Sil (6 sayfa) | `profileTitle`, `deleteAccount` |
| Bildirim anahtarı: Profil ve Ayarlar → Bildirimler | `notifications` |
| Günde en fazla 16 seans puan kazandırır; seans başlangıcından itibaren 24 saat içinde gönderilmeli | `complete_study_session` (AGENTS §5.2) |
| Apple ile giriş yalnızca iPhone ve iPad'de | `login_screen.dart` `_showAppleSignIn` |
| Görünen ad sitede nasıl gösteriliyor (Şartlar §4 ↔ Gizlilik §4) | ACC-06 kararı (`proposed/14`) |
| Premium ifadeleri (`faq`, `features`, Şartlar §6) | AS-01 kararı |
| "Son güncelleme" tarihi | `kLegalDocumentsVersion` (`legal_links.dart`) |
