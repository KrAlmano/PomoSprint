# Lig başlangıcı ve 25 kişilik odalar — 8 Ekim 2026

Kullanıcının mevcut lige yerleşme ve başlangıçta 25 kişilik oda talebi uygulandı. `20261008190000_league_launch_policy` canlıda kayıtlıdır. Nihai dosya SHA-256: `dac9176d3a4c960b2908dd3bde9fdf81558c443070d7d352098945ac93e9a277`. Önceki aday dosyaları nihai paket yerine kullanılmaz. Yeni ekran/özellik eklenmedi; mevcut lig rehberi, durum metinleri ve onboarding TR/EN güncellendi.

## Uygulanan davranış

- İlk üyelik onboarding'de değil, ilk puan kazandıran tamamlanmış seansta açılır. Aynı kademedeki mevcut uygun odanın boşluğu kullanılır; önce en dolu oda, ardından en eski başlangıç/UUID. Oda doluysa yeni oda açılır. Kapasite 25, ileride sunucu ayarıyla 30 olabilir.
- Mevcut kademe, lifetime puan, kum, dakika, seri, seanslar ve açılmış/kuşanılmış avatarlar korunur. Aynı kademedeki odalar migration ve dönem devrinde birleştirilir; aktif dönem ortasında oda değiştirilmez.
- Şu an canlı durum **preparing**: puan/rapor/sıralama işler; terfi, düşme ve yeni lig avatarı verilmez. Son 336 saatte kabul edilmiş seansı olan 25 farklı kişi eşiğiyle sonraki tam 14 günlük dönem planlanır. Günlük puan tavanına takılan geçerli çalışma da aktiflik sayılır. Global dönem çıpası 12 Ekim 2026 00:00 Türkiye; aralık sabit 336 saattir.
- Hazırlık puanları resmi dönem yarışına taşınmaz; lifetime ve geçmiş korunur. Resmi yarışın puanı kabul edilmiş seanslardan, tamamlanma zamanı `[başlangıç, bitiş)` aralığıyla hesaplanır. Maraton bonusu son seansın bonus puanında bir kez sayılır.
- Terfi: odada en az 3 aktif üye; kontenjan `floor(aktif/3)` (3→1, 10→3, 25→8, 30→10). Ham sıranın kontenjan içinde olması, en az 1 puan, kullanıcının saat dilimindeki 04:00 sınırıyla 3 farklı çalışma günü ve 300 tamamlanmış dakika gerekir. Yeterli olmayan üst sıra boşluğu başka kullanıcıya aktarılmaz. Elmas üstüne çıkılmaz.
- Lig avatarı: en az 10 aktif üye, ham ilk üç ve aynı gün/dakika/puan şartları. Birincilik ve podyum avatarı eski kademe üzerinden açılır; otomatik kuşanılmaz.
- Düşme: en az 10 aktif üyede son `floor(aktif/3)` sıra değerlendirilir; bitişten önceki son 72 saatte katılanlar korunur. Bronz altına inilmez. Aktif üye, dönem içinde kabul edilmiş seansı olan kişidir; toplam oda mevcudu değildir.

## Gerçekten koşulan doğrulamalar

