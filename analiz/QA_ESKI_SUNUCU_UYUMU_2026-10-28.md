# Eski sunucu uyumluluğu — 28 Ekim 2026

Güncel istemci kaynaklarıyla tek hedefli Flutter turu: **105/105 PASS**, çıkış
kodu 0, yaklaşık 7 saniye. Log:
`/tmp/pomosprint_old_server_compat_targeted_20261028.log`.

Bu sonuç birim/widget/sözleşme testidir; **gerçek eski sunucuya karşı yeni
bir HTTP E2E koşusu yapılmadı**. Sunucu yanıtları bu testlerde fake/mock
arka uçlarla üretilir. Maraton süre testleri kontrollü saati ilerletir;
gerçek 25/50 dakikalık bekleyiş kanıtı değildir.

## Çalıştırılan dosyalar ve kapsam

Yollar aktif `/Users/almano/Desktop/Projects/Pomodoro` köküne göredir.

| Test dosyası | Bu turda doğrulanan davranış |
|---|---|
| [test/exam_service_test.dart](../test/exam_service_test.dart) | Eksik RPC (`PGRST202`) Deneme kullanılabilirliğini kapatır; normal seans engeli oluşmaz; Deneme başlatma RPC'si gönderilmez. Ayrıca kalıcı başlatma/yeniden deneme, tamamlanma ve vazgeçme sözleşmeleri. |
| [test/exam_screen_test.dart](../test/exam_screen_test.dart) | Kullanılamayan Deneme kataloğu açıklaması görünür, başlatma düğmesi pasiftir; TR/EN ve farklı ekran boyutları. |
| [test/exam_history_freshness_test.dart](../test/exam_history_freshness_test.dart) | Eski sunucunun eksik RPC'si ve bilinçli kapatılmış özellik ağ kesintisi gibi gösterilmez; gerçek hata/bozuk yanıt ayrımı korunur. |
| [test/league_launch_policy_test.dart](../test/league_launch_policy_test.dart) | Yeni lig RPC'si yalnız `PGRST202` durumunda eski RPC'ye döner; izin/ağ hataları başarıya çevrilmez; eski lig kuralları ayrıştırılır. |
| [test/monthly_competition_client_test.dart](../test/monthly_competition_client_test.dart) | Yeni aylık sözleşme açık sürüm/alanlarla tanınır; eski sunucuda eski aylık sekme korunur ve yeni hedef düzenleyici gösterilmez. |
| [test/session_queue_test.dart](../test/session_queue_test.dart) | Normal seans kuyruğu, diske önce yazma, offline yeniden deneme, kategori eşleme, hesap ayrımı, saat düzeltmesi ve tekilleştirme. Gerçek eski RPC uygulaması bu dosyanın kapsamı değildir. |
| [test/marathon_queue_contract_test.dart](../test/marathon_queue_contract_test.dart) | Eski bağımsız seanslar Maraton'a dönüşmez; Maraton kimliği disk/kategori eşlemesinde korunur; puan sunucu yanıtından okunur; tekrar yanıtı yeni ödül sayılmaz. |
| [test/marathon_timer_test.dart](../test/marathon_timer_test.dart) | Kontrollü saatle 25/50 dakika, Maraton zinciri, 300 saniye mola/60 saniye onay, kapanıp açılma ve kayıt akışı. Maraton capability'si kaybolduğunda yeni plan kapanır, normal BAŞLAT açık kalır; mevcut plan geri yüklenebilir. |

Komut:

```sh
flutter test test/exam_service_test.dart test/exam_screen_test.dart \
  test/exam_history_freshness_test.dart test/league_launch_policy_test.dart \
  test/monthly_competition_client_test.dart test/session_queue_test.dart \
  test/marathon_queue_contract_test.dart test/marathon_timer_test.dart
```

## Gerçek eski HTTP testi neden çalıştırılmadı?

Mevcut
[client_compat_e2e_test.dart](../tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart)
yalnız REST çağrılarını ayrı PostgREST'e yönlendirir. Auth çağrıları sabit
`127.0.0.1:54321` adresinde kalır; test yeni hesabı ana yerel Auth'ta açar,
hesabı kopya veritabanına taşır ve temizlerken hem kopyadan hem ana
`postgres` veritabanından siler. Dolayısıyla ayrı `CHAIN_DB` ve REST portu
vermek tam izolasyon sağlamaz. Mevcut test ayrıca eski 20–25 paketlerinin
kapsamını taşır; yeni Deneme/normal25/normal50/Maraton E2E paketi değildir.

Bu geceki aktif gerçek süreli QA kayıtlarını korumak için söz konusu test
çalıştırılmadı; yeni sunucu/cihaz kurulmadı. Ana yerel veritabanında yalnız
veritabanı adlarının sistem kataloğu okundu; kullanıcı/şema/container
değişikliği yapılmadı. Canlı servis veya `.env` kullanılmadı.

`client_compat` klasöründe mevcut README bulunmadığından ek README
oluşturulmadı. İleride tam eski HTTP E2E için Auth'ın da ayrı veritabanına
bağlandığı veya yalnız izole veritabanında oluşturulmuş hesaplarla çalışan
bir düzenek gerekir; mevcut varsayılan komut bu güvenceyi vermez.
