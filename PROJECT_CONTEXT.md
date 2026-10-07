# PomoSprint — kısa proje bağlamı

> Son güncelleme: 7 Ekim 2026. Güncel test ve yayın durumu: [QA_RELEASE_2026-10-07.md](analiz/QA_RELEASE_2026-10-07.md). En kapsamlı çalışma/devir belgesi: [PROJE_DEVIR.md](PROJE_DEVIR.md). Kodlama ve sunucu sözleşmeleri: [AGENTS.md](AGENTS.md). Bu turda canlı DB/Auth/Edge/Resend/DNS salt okunarak doğrulandı; üretim yazımı, posta gönderimi veya deploy yapılmadı.

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
| Auth | E-posta/parola ve Google kod akışı; iOS Apple düğmesi var fakat canlı provider kapalı. Yeni şifre en az 8 karakter + ASCII küçük/büyük harf/rakam; reset web'de tamamlanır |
| Yerel test | Yalnızca debug + yerel backend seçilirse 5/10 saniye 25/50 dakika diye kaydedilebilir; canlıya kısa kayıt yok |
| Dil/tema | Türkçe/İngilizce, sistem/açık/koyu tema |
| Bildirim | Android yerel bildirim/kalıcı sayaç; iOS bildirim/Live Activity |

## 2. Teknoloji ve çalıştırma

