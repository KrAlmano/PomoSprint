# TUS, Deneme ve aylık hedef ligleri — sunucu QA

Durum: **27/28/29 proposed paketleri yalnız yerelde kuruldu ve sınandı. Canlıya okuma/yazma veya deploy yapılmadı.** Flutter/native bütünleşik sonuçlar ayrı gece raporundadır; burada o sonuçlar tekrar iddia edilmez.

## Kapsam ve değişiklikler

- `27_tus_segment`: mevcut altı hedefi koruyan TUS constraint; eski sunucu istemci yedeğiyle uyumlu.
- `28_exam_core`: sürümlü yedi sınav kataloğu; server-clock başlat/bitir/vazgeç; değişmez süre ve ekonomi snapshot'ı; owner-only RLS; ayrı deneme cüzdanı; güvenli net giriş/düzenleme; paylaşılan04:00 seri/toplam dakika; normal seansla atomik çakışma koruması; Sosyal'de Denemede; owner-only normal/Maraton rapor metaverisi.
- `29_monthly_competitions`: tek birleşik normal+deneme lig şeması; İstanbul00:00 takvim ayı; hedefe göre25kişilik odalar; ek global görünüm; sonraki ay hedef değişimi; yeterlilik/terfi/düşme/gerçek ödül; eski dönem arşivi ve tek seferlik kapanışı; eski TABLE/V2 RPC adaptörleri; yeni sitenin masked public RPC'si.
- Deneme oranı kullanıcı temsilcisi ana ajan tarafından varsayım olarak onaylandı: `floor(dakika/5)` ayrı puan, `floor(dakika/25)` ayrı kum. Netten bağımsızdır. Vazgeçme geçmişi ve elapsed korunur; çalışma/seri/ekonomi katkısı0.
- Deneme avatar slotları hazırlanır ama `avatar_id=NULL` olur. Görseller gelmeden ödül varmış gibi sunulmaz.
- Hesap silme yeni FK satırlarını cascade eder, yeni arşiv JSON'undan ilgili kimliği çıkarır.

## Gerçek test sonuçları

| Süit | Sonuç | Kanıtladığı |
|---|---:|---|
| `overnight_exam_backend.py` | **52/52** | Yedi katalog/süre/net, owner RLS, erken ret, UUID idempotency, normal/deneme çakışması, ayrı cüzdan, negatif net ve düzenleme, değişmez snapshot, gerçek60sn server-clock tamamlama yarışı, sosyal gizleme/engelleme, ay sınırı ve hedef geçişi |
| `overnight_competition_backend.py` | **21/21** |26 eşzamanlı normal tamamlama;25+1 odalar; hedef izolasyonu; global görünüm ayrı ödül üretmez; iki türde ay kapanışı, terfi/düşme/ödül/idempotency; eksik deneme-avatar ödülü verilmez |
| `overnight_transition_metadata.py` | **20/20** | Aktif eski dönem next-month sınırında kapanır, önceki ödül/lifetime korunur; ilk dakikada yeni üyelik doğru kademeye taşınır; normal/Maraton adet ve tamamlanma metaverisi;04:00 sınırında exam→normal105dk ve2gün seri, ayrı ekonomiler |
| `overnight_privacy_retention.py` | **26/26** | Ters ve karşılıklı engel maskeleme/tekilleştirme; eski RPC şekilleri; null/bozuk scope ret; cross-mode start yarışı; doğrudan süre/ödül/net yazımı ret; bitmiş UUID yeniden başlamaz; rollback kayıp riski varsa ret; hesap silme cascade ve arşiv kimliği temizleme |
| `overnight_migration_safety.py` | **16/16** | Her üç ileri gövde DRYRUN ile birebir; DRYRUN'da tüm maddelertrue ve her işlem geri alınır; sıra ve migration kayıtları; ters sırada tam şema/fonksiyon/ACL/cron eşitliği |
| `overnight_target_reservation.py` | **15/15** | İlk aktif normal rezervasyon ve ilk aktif denemede hedef sonraki ayı bekler; etkinliksiz ilk seçim hemen geçer; mevcut puan/oda korunur; iki mod aynı hedefle yeni aya geçer; kapanmış ayın geç olayı kesinleşmiş sonuç/ödülü değiştirmez |

Süitler ayrı kapsamları ölçer, Flutter test toplamına eklenmez. Makine okunur sonuçlar `build/overnight_backend/{exam_backend_results,competition_backend_results,transition_metadata_results,privacy_retention_results,migration_safety}.json`; kaynak SHA-256 listesi `source_snapshot.json`. Build çıktıları geçicidir; kalıcı sonuç bu rapordur.

