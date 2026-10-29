# Uygulama, veritabanı ve site doğrulaması — 28 Ekim 2026

**A, yeni DUS/ödül akışları ve Safari site doğrulaması tamamlandı. Chrome doğrulaması ortam engeli nedeniyle yapılamadı.** Bu rapor yeni A/B talebinin sonuçlarını toplar. Çalışılan depo `/Users/almano/Desktop/Projects/Pomodoro`, dal `codex/gece-2026-10-27`. Canlı Supabase/Resend/siteye işlem veya deploy yapılmadı; main değiştirilmedi. Kök `.env` agent tarafından açılmadı/değiştirilmedi. Bütün hesaplar ve veriler yerel, uydurmadır.

Ana yerel sunucuda 27–30 paketleri doğrulandı. **31 uygulanmadı; kullanıcı kararı bekliyor. 31 sonrası Maraton testi yapılmadı.** Kısa sınav pencerelerinin sonunda resmî yedi katalog satırı birebir geri yüklendi; özgün gerçek75 kaydı değişmedi; son parite exit0.

## GitHub yedekleri

- Başlangıç: `fb70839ecd36ce314da5389928ef01fa5e40ce00`; mevcut36commit yalnız çalışma dalına push edildi. Temiz ağaçla984yol ve yeni bloblar incelendi: yasaklı dosya ve50MB üstü blob yok; en büyük1.355.247bayt.
- İki ürün düzeltmesi: `11ea62c` kısmi/offline net journal; `8446eff` otomatik ve elle boş/negatif/toplam doğrulaması. Her biri ayrı tam analiz/Flutter/Node kapısından geçti.
- A sonu: `4be1b9c` (418dosya) temiz ağaç ve dosya/blob kontrolüyle aynı dala push edildi. Yeni DUS/ayrıntı kodu `8cb3dc9` (226dosya) olarak kaydedildi. Son Deneme arayüzü `641cc16` (19 dosya) commit’indedir. Site, taşınabilir kanıtlar ve devir belgesi bu raporun son commit’iyle aynı dalda izlenir; son push hash’i kullanıcıya kapanış mesajında bildirilir. Main push/merge/force push/deploy yok.
- Dal: https://github.com/KrAlmano/PomoSprint/tree/codex/gece-2026-10-27

## Kanıtın kapsamı

Yeni gerçek75 dakika, doğal60 saniyelik yerel katalog testleri ve kontrollü geçmiş/ay/saat dilimi fixture'ları ayrı raporlandı. Resmî metadata tablosu yedi sınavın tamamının gerçek tam süresinin beklendiği anlamına gelmez. Native faz seçimlerinin amaçlı atlamaları, çalıştırılmamış faz için başarı sayılmadı. Fiziksel cihaz/sağlayıcı girişleri ve mağaza imzalama bu tur kapsamında değildir.

Taşınabilir kanıtlar `analiz/kanit_dogrulama_2026-10-28/INDEX.json` altında özgün kaynak ve arşiv çıktısı SHA256/boyutlarıyla saklanır. Aşağıdaki `/tmp` ve `build` yolları özgün çalışma kaynaklarıdır; başka bilgisayarda arşivlenmiş karşılıklarını kullan. Tam verbose Xcode günlükleri, ham tercihler ve anahtarlar depoya alınmaz. Ekranlar `analiz/ekran_dogrulama_2026-10-28/` altındadır.

## Kanıt anahtarları

| Anahtar | Dosya / kapsam |
|---|---|
|O-I / O-A|`/tmp/pomosprint_verify_ios_official_retry.log` / `/tmp/pomosprint_verify_android_official.log`; iOS ve Android resmî katalog fazı|
|S-I / S-A|`/tmp/pomosprint_verify_ios_short_retry2.log` / `/tmp/pomosprint_verify_android_short_retry.log`; her platformda7 sınav×TR/EN doğal 60 sn|
|S-restore|`build/verification_20261028/ios_short_retry2_run.json`, `android_short_retry_run.json`; exact catalog restore, R75 değişmezliği, son parity exit0|
|R-OS|`android-catalog-cycles-a1.json`, `ios_tyt_lifecycle_recovered.json`, `ios-ayt-a2-recovered.json`, `ios-catalog-cycles-a3.json`, `joint_catalog_cycles_v3_a3.json`;14 kısa OS/offline finali|
|R75|`build/verification_20261028/real75_final.json`, `/tmp/pomosprint_verify_android_r75_resume.log`; yeni gerçek4500 sn finali|
|DB7|`build/verification_20261028/independent_inventory/summary.json` ve aynı klasördeki7 oracleJSON; 1087/1087, warnings=[]|
|DB-final|`build/verification_20261028/final_oracles/summary.json`;23 hesap,568/568 PASS,warnings boş. R75 peer RLS:16 dolu attempt/14 cüzdan. Boş net kaynakları SKIP.|
|DB-S|`build/verification_20261028/android_short_retry_independent.json`; 738/738, warnings=[]|
|DB-AH|`build/verification_20261028/android_failed_short_recovered_independent.json`; 205/205, warnings=[]|
|W|`build/verification_20261028/android_mixed_w_preflight.json`; 211/211, warnings=[]; RLS ekli önceki `verifier_mixed_w_rls.json`214/214|
|W-I / W-A|`/tmp/pomosprint_verify-ios-reports.log` / `/tmp/pomosprint_verify-android-reports-a4.log`; `[AD_REPORTS]` satırları ve6'şar ekran|
|P-I / P-A|`/tmp/pomosprint_verify-ios-reports-positive.log` / `/tmp/pomosprint_verify-android-reports-positive.log`; iki dilde pozitif günlük rapor; özet `android_positive_reports_summary.json`|
|L-I / L-A|`/tmp/pomosprint_verify-ios-leagues-final.log` / `/tmp/pomosprint_verify-android-leagues-a5.log`; her platformda24`[AF_LEAGUES]` PASS ve24 ayrı ekran|
|SOC-I / SOC-A|`/tmp/pomosprint_verify-ios-social-retry.log` / `/tmp/pomosprint_verify-android-social-a7.log`; her platformda TR/EN, 10 poll sonucu ve10 ekran|
|INS-I / INS-A|`/tmp/pomosprint_verify-ios-insights.log` / `/tmp/pomosprint_verify-android-insight-a6.log`; `[EXAM_INSIGHT_NATIVE]` PASS, 4'er ekran|
|AE-I / AE-A|`/tmp/pomosprint_verify-ios-old-retry2.log` / `/tmp/pomosprint_verify-android-old-a8.log`; her platformda2/2 PASS ve10 ekran|
|AE-export|`build/verification_20261028/isolated_old_final_export.json`; eski DB/Auth/REST kanıtı, 9 QA hesabının export'u; aktif sayaç yok; sonra yalnız bu kopya durduruldu|
|TZ / BOUND|`/tmp/pomosprint_verify_timezone_regressions.log`:40/40; `/tmp/pomosprint_verify_boundary_regressions.log`:36/36; model/widget sınırları|
|SQL-gece|`build/overnight_backend/{exam_backend_results,competition_backend_results,transition_metadata_results,target_reservation_results,d03_d05_results}.json`; önceki izole52/52, 21/21, 20/20, 15/15, 25/25|
|FIX-1 / FIX-2|`11ea62c` servis/journal ve `8446eff` sonuç diyaloğu; `gate_a2_service/results.json`, `gate_a2_ui/results.json` temiz analyze/Flutter/Node|

Ekran kökü: `analiz/ekran_dogrulama_2026-10-28/`. İlgili klasörler: `ios-official-retry`, `android-official`, `ios-short-retry2`, `android-short-retry`, `android-real75`, `verify-{ios,android}-reports*`, `verify-ios-leagues-final`, `verify-android-leagues-a5`, `verify-ios-social-retry`, `verify-android-social-a7`, `verify-ios-insights`, `verify-android-insight-a6`, `verify-ios-old-retry2`, `verify-android-old-a8`.

