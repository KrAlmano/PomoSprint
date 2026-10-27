# iOS 18.6 simülatör başlatma düzeltmesi — 7 Ekim 2026

## Sorun ve neden

Kullanıcının `flutter run` komutu iPhone 16 Plus hedefini bulamıyor, Runner için `iOS 26.5 is not installed` diyordu. Aynı hata yerelde `xcodebuild -showdestinations` ile yeniden görüldü. Simülatör silinmemişti: `BEA55019-D5C3-420F-90F2-0B0CBD5690CF`, iOS 18.6, Booted olarak hem simctl hem Flutter listesinde vardı.

Terminalde `DEVELOPER_DIR` boştu ve sistem `xcode-select` seçimi `/Applications/Xcode-26.6.app/Contents/Developer` idi. Bu Xcode 26.6 / 17F113, Runner hedeflerini platform bileşeni hatasıyla uygun saymıyordu. VS Code Dart ayarı ve önceki E2E koşucusu ise `/Applications/Xcode.app/Contents/Developer` kullanıyordu: Xcode 27.0 / 27A266a. Bu seçimle aynı Runner, aynı cihaz UUID'si ve iOS 18.6 geçerli hedef olarak listelendi. Projede iOS 26.5 zorunluluğu yok; Runner minimum iOS 15.0, Canlı Etkinlik uzantısı 16.2.

## Uygulanan düzeltme

- `.vscode/settings.json` içindeki mevcut `dart.env.DEVELOPER_DIR` korundu; aynı değer `terminal.integrated.env.osx.DEVELOPER_DIR` olarak eklendi. F5 ve yeni entegre terminal aynı Xcode'u kullanır.
- `/Users/almano/.zshrc` sonuna açıklamalı, idempotent bir blok eklendi. Kurulu `/Applications/Xcode.app/Contents/Developer` varsa yeni zsh terminalleri bunu kullanır. Eski dosya yedeği `/tmp/pomosprint-xcode-20261007-zshrc.bak`; ev dizini ayarı ve yedek Git'e dahil değildir.
- Sistem düzeyindeki `xcode-select` değiştirilmedi; yönetici şifresi gerektirmeyen ortam değişkeni yöntemi kullanıldı. Bu yöntem [Apple'ın komut satırı ayarları belgesinde](https://developer.apple.com/documentation/xcode/configuring-command-line-tools-settings) desteklenir.
- iOS 18.6 runtime, simülatör UUID'si ve projenin minimum iOS sürümleri korundu. Yeni Xcode/runtime indirilmedi; uygulama Dart/Swift/SQL kodu değiştirilmedi.

## Gerçek doğrulama

| Kontrol | Sonuç |
|---|---|
| Xcode 26.6 ile aynı Runner hedef sorgusu | Kullanıcının platform bileşeni hatası yeniden görüldü |
| Xcode 27 ile hedef sorgusu | iPhone 16 Plus, aynı UUID, iOS 18.6 geçerli hedef |
| Yeni `/bin/zsh -lic` oturumu | `DEVELOPER_DIR` doğru, `xcodebuild -version` Xcode 27.0 |
| VS Code ayarı | JSON geçerli; Dart ve terminal yolları aynı |
| Normal `lib/main.dart`, debug, yerel Supabase | **34,7 sn** Xcode derlemesi başarılı; Flutter VM ve Supabase başlatıldı, giriş ekranı görüntülendi |
| `flutter analyze --no-pub` | Temiz, `No issues found!`, 5,1 sn |
| Tam `flutter test --no-pub --concurrency=2 --dart-define=SCREENSHOTS=true --reporter=expanded` | **1129/1129 geçti**, 0 atlama, yaklaşık 64 sn; tarihsel sayaç ekran dosyaları koşu öncesi içerikleriyle korundu |
| Flutter'dan `d` ile ayrılma | Uygulama açık kaldı; simülatörün çalışan Runner süreci ayrıca doğrulandı |

Başlatma doğrulaması açık yerel URL/anon define'larıyla `http://127.0.0.1:54321` üzerinde yapıldı; QUICK_TIMER/QUICK_TIMER_SAVE kullanılmadı. Sayaç normal 25/50 dk'dır. Giriş yapılmadı, hesap/seans/e-posta oluşturulmadı ve SQL uygulanmadı. Maraton paketleri önceki QA sonunda kaldırılmış yerel baseline durumunda kaldı; bu koşu Maraton sunucu kurulumunun yerine geçmez. Fiziksel cihaz kullanılmadı.

Derleme bir Google Sign-In eklentisi yaşam döngüsü uyarısı verdi; derlemeyi veya açılışı engellemedi. Gerçek Google girişini bu başlatma doğrulamasıyla geçmiş sayma.

## Tekrar çalıştırma ve son ortam

Mevcut açık terminal yeni ayarı kendiliğinden almaz. Yeni terminal aç veya bu terminalde bir kez:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter run -d BEA55019-D5C3-420F-90F2-0B0CBD5690CF
```

Bu normal komut `.env` backend'ini kullanır. Yerel test için VS Code'da **PomoSprint (yerel Supabase)** seç veya URL/anon define'larını [yerel rehberdeki](../tool/local_supabase/README.md) gibi birlikte ver. Başka bilgisayarda bu Xcode yolu var mı kontrol et; `.zshrc` değişikliği clone ile taşınmaz.

Bu tur sonunda iPhone 16 Plus simülatörü ve uygulamanın yerel giriş ekranı açık bırakıldı. Flutter koşucusu ayrıldı; Docker/yerel Supabase korundu. Android emülatörü başlatılmadı. Commit/push yapılmadı.

## Kanıtlar

- Başlatma günlüğü (ham çıktı §37 temizliğinde kaldırıldı).
- Analiz sonucu (ham çıktı §37 temizliğinde kaldırıldı).
- Son tam Flutter testi (ham çıktı §37 temizliğinde kaldırıldı).
- Xcode 27 hedefleri (ham çıktı §37 temizliğinde kaldırıldı).
- Yeni terminal seçimi (ham çıktı §37 temizliğinde kaldırıldı).
- Açılan giriş ekranı (ham çıktı §37 temizliğinde kaldırıldı).
- Makineye okunabilir son durum (ham çıktı §37 temizliğinde kaldırıldı).
- [Genel devir](../PROJE_DEVIR.md) §16; Maraton kapsamı [ayrı raporda](QA_MARATON_2026-10-07.md).