**Zaman kapsamı:** Gerçek duvar saati deneyi yalnız izole review kataloğunda60sn'dir. Standart75/80/120/135/165/180dk ve geçmiş ay sınırları, server-clock kurallarını test eden kontrollü tarihli fixture'larla ayrıca sınandı. Bunlar tam süreli native kullanım veya doğal ayın değişmesini bekleme iddiası değildir. Native süre/cihaz sonuçları ana gece raporunda ayrıdır.

## İncelemede bulunan ve düzeltilenler

1. Yerel clone aracı `ops` şemasını kopyalamıyordu; `handle_new_user` nötr ad fonksiyonu yeni test hesabında hata veriyordu. `pg_dump` kapsamına ops eklendi. Ana/canlı şemada ürün hatası yoktu.
2. Ana ajan iki yönlü engelleme açığını buldu: segment satırları yalnız benim engellediklerimi maskeliyordu. Yeni kod iki yönlü EXISTS kullanır; karşılıklı iki block satırı listeyi çoğaltmaz. Ters/çift block regresyonları geçti.
3. Eski dönemin kapanışı anındaki yeni üyelikler eski kademede kalabilirdi. Aynı bakım transaction'ında güncel ay üyelikleri yeni kademeye, katılım tarihi/puanı korunarak yeniden yerleştirilir.
4. Yeni arşiv JSON'unda hesap silindikten sonra kimlik kalma riski giderildi; private scrub trigger ve cascade testleri var.
5. İlk düşme fixture'ı son72saate katılmış kullanıcıyı düşmeyi bekliyordu. Ürün koruması doğruydu; geçmiş katılım fixture'ı düzeltildi. İlk kısa server-clock fixture'ı dakika toplamı için2sn kullanıyordu; test60sn gerçek süreye çevrildi. Bu iki durum ürün kusuru sayılmaz.
6. İlk normal seans sürerken henüz tamamlanmış satır olmadığı için hedef hemen değişebiliyordu; ilk deneme ise aktif kaydı nedeniyle sonraki aya erteleniyordu. 29 paketinin hedef trigger'ı aktif normal sunucu rezervasyonunu da sayıyor. 15 yeni kontrol ve 16 migration/DRYRUN kontrolüyle doğrulandı.

**Geç kayıt sınırı:** Kesinleşmiş aya sonradan kabul edilen çevrimdışı normal seans, gerçek bitiş ayının geçmişine ve toplamlarına eklenir. `competition_results`, kademe ve ödül tekrar hesaplanmaz; sonlandırılmış sonuçlar değişmez. Yeni 15 testte bu davranış geçmiş tarihli fixture ile doğrulandı; doğal ay dönüşünü bekleme veya tam süreli native kullanım iddiası değildir.

## Ortam

Yalnız `supabase_db_pomosprint-local` üzerinde çalışıldı; diğer projelerin14 container'ı değiştirilmedi. Yeni yerel baz: tarihli snapshot → incelenmiş12/15/16/19A/13/14/20…26 → üç Maraton, rapor kilidi,8Ekim lig, özel avatar/Ronin → yeni27/28/29. 19B otomatik uygulanmadı. Özel avatar fixture zamanları, orijinal silme paketinin katalog guard'ını gevşetmeden9Ekim snapshot'ıyla eşlendi. İlk boş yerel katalog48/avatar ve0hesap/0seanstı; sonraki native QA hesapları ayrı iş akışının verisidir.

Yerel Auth `enable_confirmations=true`; çalışan Auth container'ında `GOTRUE_MAILER_AUTOCONFIRM=false`, SMTP yalnız `supabase_inbucket_pomosprint-local`; Mailpit 54324. Yerel `after_insert_marketing_subscribers` trigger'ının kapalı (`tgenabled=D`) olduğu ayrıca doğrulandı; yerel QA kaydı canlı karşılama webhook'una gönderilmez. Bu rapor e-posta teslimini veya native onay ekranını test ettiğini iddia etmez. `.env` dosyaları okunmadı, canlı API kullanılmadı, stage/commit yapılmadı. Python derleme, shell syntax ve `git diff --check` temizdir.

## Sabah kurulum/devir

[Kurulum ve güvenli rollback rehberi](../supabase/proposed/NIGHT_20261028_README.md), [API sözleşmesi](../supabase/proposed/EXAM_API_CONTRACT.md), [resmî sınav kaynakları](SINAV_KAYNAKLARI_2026-10-28.md). Canlıya uygulamadan önce güncel fonksiyon/constraint parmak izlerini kullanıcı onaylı akışta yeniden doğrulayın; mevcut kaynak hash'leriyle eşleşmiyorsa guard kaldırmayın. Sıra27→28→29; her adım önce kendi DRYRUN. Deneme ligi görselleri ve canlı SQL/site deploy'u bekler. Mevcut Apple/gerçek cihaz/operasyonel güvenlik açıklarının kapandığı iddia edilmez.

