# Terminal açılışı ve kullanılabilir Maraton — 7 Ekim 2026

Kullanıcı düz `flutter run` ile hedef hatasının tekrarlandığını ve Maraton'un kapalı kaldığını bildirdi. Bu tur uygulama yerel Maraton sunucusuyla gerçekten açıldı; açık uygulamada kullanıcı arayüzünden iki seanslık plan tamamlandı. Canlıya yazma veya Git push yapılmadı.

## Nedenleri

1. Sistem `xcode-select` hâlâ `/Applications/Xcode-26.6.app/Contents/Developer` seçiyor. Aynı Runner için `xcodebuild -showdestinations` yalnız uygun olmayan “iOS 26.5 is not installed” hedefi verdi. `/Applications/Xcode.app/Contents/Developer` (Xcode 27) ile **aynı iPhone 16 Plus / iOS 18.6 UUID'si uygun hedef** olarak listelendi. Yeni VS Code terminallerindeki ayar önceden açıktı; mevcut eski terminal bu ortamı sonradan alamaz. Runtime indirmek veya simülatörü yeniden yaratmak gerekmedi.
2. Düz `flutter run`, kök `.env` ile canlı backend'e bağlanır. Canlıda üç Maraton SQL paketi yoktur; istemci güvenli biçimde seçimi kapatır. Önceki QA sonrası yerel paketler de down ile kaldırıldığı için yerel seçenekler de kapalıydı. Bu kaynak kodun eski olması değildi.
3. Eski iki kayıtlı hızlı VS Code profili Dart'ın 3 sn varsayılan molasını kullanırken sunucu helper'ı 10 sn kullanıyordu. Her ikisine açık **10 sn** define eklendi.

## Tek komutla güncel Maraton

Depo kökünden:

```sh
tool/local_supabase/run_marathon.sh
```

Docker ve `supabase start --workdir tool/local_supabase` açık olmalı. Betik sabit yerel `supabase_db_pomosprint-local` konteynerini ve çalışma dizini etiketini doğrular. Yalnız eksik 500→600→700 paketini sırayla uygular; mevcut gövde, normal RPC hash'i ve özel tablo/RPC yetkilerini denetler. Kısmi/değişmiş/sırası bozuk şemayı silip sıfırlamaz. Kök `.env`, sistem Xcode seçimi ve canlı veritabanı değişmez.

Betik **Xcode 27 + iPhone 16 Plus / iOS 18.6** ile `lib/dev/local_qa_launcher.dart` çalıştırır. Gerçek uygulama akışı açılır; yalnız yerel debug QA için ayrı test hesabı otomatik girer ve Türkçe görünür. Üretilen `tool/local_supabase/.runtime/marathon-ios.json` Git dışında, dosya izni `600`'dür. Kişisel canlı hesap ve dış e-posta teslimi bu ortamda kullanılmaz.

Yerel test: **5/10 sn odak → 25/50 dk kayıt**, **10 sn mola + gerçek 60 sn Buradayım**. Normal canlı/release süreleri 25/50 dk ve 5 dk mola +1 dk onay olarak kalır. Ana ekranda 2/3/4 seçildiğinde güncel adımlı kart görünür. VS Code'da **PomoSprint (Maraton güncel, yerel demo)** aynı hazırlığı yapar.

Doğrudan Flutter kullanmak için önce hazırlık, sonra açık terminalde:

```sh
tool/local_supabase/run_marathon.sh --prepare-only
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter run -d BEA55019-D5C3-420F-90F2-0B0CBD5690CF \
  -t lib/dev/local_qa_launcher.dart \
  --dart-define-from-file=tool/local_supabase/.runtime/marathon-ios.json
```

Yalnız normal canlı uygulamayı açmak için `export` ardından `flutter run -d BEA55019-D5C3-420F-90F2-0B0CBD5690CF` kullanılır. Canlıda Maraton'u açmak ayrı [SQL Editor akışını](../supabase/tests/20261007_marathon_README.md) gerektirir; yerel önizleme canlı kurulum diye sunulmaz.

