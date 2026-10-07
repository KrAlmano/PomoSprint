# 7 Ekim 2026 mobil kod ve yayın hazırlığı incelemesi

Bu inceleme kod/statik yapılandırma içindir. Birim/widget/UI ve platform derlemelerini ana QA ajanı çalıştırır; sonuçlar ana raporda ayrı yer alır. Canlı hesap, rapor, SQL veya e-posta yazımı bu incelemede yapılmadı. Native config JSON yalnızca parse ve dosya-varlık bilgisi içerir; imza/env sırları okunmadı.

## Bulunan ve düzeltilen davranışlar

- `AppGate`: oturum kapanırken yalnızca kök ekran değişiyordu; Profil/Koleksiyon/sheet route'ları açık kalabiliyordu. Sahip değişiminde eski route'lar frame sonunda tek merkezden kapatılır; aynı sahibin profil yenilemesi route'ları kapatmaz. Onboarding ve Shell UID ile anahtarlanır; farklı hesabın taslağı/state'i yeniden kullanılamaz.
- `ProfileScreen` hesap silme: yukarıdaki merkezi kapanış gerçek iOS E2E `e` sırasında eski çift `pop` ile yarıştı (`Bad state: No element`, Navigator lock). Başarıda yönlendirme tamamen servis → AppGate'e bırakıldı. Hata yalnızca kendi aktif ilerleme DialogRoute'unu kaldırır. Bu başarısız koşu kanıtı `build/e2e_sim/e_settings_delete_test.log`; düzeltmeden sonraki koşu ana raporda ayrı doğrulanır.
- Sosyal görünürlük: ilk okuma ve paralel kaydetme eski tercihleri geri yazabiliyordu. Okuma/kayıt beklenirken anahtar kapalı; tek işlem; hata gerçek önceki değere döner; eski hesabın yanıtı UI'a uygulanmaz.
- `FriendsSheet`: paralel yenilemelerde geç gelen eski liste yeni sonucu ezebiliyordu. Yalnızca en son istek sonucu uygulanır.
- `HiddenUsersStore`: `load(null)`/silme bekleyen eski hesabın okumasını iptal etmiyordu; eski gizlenenler tekrar yayınlanabiliyordu. Epoch ve sahip denetimi eklendi; hesap değişince önceki liste hemen temizlenir.
- Kayıt ve şifre değiştirme: sunucu isteği sürerken geri çıkış engellenir; tamamlanmakta olan auth işleminin ekransız bırakılması önlenir.
- Destek/rapor/gizleme/yasal bağlantı dönüşleri: eski/dispose edilmiş ekranda SnackBar açılması önlenir.
- Kullanıcı bildirimi: mevcut `submit_user_report` RPC'sine küçük uygulama içi neden/not formu bağlandı. Kimlikli lig/aylık/arkadaş/canlı satırları için e-posta uygulaması gerekmez. Mükerrer/başarı/hız sınırı/ağ hatası yerelleştirilir; tek işlem ve hesap denetimi var. Kimliksiz eski sunucu satırında destek e-postası yedeği korunur. RPC/DB değişmedi; fresh izole DB sözleşmesi backend ajanında 21/21 geçti (`backend/report_contracts.log`).
- Şifre alt sınırı: canlı Auth salt-okuma denetimi `minimum_password_length=8`, `lower_upper_letters_digits` buldu. Mobil ortak helper, kayıt/şifre değiştirme doğrulaması ve TR/EN üç kural metni 8'e hizalandı; 6/7 karakterin reddi ve 8 karakterde harf/rakam kuralları regresyonda kilitlendi. Mevcut hesaba giriş için yeni şifre kuralı dayatılmadı. Site/yerel config hizası ilgili ajanlara devredildi; canlı Auth değiştirilmedi.
- iOS privacy manifest: sunucuda tutulan özel kategori ve bildirim notu serbest metnini kapsamak için `OtherUserContent` eklendi; hesaba bağlı, takip yok, uygulama işlevi. `plutil -lint` ve içerik assertion'ları geçti (`privacy_manifest_check.json`). App Store Connect etiketleri ayrıca hizalanmalı.

## Yeni regresyonlar

- `test/auth_navigation_lifecycle_test.dart`: remote signout overlay, aynı sahipte overlay korunması, aynı frame'de çoklu hesap geçişi ve onboarding reset.
- `test/account_deletion_navigation_test.dart`: silme sırasında null sahibi ve bekleyen servis/ilerleme; route'lar çift kapanmaz.
- `test/profile_visibility_race_test.dart`: ilk okumayı bekleme, tek işlem/çift callback, ağ hatası/geri alma.
- `test/friends_refresh_race_test.dart`: eski yanıtın yeni listeyi ezmemesi.
- `test/user_safety_test.dart`: pending load/logout/delete ve eşzamanlı sahip yükleme.
- `test/user_report_dialog_test.dart`: UI→RPC payload, zorunlu neden, boş/trim not, tek işlem/back, duplicate/rate-limit/account switch ve dar/yatay/tablet büyük yazı.
- `test/registration_consent_test.dart`, `test/account_session_test.dart`: 8 karakter sınırı,6/7 karakter reddi, ASCII büyük/küçük harf ve rakam ayrımı.

