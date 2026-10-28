# Uygulama, veritabanı ve site doğrulaması — 28 Ekim 2026

**A doğrulaması tamamlandı; B site güncellemesi sürüyor.** Bu rapor yeni A/B talebinin sonuçlarını toplar. Çalışılan depo `/Users/almano/Desktop/Projects/Pomodoro`, dal `codex/gece-2026-10-27`. Canlı Supabase/Resend/siteye işlem veya deploy yapılmadı; main değiştirilmedi. Kök `.env` agent tarafından açılmadı/değiştirilmedi. Bütün hesaplar ve veriler yerel, uydurmadır.

Ana yerel sunucuda 27–30 paketleri doğrulandı. **31 uygulanmadı; kullanıcı kararı bekliyor. 31 sonrası Maraton testi yapılmadı.** Kısa sınav pencerelerinin sonunda resmî yedi katalog satırı birebir geri yüklendi; özgün gerçek75 kaydı değişmedi; son parite exit0.

## GitHub yedekleri

- Başlangıç: `fb70839ecd36ce314da5389928ef01fa5e40ce00`; mevcut36commit yalnız çalışma dalına push edildi. Temiz ağaçla984yol ve yeni bloblar incelendi: yasaklı dosya ve50MB üstü blob yok; en büyük1.355.247bayt.
- İki ürün düzeltmesi: `11ea62c` kısmi/offline net journal; `8446eff` otomatik ve elle boş/negatif/toplam doğrulaması. Her biri ayrı tam analiz/Flutter/Node kapısından geçti.
- A sonu push: kontrol ve commit hazırlanıyor. B sonu ve kapanış yedekleri sonra kaydedilecek. Main push/merge/force push/deploy yok.
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

B henüz uygulanmadı. Hazır tasarım/çekim araçları önce A yedeğinden sonra kullanılacak. Hedef: tek iOS18.6/09:41 cihazı ve aynı Deniz demo hesabı;15sahne×TR/EN, dört gerçek zamanlı video,540×1170 ortak web boyutu ve mevcut telefon çerçevesi; Deneme/aylık kategori+global/TUS içerik eşliği; eski kullanılmayan medya temizliği.

Safari'nin geçici `cgWindowNotFound` erişim hatası kullanıcı Mac'i görünür bırakınca çözüldü. Yalnız yerel önizleme sekmesi ayrı test penceresine taşındı; kişisel Chrome sekmeleri okunmadı/değiştirilmedi. Mevcut site tabanında Safari iframe ölçüm matrisi72/72 geçti; bu sonuç yeni B dosyalarının final kontrolü değildir. B sonrası tekrar ve gerçek görsel/video etkileşimleri bekliyor.

## Kapanışta kalanlar

A tamam; B medya, yerel tarayıcı kontrolleri, README/kurulum/devir güncellemesi, son normal derlemeler ve B/kapanış push'ları henüz bekliyor. 31, fiziksel cihaz ve ertelenmiş yayın operasyonları bu çalışma ile kendiliğinden tamamlanmış sayılmaz.

## Doğrulama sonrasında gelen ek istekler

- Kullanıcı doğru/yanlış girip tek Kaydet ile kayıt ister; otomatik/elle boş, kısmi veya bütün derslerin tek gönderimi A2 kapsamında hazır ve iki platformda doğrulandı. TYT Türkçe40/Matematik40; Sosyal20 ve Fen20 alt ders kotalarıyla tutulur, toplam120soru.
- Kullanıcı yeni hedefleri LGS Sözel60, TYT150, AYT175 Deneme kumu olarak belirledi. Henüz uygulanmadı. AYT için erken bitirme, çözülen dört test grubunu seçme ve deneme adı/notu da istendi; resmî dağılım araştırılıyor. Erken bitirmede ödülün süreye oranlanması veya tam175 olması kullanıcıya soruldu. Ayrı32önerisi planlanıyor;31'e bağımlı olmayacak. Bu A raporundaki3/6kum gibi değerler mevcut politikadaki özgün kayıtların doğru sonuçlarıdır; geçmiş/aktif snapshot geriye dönük değiştirilmeyecek.
- Sitedeki QA Deneme/Odak/Mola adları yeni aynı-hesap çekiminde uydurma insan adlarıyla değişecek (Deniz, Ece, Mert, Ada, Arda, Duru, Can). Gerçek kullanıcı hesaplarına dokunulmaz.
