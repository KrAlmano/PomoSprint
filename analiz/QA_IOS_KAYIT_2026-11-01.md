# iOS kayıt/onboarding denemesi — 1 Kasım 2026

## Sonuç: tamamlanmadı

YKS kayıt akışı `integration_test/a_register_onboarding_test.dart` içindeki **yalnız a1** senaryosuyla, iPhone 17 simülatöründe `com.pomosprint.qa.nov1onboard` ayrı QA uygulama kimliği ve sadece yerel Supabase/Mailpit kullanılarak denendi. Doğal Android 50 dakika testi ve normal PomoSprint/HocamMacVar uygulamaları ayrıydı. Kayıttan önce, kullanılması planlanan yeni yerel QA e-postasına ait hesap sayısı 0 ve QA bundle kurulu değildi.

Xcode debug simulator derlemesi 29,1 saniyede tamamlandı. Uygulama yerel Supabase'e bağlanıp girişten **Yeni Hesap Oluştur** formuna geçti. Formdaki alanlar boşken metin giriş aşamasında ilerleme durdu; [ekran görüntüsünde](kanit_2026-11-01/ios/onboarding-stalled.png) bir sistem izin penceresi görünmüyor. Yaklaşık 45 saniye arayla alınan iki kısa süreç örneğinde, ana iş parçacığı `FlutterTextInputPlugin` → iOS `RemoteTextInput` bağlantısı içinde, başka bir iş parçacığı Sentry sınıf taraması ve `dyld` okuma yolu içinde beklerken gözlendi. Bu gözlemler bir simülatör koşusunun tanısıdır; **kesin kök nedeni veya fiziksel cihaz davranışını kanıtlamaz**.

Yaklaşık 3 dakika 17 saniyede ilerleme oluşmadığından, Android gerçek 50 dakika finalinin planlanan saatine engel olmaması için yalnız bu QA Flutter test süreci kontrollü kesildi. Test günlüğü `did not complete`, süreç çıkışı 1 olarak kaldı; sonlandırma sırasında Flutter'ın geçici dinleyici klasörü temizliğinde ayrıca yol bulunamadı mesajı verdi. Bu koşu PASS veya otomatik test timeout'u değildir. Durdurma sonrası QA uygulaması ve kendi veri alanı korunuyordu; yerel Auth'ta bu denemeye ait hesap sayısı hâlâ 0 idi. Başka kullanıcının hesabı veya verisi silinmedi. Ayrı geçici kanıt hostu kapatıldı.

## Kanıt sınırları ve sonraki adım

Bu tur gerçek kayıt, Mailpit doğrulama bağlantısı, giriş, yaş adımı veya onboarding tamamlanmasını **doğrulamadı**. 13 yaş altı engeli test edilmedi ve yaş kuralı değiştirilmedi. Mailpit zaten kişisel e-posta kutusuna gerçek teslim kanıtı değildir. Önceki tarihli başarılı iOS/Android kayıt turları bu yeni denemeyi başarılıya çevirmemektedir.

Sonraki turda aynı sorunu bağımsız olarak yeniden üretmek, simülatör/yazı girişi ve Sentry native yükleme sırasını incelemek; ardından yeni QA hesabıyla kayıt ve onboarding'i tekrar çalıştırmak gerekir. Sistem uygulamalarını, kişisel simulator verilerini veya bekleyen seansları sıfırlayarak test geçişi üretilmemelidir. Gerçek cihazda yazı girişi ve kayıt ayrıca doğrulanmalıdır.

Kişisel bilgi içermeyen test günlüğü ve tanı özeti [güvenli kanıt dosyasındadır](kanit_2026-11-01/ios/onboarding-safe.txt).

Kanıtlar kaydedildikten sonra yalnızca bu turun ayrı QA uygulaması simülatörden kaldırıldı; normal uygulamalar kaldırılmadı. Yeniden denemede ayrı bir QA kimliği kullanılmalıdır.