### A1 — resmî katalog ve deneme yaşam döngüsü

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A1.01 TYT|165 dk /9900 sn, 120 soru, yanlış/4|iOS ve Android TR/EN doğru katalog/başlangıç|Snapshot metadata'sı doğru; erken vazgeçme korunmuş|GEÇTİ — resmî metadata|O-I, O-A|
|A1.02 AYT|180 dk /10800 sn, 160 soru, yanlış/4|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.03 YDT|120 dk /7200 sn, 80 soru, yanlış/4|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.04 LGS Sözel|75 dk /4500 sn, 50 soru, yanlış/3|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.05 LGS Sayısal|80 dk /4800 sn, 40 soru, yanlış/3|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.06 TUS Temel|135 dk /8100 sn, 100 soru, yanlış/4|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.07 TUS Klinik|135 dk /8100 sn, 100 soru, yanlış/4|İki platform/iki dil doğru|Snapshot metadata'sı doğru|GEÇTİ — resmî metadata|O-I, O-A|
|A1.08 Başlangıç ve mola kuralı|3-2-1; mola/duraklatma yok|Yedi türün TR/EN başlangıçları geçti|Sunucu tam süreyi kendi belirliyor|GEÇTİ|O-I, O-A|
|A1.09 Erken tamamlama reddi|Süre dolmadan ödül yok|Native RPC erken tamamlamayı reddetti|`exam_not_elapsed`; durum/ekonomi korunuyor|GEÇTİ|O-I, O-A|
|A1.10 Vazgeçme|Kayıt silinmesin; 0 puan/kum/dakika|Her platformda14 vazgeçilen kayıt geçmişte|`abandoned`; normal/deneme ödülleri0, tamamlanma olayı yok|GEÇTİ|O-I, O-A; Android oracle116/116|
|A1.11 Deneme→normal ve Maraton çakışması|Aktif denemeyle yeni odak açılamasın|Her iki başlatma yolu engellendi|Başarısız işlem ödül/satır üretmedi|GEÇTİ|O-I, O-A|
|A1.12 Normal/Maraton→Deneme çakışması|Aktif odak varken deneme başlamasın|İki odak türünde de reddedildi|Ekonomi değişmedi|GEÇTİ|O-I, O-A|
|A1.13 TYT widget yeniden kuruluşu|Aynı owner/attempt/start/end sürsün|Mevcut sayaç geri geldi|Özgün zamanlar aynı|GEÇTİ — widget ağacı; OS kill değildir|O-I, O-A|
|A1.14 Doğal kısa tamamlanma|Yedi tür×iki dil, gerçekten60 sn|iOS14/14 ve Android14/14 tamamlandı|Her hesapta14 dk, 14 completed, 14 tek sıfırpuanlıevent; 0 normal/denemeödülü|GEÇTİ — kısa QA kataloğu|S-I, S-A; 741/741 ve738/738|
|A1.15 Tamamlama idempotency|Tekrar gönderim ikinci ödül/satır yaratmasın|Tamamlanma tekrarları duplicate döndü|Cüzdan/süre/event adetleri değişmedi|GEÇTİ|S-I, S-A; DB7, DB-S|
|A1.16 Yeni gerçek LGS75 — kapama ve final|Tam4500 sn; OS kapaması sonrası özgün kayıt|Android'de yeniden açınca aynı deneme tamamlandı|07:37:35.623271 Z→08:52:35.623271 Z; 75 dk/15 denemepuanı/3 denemekumu; 1 attempt/1 event;normal0|GEÇTİ — gerçek75 dk|R75; bağımsız26/26|
|A1.17 Yedi türün OS/offline/final matrisi|Kalıcı pending; aynı attempt ile tek final|Android EN 7/7; iOS TR özgün TYT+AYT recovery ve v3 kalan 5/5|14 hesapta birer completed/event/dakika;0 puan/kum; oracle PASS|GEÇTİ — doğal 60 sn QA yaşam döngüsü|R-OS; final_oracles/|
|A1.18 Katalog ve bağlantı kapanışı|Hata/iptalde eski katalog/R75 korunsun|AD kısa koşuları ve yeni R pencereleri kapandı|a1 ve a2 FAIL olmasına rağmen exact restore/R75 aynı/parite0; son v3 PASS ve aynı restore şartları|GEÇTİ — restore güvenliği; özgün test FAIL'leri ayrı|S-restore; joint a1/v2/v3 JSONları|

Resmî süre tablosu bütün sürelerin doğal beklendiği anlamına gelmez. Bu yeni turda tam süre kanıtı yeni Android LGS Sözel75 dk'dır; diğer resmîler metadata/erken vazgeçme, tamamlamaları60 sn QA kataloğu kapsamındadır.

### A2 — net girişi

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A2.01 Tamamlanmış kayıttan net formu|Sonuç girişi ve geçmişten düzenleme açılsın|Yedi tür, TR/EN formları açıldı|İki kısa hesapta76'şar sonuç satırı doğrulandı|GEÇTİ|S-I, S-A, DB7, DB-S|
|A2.02 Doğru/yanlışa göre otomatik boş|Kullanıcı soru toplamını elle tamamlamak zorunda kalmasın|Alan değişiminde boş otomatik hesaplandı|Geçerli toplamla kaydedildi|GEÇTİ — ürün düzeltildi|FIX-2; 5 widgetregresyonu; S-I/S-A|
|A2.03 Elle boş değiştirme|Otomatik hesap gerektiğinde elle düzenlenebilsin|Elle değer korunup doğrulandı|Doğru+yanlış+boş=derskotası|GEÇTİ|FIX-2, S-I, S-A|
|A2.04 Negatif/taşan değer|Açık hata; geçersiz kayıt yok|UI doğrulaması geçersiz gönderimi engelledi|Oracle her dersin tam sayı/kota kuralını doğruladı|GEÇTİ|FIX-2; S-I/S-A; oracle|
|A2.05 YKS/TUS neti|Doğru−yanlış/4|İki dilde sonuçlar doğru|Snapshot böleniyle numeric net eşleşti|GEÇTİ|S-I/S-A, oracle netchecks|
|A2.06 LGS neti ve ondalık|Doğru−yanlış/3; TRvirgül/ENnokta|LGS formlarında iki dil doğru|Negatif/üçtebir numeric değerler ölçek kaybı olmadan doğrulandı|GEÇTİ|S-I/S-A; oracle19 regresyonu|
|A2.07 Kısmi giriş|Dokunulmayan dersler sıfırlanmasın|Yalnız düzenlenen ders kaydedildi|Partial upsert diğer sonuçları korudu|GEÇTİ — ürün düzeltildi|FIX-1; 3 servis/journalregresyonu; S-I/S-A|
|A2.08 Sonradan düzenleme/updated_at|Geçmişten düzeltme saklansın|Kayıt yeniden açılıp değiştirildi|Net ve updated_at koşulları geçti|GEÇTİ|S-I/S-A; DB7, DB-S|
|A2.09 Kesintide kısmi giriş|Alanlar kaybolmasın veya açık uyarı olsun|Her platformda TR/EN LGS Sayısal offline form uyarısı ve tekrar kayıt geçti|Bekleyen farklı ders değişimleri birleştiriliyor; kabul sonrası tek sonuç|GEÇTİ — yerel API kesintisi; Wi-Fi testi değildir|`e2e-ad-net-offline-{tr,en}.png`; FIX-1; S-I/S-A|
|A2.10 Net ekonomiden bağımsız|Net düzenleme puan/kum/ligi değiştirmesin|Her düzenleme öncesi/sonrası ekonomi eşit|Normal ve deneme cüzdanı/süre/event değişmedi|GEÇTİ|S-I/S-A; oracle; INS-I/INS-A|

