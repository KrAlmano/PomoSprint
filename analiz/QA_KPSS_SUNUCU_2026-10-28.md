# KPSS sunucu doğrulaması — 28 Ekim 2026

Yerel KPSS paketi: **242/242 SQL**, **74/74 ağsız guard/oracle/host/parite** ve **5/5 salt okunur şema paritesi** geçti. Canlıya uygulanmadı.31 kurulmadı; mevcut DUS review/site ve ana veritabanlarına yazılmadı. Native ve tam130dakika bekleme testi bu raporun kapsamı değildir.

## Kaynak ve sözleşme

Yeni paket numarası açılmadı.28 kataloğa12 ayrı KPSS sınav/testi ekler.32 aynı12 türün ödülünü yeni politika ile günceller; toplam20 tür vardır.27/29 zaten `kpss` hedefini desteklediğinden değiştirilmedi. İki JSON kataloğunun önceki8 satırı `HEAD` ile birebir aynı kaldı.

| Deneme | Süre | Soru | Kum | Puan |
|---|---:|---:|---:|---:|
| KPSS Lisans GY–GK |130dk|120|105|26|
| KPSS Ön Lisans GY–GK |130dk|120|105|26|
| KPSS Ortaöğretim GY–GK |130dk|120|105|26|
| İşletme, Muhasebe, Hukuk, Kamu Yönetimi, İktisat, Maliye, Uluslararası İlişkiler, Çalışma Ekonomisi ve Endüstri İlişkileri (her biri ayrı) |50dk|40|40|10|
| İstatistik |60dk|40|50|12|

Üç GY–GK türünde iki60 soruluk resmî test kullanılır; kılavuzdaki yaklaşık alt ders ağırlıkları kesin kota olarak sunulmaz. Alan Bilgisi dokuz ayrı testtir. Net = doğru − yanlış/4; resmî standardize KPSS puanı değildir. AYT dışındaki hiçbir tür erken bitirilemez. Ders eşlemeleri ve TR/EN adları [JSON katalog](../supabase/proposed/exam_catalog_32.json) ile istemci paritesine tabidir. Resmî kaynaklar [sınav kaynakları raporundadır](SINAV_KAYNAKLARI_2026-10-28.md).

## Çalıştırılan kontroller

- Boş baseline doğrulandı; yalnız yeni `pomosprint_review32_kpss` oluşturuldu.27→28→29→30→32 zinciri, her DRYRUN ve boş-veri ters sıra roundtrip geçti.28 DRYRUN20,32 DRYRUN17 yapısal kontrol içerir.
-20 türün tam ödülleri ve idempotent ikinci tamamlama çağrıları doğrulandı.12 KPSS türünde erken bitiş reddi, ret sonrası bütün veri hash'lerinin korunması, doğru/yanlış/boş ve net kaydı, kota aşımı reddi ve başka sahibin sonuçlarını okuyamaması doğrulandı.
- KPSS odasında yalnız13 KPSS fixture sahibinin yer alması,25kişilik kapasite, gizli profillerin kimlik maskelemesi ve görünürlük açıkken global sıralamada DUS/KPSS'nin birlikte görünmesi doğrulandı. Ay ortasında hedef değişimi mevcut hedefi/puanı taşımadı, sonraki ay için beklemeye alındı.
-32 öncesi KPSS denemesi5kumluk snapshot'ını korudu; yeni105kumla yeniden yazılmadı. Önceki AYT7/175kum snapshot'ları, yeni AYT90dk72kum/18puan,1saniye0dakika/0puan ve eşzamanlı çağrıda tek ödül doğrulandı.
- Özel başlık/not, kısmi net, revision, owner RLS, anon yetkileri, veri kaybettiren down reddi, normal cüzdan/seans/Maraton/önceki avatar korunması ve bütün fixture denemelerinin terminal olması geçti.
- KPSS paritesi şema, migration listesi, katalog, kapalı welcome tetikleyicisi ve orantılı ödül politikasını doğruladı. Ref: `tool/local_supabase/parity/reviewed_exam32_kpss_20261028.json`.

## Kanıt ve tekrar

[Taşınabilir sonuç ve dosya özeti](kanit_kpss_2026-10-28/INDEX.md). Ham yerel SQL/snapshot kanıtları `build/isolated32_kpss/20261028T195601Z-416360a4/` altında tutulur. Yerel zaman kaydırmaları kontrollü fixture'dır; gerçek süre beklendiği iddia edilmez.

İlk tur `20261028T195453Z-32f7381f`, testin bütün fixture'ları gizli oluşturmasına rağmen görünür ID beklemesi nedeniyle durdu. Salt okunur inceleme odanın13 doğru KPSS üyesi taşıdığını gösterdi. Test, gizlilik maskesi ve görünür global projeksiyonu ayrı doğrulayacak şekilde düzeltildi. Bu yeni test DB'si `pomosprint_review32_kpss_failed_20261028` adıyla, verisi ve başarısız kanıtıyla korundu; başarılı tur temiz baseline'dan yeniden kuruldu. Arşivleme sonrası yardımcı Python OID karşılaştırmasındaki str/int tür farkı yalnız kanıt assertion'ını etkiledi; sonraki salt okuma arşiv ile yeni hedefin ayrı ayrı varlığını doğruladı. Hiçbir veritabanı silinmedi.

```sh
python3 -m unittest tool/local_supabase/test_isolated32_check.py tool/local_supabase/parity/test_exam32_parity.py tool/local_supabase/e2e/test_isolated32_stack.py tool/local_supabase/e2e/test_verify_reports_and_exams.py -q
(cd tool/local_supabase/e2e/sim && python3 -m unittest test_exam32_host.py -q)
python3 tool/local_supabase/parity_check_exam32.py --profile kpss
```

Sabit isimli SQL runner mevcut DB'yi tekrar oluşturmaz/ezmez; aynı komutun yeniden `--apply-tests` ile çağrılması bilinçli olarak reddedilir. Yerel native test için API54401, REST54402, Auth54403, iOS host54409 hazırlanmıştır. Stack başlatma ve cihaz doğrulaması ayrıca koordine edilir.
