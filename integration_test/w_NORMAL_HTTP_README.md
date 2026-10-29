# w — gerçek 25 dakika, HTTP kesintisi ve süreç yeniden başlatma

Kaynak: `w_normal_http_restart_test.dart`. **Yalnız yerel QA ve açık opt-in**. Ürün sayacı 1.500 saniyedir; tarih, saat, katalog, süre veya sunucu fonksiyonu değiştirilmez. E2E host SQL erişimi salt okumadır. Bu test fiziksel Wi-Fi/uçak modu testi değildir.

İki ayrı native çalıştırma gerekir. Aynı cihaz, uygulama kurulumu/verisi ve koşu kimliği korunmalıdır. Her fazın zaman aşımı 35 dakikadır; ilk faz gerçek 25 dakika + kurulum süresi sürer.

## Ortak parametreler

```text
E2E_NORMAL_HTTP_REAL25=true
E2E_RUN_ID=night-w-ios18
E2E_HTTP_PROXY=true
E2E_PROXY_ADMIN_PORT=54326
```

Mevcut çalıştırıcılar iOS'ta ve `adb reverse` kullanan Android'de `SUPABASE_URL=http://127.0.0.1:54325` verir. Android host köprüsü gereken ayrı kurulumlar için kaynak `http://10.0.2.2:54325` adresini de kabul eder; mevcut wrapper yolunda buna gerek yoktur. Yerel E2E host ve yerel public anahtar mevcut native çalıştırıcı üzerinden verilir. Anahtarları bu belgeye veya komut günlüğüne yazmayın. Proxy ortak olduğundan **başka 54325 kullanan testle eşzamanlı çalıştırmayın**; doğrudan 54321 kullanan diğer cihazlar etkilenmez.

1. `E2E_NORMAL_HTTP_MODE=start`: yeni `e2e-sim-http-normal-<RUN>@pomosprint.local` hesabı ile uygulamadan gerçek 25 dakika başlatılır. Sunucu rezervasyonu alındıktan sonra HTTP503 etkinleşir. Doğal bitişte cihazda tek outbox kaydı, sunucuda henüz yeni satır/ödül olmadığı doğrulanır. Kalıcı kanıt yazılır. **Başarılı ilk faz proxy'yi kapalı bırakır.** `START-STAGE PASS` henüz uçtan uca başarı değildir.
2. Uygulama OS sürecini kapatın ve çıkışını kaydedin. iOS'ta seçili QA UDID için `simctl terminate`, Android'de seçili emülatör için `am force-stop com.pomosprint.app` kullanılabilir. Cihazı sıfırlamayın, uygulamayı kaldırmayın, verisini temizlemeyin. Sadece widget ağacını yeniden kurmak bu test için yeterli değildir.
3. Aynı parametrelerle `E2E_NORMAL_HTTP_MODE=resume`: uygulama HTTP503 altında yeniden açılır. OS PID farklı, hesap aynı, outbox kaynak alanları aynı olmalıdır. Ardından proxy açılır ve gerçek uygulama senkronu çalışır. Tek 25 dakikalık satır, +5 normal puan/+20 kum, değişmeyen deneme cüzdanı, bir lig olayı ve doğru çalışma günü/seri doğrulanır. Tekrar gönderim ikinci satır veya ödül üretmez. Günlük/haftalık/aylık UI veri toplamları bağımsız SQL ile kıyaslanır. Ancak `FINAL PASS` ve genel native test başarısı final kanıtıdır.

Hata durumunda `finally` proxy'yi yeniden açar. İlk fazdan sonra hiç resume yapılmayacaksa proxy'nin tekrar açılması çalıştırıcının sorumluluğundadır. Başarılı finalde de açılır. Test, hesap/geçmiş/veri veya kanıt kaydını silmez; I-21 temizliği ayrı yapılır. Yarım koşuyu aynı kimlikle yeniden `start` yapmayın; kaydı varsa `resume`, yoksa yeni koşu kimliği kullanın. Başka tamamlanmamış `r`/`w` probe kaydı bulunan uygulama kurulumu korunur ve yeni başlangıç reddedilir.

## İsteğe bağlı karışık geçmiş

Varsayılan yeni hesap boştur. Deneme sürelerinin ortak raporlara da girdiğini aynı native turda kontrol etmek için önce bu **tam e-posta** ile yeni yerel fixture hesabı oluşturulabilir:

```sh
python3 tool/local_supabase/e2e/create_exam_qa_fixture_account.py \
  --email e2e-sim-http-normal-night-w-ios18@pomosprint.local
```

