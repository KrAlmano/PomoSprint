# iOS paket ve normal uygulama kapanış doğrulaması — 28 Ekim 2026

Sabah kullanıcının yalnız kapanış işlerini tamamlama talebiyle yapıldı. Yeni özellik veya ürün kodu değişikliği yok; 31 numaralı paket uygulanmadı ve 31 sonrası Maraton testi yapılmadı. Canlı Supabase/Resend/siteye istek veya deploy yoktur.

## İmzasız Release: geçti

Kaynak, gece hazırlanmış temiz `1cc6a05` kopyasıdır. Daha sonraki commit'lerin ürün dosyalarıyla aynı olduğu hash üzerinden doğrulandı; 235 güvenli kaynak dosyası ve `pubspec.lock` aynı kaldı. Kopyadaki Android Gradle kaynak sınırları bu iOS doğrulamasının kapsamı dışındadır. Boş `.env` asset'i **0 bayt**; kullanıcının `.env` dosyası okunmadı. Gerçek anahtar/sertifika kopyalanmadı.

Önce `flutter build ios --release --no-codesign --pub --config-only --target lib/main.dart` ile yerel QA tanımları üretildi (**17,14 sn**, çıkış0). Ardından Flutter'ın ürettiği ayarlarla `xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -destination generic/platform=iOS` çalıştırıldı (**77,99 sn**, çıkış0). İkinci komut `-disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates -jobs 2` ve `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO`, boş `CODE_SIGN_IDENTITY` kullandı. Bu, iki aşamalı gerçek Release derlemesidir; `--config-only` tek başına derleme başarısı gibi sunulmaz.

**9 Swift paket pini** ve Dart lock dosyası değişmedi. Son uygulama ana bundle'ında `_CodeSignature` yoktur; hedef `com.pomosprint.app`, minimum iOS15.0. Derleme üçüncü taraf başlık uyarıları verdi; derleyici hatası yok. Ürün kaynakları veya bağımlılık sürümleri değiştirilmedi.

- [Yapılandırılmış sonuç](../build/overnight_final_main/ios_closing_unsigned_release.json)
- [Release derleme günlüğü](../build/overnight_final_main/ios_closing_unsigned_release.log)
- [Korunan imzasız uygulama](../build/overnight_final_main/Runner-unsigned-release-final.app): **55.029.553 bayt**; executable SHA256 `c49c4243459404a98a560f3d35931f3ba70b23e63de8700fea3e4192068363ff`.

Bu yerel QA adresli, imzasız cihaz derlemesidir; mağaza indirme boyutu, Apple imzalama, fiziksel cihaz veya TestFlight doğrulaması değildir.

## iOS18.6 normal uygulama: kuruldu ve açıldı

Yalnız **PomoSprint QA iPhone 16 (18.6)** (`8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C`) boot edildi. Tam normal DEBUG `lib/main.dart` paketi `xcrun simctl install` ile mevcut uygulamanın üzerine yüklendi; **uninstall, erase veya veri sıfırlama yapılmadı**. Uygulama `simctl launch` ile açıldı; PID **72227**, en az30 saniyelik gözlemden sonra da canlıydı (son kontrolde100 saniyeden uzun).

Kurulum öncesi H18 hesabının tamamlanmış ilk-kullanım işareti, owner ve boş aktif sayaç durumu kaydedildi. iOS güncellemede veri konteynerinin UUID yolunu değiştirdi; buna rağmen **aynı owner, tamamlanmış H18 işaretinin birebir aynı SHA256'sı ve boş aktif sayaç** kurulum sonrasında doğrulandı. Yalnız konteyner yolunun değişmemesini şart koşan ilk kontrol bu nedenle düzeltilerek veri içeriğinin korunması doğrudan sınandı.

Son stdout/stderr taramasında **0 fatal hata deseni** ve **0 entegrasyon test koşucusu deseni** bulundu. Gerçek simülatör ekran görüntüsü gözle incelendi: normal Pomo ekranı, **25:00**, 25/50 seçimi, mevcut **5 puan /20 kum**, Maraton düğmesi ve beş alt sekme görünüyor; hata ekranı veya test koşucusu katmanı yok. Seans başlatılmadı, ekonomi değiştirilmedi. Bu açılış kontrolü bütün özelliklerin yeni baştan E2E tekrarlandığı anlamına gelmez.

- [Kurulum öncesi veri kanıtı](../build/overnight_final_main/ios_preinstall_data_proof.json)
- [Kurulum/açılış ve koruma sonucu](../build/overnight_final_main/ios_normal_main_install_smoke.json)
- [Gerçek normal uygulama ekranı](../build/overnight_final_main/ios-normal-main-smoke.png)

Kurulu uygulama **yerel QA Supabase `127.0.0.1:54321`** kullanır; Sentry kapalıdır. Kişisel canlı hesaba veya üretim ortamına bağlı kurulum gibi değerlendirilmemelidir. Mevcut İngilizce tercih korundu; süreler normal25/50 dakikadır.

## Önceki iOS kontrolünün açıklaması ve temizlik devri

04:27'deki doğrudan DEBUG Xcode derlemesinin çıkışı0 olmasına rağmen postflight aracı `Debug-iphonesimulator/Runner.app` içindeki eksik asset yolunu inceleyip başarısız olmuştu. Tam Flutter paketi `iphonesimulator/Runner.app` ve önceden korunmuş `Runner-normal-main.app` altında bulunuyordu. Bu paket için0 bayt asset, bundle, kaynak ve Swift pin doğrulamaları tamamlandı; ardından normal uygulama kuruldu. Eski `FAIL_POSTFLIGHT` kaydı silinmedi veya geçmişten PASS yapılmadı.

Son Release ve simülatör uygulaması, JSON/günlükler ve ekran kanıtı `build/overnight_final_main/` altında temiz kaynak kopyasından bağımsız korunuyor. Bu ajanın derleme/kurulum süreçleri tamamlandı. Root, `/tmp/pomosprint-final-main-20261028-vgcv2fgh` kopyasını ve planındaki yeniden üretilebilir ara çıktıları kaldırabilir; **SwiftPM `SourcePackages` symlink hedefi ve nihai kanıt/artifact dizini korunmalıdır**. HocamMacVar cihazına veya başka projeye dokunulmadı.