### A3 — bağımsız DB ve RLS

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A3.01 Attempt alanları|Status, başlangıç, bitiş, kabul, elapsed ve ödül tutarlı olsun|Native akışla aynı durumlar|Saklı definition üzerinden bütün alanlar doğrulandı|GEÇTİ|DB7, DB-S, R75|
|A3.02 Cüzdan ayrımı|Normal ve Deneme ödülleri karışmasın|İki ürün ayrı değer gösteriyor|Dört cohort'ta normal puan20/15/25/10; Deneme puanı15/15/27/27; kumlar ayrı|GEÇTİ|DB7, cohort manifesti|
|A3.03 Sıfır ödüllü kısa sınav|Bir dakika ve tek sıfır puanlı event|Tamamlanma rapora katkı veriyor|İki kısa hesapta14'er dakika/event, bütün cüzdanlar0|GEÇTİ|DB7, DB-S|
|A3.04 Net alanları|Ders kotası, bölen, numeric net ve updated_at doğru olsun|Geçerli form sonucu aynı|Doğru/yanlış/boş ve tam kesir hesabı geçti|GEÇTİ|iOS741/741, Android738/738|
|A3.05 Maraton eşlemeleri|Odak ve plan tek eşleşsin; bonus doğru olsun|Karma raporda2 odak/1 plan|W:100 odakdk, 22 normal puan/80 kum; 330 deneme dk/66 puan/12 kum; toplam430 dk|GEÇTİ|W, W-I, W-A|
|A3.06 Profil ve seri|Ortak dakika; tamamlanmış Deneme çalışılmış gün sayılsın|R75 seri1|R75:last_study_date2026-10-28; cohort seri2; warnings boş|GEÇTİ|R75, DB7|
|A3.07 Lig olayı|Doğru kaynak/tür/puan/ay/gün|Lig UI aynı kaynaklardan besleniyor|source_id,kind,points,minutes,period_month,study_day doğrulandı|GEÇTİ|DB7, DB-S, W|
|A3.08 Idempotency|Tek UUID/source ve tek ödül|Tekrar çağrılar duplicate makbuzu verdi|Satır/event adetleri ve cüzdan değişmedi|GEÇTİ|S-I, S-A, R75, oracle|
|A3.09 RLS|Başka hesap özel Deneme/net/cüzdanı okuyamasın|Özel veriler diğer hesaba sunulmuyor|Dolu kaynakta peer görünürlüğü0; boş veriyle PASS üretilmedi|GEÇTİ — read-only authenticated rol|DB7; W214/214 RLS|
|A3.10 Araç güvenliği|Sabit loopback, QA kimliği, read-only, secretsız|Native host sabit verifier endpoint'i kullanıyor|Repeatable read-only snapshot; eksik27–30/kurulu31 reddediliyor|GEÇTİ — araç regresyonu|Host39/39; oracle19/19 logları|

Kontrol adetleri benzersiz ürün senaryosu sayısı değildir; aynı hesapların alanları ve tekrarlanan muhasebe denetimleridir. Her JSON'un status ve warnings alanı ayrı değerlendirilmiştir.

### A4 — native raporlar ve zaman sınırları

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında / bağımsız beklenen | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A4.01 Bugün sıfır|Dünün çalışması bugüne taşınmasın|İki platform/TR/EN günlük0; sayılar0|W günlük0, hedef120, verimlilik0, kategoriler boş|GEÇTİ|W-I, W-A, W|
|A4.02 Haftalık karma toplam|Üç tür toplanıp plan çift sayılmasın|İki platform/TR/EN265 dk|100 odak+165 deneme; 2 normal, 2 Maraton odağı/1 plan, 1 deneme; 4 odak eşdeğeri|GEÇTİ|W-I, W-A|
|A4.03 Haftalık dağılım|Deneme ayrı; yüzdeler100|Deneme165 dk62%; Türkçe100 dk38%|Kategori haritaları aynı; sınav süresi derslere dağıtılmadı|GEÇTİ|W-I, W-A|
|A4.04 Haftalık hedef|Tam hafta ile geçen gün hızı ayrı olsun|Hedef840 dk; verimlilik31%; hız73%|265/840 ve geçen gün paydası ayrı doğrulandı|GEÇTİ|W-I, W-A|
|A4.05 Aylık karma toplam|Türler ortak süreye birer kez girsin|İki platform/TR/EN430 dk|2 normal, 2 Maraton odağı/1 plan, 2 deneme; 100+330 dk|GEÇTİ|W-I, W-A|
|A4.06 Aylık dağılım|Deneme ayrı; çift ekleme yok|Deneme330 dk77%; Türkçe100 dk23%|Yüzdeler ve toplam100|GEÇTİ|W-I, W-A|
|A4.07 Gün sayısı ve kıyas|Doğru aktif/en yoğun gün; sıfır baza sahte artış yok|Hafta2, ay3 aktif gün; en yoğun gün165 dk|Önceki ay0; büyüme null|GEÇTİ|W-I, W-A, oracle MTD|
|A4.08 Vazgeçilen Deneme|Sayı/süre/seri/ödül üretmesin|Abandoned geçmişte var, rapora girmiyor|Ay completed2 ve430 dk; abandoned eklenip3/490 dk olmadı|GEÇTİ|W, W-I, W-A|
|A4.09 Pozitif günlük iOS|Pozitif veride kartlar sıfır kalmasın|TR/EN75 günlük/175 hafta/175 ay|LGS-a:75 dk sınav; günlük hedef120, 62%|GEÇTİ|P-I|
|A4.10 Pozitif günlük Android|Ham verimlilik ile halka tavanı ayrı|TR/EN160 günlük/260 hafta/260 ay|TUS-a:135 deneme+25 odak; 84%/16%; verimlilik133%, halka100%|GEÇTİ|P-A, pozitif rapor özeti|
|A4.11 Pozitif hafta|Her profil kendi oracle sonucu ile aynı olsun|iOS175 dk20%, hız48%; Android260 dk30%, hız72%|Tür sayıları ve kategoriler profil bazında aynı|GEÇTİ|P-I, P-A|
|A4.12 Gün/ay04:00 sınırı|Başlangıç çalışma günü; planın sayısı bitiş gününde|Model/widget eşleşti|03:59:59→04:00; ay başı; önce başlayan/sonra biten kayıtlar|GEÇTİ — model/widget|TZ40/40, BOUND36/36|
|A4.13 Saat dilimi/DST|Profil IANA ile grupla; cihaz dilimiyle karışmasın|America/New_York ortamlı regresyon geçti|Tekrarlanan DST saati, hafta/ay ve ayrı İstanbul lig sınırı|GEÇTİ — gerçek NY cihazı değildir|TZ; oracle DST testleri|
|A4.14 Geç gelen kuyruk|Kabul sonrası aynı UUID; geçmiş günü bugüne taşıma|Yeni native UI kabul edilmiş W geçmişiyle eşleşti|Outbox dedup modeli ve önceki doğal W kuyruk kanıtı; seri politikası açık|GEÇTİ — model+önceki kuyruk; yeni R ayrı|unified stats; w_final_verified.json; W-I/W-A|

Aylık türetilmiş hedef yüzdesi, ayrı bir aylık verimlilik kartı varmış gibi sunulmadı. Çalışma günü başlangıca göredir; 04:01'de biten her kayıt otomatik yeni güne gitmez. Saklı seri sonradan gelen geçmiş boşlukları yeniden yazmaz. Seyahat sonrası güncel rapor dilimi ile kabul anındaki lig günü farklılaşabilir; oracle bunu uyarıyla açıklar.

### A5 — ligler

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A5.01 İki ekonomi|Pomodoro/Maraton study; Deneme exam ligine yazılsın|İki ürün farklı doğru sıralama gösterdi|Cohort normal20/15/25/10; exam15/15/27/27|GEÇTİ|L-I, L-A, DB7|
|A5.02 Kategori odası|LGS ve TUS karışmasın|Segmentte LGS çifti; TUS kimliği yok|Her ürünün iki LGS üyesi aynı odada|GEÇTİ|Cohort manifesti, L-I/L-A|
|A5.03 Global|Kategoriler birlikte doğru sırada|LGS/TUS birlikte; puan/dakika/UUID sırası doğru|SQL=RPC=UI; ölçüm anında18 study/17 exam görünür|GEÇTİ|L-I, L-A|
|A5.04 Özel profil|Odada rank/puan korunsun, kimlik maskelensin; globalden çıksın|Ad/avatar/kimlik yok; global bir satır azaldı|Oda2 satır, biri maskeli; global17/16|GEÇTİ|Her platform8 private görünüm|
|A5.05 Engel|İki yönlü engelde kimlik sızmasın|Kimlik maskeli/global dışında|Block doğrulandı; iki ekonomi sabit|GEÇTİ|Her platform8 blocked görünüm|
|A5.06 Bütün kombinasyonlar|2 ürün×2 scope×3 state×2 dil|Her platform24 PASS ve24 ayrı ekran|Sıra/ad/avatar/puan/is_me/is_blocked aynı|GEÇTİ|L-I, L-A; 24+24 PNG|
|A5.07 Açık ekran ay dönümü|Eski ay cache'i yeni aya taşınmasın|Widget'ta açık ekran yenilendi|Enjekte edilen saat ve period endpoint; doğal ay beklenmedi|GEÇTİ — model/widget|BOUND; league_refresh_regression_test|
|A5.08 Kapasite/tier/ödül|25 kapasite; dönem/hedef/ödül idempotency|Yeni AF'de doğal terfi/ödül beklenmiş denmedi|Önceki izole26 eşzamanlı üye/25 kapasite; 21 lig+20 geçiş+15 hedef kontrolü|GEÇTİ — önceki kontrollü SQL|SQL-gece; AF yalnız güncel okuma|