Ardından `start` fazına `E2E_NORMAL_HTTP_PRESEEDED=true` eklenir. Test hazır hesabı kullanır; yeniden kayıt veya geçmişe yazma yapmaz. En az bir tamamlanmış deneme bulunması zorunludur. Hazırlayıcı iki kontrollü 165 dakikalık TYT geçmişi oluşturur; bunlar **gerçekte beklenmiş 330 dakika değildir**. Gerçek 25 dakikalık yeni odakla lifetime toplam 355 dakikaya çıkar; gün/hafta/ay toplamları kayıtların kendi tarih aralıklarına göre hesaplanır. Bu modun başlangıç kanıtı önceki satırları ve ekonomi değerlerini saklar, bitişte değişmediklerini kontrol eder.

Hazırlayıcı yalnız `e2e-sim-exam-fixture-<1–40 küçük harf/rakam/tire>` ve `e2e-sim-http-normal-<aynı sınır>@pomosprint.local` isim alanlarını kabul eder. Yeni `http-normal` izni yalnız bu yeni QA hesabına aynı iki tarihsel TYT fixture'ını hazırlamaya yarar; kişisel e-posta, başka domain/isim alanı veya mevcut hesabı değiştirme izni vermez. Her iki yolda mevcut e-posta ilk salt-okuma kontrolde reddedilir; yerel bağlantı, yeni owner ve exact allowlist korumaları değişmez.

Başka normal/Maraton fixture'ları kullanılacaksa bunlar yalnız bu yeni QA hesabında, ayrı açık fixture hazırlığıyla oluşturulmalıdır; `w` onların tarihini veya ödülünü düzenlemez. Fixture hesabı 12 saatten yeni olmalı ve aktif denemesi/odağı bulunmamalıdır. Başka kullanıcıların veya önceki testin hesabı yeniden kullanılmaz.

28 Ekim `night-w-ios18` için `extend_w_mixed_fixture.py` yalnız açık UID/e-posta eşleşmesinde bir normal25, iki25 dakikalık tamamlanmış Maraton odağı ve bir vazgeçilmiş TYT ekledi. İlk işlem ROLLBACK ile doğrulandı; sonra aynı kontrollerle commit edildi. Ödüller authenticated public tamamlama fonksiyonları tarafından hesaplandı; yalnız yeni Maratonun mola/onay zamanları ve yeni vazgeçilen denemenin zamanları tarihsel fixture olarak yazıldı. **Bu sentetik onay kaydı, gerçek5 dakika mola veya Buradayım tıklaması kanıtı değildir.** Gerçek mola/onay `s`/`v` koşularının konusudur. Eski iki TYT ve netlerinin tam hashleri korundu. Başlangıç405dk / normal17puan60kum / deneme66puan12kum; gerçek25 sonrası430dk / normal22puan80kum beklenir. Tekrar hazırlama girişimi reddedildi ve hesap değişmedi. Ayrıntı: `build/overnight_backend/w_mixed_fixture_71ffd38f-84db-4003-b785-840ea83bb477.json`.

Bu tamamlanmış tek kullanımlık yardımcı, 29 Ekim 2026 temizliğinde aktif kaynaklardan kaldırıldı; tarihsel kaynak `889cab0` commit'inde korunur. Yukarıdaki kayıt geçmiş doğrulamayı anlatır, yeniden çalıştırma talimatı değildir. Yeni karışık veri senaryoları desteklenen `w_normal_http_restart_test.dart` ve `ad_verify_reports_exams_test.dart` akışları için yeni, ayrı bir QA kurulumu ile hazırlanır; eski UID/baseline yeniden kullanılmaz.

## Kanıt kapsamı

- Gerçek 25 dakika: monotonic geçen süre, değişmeyen başlangıç/bitiş, normal uygulama sayacı ve son kuyruk kaydı.
- Süreç kapanışı: test iki fazda farklı OS PID ister; çalıştırıcının kapatma/çıkış günlüğü ayrıca saklanmalıdır.
- Tamamlanma: tek kaynak UUID, değişmeyen önceki satırlar, bağımsız sabit ödül, tek aylık lig olayı, çalışma günü/seri ve tekrar gönderim.
- Raporlar: gerçek uygulamanın günlük/haftalık/aylık widget verisi; normal/Maraton/deneme adetleri, dakika toplamı ve ayrı deneme kategorisi salt okuma SQL ile karşılaştırılır. Ayın/DST'nin doğal geçişi beklendiği iddia edilmez.
- `e2e-normal-http-*` ekran görüntüleri ve native iki faz günlüğü saklanmalıdır. İlk fazı tek başına tamamlanmış test diye raporlamayın.
