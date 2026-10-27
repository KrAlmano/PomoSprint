# 25 kişilik lig odaları ve rekabet başlangıcı

Bu paket `20261008190000_league_launch_policy.sql` içindir. **8 Ekim 2026 canlıya uygulanıp doğrulandı**: önce55/55rollback, atomik exactdosya, sonra55/55rollback veverikoruma. SHA256 `dac9176d3a4c960b2908dd3bde9fdf81558c443070d7d352098945ac93e9a277`; [QA](../../analiz/QA_LEAGUE_LAUNCH_2026-10-08.md), PROJE_DEVIR§29. İleri dosyayı yeniden çalıştırmayın. Kaynak gövdeler 8 Ekim canlı salt okuma kanıtından alınmıştır: `analiz/qa_evidence_20261008/league_launch/baseline.json` ve `dependencies.json`.

## Ürün kuralları

- Oda üst sınırı başlangıçta **25**. `app_config.league_room_capacity` sayısal JSON değeridir; sunucu 3–30 aralığına sınırlar. Sonradan 30 yapmak yalnız bu ayarı değiştirmeyi gerektirir. Mevcut boşluğu olan aynı kademe odasına, en dolu uygun oda önce olacak şekilde yerleştirilir. İlk üyelik ilk puan kazandıran tamamlanmış seanstadır; onboarding veya sıfır puanlı seans üyelik açmaz.
- Hazırlıkta seanslar, puanlar ve sıralama çalışır; terfi, düşme ve lig avatarı verilmez. Gecikmiş cron nedeniyle `carry_points` varsa hazırlık görünümünde toplam puana dahildir.
- Son 336 saatte tamamlanmış 25/50 dakikalık seansı olan **25 farklı kullanıcı** başlangıcı planlar. Günlük ödül tavanından dolayı sıfır puanlı gerçek seans aktiflik hesabına girer. Eşik aşılması aynı gün başlatmaz: ilk **sonraki tam 14 günlük dönem** planlanır. Takvim çıpası 12 Ekim 2026 Pazartesi 00:00 Türkiye; sonrasında 14 günlük pazartesi aralıkları. 14 gün hesabı SQL oturumunun saat diliminden bağımsız 336 saattir.
- Hazırlık puanları ilk resmi döneme taşınmaz. Toplam dakika, lifetime puanı, kum, seans geçmişi ve önceden açılmış avatarlar korunur. İlk resmi puanlar kabul edilmiş `study_sessions` satırlarından hesaplanır; başlangıç ile 00:01 cron arasındaki seanslar kaybolmaz.
- Bir odada en az **3 aktif kullanıcı** olursa terfi kontenjanı `floor(aktif / 3)` olur: 3→1, 10→3, 25→8, 30→10. Terfi için dönem içi kullanıcı saat diliminde 04:00 sınırıyla **3 farklı çalışma günü**, **300 tamamlanmış dakika**, en az 1 puan ve ham sıralamada kontenjan içinde olmak gerekir. Elmas üstüne çıkılmaz.
- Avatar için en az **10 aktif üye**, ham ilk 3 ve aynı kişisel gün/dakika/puan şartları gerekir. Birincilik avatarı ayrı, ikincilik/üçüncülük aynı podyum avatarıdır; tamamlanan eski kademeye göre verilir. Kuşanılan avatar otomatik değiştirilmez.
- Düşme yalnız en az **10 aktif üyeli** odada olur; kontenjan `floor(aktif / 3)`, ham sıralamadaki son kontenjan kadar üye değerlendirilir. Bitişe 72 saatten daha kısa süre kala katılan kullanıcı düşürülmez. Bronz altına inilmez.
- Dönem sonunda aynı kademe odaları 25 üst sınırıyla yeniden doldurulur. Kararlar bütün odaların taşınma öncesi tek snapshot'ından alınır; aynı kullanıcı bir turda iki kez işlenmez. Dönem ortasında cron odayı değiştirmez. Tekrar cron puan/terfi/ödül üretmez.

## Sözleşme ve güvenlik

`get_league_config()` anon/authenticated/service_role için yalnız güvenli yapılandırma ve `policy_version:1`, `competition_phase:preparing|scheduled|active`, `competition_starts_at` döndürür. Salt okumadır; başlangıç planlamaz.

`get_my_league_ranking_v2()` authenticated/service_role için JSONB dizidir. Eski sıralama alanları korunur; ek olarak `has_league`, `active_member_count`, `competition_phase`, `competition_starts_at`, `room_capacity`, `promotion_eligible`, `award_eligible`, `demotion_eligible` ve ağda ayrı config isteği başarısız olsa da kullanılabilen aynı güvenli `league_config` nesnesi vardır. Booleans ham sıra, aktif rakip, kişisel yeterlilik, dönem ve kademe sınırları dahil sunucudan gelir. `get_league_ranking(uuid)` ve `get_my_league_ranking()` eski TABLE şemasıyla çalışır. Engellenen rakibin adı/avatarı maskelenir.