### A6 — süre–net içgörüsü

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A6.01 Olumlu içgörü|İlişkili süre ve net trendi doğru olsun|İki platform/TR/EN25 dk Türkçe ve19.25→27.50 net|İki tarihsel TYT ve aradaki25 dk; ekonomi aynı|GEÇTİ — kontrollü geçmiş|INS-I, INS-A|
|A6.02 Nedensellik sınırı|Artışın çalışma yüzünden olduğu vaat edilmesin|İki dilde açıklama/uyarı görünür|Net özel bilgi; ödül üretmiyor|GEÇTİ|Her platform4 positive/disclaimer ekranı|
|A6.03 Yetersiz veri|Az, aynı gün, eski/gelecek/abandoned veriden trend çıkarma|Model/widget boş ve güvenli durumları geçti|Completed-only, dedup, katalog sürümü ve21 gün kuralları|GEÇTİ — model/widget|İçgörü/loading testleri; TZ|
|A6.04 Ders eşlemesi|TUS Fizyoloji/Histoloji ve AYT Edebiyat doğru bağlansın|Eşleme regresyonları geçti|Birleşik kategori bağlamı toplam süreyi ikiye katlamıyor|GEÇTİ — eşleme modeli|Category mapping testleri; TZ|

### A7 — sosyal

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A7.01 Çok hesap|En az3 hesap birbirini görsün|1 native gözlemci+8 API arkadaşı; 4 odak/2 mola/2 deneme|9 ayrı QA Auth, kabul edilmiş arkadaşlıklar|GEÇTİ — API aktörlü|SOC-I, SOC-A|
|A7.02 Odak bitişi|Durum açık ekrandan kendiliğinden kalksın|Her platform/TR/EN30 sn polling ile kaldırıldı|Cancel sonrası RPC'de de yok|GEÇTİ|Her platform2 odak sonu ekranı|
|A7.03 Mola bitişi|Mola etiketi ve yeşil durum doğru; bitince gizlensin|Her platform/TR/EN poll ile kalktı|Cancel odak ve mola tarihini temizledi|GEÇTİ — presence; tam Maraton bekleyişi değil|Her platform2 mola sonu ekranı|
|A7.04 Deneme bitişi|Denemede durumu ödülsüz sonlansın|Her platform/TR/EN poll ile kalktı|Abandoned kalıcı, ödül0; sonra QA aktörü yeniden başlatıldı|GEÇTİ|Her platform2 deneme sonu ekranı|
|A7.05 Sosyalde görün kapalı|Manuel refresh/navigasyon olmadan gizlensin|TR/EN açık ekran poll ile kaldırdı|show_in_social_feed=false, sonra true geri alındı|GEÇTİ|Her platform2 privacy-off ekranı|
|A7.06 Engel ve geri alma|Engelli arkadaş kaybolsun; QA sonra geri görünsün|TR/EN poll ile kalktı, geri görünür oldu|Block/unblock ve silinen arkadaşlık istek/kabul ile geri kuruldu|GEÇTİ|Her platform2 blocked ekranı|
|A7.07 Kanıt kapsamı|İki dilde5 durum, her platformda10 sonuç|iOS ve Android5:17 nativePASS|Görünen satırlar RPC ile de karşılaştırıldı|GEÇTİ|SOC-I, SOC-A; 10+10 PNG|
|A7.08 Test sonrası API presence kapanışı|Hesap/geçmiş/arkadaşlık silmeden durumlar sonlansın|Observer canlı listesi0; arkadaşları8|Yalnız 8 peer:2 deneme süresinden önce abandoned/0 ödül;8 cancel;9 hesabın ekonomi/seri/cüzdan ve geçmişi aynı|GEÇTİ — yalnız yerel authenticated RPC|`build/verification_20261028/i08_presence_cleanup.json`|

### A8 — eski sunucu

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
|A8.01 İzolasyon|27–29 yokken ana DB/Auth'a dokunma|Uygulamalar gateway54341'e bağlı|Ayrı DB/Auth/REST; exam/monthly RPC yok, welcome disabled|GEÇTİ|AE-I, AE-A, AE-export|
|A8.02 İki dil|Çökmeden kayıt/onboarding/normal akış|Her platformda TR/EN2/2 PASS|Final QA hesapları ve kategoriler doğru|GEÇTİ|AE-I, AE-A|
|A8.03 TUS niyeti|Eski constraint reddetse de tercih kaybolmasın|TUS kategorileri ve istemci niyeti korundu|Server segment null; uydurma TUS yazılmadı|GEÇTİ|TUS kategori ekranları; AE-I/AE-A|
|A8.04 Deneme güvenli yedeği|Yeni RPC yoksa güvenli kullanılamaz bilgisi|TR/EN kullanılamaz mesajı; çökme yok|RPC yok/404 PGRST202; deneme satırı/ödülü yok|GEÇTİ|AE-I, AE-A|
|A8.05 Normal sayaç|Başlat/iptal çalışsın|TR/EN UI adımları geçti|Son durumda aktif odak boş|GEÇTİ|AE-I, AE-A, AE-export|
|A8.06 Rapor uyumu|Normal geçmiş gün/hafta/ayda görünsün|TR/EN25 dk raporu|Kontrollü25 dk RPC:1 seans/5 puan/20 kum; doğal25 dk iddiası yok|GEÇTİ|AE-I, AE-A, AE-export|
|A8.07 Güvenli kapanış|Önce kanıtları sakla; ana DB korunsun|AE tamamlanınca yalnız eski kopya durduruldu|9 QA hesabı export; aktif odak yok; main değişmedi|GEÇTİ — sahiplikli eski kopya|AE-export; old_stop.log|

## Gerçek ürün düzeltmeleri

| Sorun | Düzeltme | Regresyon ve commit öncesi kapı |
|---|---|---|
|Kısmi net listesi servis/journal tarafından reddediliyor veya diğer bekleyen ders değişikliği kayboluyordu|`11ea62c`: yalnız değişen geçerli dersler kabul ediliyor; offline değişiklikler diğer dersleri kaybetmeden birleşiyor|3 servis/journal regresyonu; analyze temiz, Flutter1425PASS/5opsiyonelPNGskip, Node164/164|
|Boş sayısı otomatik hesaplanmıyor; kullanıcı bütün dersleri elle tamamlamak zorunda kalıyordu|`8446eff`: doğru/yanlıştan otomatik boş, elle düzenleme, negatif/taşan doğrulama, yalnız değişen dersleri gönderme|5 widget regresyonu ve güncel l10n testi; analyze temiz, Flutter1425PASS/5opsiyonelPNGskip, Node164/164|

Bu iki hata için yeni sunucu ürün düzeltmesi gerekmedi;28'in partial-upsert sözleşmesi zaten vardı. Finder, bekleyiş ve kanıt toplama düzeltmeleri bu ürün commit'leriyle karıştırılmamalı.

### Korunan özgün FAIL kayıtları