## Bu turda çalıştırılanlar

| Kontrol | Gerçek sonuç |
|---|---|
| Yanlış/doğru Xcode hedef sorgusu | Yanlış sürüm hatası tekrarlandı; doğru sürüm aynı UUID'yi listeliyor |
| Başlatıcı hazırlığı iki kez | Geçti; paketler yeniden körlemesine uygulanmadı, normal RPC hash'i değişmedi |
| Başlatıcı güvenlik/okuma/yapılandırma kontrolleri | 16/16 (ham çıktı §37 temizliğinde kaldırıldı); tekrar üretme (ham çıktı §37 temizliğinde kaldırıldı) |
| `flutter analyze` | 0 bulgu (ham çıktı §37 temizliğinde kaldırıldı) |
| `flutter test --concurrency=2` | 1142 geçti (ham çıktı §37 temizliğinde kaldırıldı), 5 isteğe bağlı görüntü testi bu tekrar koşusunda etkin değil |
| Başlatıcıyla gerçek iOS derleme/açılış | 24,3 sn derleme; doğru yerel backend ve hazır test hesabı, TEST rozeti |
| Gerçek UI ile 25×2 Maraton | İlk odak kaydoldu, mola sonrası 60 sn onay açıldı, dokununca ikinci odak başladı, +2 bonuslu tamamlanma diyaloğu görüldü |
| SQL + rapor toplamı | 2 ayrı UUID / 50 dk / 12 puan / 40 kum / 1 onay bileti (ham çıktı §37 temizliğinde kaldırıldı); UI aynı toplamı gösteriyor |

İki `category_invalid` debug mesajı görüldü; mevcut outbox yeniden eşleme akışı kategoriyi yeniden çözüp aynı seansları kaydetti. Son DB doğrulamasında iki ayrı kayıt ve doğru bonus bulunur; cihazdaki bekleyen/reddedilen seans anahtarları boş/yoktur. Bu mesajları çökme veya seans kaybı olarak sunmuyoruz. Yeni ürün Dart kodu değiştirilmedi; başlatma/hazırlık ve VS Code profilleri düzenlendi. Animasyon ve tüm altı planın iki platformdaki kapsamı önceki [UI/onay QA](QA_MARATON_PRESENCE_2026-10-07.md) içindedir; bu tur yalnız 25×2 gerçek UI tekrarını ekler.

Görüntüler: tamamlanma (ham çıktı §37 temizliğinde kaldırıldı), 50 dk rapor (ham çıktı §37 temizliğinde kaldırıldı), kullanıcıya bırakılan dört adımlı kart (ham çıktı §37 temizliğinde kaldırıldı).

## Kullanıcıya bırakılan ortam

Yerel üç Maraton paketi ve hızlı kayıt yardımcıları **açık bırakıldı**, down/QA temizliği yapılmadı. Docker çalışıyor. iPhone 16 Plus / iOS 18.6'da ayrı yerel test hesabı ile dört seanslı güncel kart, MARATONU BAŞLAT düğmesi ve TEST rozeti açık. Aktif odak yoktur. `flutter run`'dan `d` ile ayrılındı; Runner PID **33614** doğrulandı. Kullanıcı bu karttan kendi denemesini yapabilir; aynı başlatıcı tekrar kullanılabilir.

Canlı Maraton SQL'i hâlâ uygulanmadı. `AGENTS.md §2.4` gereği kullanıcı SQL Editor'de üç paketi uygular; ön koşullar ve DRYRUN/down dosyaları hazırdır. Fiziksel cihaz, mağaza dağıtımı ve yeni canlı doğrulama bu turun kapsamı değildir. Bu ortam notu, önceki QA raporundaki temizlenmiş/normal canlı uygulama durumundan daha yenidir.
