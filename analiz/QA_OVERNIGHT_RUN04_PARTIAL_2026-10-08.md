# Gerçek süreli gece QA — 8 Ekim 2026

Koşu `overnight1007_04`: **TAM GEÇİŞ DOĞRULANAMADI**. 53/72 bağımsız son kontrol geçti. Bu rapor manager tarafından gerçek sonuç dosyalarından otomatik üretildi; bitiş beklenmeden başarı varsayılmadı.

Yalnız JSON içinde passed=true olan kontroller doğrulanmıştır; bu girişim bütün gecenin başarılı testi olarak raporlanmaz.

Yerel Supabase, Pro iOS simülatörü ve Android emülatörü; üç ayrı Auth/API gözlem hesabıyla toplam beş yeni kimlik. Odaklar gerçek 25/50 dk, mola 300 sn ve onay 60 sn. Son çalışma sınırı `2026-10-08T04:00:00+00:00`; kullanıcı Plus önizlemesi korunur.

Okunabilen gerçek DB toplamı: **14 kayıt / 500 dakika / 114 puan / 280 kum**. Çekirdek senaryo beklentisi 5 kayıt/150 dakika/31 puandır; geceyi dolduran ve 04:00 çalışma günü sınırını geçen seanslar için dinamik UUID ledger kontrol sonuçları JSON içindedir. Sabit 350/80 bütün gecenin sonucu sayılmadı.

| Hesap | Seans | Dakika | Puan | Kum |
|---|---:|---:|---:|---:|
| 1 | 8 | 250 | 53 | 160 |
| 2 | 6 | 250 | 61 | 120 |
| 3 | 0 | 0 | 0 | 0 |
| 4 | 0 | 0 | 0 | 0 |
| 5 | 0 | 0 | 0 | 0 |

Başlangıç zamanı, gerçek elapsed clock, normal/Maraton puanı, duraklatma cezası, bitmemiş Maratonun ilk seansının korunması, mola/onay süresi, çalışma günü, rapor UUID/kategori toplamları ve hesap izolasyonu JSON kontrol listesinde ayrı ayrı yer alır. Bağımsız API oturumlarının kendi seansları, arkadaş kimlikleri ve bitişte sosyal presence sonuçları `api_facts` içindedir; eksik veya başarısız kontrol geçilmiş sayılmaz.

Örnekleme kapsamı ayrıca denetlendi: beş hesaplı API 282 örnek, en büyük aralık 60.636 sn (sınır150); sunucu config 57 örnek, en büyük aralık 301.645 sn (sınır360). Başlangıç ve hedef bitişe yakın örnekler zorunludur; tek başarılı örnek bütün gecenin doğrulaması sayılmaz. Ayrıntılı timestamp kapsamı `sampling_coverage` içindedir.

Ham cihaz başlangıcı ile DB başlangıcı arasında SessionQueue/ServerClock HTTP Date saat düzeltmesi uygulanır. Her UUID için iki zaman ve gözlenen fark kaydedildi; yerel başlık yuvarlama payı en fazla 2 saniyedir. Gerçek cihaz elapsed süresinin ve sunucu seans aralığının 1500/3000 saniye koşulları ayrıca kontrol edilir; bu pay odak süresini kısaltmaz.

Gerçek OS process kill/background testi yapılmadı; native yön/orientasyon ve gerçek sekme geçişleri ayrı UI kanıtıdır. Fiziksel cihaz, canlı DB ve mağaza yayını bu turun kapsamında değildir. Canlıya okuma/yazma yapılmadı. Parola/e-posta/JWT rapora kaydedilmedi.

Kanıt klasörü: `analiz/qa_evidence_20261008/overnight_real/run04`. Giriş dosyaları `final_rollup.json`, `overnight_state.json`, `native_framework_summary.json`, `cleanup.json`, API/DB/config-watch JSONL ve native loglardır.