| Özgün koşu | Neden / görülen | Düzeltme ve sonraki kanıt | Sonucun yorumu |
|---|---|---|---|
|İlk iOS resmî AD: `/tmp/pomosprint_verify_ios_official.log`|Reset metni arka plan ve onay diyaloğunda aynı; finder birden çok sonuç verdi|Finder diyalogla sınırlandı; yalnız bu QA odağı UI'den iptal edildi; O-I native PASS|İlk FAIL korunur; ürünün Reset özelliği bozuk denmedi|
|iOS resmî retry wrapper: O-I log sonu|Çalışan bash dosyası güncellendi; postflight satır132 syntax error|Native14katalog+çakışma PASS; ayrı bash-n/parite/DB kontrolü geçti|Wrapper FAIL, native başarıyla örtülmez|
|İlk iOS short: `/tmp/pomosprint_verify_ios_short.log`|Xcode build sonrası Flutter TARGET_BUILD_DIR bulamadı; uygulama başlamadı|Ayrı build-settings doğrulaması ve verbose retry; katalog restore/parite|Build/harness FAIL; ürün akışı çalışmış sayılmadı|
|İkinci iOS short: `/tmp/pomosprint_verify_ios_short_retry.log`|LGS ekran adındaki alt çizgi host güvenlik kuralına takıldı|Tireli ad kullanıldı; üçüncü tur14/14; her hata sonrası restore/parite|Önceki FAIL silinmedi|
|İzole eski Auth bootstrap: `isolated_old/auth_bootstrap_failure.log`|GoTrue init migration: permission denied for schema auth|Yalnız eski kopyanın kurulumu düzeltildi; boş baseline hash'i korundu; signup200/gateway kanıtı|Üretim Auth hatası değildir; başarısız kurulum logu korunur|
|İlk iOS AE: `/tmp/pomosprint_verify_ios_old.log`|Ekran adında e2e- öneki yok; iki dilde host400|Güvenli ekran öneki eklendi|İki başarısız assertion korunur|
|İkinci iOS AE: `/tmp/pomosprint_verify_ios_old_retry.log`|Eski “Ders Raporları”/“Subject Reports” metinleri aranıyordu; finder0|Güncel UI/l10n etiketleri kullanıldı; AE-I2/2|Harness hatası ürün fallback hatası diye anlatılmaz|
|İkinci AE'nin ana paritesi|Eşzamanlı Android short kataloğu resmî referansa farklıydı|Kısa pencere sonrasında exact restore ve parite0|O andaki fark başarılı diye geçiştirilmez|
|Android ilk short: `/tmp/pomosprint_verify_android_short.log`|YDT60sn tamamlanması85sn test sınırına takıldı; complete/exam_not_elapsed journal'ı korundu|Aynı owner/attempt/UUID ile AH recovery; tarih değişmedi; kuyruk retry aralığını kapsamak için test120sn|İlk FAIL ve pending kanıtı kaldı; süre/ödül gevşetilmedi|
|İlk AH: `/tmp/pomosprint_verify-android-short-recovery.log`|Testte debugPrint import'u eksikti; Gradle kernel derlemesi başarısız|Import düzeltildi; recovery2 native1/1, DB205/205|Uygulama başlamadı; eski diske reset yapılmadı|
|İlk iOS sosyal: `/tmp/pomosprint_verify-ios-social.log`|Sliver cache'inde hazırlanmış fakat hit-test dışında kart; finder varsayımı yanlış|Gerçek viewport'a ortalama ve kare yerleşimini bekleme; SOC-I5:17PASS|İlk FAIL korunur; ürün kartı bozuk denmedi|
|Yeni joint R a1, iOS TYT|Native start PASS ardından CFPreferences proof anahtarı diske geç yansıdı; host erken okudu|Aynı run/owner/client/attempt/zaman/snapshot ile offline+final recovery PASS; son oracle1dk/1event|a1 joint ve iOS driver FAIL korunur; ürün hatası değildir; TYT yeniden başlamadı|
|iOS a2 AYT host kapama kontrolü|Start/proof PASS; Flutter zaten kapattıktan sonra simctl code3 “found nothing to terminate” döndü|Aynı özgün AYT offline/final recovery PASS; v3 exact launchctl yokluğu doğrulaması eklendi|a2 FAIL korunur; yeni hesap/attempt açılmadı|
|R tamamlanmasının kapsamı|a1 Android7 PASS; iOS ilk iki tür ayrı recovery; v3 kalan5 PASS|Bütün14Rowner oracle PASS; son exact restore/R75 aynı/parite0|Aggregate yaşam döngüsü GEÇTİ; a1/a2 joint dosyaları yine FAIL|

AH tek recent owner/attempt'in aynı diskte kurtarılmasıdır; genel suite değildir. CFPreferences düzeltmesi de yalnız diski tekrar okur; native başlangıcı veya denemeyi tekrar oluşturmaz. Katalog/attempt zamanı, puan veya soru sayısı değiştirilerek FAIL geçirilmeye çalışılmadı.

### Açık sınırlar ve ana raporda güncellenecek satırlar

- Ana rapordaki A2 BEKLİYOR ve Android sosyal sırada ifadeleri eskidi: S-I/S-A ve SOC-A bitmiş PASS kanıtlarıdır.
- Pozitif günlük örnekler aynı owner değildir: iOS 75/175/175; Android 160/260/260 dk.133% verimlilik/100% halka Android'in hedef üstü örneğidir.
- Yeni R matrisi tamamlandı; iOS TR ve Android EN kapsamındadır. AD resmî/kısa/net fazları her iki platformda TR/EN çalıştı. Yeni R restore/parite kanıtı önceki AD kanıtlarından ayrı saklanır.
- Fiziksel cihaz, gerçek bildirim teslimi, sağlayıcı girişi, üretim SQL'i, Store/TestFlight veya doğal ay dönümü bu tablodan PASS çıkarılamaz.
-31 kurulmadı;31 sonrası Maraton native koşusu yok. Eski Maraton sözleşmesinin bütün geç gönderim/AFK yollarını kapattığı iddia edilmez.

## Son salt okunur oracle turu

Gerçek final_proof/recovery dosyalarından seçilen 14 R sahibi ve korunmuş 9 I08 hesabı: **23 hesap,568/568 PASS,warnings boş**. IDs tahmin edilmedi. TYT/AYT recovery için özgün native start logundaki run/owner/client/attempt/start/end/definition, son proof ile birebir karşılaştırıldı; `final_oracles/same_owner_recovery_crosscheck.json` PASS.

Standart `--peer-owner` modu kaynakta hem deneme hem net satırı ister; bu koruma gevşetilmedi. Son 23 hesapta net girilmediğinden tam net-RLS modu kullanılmadı. Bunun yerine R75 peer ile ayrı read-only authenticated sorguda 16 dolu attempt kaynağı ve 14 dolu cüzdan için görünürlük0 doğrulandı. Boş net kaynakları **SKIP_EMPTY_SOURCE**, güçlü net-RLS kanıtı değildir. Önceki dolu cohort/iOSshort/W net-RLS kanıtları korunur.


## Tam kontrol kapısı — A

`build/verification_20261028/gate_A_full/`: `flutter analyze --no-pub` temiz; `flutter test --no-pub --concurrency=2 --reporter=expanded` **1425 PASS /5 isteğe bağlı PNG üreticisi atlaması /0 FAIL**; `cd scripts && npm test` **164/164**. Yeni Python araçları: oracle19, cohort10, eski stack9, host39; toplam **77/77**. New York ortamında ek40+36 model/widget kontrolü geçti. Kaynak davranışı değiştirilmeden native sonuçları tamamlandı.

A görsel incelemesinde12gerçekPNG açıldı. İncelenen karelerde bloker bulunmadı. EN iOS rapor sekmesi yatay kaydırmalı olduğundan son etiket kısmen kesilebilir; seçilmesi ve aylık ekran doğrulandı. QA toast/kaydırılmış görüntüler site medyası olarak kullanılmayacak. Sahte hesapların özel adları çevrilecek UI metni değildir.

Xcode'un ürettiği nested SwiftPM kilit dosyası, çalışmaya ait yedek/hash kaydı alındıktan sonra HEAD'deki özgün baytlara döndürüldü; bağımlılık yükseltmesi commit'e alınmadı.

## B. Site önce/sonra

