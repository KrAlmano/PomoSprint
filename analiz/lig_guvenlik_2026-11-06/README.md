# Lig kontrolü — 6 Kasım 2026

Canlı şemaya yazılmadı; 31 kurulmadı. Canlı `_league_period_activity` gövde hash'i güvenlik incelemesinde salt okunur yerel kaynakla eşleşti. Üretim kullanıcılarıyla hesap açma, ödül verme, yarışma geçişi veya doğal cron denenmedi.

## Aylık ligler

Kullanıcı satırı kopyalanmadan, mevcut gözden geçirilmiş yerel şema ve yalnız katalog/config tablolarından yeni bir QA veritabanı oluşturuldu. 26 yeni kurgu kullanıcının eşzamanlı tamamlamaları ve sahipçe ayarlanmış geçmiş zamanlar ile `overnight_competition_backend.py` **21/21** geçti. [Makine sonucu](competition_backend_results.json): 25 kişi kapasitesi ve 26. kişiye ikinci oda, tek üyelik, hedef izolasyonu, dönem ortasında hedefin sonraki aya kalması, global/segment görünümü, normal ve deneme liglerinin ayrılması, on kişilik örnekte terfi/düşme/avatar, tekrarlı kapanış, saat dilimi ve artık yıl. Ayrıca ikinci yeni klonda 4 kurgu LGS/TUS hesabı ve iki lig için [global/segment kontrolü](global_scope_results.json) **46/46** geçti; görünüm sorguları ekonomi kayıtlarını değiştirmedi. Her iki QA klonu test sonrası silindi; diğer veritabanlarına dokunulmadı. Ödül ve ay değişimi verileri sentetiktir; ilk doğal 1 Aralık cron'unun başarısını göstermez.

## 34 için eski lig yeterlilik açığı ve öneri

34 kapısı açıkken (`unverified_session_daily_cap=0`) doğrulanmamış offline seans kayıtlı ve puansız olsa da eski `_league_period_activity` bütün dakikaları sayıyordu. Bir PostgreSQL fixture'da doğrulanmış 25 dk/10 puan ve doğrulanmamış 300 dk toplam 325 dk/3 gün olarak sayıldı; `_competition_finalize_legacy` kullanıcının ligini 1→2 değiştirdi. Bu, cap 0 canlıda hâlâ kapalı olduğundan **gelecekteki aktivasyon için koşullu risk**tir; canlı istismar kanıtı değildir.

34 adayı, aktivasyon öncesi kabul edilmiş mevcut seansları gizli RLS tablosunda snapshot alır. Cap=0 iken eski lig aktifliğine yalnız kayıtlı eski veya sunucuda doğrulanmış seanslar sayılır. Yeni doğrulanmış ve günlük sınır nedeniyle sıfır puanlı gerçek seanslar korunur. Lig başlangıcı eşiği de aynı kurala uyar. Hesap silinirse seans silmeye bağlı snapshot kimliği de silinir. Cap=null iken eski davranış sürer. Ayrıntılar [34 README](../../supabase/proposed/34_verified_reward_guard_README.md).

- Geçici ayrı PostgreSQL kümesinde kaynak SQL ve kapanış işleviyle `python3 -m unittest tool.local_supabase.e2e.test_legacy_verified_league_guard -v` geçti. Gerçek seans/üretim verisi kullanılmadı.
- Tekrar sıfır kullanıcıyla kurulan yerel Supabase şema/katalog klonunda güncel ileri/DRYRUN ile **14/14**, `verified_reward_guard_test.py` gerçek SQL/RPC ile **33/33** geçti. Saatler fixture olarak ayarlandı.
- Aktivasyon taslağının fail-closed sentineli reddetti. Test için yalnız sentineli çıkarınca snapshot ve cap aynı transaction'da kuruldu; aktifken rollback reddedildi, test verisi sıfırlandıktan sonra geri alma hem `_league_period_activity` hem `_league_refresh_start` kaynak hash'lerini geri getirdi. Klonda 31 yoktu; klon testten sonra silindi.
- 34 hiçbir aşamada canlıya kurulmadı; cap 0 etkin değil. İki platformda uyumlu istemci ve kuyrukların geçişi ile doğal ay sonu ayrıca doğrulanmalıdır. Politikanın 24 saatten eski offline kayıtları kabul etmemesi sürer.

Mevcut aylık lig tasarımında seans kapatılmış ayın cron sonrası kuyruğundan geç gelirse lig kararları tekrar hesaplanmaz; kayıt/ödül ve dönemi kapalı lig sonucu ayrı değerlendirilir. Ay sınırındaki bağlantı kaybı için bu kullanıcı etkisi doğrulanmalı ve ürün politikası net olmalıdır.

## 35 yaş korumasının bağımsız kapsam incelemesi

35, onboarding'in eksik doğum yılıyla tamamlanmasını ve önceden girilmiş bir doğum yılının null'a çevrilmesini reddetmeyi, mevcut tamamlanmış ama yılı NULL profilleri korumayı hedefler. Başlangıçtaki ACL kontrolünde SQL NULL'ın `<>` ile karşılaştırılması fail-open idi; güvenlik ajanı bunu `IS DISTINCT FROM` kullanacak şekilde düzeltti ve hata enjeksiyonunu ayrıca test ediyor.

Bu çözümün sınırı: onboarding'i tamamlamamış Auth hesabı bazı mevcut SECURITY DEFINER RPC'lerde tamamlanma/yaş ön şartı olmadığı için doğrudan API kullanabilir. Kullanıcı verisi kopyalanmayan ayrı yerel Supabase klonunda 35 kurulduktan sonra doğum yılı ve onboarding tarihi NULL olan sentetik hesapla `register_session_start` ve `start_exam_attempt` çağrılarının her ikisi de başarılı oldu; iki çağrı ROLLBACK edildi ve klon silindi. Tekrar: `python3 tool/local_supabase/e2e/reproduce_onboarding_rpc_scope.py` (bu bir açık reproduksiyonudur, geçilen güvenlik kontrolü değildir). Doğum yılı bir öz beyandır, ayrıca yalnız yıl alındığından gerçek 13. doğum günü kesin doğrulanamaz. Bunlar 35 ile tamamen çözülmüş iddia edilmemelidir. 35'in canlı uygulanması bu inceleme kapsamında yapılmadı.

## Resend kontrolü

6 Kasım Safari'de önceden açık Resend sekmesi yoktu. Ayrı pencerede Resend Domains giriş ekranına yönlendiği görüldü; oturum kapalı olduğundan domain doğrulaması, teslim ve kota durumu okunamadı. Pencere kapatıldı, e-posta gönderilmedi.

Kullanıcı sonradan giriş yaptı: Safari Domains ekranında `mail.pomosprint.app` **Verified** ve gönderime hazır göründü; SPF/DKIM başlıkları vardı, Free plan etiketi görüldü. E-posta geçmişi yüklenmediğinden gerçek teslimat ve kullanılan kota doğrulanamadı. E-posta gönderilmedi.