| Kontrol | Sonuç / kanıt |
|---|---|
| Tam Flutter birim/widget paketi | **1215/1215**, 0 hata/atlama; screenshot açık, concurrency 1, 124,41 sn. `flutter_test.log`, `flutter_checks.json` |
| Flutter analiz | Temiz, `analyze.log` |
| İstemci odaklı testler | 116/116; tam paketin alt kümesi. Yeni dosya 39/39; TR/EN, eski RPC yedeği, hatalı/kayıp config, bayat cache, gizli satırlar, server eligibility, responsive rehber |
| İzole backend paketi | **55/55** DRYRUN; down sonrası public şema birebir, yeni gerçek RPC seansı/ekonomisi korunma kontrolü **4/4**. `backend_summary.json`, `backend_rollback_summary.json` |
| Bağımsız backend denetimi | **89/89** son tekrar: 85 davranış + 4 gerçek yerel pg_cron (önceki86/86 tarihsel). `independent_results.json`, `independent_review.md`, `independent_cron.json` |
| Canlı kurulum öncesi rollback DRYRUN | **55/55**, kasıtlı DRYRUN_RESULT/rollback; mevcut veri ve eski gövdeler aynı. `live_dryrun_summary.json`, `live_dryrun_invariants.json` |
| Canlı kurulum ve koruma | Atomik exit 0, **18/18** sözleşme/ACL/veri kontrolü. `live_apply_summary.json`, `live_apply_invariants.json` |
| Canlı kurulum sonrası davranış | **55/55**, ayrı BEGIN/scenarios/ROLLBACK. Ardından 13/13 veri/gövde invariant aynı. `live_postapply_scenarios_summary.json`, `live_postapply_data_invariants.json` |
| Canlı HTTP güvenlik/config | **4/4**: anon güvenli config 25/preparing, owner ranking anon reddi, iki private helper anon kapalı. `live_http.json` |
| Normal iOS açılışı | `main.dart`, canlı `.env`, hiçbir quick/local define yok; gerçek 25/50 dk. iPhone16Plus/iOS18.6 debug run exit 0; TR giriş ekranı gerçek simctl capture. `ios_launch.log`, `analiz/ekranlar/20261008_league_launch/production-login.png` |
| Android derleme | Debug APK başarı; `android_build.log`. Bu tur yeni Android native UI/mağaza/release testi sayılmaz |
| Site/Edge ağsız testleri | **133/133**, 0 hata/atlama; `node_tests.log`. Partial sync ve Wrangler dry-run exit 0 |
| Yerel ana kopya parity | Yeni canlı 498 katalog satırı, **13/13 kategori aynı**; korunan veri hash'leri aynı. `local_sync_summary.json`, `local_sync_parity.log` |

Kontrol toplamları birbirine eklenmez; bağımsız ve canlı paketler aynı davranışları kısmen yeniden sınar. Rehberin `analiz/ekranlar/20261008_league_launch/league-launch-*` dört görüntüsü gerçek Roboto/icons ve ×2 yazı boyutlu widget capture'dır: TR 390×844 ve EN 844×390. Root görsel olarak okudu; bu yeni native rehber dokunma/rotasyon koşusu diye sayılmaz.

## Site yayını

Worker **6bdb8f56-a8c5-4973-8b18-74344edee7f4**: yalnız index/features/FAQ üç HTML yüklendi; 80 varlık aynı, toplam83. Mevcut düzen, videolar, CSS/JS ve Range Worker değişmedi. Bağımsız **11 gerçek HTTP isteğinde68/68 kontrol** geçti: varsayılan curl yanıtında üç HTML SHA eşleşmesi, SSS12/JSON-LD, lig koşulları, aynı medya adresleri, iki MP4 Range206/tam1024bayt. Bazı User-Agent yanıtlarında Cloudflare mevcut367bayt Analytics betiği ekler: ilk62/65 ham-hash sonucu korunur, yalnız bu betik çıkarıldığında kaynak eşitliği ayrıca doğrulanır; yanlış birebir iddiası yapılmaz. `site_verification.json` ve `review.md`; yeni Safari UI turu yok.

## Düzeltilen sorunlar ve güvenlik

Hazırlıkta eski carry puanının kaybolması; ilk üyeliği olmayan kişinin geç gelen önceki dönem seansının yeni döneme puan yazması; ayrı config isteği başarısız olduğunda v2 satırının yanlış eski ödül kuralına düşmesi düzeltildi. V2 içine aynı güvenli config gömülür ve eligibility bayrakları sunucudan gelir; eksik v2 bilgi güvenli biçimde ödül/terfi kapalı kalır.