- Flutter, Dart `^3.12.2`; ürün platformları `android/`, `ios/`.
- Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`.
- `pomosprint.app`: statik Cloudflare Workers site (`landing/`).
- Sentry: DSN boşsa veya açık yerel `--dart-define` bağlantısında ayrıca verilmezse kapalı.
- Google plugin kodu 6.x API'sinde. Gerçek Google/Apple sağlayıcı girişi son QA'da doğrulanmadı.
- Mobil/site/Edge kaynak düzeltmeleri çalışma ağacında olabilir; `git status` ile koru. Test geçişi deploy veya GitHub push anlamına gelmez.

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

`AppGate` tek yönlendirme kapısıdır. `SupabaseService.currentUser` tek kullanıcı kaynağıdır. Sahip değişiminde eski hesabın Profil/Koleksiyon/dialog/sheet route'ları frame sonunda kapanır; aynı sahibin profil yenilemesi overlay kapatmaz. Onboarding/Shell UID ile anahtarlanır. Hesap silme başarıda ayrıca pop/onLogout yapmaz; servis→AppGate yönlendirir. Tamamlanan seans önce diskteki `SessionQueue`'ya yazılır; `client_uuid` idempotency sağlar. Raporlar uzak kayıtları ve pending seansları `mergeStatSessions` ile birleştirir. Profil, ekonomi veya başka kullanıcının verisine ekrandan rastgele doğrudan erişme; [AGENTS.md](AGENTS.md)'deki RLS/RPC sözleşmesini izle.

## 4. Çalışma günü, arkadaşlık ve yasal kayıt

- `study_day.dart`: 04:00 çalışma günü, Pazartesi başlayan hafta ve DST güvenli takvim. Yerel IANA saat dilimi iOS/Android MethodChannel'ından (`device_time_zone.dart`) okunur. Profil açılışında ve uygulama ön plana dönünce eşitlenir. Geçersiz dilim veya ağ hatası eski profil değerini korur.
- Sosyal sekmenin görünür tazelemesi normalde 30 saniye; kısa kayıtlı yerel testte 2 saniye. Bu push realtime yayını değil.
- Arkadaş sheet: gelen/giden, iptal, remove, block/unblock. Gizle cihazda saklanan ayrı davranış. Bilinen kullanıcı kimliğinde uygulama içi zorunlu neden/isteğe bağlı not formu `submit_user_report` RPC'sine bağlıdır; kimliksiz eski sunucu satırında destek e-postası yedeği vardır. Duplicate/hız sınırı/hata/hesap izolasyonu test edildi.
- Paralel arkadaş yenilemesinde yalnız son yanıt uygulanır. Sosyal görünürlük ilk okuma/kayıt boyunca tek işlemle korunur. Gizlenen kullanıcı async yüklemesi logout/silme/hesap değişiminden sonra eski veriyi yayınlayamaz.
- SocialSignInNotice sonrasında başarıyla Google/Apple girişi yapılırsa `accept_legal_documents` terms/privacy sürümünü `consents` ledger'ına yazar. Hata durumunda Shell'e ilerlenmez. Bu yeni provider adımı gerçek provider login testi değildir.
- Şifre unuttum formu adres alır ve reset mailinden sonra “gönderildi” ekranını gösterir; reset bağlantısı web'de tamamlanır.
- Yasal sürüm `2026-10-07`; TR/EN kaynak sayfaları güncel, canlı site deploy edilmedi. iOS privacy manifest özel kategori/bildirim notu için hesapla bağlantılı `OtherUserContent` içerir; takip yok. Store etiketleri ayrı panel işidir.

## 5. Son QA ve kapsam sınırı

7 Ekim 2026 güncel tur: `flutter analyze` temiz; screenshot senaryoları dahil birim/widget **1091/1091, 0 atlama**; New York DST alt kümesi **93/93**; izole backend 9 paket **466/466**; son site/Edge/e-posta Node paketi **99/99** (welcome 15/15, unsubscribe 24/24, delete-account 25/25 alt kümeleri; ilk site turu 61/61 tarihsel). Gerçek iOS normal `a,b,c,d` ve düzeltme sonrası `e,m,n` 3/3 geçti. İlk hesap silme koşusundaki gerçek Navigator yarışı düzeltildi. iOS kayıtlı hızlı `f,k,g,h,i,l,m` 7/7 geçti; seanslar 5/10 saniyede test edildi. Android gerçek UI temel koşusu 6/6, tam koşusu 8/8 geçti. İki platformda gerçek OS süreç sonlandırma/restore aynı UUID'yi bir kez kaydetti. Alt kümeleri tam test sayısına tekrar ekleme. `o/q/r` toplu import dosyaları bu koşunun geçici yardımcılarıydı ve kaldırıldı; kalıcı senaryolar `a`–`n` dosyalarıdır.

Android mağaza pipeline 64,2 MB AAB üretti; imzası doğrulandı, mağazaya yüklenmedi. Yerel QA release APK'sı 28,0 MB derlendi; normal main ile emülatörde release giriş/rapor/sekme/sayaç/native bildirim, duraklat/sıfırla ve soğuk açılış kontrolleri geçti; bu koşuda çökme yok. iOS obfuscated imzasız release geçti (28,4 MB uygulama); imzalı IPA kişisel takımın Sign In with Apple / Time Sensitive Notifications ve provisioning kısıtında kaldı. Son artifact/runtime durumu [ana QA raporunda](analiz/QA_RELEASE_2026-10-07.md). 5 Ekim APK/unsigned iOS ve eski süreç testleri tarihsel kanıttır; güncel tur yerine kullanılmaz. Önceki detaylar [QA_FOLLOWUP](analiz/QA_FOLLOWUP_2026-10-05.txt) ve [QA_FULL](analiz/QA_FULL_2026-10-05.txt) içinde korunur.

Doğrulanmamışlar: fiziksel Android/iOS; gerçek Google/Apple giriş; fiziksel tam bildirim/ses/kilit ekranı sunumu; gerçek cihazda saat dilimini değiştirme; mağaza imzalı dağıtım ve yayın. Apple provider kapalı ve `delete-account` Edge Function yok: Apple login/revoke operasyonu yayın engelidir. Test geçişi bütün mağaza koşullarının tamamlandığı anlamına gelmez.

## 6. Backend durumu

5 Ekim uygulama sırası `12 → 15 → 16 → 19 A → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25 → 26`. 7 Ekim yeniden canlı salt-okuma: **409 katalog kaydı** baseline ile aynı; **14 ops fonksiyonu** canlı/yerel eşleşiyor. 19 B uygulanmadı. Yeni SQL işi için o andaki canlı tanımı yeniden oku; [supabase/README.md](supabase/README.md) ve `AGENTS.md` §2.3–2.4 akışını izle.

Canlı Auth: minimum şifre 8 + `lower_upper_letters_digits`, Google açık, Apple kapalı/client ID boş. Mobil/web yeni şifre doğrulaması ve yerel Auth config minimumu 8'e hizalandı; çalışan yerel Auth restart edilmedi, mevcut yerel fikstürlerin karakter politikası boş kaldı. Canlı sunucu ayarı değiştirilmedi. Canlı welcome v9 ve unsubscribe v10 yeni kaynak düzeltmelerini içermiyor; deploy bekliyor. Resend gönderici domaini verified ve geçmiş tek reset postası Delivered, 0 bounce/complaint; yeni posta gönderilmedi. Welcome gönderici adı/adresi secret'ları yok. Güncel SMTP alanları CLI çıktısında redakte/eksik olduğu için ayrıca doğrulanmalı.

Kanıt kökü [analiz/qa_evidence_20261007](analiz/qa_evidence_20261007); [backend özeti](analiz/qa_evidence_20261007/backend/summary.json), [mobil inceleme](analiz/qa_evidence_20261007/mobile_audit/mobile_review.md), [site raporu](analiz/qa_evidence_20261007/site/report.md), [e-posta özeti](analiz/qa_evidence_20261007/backend/email/summary.json). Gönderici/geliştirici kimliği, site/Edge deploy, Apple ayarları, mağaza privacy/Data Safety/exact-alarm beyanları ve fiziksel cihaz doğrulamaları kullanıcı/operasyon işleri olarak açık kalır.