| Alan | Önce | Sonra |
|---|---|---|
| Ekranlar | Eski 4 sekme ve iki farklı ölçü/dil seti | Tek QA iPhone 16 / iOS 18.6; saat 09:41; aynı Deniz hesabı; TR/EN için 15'er sahne, toplam 30 PNG (540 × 1170) |
| Veriler | Boş hesap; QA Deneme/Odak/Mola adları | Kurgu Deniz hesabı; normal 29 puan / 80 kum, seri 2, toplam 455 dk; deneme 66 puan / 260 kum; insan adları kullanan 6 arkadaş |
| Özellikler | TR/EN arasında bölüm farkı; eksik Deneme bölümü | Aynı bölüm/konu sayıları; 8 deneme türü, dört sınav ailesi (YKS/LGS/TUS/DUS); net, başlık, not, AYT erken bitirme; aylık kategori ve global sıralama |
| Videolar | Eski arayüz/dil; elle oynatma katmanı | TR/EN için uygulamadan alınmış 4 gerçek video; sessiz ve otomatik döngü; gerçek dokunmaları gösteren imleç; hız değiştirilmedi |
| Dosyalar | Karışık veya kullanılmayan medya | Hiçbir yerde referansı bulunmayan 27 eski public medya dosyası kaldırıldı; yeni manifestler boyut, dil, hash ve kaynağı doğruluyor |
| Yerel QA | Geçici HTTP kurulumu | Tekrar kullanılabilir [güvenli önizleme](../tool/site_qa/README.md); canlı API, form veya Auth bağlantısı yok |

Güncel bilgiler [medya rehberinde](../landing/screenshots/README.md), [fotoğraf manifestinde](../landing/screenshots/manifest-20261028.json) ve [video manifestinde](../landing/videos/manifest-20261028.json) bulunuyor. Ham PNG kaynakları (604 × 1311) ve uygulamadan kaydedilmiş video bölümleri (1178 × 2556) korunuyor. Web için hazırlanan 540 × 1170 türevlerde orantılı ölçekleme ve ince kenar boşluğu kullanılıyor; ekran içeriği üretilmiyor, kırpılmıyor veya esnetilmiyor. Kaynak MP4'ler, özgün MOV kaydının paket SHA/PTS/DTS değerleriyle eşleşiyor. Tam MOV kayıtları ve derleme dosyaları commit'e alınmıyor.

İlk B çekiminde TYT 150 kum / deneme cüzdanı 300 kum politikası kullanılıyordu. Son kullanıcı kararından sonra boş bir DUS site veritabanında 7 yeni hesap oluşturuldu; 30 görsel ve 4 video **yeniden çekildi**. Aradaki DUS çekimi `site-oct28-dus` idi. Son Deneme arayüzü isteğinde bu veritabanı `pomosprint_site32_dus_pre_ui` adıyla korunup yeni boş yerel kopyada `site-oct28-ui` çekimi yapıldı. Son hesap sahibi kimliği `ca271e26-fc2c-44b6-b88f-9537f809639c`; eski 4328 kimlikli hesabın ödülleri değiştirilmedi. Tarihsel verilerle oluşturulan 455 dk'lık test verisi, 455 dk boyunca doğal süreyle beklenmiş olduğunun kanıtı değildir.

| Kontrol | Beklenen | Uygulamada/sitede görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
| Tek veri/dil/cihaz | Aynı hesap; iki gerçek dil | 30 görsel / 4 video; güncel 5 sekme | Boş kurulan DUS site veritabanında yalnızca 7 kurgu hesap | GEÇTİ | [Manifest](../landing/screenshots/manifest-20261028.json) |
| 30 görselin incelenmesi | Doğru dil, saat ve veri; klavye veya geçici bildirim yok | 15 TR + 15 EN görsel tek tek açıldı; EN “Unanswered” hizası düzeltildi | TYT 130 kum; deneme cüzdanı 260 kum; normal 29 puan / 80 kum; seri 2 tutarlı | GEÇTİ | [TR](ekran_site_2026-10-28/visual_review/tr.json), [EN](ekran_site_2026-10-28/visual_review/en.json) |
| 4 videonun teknik ve görsel kontrolü | 540 × 1170, 24 fps, h264, sessiz, ≤256 KiB | İlk/orta/son/dokunma anlarından 20 kare; imleç 50 dk / 4 seans hedefleriyle eşleşiyor | Ödül doğurmayan arayüz iptalleri; eski ödüller korundu | GEÇTİ | [Video QA](ekran_site_2026-10-28/video_review/README.md) |
| Kaynak videonun gerçek zamanlı olması | Stream copy; hız değişikliği yok | Kaynak paketleri ve sabit PTS/DTS farkı 4/4 videoda doğrulandı | — | GEÇTİ | [Teknik kontrol](ekran_site_2026-10-28/video_review/technical_checks.json) |
| Safari: 375/1024/1440 | 24 yerel TR/EN sayfa; 404 veya taşma yok | 72/72 PASS, 0 uyarı | Canlı API kapalı; veritabanına yazılmadı | GEÇTİ | [72 kontrol matrisi](ekran_site_2026-10-28/browser/safari_final_72.json) |
| Safari manuel kontrol | Son turda dört video; menü/SSS/dil aynı kaynakların önceki turunda | 4 videoda `currentTime` ilerledi; duraklatma/devam, sessiz oynatma, döngü ve sayacın başa dönmesi gözlendi | DB/API/form işlemi yok | GEÇTİ | [Manuel rapor](ekran_site_2026-10-28/browser/SAFARI_MANUEL_2026-10-28.md), [50 örnek](ekran_site_2026-10-28/browser/safari_manual_final.json) |
| Gerçek site görüntüsü | Tarayıcı görüntü alanından kanıt | 375/1024/1440 genişliklerinde 3 gerçek CUA JPEG; birebir aynı dosyayı doğrulayan SHA değerleri | — | GEÇTİ | [375](ekran_site_2026-10-28/browser/safari-cua-tr-home-375.jpg), [1024](ekran_site_2026-10-28/browser/safari-cua-tr-home-1024.jpg), [1440](ekran_site_2026-10-28/browser/safari-cua-en-home-1440.jpg) |
| Hero başlığının okunurluğu | Başlığın ilk çizimde gizlenmemesi | 375/1024/1440 görselleri ve CSS regresyonu PASS; kesin ilk çizim karesi kaydı yok | — | SINIRLI | [Manuel kapsam](ekran_site_2026-10-28/browser/SAFARI_MANUEL_2026-10-28.md) |
| Chrome | Ayrı QA oturumunda gerçek kontrol | “Browser access host unavailable”; iki API çağrısı başarısız | Kişisel Chrome'a erişilmedi | KALDI—ORTAM | [Engel kaydı](ekran_site_2026-10-28/browser/chrome_unavailable.json) |
| Node / statik medya | Boyut, dil, hash, kullanım, Range ve erişilebilirlik | 172/172 PASS | Ağ bağlantısı kullanmayan mock testleri | GEÇTİ | [Son Node sonucu](kanit_son_kapilar_2026-10-28/gate1-node.log) |

Üç küçük sunum uyarısı kaldı: kaydırılabilir rapor sekmelerinin son etiketinin dar kadrajda kısalması, koleksiyon başlığının üç noktayla kısaltılması ve Deneme liginde özel avatarların hazırlandığını belirten mevcut metin. Videoların ortasında normal duraklatma/başlatma bilgi bildirimleri görünüyor. Bunlar veri veya çökme hatası değil. Görüntü kadrajında bulunmayan aylık/haftalık toplamlar fotoğraflardan doğrulanmış sayılmadı; bu değerler ayrı uygulama ve SQL kanıtlarına dayanıyor.

## DUS ve son Deneme ödül kararı

Kullanıcının son tablosu, önceki 150/175 kararının yerini aldı. 32 numaralı paket yalnızca yeni başlatılan denemelerde kaydedilen ödül değerlerini etkiliyor; daha önce başlamış veya tamamlanmış kayıtların ödülleri korunuyor.

| Sınav | Dakika | Kum | Deneme puanı |
|---|---:|---:|---:|
| LGS Sözel | 75 | 60 | 15 |
| LGS Sayısal | 80 | 70 | 16 |
| YDT | 120 | 95 | 24 |
| TUS Temel | 135 | 110 | 27 |
| TUS Klinik | 135 | 110 | 27 |
| DUS | 150 | 120 | 30 |
| TYT | 165 | 130 | 33 |
| AYT | 180 | 145 | 36 |

Kum hesabının temeli, dakika × 0,8 değerinin en yakın 5'in katına yuvarlanmasıdır. LGS Sayısal için 70 kum, kullanıcının açıkça belirlediği istisnadır. AYT erken bitirmede kum `floor(snapshot_fullcoins × elapsed / planned)`, puan ise `min(snapshot_fullpoints, floor(elapsed / 300))` olarak hesaplanır. Yeni ödül tablosuyla 90 dk → 72 kum / 18 puan; 1–59 sn → 0; tam süre → 145 kum / 36 puandır. Diğer 7 türde (DUS dahil) erken bitirme reddedilir. Deneme ekonomisi normal ekonomiden ayrıdır; net, başlık veya not kaydetmek ikinci kez ödül üretmez.