Son katalog tekrarında **27/27** tanım/ACL/config/cron/veri/nihai SHA kontrolü aynı kaldı (`live_final_catalog_checks.json`).

Normal tamamlamada yalnız ilk üyelik/geç dönem guard'ı değişti: MD5 `72023f3f4d8636363cf0231f42d4c7e1`; guard çıkarıldığında eski gövde birebirdir. Puan, kum, seri, overlap, gerçek süre, 24 saat ve duplicate kontrolleri korunur. İki Maraton tamamlama gövdesi birebirdir. Yeni özel tablo RLS açık/API yetkileri kapalı; `_league_*` helper EXECUTE izinleri PUBLIC/anon/authenticated/service_role'a kapalı. Kilit sırası denetlendi, 24+2 eşzamanlı ilk üyelik 25+1 yerleşti; 30 kapasite artışında mevcut boşluk kullanıldı.

Takvim sınırı testleri izole veya rollback transaction'da `_league_grid_start`ı geçici geçmiş sınıra sabitler; sunucu `now`, süre/24 saat/overlap kontrolleri değiştirilmez. Helper geri yüklenir. Bu testler doğal 14 gün beklemesi değildir. Gerçek yerel cron yalnız review DB'de çalıştı, geçici job temizlendi; canlı haftalık job zamanlaması değişmedi.

Canlı önce/sonra 4 profil, 9 seans, 3 üyelik ve 42 avatar açılımı aynı kaldı; puan/kum/geçmiş/kategori/arkadaş hash'leri aynı. Canlı test hesapları transaction içinde geri alındı; kalıcı yeni hesap, seans, Auth maili veya Resend gönderimi yok. Bu talep yalnız yeni lig paketi için uygulama yetkisi olarak kaydedildi; diğer SQL/Edge/ödeme/plan değişikliklerine genişletilmedi. `db push/reset` çalıştırılmadı.

## Ortam ve kalan kapsam

Son ortam `environment_final.json` ve root tarafından görüntülenen `analiz/ekranlar/20261008_league_launch/final-production-login.png` ile kayıtlı; yeni metin kanıtlarında public anon dışı JWT bulunmadı.

Normal üretim uygulaması TR giriş ekranında açık; kişisel canlı hesapla kullanılabilir. Ana yerel kopyanın 427 Auth/profil, 552 seans, 2989 avatar açılımı, 2330 kategori, 325 arkadaşlık, 202 üyelik verileri korunarak policy ve daha önce canlıya alınmış rapor kilidi eşitlendi. Yerelde 202 yakın tarihli QA kullanıcısı nedeniyle başlangıç **12 Ekim 00:00 TR için scheduled**; canlıdaki preparing ile veri farkıdır, şema farkı değildir. QA kısa kayıt helper'ı 0. Bağımsız harness eski/yeni kaynak şemayı parmak iziyle tanır; eski baseline yalnız review DB içinde down ile kurulabilir. Son yeniden koşuda89/89; ana scheduled veri/state ve job hash'leri aynı kaldı, zorla state reset gerekmedi. Geçici review DB/job ve backend DB/REST temizlendi; diğer proje simülatörleri/Docker işleri korunur.

Yeni fiziksel cihaz, Google/Apple sağlayıcısı, push/inbox, 14 günlük doğal canlı rollover veya mağaza testi iddia edilmez. Önceki gece/native testler tarihli raporlarda kalır. Geliştirici kimliği/adresi, Apple provisioning/TestFlight ve fiziksel testler ayrı yayın işleridir. Commit/push yapılmadı.

Devam kaynağı: [PROJE_DEVIR §29](../PROJE_DEVIR.md), [AGENTS §6.4](../AGENTS.md), [SQL rehberi](../supabase/tests/20261008_league_launch_policy_README.md). İleri migration canlıda uygulanmıştır; yeniden çalıştırma. Down yalnız resmi başlangıç geçmeden kullanılabilir; sonrasında incelenmiş telafi gerekir.