## I-10 yerel e-posta onayı desteği

`e2e_host.py` için `POST /confirm-email` eklendi. Gövde yalnız `{"email":"…@pomosprint.local"}` olabilir. Yardımcı en fazla 15 saniye yerel Mailpit'i bekler; alıcının hem liste hem ileti ayrıntısında aynı olduğunu doğrular. Yalnız tam `http://127.0.0.1:54321/auth/v1/verify` adresindeki signup bağlantısını kabul eder; haricî host, yanlış port/yol, recovery türü, tekrarlanan parametre ve haricî dönüş adresini reddeder. HTTP yönlendirmesini takip etmez, ortam proxy'lerini kullanmaz, token veya ileti içeriğini loglamaz. Yanıtta yalnız `confirmed` ve gerekirse sabit hata kodu bulunur.

Host artık varsayılan/eski cihaz UUID'si kullanmaz: `--udid` veya `--android-serial` açıkça ve tek başına zorunludur. Mevcut çalıştırma betikleri zaten cihazı açıkça geçirir.

`python3 tool/local_supabase/e2e/sim/test_local_mailpit.py --live`: **16 test geçti.** Güvenli ayrıştırma, yanlış alıcı/host/yol/parametre, yönlendirmeyi takip etmeme, token loglamama ve cihaz seçimi doğrulandı. Gerçek yerel kayıt önce oturum vermedi; onaysız parola girişi `email_not_confirmed` aldı; yeni endpoint Mailpit onayını gerçekleştirdi; ardından parola girişi başarılı oldu. Sadece bu testin oluşturduğu hesap sonunda silindi. Bu sonuç Resend veya canlı e-posta teslimi iddiası değildir. Makine sonucu: `build/overnight_backend/mailpit_helper_results.json`.

## İncelenmiş yerel şema eşitliği

Varsayılan `parity_check.sh` eski kayıtlı canlı referansını aynen korur. Yeni yerel aday yalnız açık `--reviewed-night-20261028` seçeneğiyle ayrı `parity/reviewed_night_20261028.json` referansına karşı denetlenir. Bu yol 11 kaynak dosyasının SHA-256 değerini; bütün public şema, RLS, ACL, fonksiyon, trigger, cron ve diğer 13 parmak izi kategorisini; migration listesini; 48 avatar, 7 sınav ve 30 ödül slotunun katalog hash'lerini denetler. Yerel karşılama webhook trigger'ı kapalı olmalıdır. Sadece sabit `127.0.0.1:54322/postgres` kabul edilir; tüm sorgular salt okumadır. Otomatik referans yenileme veya kontrol atlama seçeneği yoktur.

`bash tool/local_supabase/parity_check.sh --reviewed-night-20261028` **geçti**. `python3 tool/local_supabase/parity/test_reviewed_parity.py` **6/6 geçti**: kaynak/şema-yetki/migration/katalog/trigger değişimi ve farklı bağlantı adresi reddedilir. Bu eşitlik canlı sunucunun güncel hâliyle eşitlik anlamına gelmez.

## I-08 çok hesaplı native test hazırlığı

`i08_multiuser_fixture.py` ile **9 yeni yerel hesap** gerçek e-posta onayıyla açıldı: 1 gözlemci + 8 arkadaş. Kodla istek/kabul ve ters arkadaşlık kontrolleri geçti. Gözlemcinin gerçek Sosyal RPC'si **8 farklı UID: 4 odak, 2 mola, 2 deneme** döndürdü. Token/parola manifestte bulunmadığı doğrulandı. Bu, 8 ayrı native cihaz veya tamamlanmış Maraton deneyi değildir; native gözlemci testi ana ajan tarafından ayrıca çalıştırılır.

Yeni fixture araçlarının **7/7 güvenlik testi geçti**. Sabit loopback dışı ortam/path, kişisel hesap, izin listesi uyuşmazlığı, mevcut geçmişin üzerine yazma, yanlış fixture işareti ve HTTP yönlendirmesi reddedilir. Ayrı geçici QA hesabında deneme geçmişi hazırlayıcı sınandı: iki kontrollü 165 dakikalık TYT kaydı, Türkçe net 19/27, 330 dakika toplam, normal ekonomi 0, deneme ekonomisi 66 puan/12 kum. Bu geçici hesap testten sonra silindi; native I08 hesapları korunuyor. Kontrollü geçmiş kayıtları doğal tam süreli test diye sayılmaz.

Komutlar ve temizleme sınırları: [I08_FIXTURES.md](../tool/local_supabase/e2e/I08_FIXTURES.md). Native satır/dil/yenileme testinin kaynağı `integration_test/q_social_eight_accounts_test.dart`; burada henüz cihazda çalıştırıldığı iddia edilmez.