Testleri bu alt ajan çalıştırmadı; ana ajanın logları son doğrulama kaynağıdır. Ana ajan yeni report/silme/race odaklı koşunun 86/86 geçtiğini bildirdi. İlk focused koşuda yeni testteki `ValueKey<String>`/nullable tür beklentisi düzeltildi; ürün hatası değildi. Son tam test seti ve gerçek iOS/Android uçtan uca sonuçları ana raporda yer alır.

## Statik native/release sonuçları

`native_config_static.json`: 5 plist + 5 Android XML parse geçti. Apple privacy manifest Runner Resources'a bağlı; UserDefaults CA92.1 var. App ID Android/iOS `com.pomosprint.app`, widget `com.pomosprint.app.TimerWidget`. Apple giriş entitlement Profile/Release'te, debug'da kasıtlı yok. Android debug yerel HTTP config release manifestine taşınmıyor; backup kapalı ve dataExtractionRules mevcut. `bash -n scripts/build_release.sh` ve `git diff --check` geçti.

`android/key.properties` mevcut; içeriği/keystore okunmadı. Bu varlık tek başına mağaza imzasını kanıtlamaz; ana ajanın signed AAB doğrulaması gerekir. `ios/ExportOptions.plist` yok; otomatik export/provisioning yine mümkün olabilir, bu yokluk tek başına hata değildir. Gerçek signed archive/IPA/TestFlight ve Google/Apple OAuth başarıları yerel UI testlerinden çıkarılamaz.

## Resmî kaynaklarla yayın koşulları (7 Ekim 2026 okunarak)

- [Google Play hedef API gereksinimi](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en): 31 Ağustos 2026'dan beri yeni telefon uygulaması/güncelleme en az API 36. Gradle Flutter değerinden alır; gerçek derlenen artifact hedefi ayrıca ölçülmeli.
- [Google Play exact alarm politikası](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en):çekirdek kullanıcı işlevi zamanlayıcı olan uygulamalar USE_EXACT_ALARM kullanabilir; Play Console beyanını repository kontrolü doğrulayamaz. Alarm izni sırf denetim diye kaldırılmadı.
- [Google Play kullanıcı içeriği](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en):görünür kullanıcı içeriğinde uygulama içi report/block beklenir. Mevcut block RPC/UI korunarak mailto-only report boşluğu yukarıdaki form ile kapatıldı. Operatörün bildirimi ele alma süreci ayrı operasyon gereğidir.
- [Apple minimum SDK](https://developer.apple.com/news/upcoming-requirements/?id=02032026a): 28 Nisan 2026'dan beri Xcode 26+/iOS 26 SDK. iOS 18.6 simülatör hedefi farklıdır; eski runtime ile test bu minimum SDK kuralını değiştirmez.
- [Apple privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [UserDefaults CA92.1 örneği](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest):app ve üçüncü taraf SDK reason/data kayıtları bundle'da olmalı. Repo manifesti mevcut; archive'ın birleşmiş privacy raporu ve App Store Connect etiketleri bu statik kontrolle doğrulanmış sayılmaz.
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/) serbest metin için Other User Content kategorisini belirtir; [manifest veri türü değerleri](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype) doğru anahtarı tanımlar. Yukarıdaki ekleme bu kaynaklardan ve uygulamanın sakladığı metinlerden çıkarıldı.
- [Apple hesap silme rehberi](https://developer.apple.com/support/offering-account-deletion-in-your-app/) ve [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple):hesap silme uygulamada ve Apple kullanan hesapta token revoke yapılmalı. SQL fallback hesabı siler; deploy/secrets olmadan Apple revocation yoksa bu yayın açığıdır.

## Yayın için açık kalan/harici gerektirenler

- Apple provider canlıda kapalı/client ID boş olduğu backend salt-okuma denetiminde görüldü; görünür Release Apple düğmesi gerçek sağlayıcıyla doğrulanmalı ve provider/capability/revoke operasyonu tamamlanmalı. Mevcut konfigürasyonla Apple login başarılı sayılamaz.
- Backend salt-okuma Auth denetimindeki şifre 8 uyumsuzluğu mobilde giderildi; web/yerel configin son durumu ana raporda doğrulanır.
- Signed mağaza artifact ve sağlayıcı kimlik doğrulama, fiziksel tam bildirim/ses/banner/Live Activity ve arka plan/kill, store metadata/etiketler/beyanlar ayrıca kanıtlanmalı.
- Güvenli token depolama, Google plugin 7 göçü ve servisin bölünmesi ayrı teknik işlerdir; bu QA'da sırf yeni sürüm var diye paket güncellemesi/ek özellik yapılmadı.