Özel `league_competition_state` RLS açık ve API rollerinin tüm tablo yetkileri kapalıdır. İç `_league_*` fonksiyonları PUBLIC/anon/authenticated/service_role için EXECUTE iznine kapalıdır. Güvenlik tanımlayıcıları `search_path=public,pg_temp` kullanır. Normal tamamlama RPC’sinin yalnız ilk üyeliği olmayan kullanıcı için geçmiş dönem kontrolü eklenir: geç gelen ilk seans lifetime ödülünü korur, sıfır lig puanıyla yerleşir ve `league_points:0`, `league_period_closed:true` döndürür. Puan/kum/seri formülleri, doğrulama, kuyruk ve idempotency korunur. Normal yeni gövde MD5 `72023f3f4d8636363cf0231f42d4c7e1`; eski gövde rollback içinde birebir bulunur. Maraton tamamlama gövdesi birebir korunur; Maraton ek puanı zaten son seansın `bonus_points` kolonundadır ve bir kez sayılır.

Yeni `league_schedule_after_completed_session` AFTER INSERT trigger'ı yalnız başlangıç durumunu günceller, diğer profil/üyelikleri kilitlemez. Başlangıç planlandıktan sonra durum satırı kilitlenmeden hızlı döner. Bakım kilit sırası: sıralı profiller → kademe advisory kilitleri → başlangıç durumu. Böylece normal tamamlama profil → kademe → AFTER trigger durum sırasına ters kilit alınmaz.

## Uygulama ve geri alma

1. Canlı fonksiyon/trigger parmak izlerini ve veri sayımlarını tekrar salt okuyun. Paket eski tanım farklıysa atomik işlemi durdurur.
2. İzole canlı şema kopyasında testleri, iki bağlantılı yerleşim yarışı ve rollback testini çalıştırın. Ana yerel QA veritabanına veya canlıya fixture yazmayın.
3. Genel yöntem kullanıcı SQL Editor'ünde kısa bakım penceresidir; bu paketin8Ekim kullanıcıyetkili CLIuygulaması §29'da kayıtlıdır. Tarihsel/yenidenincelenmiş denemede `20261008_league_launch_policy_dryrun.sql` çalıştırır. **55 sonuç true**, son `DRYRUN_RESULT` hatası kasıtlı rollback'tir. İlk ASSERT false ise ayrı bir açıklayıcı hata ile hemen durur. Satır kilitleri canlı insan seanslarını kısa süre bekletebilir; dryrun gerçek veriyi kalıcı değiştirmez.
4. İleri migration tek BEGIN/COMMIT içerir; bütün paket atomiktir. `db push/reset` kullanılmaz. Uygulama sonrası katalog/ACL, güvenli RPC, mevcut lifetime/seans/puan/kuşanılmış avatar bütünlüğünü doğrulayın.
5. `20261008190000_league_launch_policy_down.sql` yalnız resmi başlangıç geçmeden çalışır. Özgün config, oda UUID/eşlemeleri, katılım ve dönem sınırları geri gelir; arada kazanılan yeni seans, puan, kum ve lifetime korunur. Ek yeni oda içinde yeni kullanıcı varsa oda silinmez. Resmi dönem başlamışsa rollback bilinçli durur: gerçekleşmiş terfi/ödül için ayrı incelenmiş telafi/yedek gerekir.

Yerel kopyayı `proposed_chain_check.sh UNTIL=0` ile kurarken `ops` şeması da kopyalanmalıdır; `handle_new_user` nötr görünen ad fonksiyonuna bağlıdır. Tamamlanan QA komutları ve kesin kanıtlar tarihli QA raporundadır. `run_local.sh` tarihsel stub migration zincirini sınar ve bu güncel canlı ön koşullu paketin yerine geçmez.

Sınır testi gerçek `complete_study_session` ile koşulur. Test transaction’ı `_league_grid_start` helper’ını geçici olarak `now() − 1 saat` sınırına sabitler; gerçek sunucu zamanı, 25/50 süre, overlap, 24 saat ve ödül kontrolleri durur/gölgelenmez. İlk geçmiş dönem seansı, tam sınırda biten seans, sonraki güncel puan ve duplicate sınanır; helper aynı transaction içinde eski tanımına geri döner. Bu takvim kontrollü test doğal 14 günlük zaman beklemesi olarak raporlanmaz.