Doğrulanamayan kontroller:
- `two_native_success_reports`
- `both_native_frameworks_teardown_and_pass`
- `manager_reached_requested_deadline`
- `five_account_api_sampling_covers_requested_night`
- `real_config_sampling_covers_requested_night`
- `slot1_final_three_report_tabs_cover_full_ledger`
- `slot1_independent_auth_rls_read`
- `slot2_exact_owner_uuid_set`
- `slot2_one_real_clock_observation_per_uuid`
- `slot2_final_three_report_tabs_cover_full_ledger`
- `slot2_fixed_core_scenario_totals`
- `slot2_dynamic_expected_totals`
- `slot2_real_boundary_and_reports`
- `slot2_streak`
- `slot2_started_at_daily_totals_and_cap`
- `slot2_marathon_expectations`
- `slot3_independent_auth_rls_read`
- `slot4_independent_auth_rls_read`
- `slot5_independent_auth_rls_read`

Başlangıç doğrulaması: 1174/1174 Flutter testi (0 atlama), temiz analiz, 18/18 host kontrolü; iOS ve Android debug derlemeleri geçti. Ayrıntılar üst kanıt klasöründedir.

İlk başlatma girişimi beş Auth hesabı ve arkadaş ağından sonra görüntü yolu hatasıyla durdu; tamamlanmış seans yoktu. Yol düzeltildi ve temizliği doğrulandı. Sonraki iki girişim Android yazılım çizicisinin işlemci yükü nedeniyle ilk 25 dk tamamlanmadan durduruldu; ikisinde de 0 kayıt ve sahip süreçlerin temizliği doğrulandı. Önceki kanıtlar silinmedi.

Bu koşudaki Android yatay görüntüsü yerleşim tamamlandıktan sonra görsel okundu: kum saati, sayaç, duraklatma hakkı, duraklatma ve durdurma düğmeleri doğru görünüyor. Önceki girişimlerde geçiş ortasında alınan görüntü son yerleşimin kanıtı sayılmadı; test görüntüsü öncesi bekleme düzeltildi.

Uzun gece testinde yalnız test binding çizimi seyreltilir: odak beklerken yaklaşık saniyede bir kare, etkileşim sırasında daha sık kare. Live binding gerçek Timer/DateTime kullanır; fake saat, süre atlatma ve ürün animasyonu değişikliği yoktur. Bu koşu animasyon akıcılığı ölçümü sayılmaz. Android için süreç özelinde LP_NUM_THREADS=2 kullanılır; [Mesa resmi açıklaması](https://docs.mesa3d.org/envvars.html#lp-num-threads).

Gece sırasında test aracının zaten görünür düğmeye dokunmadan önce kontrolleri gereksiz kaydırdığı bulundu. Yalnız integration_test/support/e2e.dart düzeltildi; ürün yerleşimi ve kum saati değişmedi. Ayrı iPhone 16e native kontrolünde boşta, odakta, duraklatılmış, devam edilmiş ve ikinci duraklatma reddedilmiş beş durumda kategori tamamen görünür ve kaydırma 0 doğrulandı. Gerçek 50 dk modunda başlatılan bu kısa kontrol iptal edildi; seans/puan/kum üretmedi. Kanıt visible_tap/result.json. Ana gece binary’si önceki helper ile çalışmayı sürdürdü; yeni helper çalışıyor gibi sunulmadı. Bu değişiklikten sonra 1169 birim/widget testi ve ayrı etkinleştirilen 5 görüntü testi geçti (1174 farklı vaka); analiz temizdi.

Görsel kanıt: 68 çekim olayı, 61 benzersiz ana PNG yolu. Tekrarlanan adlar eski PNG üzerine yazabiliyordu; yerel arşivleyici başladıktan sonra 28 yeni olayın bytes/hash/zamanı ayrı korundu. İlk gözlemde 36 mevcut PNG korundu; 4 önceki üzerine yazılmış olay geri getirilemedi ve ayrı görsel kanıt sayılmadı. Olay sayısı korunan benzersiz görüntü sayısı değildir. Arşiv ayrıntıları archived_screenshots/archive_events.jsonl ve archive_status.json; uygulama/native host değiştirilmedi.