Resmî kaynak: [ÖSYM 2026-DUS 2 kılavuzu](https://dokuman.osym.gov.tr/web/2026/9/basvuru-kilavuzu-e1esxj-16163038.pdf). §1.3 / PDF sayfa 4 süreyi 150 dk; PDF sayfa 27 net hesabını D−Y/4 olarak veriyor. Basılı sayfa 40 / PDF sayfa 43, Tablo 1'de toplam 120 soru (40 + 80) bulunuyor. 16 alanın standart kotaları yaklaşık kapsamı gösteriyor. [Araştırma/kaynaklar](SINAV_KAYNAKLARI_2026-10-28.md) ile PDF SHA/boyut kaydı korunuyor. DUS tanımı, onboarding'de 16 ders önerisi, UID bekleyen eski kayıtlarla uyum, lig hedefi, filtreler ve TR/EN metinleri eklendi; diğer mevcut hedefler silinmedi.

| Kontrol | Beklenen | Uygulamada görünen | Veritabanında | Sonuç | Kanıt |
|---|---|---|---|---|---|
| 27 → 28 → 29 → 30 → 32 | Boş yerel kurulum; 31 yok | Güncel 8 türden oluşan katalog | Review/site ortamları veri kopyalanmadan kuruldu; 128/128 SQL, DRYRUN, geri alma ve başlangıç değerleri kontrolü | GEÇTİ | [DUS sunucu arşivi](kanit_dus_2026-10-28/INDEX.md) |
| 8 tam ödül / sürüm 2 | Tabloyla birebir eşleşme | Tek istemci yedek tablosu; sunucunun kabul ettiği kayıt öncelikli | 8 tam ödül; politika 2; normal cüzdan değişmiyor | GEÇTİ | [Sunucu](kanit_dus_2026-10-28/INDEX.md), [istemci](QA_DUS_ISTEMCI_2026-10-28.md) |
| AYT: 90 dk / 1 sn / tam süre | 72/18, 0, 145/36 | Uygulamadaki kısa denemede planlanan 180 dk yerine gerçekten geçen süre kullanıldı | 128 SQL kontrolünde sınırlar, tekrar çağrılar ve eski 7/175 kum başlangıç değerlerinin korunması doğrulandı | GEÇTİ | Aynı sunucu arşivi |
| DUS onboarding / eski kayıt uyumu | Seçim kaybolmuyor; 16 ders | DUS'ta UID bekleyen kayıtlar için TUS ile aynı akış; TR/EN ve filtreler | `dus` hedefi; kategori ve global sıralama; ay ortasındaki değişiklik sonraki ay geçerli | GEÇTİ | [164 istemci regresyonu](QA_DUS_ISTEMCI_2026-10-28.md) |
| Android DUS | 150 dk / 120 soru / 16 alan; erken bitirme yok | TR/EN: başlat → gerçek 3 sn → vazgeç | 14/14 SQL, 0 ödül | GEÇTİ | [Android uygulama kanıtı](kanit_dus_native_2026-10-28/android/INDEX.md) |
| Android AYT | Güncel 8 türün tablosuyla güvenli ayrıntı işlemleri | TR/EN: erken bitirme, net, başlık/not, tekrar gönderim, rapor ve normal başlatma | 17/17 SQL; son parite 5/5 | GEÇTİ | Aynı Android arşivi |
| iOS DUS resmî bilgileri | 150 dk / 120 soru / 16 alan; erken bitirme yok | TR/EN: gerçek başlatma → vazgeç | 14/14 SQL + 56 bağımsız doğrulama, 0 ödül | GEÇTİ | [iOS uygulama kanıtı](kanit_dus_native_2026-10-28/ios/INDEX.md) |
| iOS DUS kısa sürenin doğal tamamlanması | İzole ortamda 60 sn / 0 ödüllü başlangıç kaydı | TR/EN: 60 sn; 16 alanlı form, 2 net, başlık, not ve tekrar gönderim; rapor 1 → 2 dk | 18/18 SQL + 94 bağımsız doğrulama; gerçek 2 dk, seri 1, cüzdan 0; 9000 sn / 30 puan / 120 kum kataloğu birebir geri yüklendi | GEÇTİ | Aynı iOS arşivi |
| Bağımsız doğrulayıcı / RLS | Gerçek ve planlanan süre, sıfır ödül ve başlangıç değerleri doğru | Gerçek kaydı bağımsız okuyor | 34/34 birim testi; 17 hesapta 712/712; başka hesap üzerinden RLS kontrolü 3/3 | GEÇTİ | [DUS doğrulayıcısı](kanit_dus_2026-10-28/INDEX.md) |
| Özel ayrıntılar / güvenlik | Yalnızca kayıt sahibine erişim; kapsam, revizyon ve kuyruk koruması | Yalnızca başlık/not veya kısmi net kaydı; çevrimdışı değişmez istek zarfı; hesap değişimi koruması | Eski RPC'nin kapsamı sınırlı; veri kaybı oluşturacak geri alma reddediliyor | GEÇTİ | [32 fazı](QA_DENEME_EKLERI_2026-10-28.md), [DUS raporu](QA_DUS_ISTEMCI_2026-10-28.md) |

60 sn'lik kısa DUS kontrolü, standart 150 dk / 120 kum ödülünün doğal süre boyunca beklenerek doğrulandığı anlamına gelmiyor. Ödül tablosu, pozitif ödül üreten SQL test verileriyle ayrıca kanıtlandı. Önceki 32 fazının 104 SQL, 113 istemci ve iOS/Android için 21'er SQL sonucu tarihsel kanıt olarak korunuyor; güncel DUS 128 SQL / 164 istemci matrisiyle karıştırılmamalı.

## Bulunan ve düzeltilen yeni hatalar

- Aşırı uzun başlık/notların otomatik kaydı, yerel işlem günlüğünü okuyan kodla çelişiyor ve ilgili hesaba ait kayıtların açılmasını engelliyordu. Arayüze 120/2000 Unicode scalar değeri sınırı, servis kontrolü ve diske yazılan verinin tekrar okunabilir kalmasını doğrulayan koruma eklendi. Eski ham veriler silinmiyor.
- Hesap değişiminde formun aynı ekranı iki kez kapatması ve 320 px genişlikte, 2× yazı ölçeğinde taşması düzeltildi.
- İngilizce “Unanswered” sözcüğü ortadan bölünüyor ve üçüncü giriş alanını aşağı kaydırıyordu. Tek satırda ölçekleme ve eşit sütun hizası eklendi; 30 görsel yeniden çekildi.
- Eski “tam süreyi kullan” giriş metni AYT erken bitirme özelliğiyle çelişiyordu. Desteklenen özelliğe uygun TR/EN metni eklendi.
- Bu çalışmadaki iki Android release FAIL sonucu, `--no-pub` kullanıldığında yenilenmeyen geliştirme eklentisi kaydında `IntegrationTestPlugin` bulunamamasından kaynaklandı. Normal release üretim yapılandırmasıyla a3 denemesi başarılı oldu; üretilen Java dosyası elle yamalanmadı. Aynı çalışma kopyasındaki Flutter işleri sırayla çalıştırılıyor.

Bu özellikler ve düzeltmeler `8cb3dc9`, sade Deneme arayüzü `641cc16` commit’indedir. Site/kanıt/devir değişiklikleri bu raporun bulunduğu son commit’tedir; dal adresi yukarıdadır.

## Derleme, son kapı ve kalan sınırlar

- iOS imzasız cihaz release derlemesi: PASS. `Runner.app` 55,1 MB (sıkıştırılmamış paket). Bu sonuç fiziksel cihaz veya TestFlight doğrulaması değil.
- Son arayüz Android release APK: PASS. Universal APK 99.289.837 bayt (önceki paket 99.289.757 bayttı). Bu ölçü Play/App Store indirme paketinin boyutu veya mağaza AAB/imza onayı değil; derleme dosyası push edilmiyor.
- Normal `lib/main.dart`, iOS QA cihazına kuruldu ve açıldı. Android'de normal debug uygulaması çalıştı; işlem kimliği (PID) görüldü. İki ana ekran da 25:00 gösteriyor; 5/10 sn modu veya test yazısı yok. Ortamlar bilinçli olarak YEREL site/review API'lerine bağlı; canlı kişisel hesap kullanılmıyor.
- Son kapı 1: `flutter analyze` temiz; Flutter 1476 PASS / isteğe bağlı 5 PNG kontrolü atlandı / 0 FAIL; Node 172/172; `partial-sync` 0. [Kapı ve paket kanıtları](kanit_son_kapilar_2026-10-28/packages_and_gate1.json).
- Chrome, ortam engeli nedeniyle doğrulanamadı; kesin ilk çizim filmi kaydedilmedi. Safari için tarayıcı görüntü alanından alınmış gerçek JPEG'ler, 72 kontrol matrisi ve manuel video örnekleri bulunuyor.
- 31 numaralı paket kullanıcı kararını bekliyor; kurulmadı ve paket sonrası Maraton testi yapılmadı. Canlı ortamda SQL/Edge/site işlemi, main'e merge/push, force push veya plan/ücret yükseltmesi yapılmadı.
- Fiziksel cihaz, gerçek Apple/Google girişi, bildirim teslimi, imzalama, ertelenmiş yasal/gönderen kimliği bilgileri ve daha önce belgelenmiş operasyonel güvenlik kararları ayrı işler olarak duruyor. Bu rapordan bütün mağaza yayın koşullarının tamamlandığı sonucu çıkarılmamalı.


## Son arayüz ve kapanış doğrulaması

Kullanıcının son ekran isteği uygulandı: uzun giriş ve ders listeleri kaldırıldı; eşit boyda **Yeni / Geçmiş / Lig** sekmeleri, tek net kuralı kutusu ve soru/süre etiketli küçük kartlar kullanılıyor. İngilizce karşılıkları da güncel. LGS’nin **3 yanlış**, YKS/TUS/DUS’un **4 yanlış** kuralı açıkça ayrıldı. Sunucu, süre ve ödül kuralları bu görsel düzenlemede değiştirilmedi.

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| TR/EN; dar ekran, 2× yazı ve yatay düzen | 40 seçili test, 14 dosya analizi PASS | [UI kanıtı](kanit_deneme_ui_2026-10-28/README.md) |
| Eski lig yenileme bulucuları | 5 metin bulucu sabit anahtara geçirildi; özgün doğrulamalar korundu; dosya 9/9 PASS | [Özgün hata ve düzeltme](kanit_son_kapilar_2026-10-28/compact-final/initial-finder-failure/) |
| Android son UI, TR/EN erken AYT | Native PASS; SQL 21/21; DUS katalog paritesi 5/5. Gerçek 5/6 saniye ve 0 ödül; çift gönderim tek kayıt | [Native kanıt](kanit_deneme_ui_2026-10-28/android/proof.json) |
| Normal iOS uygulaması | `lib/main.dart` kuruldu; 25:00 ana ekranı ve yeni Deneme ekranı CUA ile açıldı | [Yeni ekran](kanit_son_kapilar_2026-10-28/compact-final/ios-normal-exam.png) |
| Normal Android uygulaması | `lib/main.dart` açıldı, işlem kimliği ve 25:00 ana ekranı doğrulandı | [Ana ekran](kanit_son_kapilar_2026-10-28/compact-final/android-normal-main.png) |
| Son UI genel regresyonu | **1482 PASS**, yalnız 5 isteğe bağlı PNG atlaması; analiz temiz; **172/172 Node**; partial eşliği temiz | [Kapı/paket özeti](kanit_son_kapilar_2026-10-28/compact-final/proof.json) |

Normal uygulamalar test entrypoint’i veya hızlandırma define’ı kullanmaz. iOS yerel site API 54361’e, Android yerel review API 54351’e bağlıdır; kişisel hesabınla canlı sunucuda deneme yerine bu ortamın örnek hesaplarını kullan. iOS ilk açılış karesi splash’tır; yükleme sonrası ana ekran ve Deneme karesi ayrı korunmuştur.

Son cihaz envanteri: **bir PomoSprint QA iPhone 16 (18.6), bir PomoSprint_QA_API36**. `HocamMacVar · iPhone 17` korunur, kişisel cihaza dokunulmadı. Gereksiz derleme temizliği ve kapanış tekrarı aşağıdaki kayıtta ayrıca bulunur. 31 hâlâ kullanıcı kararı bekliyor; bu sonuçlar kurulmamış paketi doğrulamaz.


Kapanış tekrarı da temiz: **1482 Flutter PASS / 5 isteğe bağlı PNG atlaması**, **172 Node PASS**, analiz ve ortak parça kontrolü başarılı. [Ham kapanış sonuçları](kanit_son_kapilar_2026-10-28/compact-final/closing-gate/summary.json).

Temizlikte 7 yeniden üretilebilir derleme/ham medya klasörü kaldırıldı; diskte yaklaşık **6.95 GB** boş alan açıldı. Son unsigned iOS paketi ve Android APK `build/final_release_20261028/` altında yerel olarak korundu; Git'e alınmadı. Test veritabanları, yüklü normal uygulamalar ve kalıcı kanıtlar silinmedi. Eski 4 kayıt/önizleme yardımcı süreci kapatıldı; uygulamanın iki yerel API sağlık kontrolü HTTP200. [Temizlik ve korunanlar](kanit_son_kapilar_2026-10-28/compact-final/cleanup.json).

Son gönderim kapsamı yalnız `codex/gece-2026-10-27` dalıdır. Ana dal `5f99f90` olarak korunur. Bu rapor ve site medyasıyla aynı commit kapanış paketidir; tam son commit kimliği Git dal geçmişinde ve kullanıcıya verilen sonuç mesajında bulunur.


### GitHub yedeği doğrulandı

B/site kontrol noktası **`635a89df7cd8bf45b6dc16e21e95e4210dc0a465`** uzak `codex/gece-2026-10-27` dalından okunarak doğrulandı. İlk toplu aktarım HTTP408, ikinci aktarım bağlantı kesilmesiyle başarısızdı; yayınlanmamış B paketi içerik değişmeden küçük commit’lere bölününce yedi kontrol noktası başarıyla ulaştı. [Aktarım kanıtı](kanit_son_kapilar_2026-10-28/compact-final/push-checkpoints.json) kayıtlıdır. Kapanış notu bu yedek üzerine ayrı küçük doküman commit’i olarak eklenir. Main `5f99f90` korunur; merge/force/deploy yok.

## Son ek: KPSS ve onaylı web düzeltmeleri

Onaylanan web düzeltmeleri `6cfd9b5` kaynağından yayımlandı; Worker `ad2fc988-4462-40ae-9333-ab0107e2138b`, canlı kontrol 6/6. KPSS bu pakette değildir.

KPSS için 12 yeni seçenek, toplam20 katalog kaydı; GY–GK 130dk/105kum/26puan, 8 alan 50dk/40kum/10puan, İstatistik60dk/50kum/12puan. Kaynaklar ve sınırlar [KPSS raporunda](QA_KPSS_2026-10-28.md). Tam ürün kapısı1493Flutter/173Node, SQL242, Python74 ve parite5 geçti. Son iOS turu host/simülatör yanıt vermediği için **tamamlanamadı**. Kısmi TR ekranları ve başarısız testler başarı sayılmadı; normal uygulama paketinin geri kurulması bekliyor. Bu ek önceki DUS native sonuçlarını değiştirmez ve onlardan KPSS başarısı çıkarmaz.

### 29 Ekim tamamlanma eki

Yukarıdaki son iOS engeli kullanıcı Simulator'ü yeniden açınca çözüldü. Nihai KPSS native turu **TR/EN PASS**,8ekran; [başarı manifesti](kanit_kpss_2026-10-28/ios/manifest.json). Normal uygulama yeniden derlenip kuruldu ve açıldı; eski taslak korundu. Son native dosya analizi, Node173 ve partials geçti; [kapanış kanıtı](kanit_kpss_2026-10-28/closure/manifest.json). Önceki tamamlanmamış girişimler tarihsel tanı olarak korunur. KPSS uygulama/site/SQL canlıya yayımlanmadı; onaylanan iki web düzeltmesi yayındadır.
