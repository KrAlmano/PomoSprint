# 28 Ekim 2026 — TUS/DUS/KPSS, Deneme ve birleşik aylık lig paketleri

**Durum: yalnız yerelde hazırlanmıştır; canlıya uygulanmadı.** Gece boyunca canlı Supabase'e okuma/yazma isteği yapılmaz. Yeni uygulama eski sunucuda Deneme için güvenli hazırlık/kapalı görünümünü kullanır; eski normal seans/Maraton sürer.

Güncel yerel sözleşme aynı paketler içinde DUS ve KPSS içerir; yeni bir paket numarası açılmadı. Yirmi sınav/testin tek ödül tablosu ve AYT erken bitiş/ayrıntılar için [32 rehberi](32_exam_details_early_finish_README.md) geçerlidir. KPSS üç130dk GY–GK ve dokuz ayrı Alan Bilgisi testidir;27/29 zaten `kpss` içerdiği için yeniden değiştirilmez. Önceki yedi/sekiz sınavlı yerel veritabanları korunur. KPSS zinciri yeni ve boş `pomosprint_review32_kpss` üzerinde kurulur; DUS'un `review` ve `site` hedefleri otomatik taşınmaz. **31 bu akışta yoktur.**

## Uygulama sırası

| Sıra | Önce geri alınan kontrol | İleri | Geri alma |
|---|---|---|---|
| 1 | `27_tus_segment_dryrun.sql` | `27_tus_segment.sql` | `27_tus_segment_down.sql` |
| 2 | `28_exam_core_dryrun.sql` | `28_exam_core.sql` | `28_exam_core_down.sql` |
| 3 | `29_monthly_competitions_dryrun.sql` | `29_monthly_competitions.sql` | `29_monthly_competitions_down.sql` |
| Ek güvenlik | `30_session_start_atomic_dryrun.sql` | `30_session_start_atomic.sql` | `30_session_start_atomic_down.sql` |
| 4 | `32_exam_details_early_finish_dryrun.sql` | `32_exam_details_early_finish.sql` | `32_exam_details_early_finish_down.sql` |

Dosyalar bu klasördedir. İleri/down başındaki `\echo` ve `\quit` satırları yanlışlıkla CLI uygulamasını önler. Sabah kullanıcı incelemesinde SQL Editor için yalnız bu iki satır kaldırılır. DRYRUN olduğu gibi çalıştırılır; sondaki **`DRYRUN_RESULT` hatası bilinçli rollback** sonucudur. Her Txx sonucu `true` olmalıdır. Her DRYRUN, kendi önceki paketleri kurulmuş durumda çalıştırılır. Bir adım başarısızsa devam edilmez. **Toplu `db push/reset` yoktur.**

27, altı eski hedefin tamamını koruyup `tus` ve `dus` ekler. 28, 8 Ekim sonrası normal başlatma/sosyal/tamamlama gövde parmak izlerini denetler. Kaynaklar 27 Ekim kontrolünden sonra yeniden canlıdan okunmadığından sabah canlı tanımla eşleştirme gerekir; uyuşmazlıkta guard kaldırılmaz, paket yeniden incelenir.

## Deneme ve ekonomi

Tam API: [EXAM_API_CONTRACT.md](EXAM_API_CONTRACT.md). Katalog: [exam_catalog_v1.json](exam_catalog_v1.json); resmî süre/soru/net kaynakları: [Sınav kaynakları](../../analiz/SINAV_KAYNAKLARI_2026-10-28.md).

- Her denemenin sunucu başlangıcı, bitişi ve tam katalog sürümü değişmez snapshot'tır. Başlangıçtan önce 3-2-1 istemcide; başlangıç isteği aynı kalıcı UUID ile yeniden denenir.
- Normal tamamlama RPC’sinde erken bitirme, başkasının denemesi, üst üste seans ve tekrar ödül reddedilir.32’nin ayrı AYT erken bitiş RPC’si gerçek süreyi kabul eder; diğer türler tam süre ister. Normal başlangıç/deneme başlangıcı/tamamlama aynı profil satırını kilitler. Normal tamamlamanın INSERT trigger'ı deneme aralığıyla çakışırsa bütün ekonomik transaction geri alınır.
- Puan: her **5 dakika için 1 deneme puanı**.32 ile kum tek tabloda LGS Sözel60, LGS Sayısal70, YDT95, TUS Temel110, TUS Klinik110, DUS120, TYT130, AYT145; KPSS GY–GK105,50dk Alan Bilgisi40,60dk İstatistik50 olur. Yirmi katalog satırında reward_policy_version2. AYT erken bitiş kumu gerçek sürenin dondurulmuş tam ödüle oranıdır. Bunlar katalog snapshot’ındadır. Normal puan/kum cüzdanına eklenmez; netler sonucu değiştirmez.
- Vazgeçme `abandoned` ve sunucunun ölçtüğü `elapsed_seconds` ile geçmişte saklanır. Sayı, toplam çalışma süresi, seri veya ekonomi kazandırmaz. Tam süre dolmuşsa vazgeçme isteği güvenli/idempotent tamamlamaya döner.
- Kapanma ve arka plan süreyi durdurmaz; uygulama açıldığında aynı sunucu zamanlarıyla devam edilir. Bu, kullanıcının fiziksel dikkatini ölçen bir cihaz tasdiki değildir.
- D-05: Yeni başlangıç aynı sahibin süresi dolmuş aktif denemesini önce normal tamamlama yoluyla bir kez kapatır. Süresi dolmuş aynı UUID tekrarında da yeni kayıt açmadan tamamlanmış makbuz döner. Orijinal süre/bitiş/ödül snapshot'ı korunur; henüz dolmamış deneme yine çakışma hatası verir.
- Tamamlanan deneme toplam çalışma dakikası ve 04:00 çalışma günü serisine katkı verir; Pomodoro/Maraton ekonomisiyle karışmaz. Süre derslere paylaştırılmaz. Raporlar ayrıca tamamlanmış denemeleri birleştirir.
- Net satırı dersin tam soru toplamını karşılar, boşlar açıkça kaydedilir. Eksik ders sonucu “0 net” diye uydurulmaz; gönderilmeyen ders korunur. Negatif net geçerlidir. Sahip dışındaki istemci deneme/net okuyamaz veya yazamaz.
- TUS'ta yedi temel ve dört klinik resmî test grubu vardır. TUS Fizyoloji ile Histoloji/Embriyoloji, `Fizyoloji, Histoloji ve Embriyoloji` çalışma kategorisine; AYT edebiyatı `Edebiyat` ve `Türkçe` kategorilerine bağlanır. Birleşik kategorinin aynı dakika toplamı her ilgili net karşılaştırmasına bağlam olur; derslere paylaştırılmaz ve toplam çalışma süresini artırmaz. Arayüz bu yüzden “İlişkili çalışma kategorilerinde …” der. “Küçük Stajlar” için resmî ayrı soru kotası veya uydurma ders eşlemesi yoktur; yetersiz sonuç içgörü oluşturmaz.

DUS tek150 dakika/120 soru oturumdur:16 ayrı ders ve kategori, temel bilim40/klinik bilim80 standart dağılım. [ÖSYM2026 DUS2 kılavuzu](https://dokuman.osym.gov.tr/web/2026/9/basvuru-kilavuzu-e1esxj-16163038.pdf), §1.3 ve basılı sayfa40 Tablo1 bu planın kaynağıdır. Kılavuz dağılımın yaklaşık olduğunu belirtir; her kitapçık için sabit kota iddiası değildir.

## Tek aylık lig geçişi

29 hem normal hem deneme ligini ve hedef ayrımını **bir kez** oluşturur; ayrı paketler aynı lig tablosunu yeniden değiştirmez. Yeni tablolar `competition_*` ad alanındadır. Hesap silmede owner satırları FK cascade ile, yeni arşiv JSON kimlikleri private temizleme triggerıyla kaldırılır. Eski `leagues`, `league_memberships`, kazanılmış avatarlar, lifetime puan/kum, seri ve çalışma kayıtları silinmez.

- Lig ayı **Europe/Istanbul ayın 1'i 00:00** sınırıdır. Puanı hangi aya yazacağını normalde `completed_at`, denemede gerçek `finished_at` belirler; tam süreli kayıtta bu `ends_at` ile aynıdır. Çalışma günü ve seri **profil saat diliminde 04:00** olarak kalır. Örneğin 1 Kasım 03:30'da başlayan denemenin çalışma süresi 31 Ekim çalışma günündedir; lig puanı Kasım'dadır.
- Normal ve deneme ayrı `kind=study|exam` kayıtlarıdır. Her tür kendi hedef odasında en fazla25 kişiyle yarışır. Global sıralama bütün hedeflerin aynı tür puanını gösteren ek görünümdür; ikinci ödül/cüzdan oluşturmaz.
- İlk puanlı aktivite odaya yerleştirir. Üçten az aktif kişide hazırlık vardır. Terfi için ham sıranın ilk `floor(aktif/3)` içinde olması, en az3 çalışma günü/300dk/pozitif puan gerekir. Düşme en az10 aktif kişide son `floor(aktif/3)`; son72saatte katılan korunur. Bronz–Elmas sınırları korunur.
- Normal avatar ödülü en az10 aktif kişi, ilk3 ve aynı kişisel yeterlilikle verilir. Deneme ödül slotları15 adet `NULL` yer tutucudur; gerçek görseller/katalog gelmeden hayalî avatar açılmaz veya kuşanılmaz.
- Kurulum ayının aylık kayıtları yeniden hesaplanır; resmi yeni aylık rekabet sonraki ayın başında etkinleşir. Geçişe kadar eski dönem bakım motoru sürer. Geçiş anında son eski dönemin geçerli aktivitesi aynı yeterlilikle bir kez karara bağlanır; sonuçlar ve son üyelikler arşivlenir. Önceden kazanılmış avatar silinmez.
- İlk00:00–00:01 aralığında gelmiş yeni seans eski kademeye yerleşmişse bakım, yeni kademeye geçirir; puanı ve katılım zamanı korunur. Gecikmiş cron da kapalı ayları sırayla/idempotent işler. Eski TABLE/V2 RPC'ler korunmuş alanlarla yeni aylık veriyi döndürür.
- D-03: Günlük bakım önce kilitsiz olarak gerçekten kapanacak dönem/legacy geçişi var mı bakar. İş yoksa profil kilidi almadan döner. İş varsa eski kilit sırası korunur; kilit altında tekrar kontrol edilerek iki worker'ın aynı işi tekrarlaması engellenir.
- Ay ortasında hedef değişimi sonraki ay için tutulur. Mevcut ay hedefi/odası/puanı değişmez; global/segment sekmesine basmak hedefi değiştirmez. İlk çalışmadan önceki onboarding seçimi hemen uygulanır. İlk normal seansın aktif sunucu rezervasyonu veya ilk deneme kaydı bulunduğunda da hedef değişikliği sonraki ayı bekler; iki mod bu konuda aynı davranır. Süresi dolmuş, hiç tamamlanmamış normal rezervasyon tek başına ilk seçimi kilitlemez.
- **Kapanmış ayın çevrimdışı kayıt politikası:** Kabul edilen geç seansın gerçek bitiş tarihi korunur; çalışma geçmişi, toplamları ve o eski aya ait event kaydı eklenir. Kesinleşmiş aylık sıralama, kademe kararı ve avatar ödülü yeniden hesaplanmaz. Aynı olayı tekrar göndermek ek ödül üretmez. Bu nedenle ay kapandıktan sonra gönderilen eski seansa geriye dönük terfi veya ödül vaat edilmez.

## Geri alma ve kayıt güvenliği

Ters sıra32→30→29→28→27.32 kişisel ayrıntı veya erken bitiş geçmişi oluşmuşsa veri kaybını önlemek için reddeder. 29, aktivasyondan sonra veya kaybolacak bekleyen hedef tercihi/işlenmiş sonuç varsa **reddeder**; telafi migration gerekir. 28, kaydedilmiş tek bir deneme/cüzdan varsa **reddeder**, geçmişi silmez. 27, TUS veya DUS profili varsa **reddeder**, hedefi sessizce NULL yapmaz. Boş izole kopyada ileri→down şema/fonksiyon/ACL/cron eşitliği test edilir. Canlı kullanıcı verisi silinerek rollback zorlanmaz.

## Yerel tekrar

Yerel proje `pomosprint-local`; yeni Auth e-posta onayı açıktır, gönderim yalnız Mailpit54324'te kalır. [Yerel rehber](../../tool/local_supabase/README.md).

```sh
# Yalnız yeni ve boş yerel snapshot üzerinde eski incelenmiş paketleri kurar:
python3 tool/local_supabase/prepare_overnight_backend.py
# Her yeni paket tek tek, yerel SQL sahibiyle ve header guard'ı bilinçli kaldırılarak kurulur.
# Testler kendi sabit isimli review DB'lerini kullanır; ana QA hesaplarını silmez:
python3 tool/local_supabase/e2e/overnight_migration_safety.py
python3 tool/local_supabase/e2e/overnight_exam_backend.py
python3 tool/local_supabase/e2e/overnight_competition_backend.py
python3 tool/local_supabase/e2e/overnight_transition_metadata.py
python3 tool/local_supabase/e2e/overnight_privacy_retention.py
python3 tool/local_supabase/e2e/overnight_target_reservation.py
python3 tool/local_supabase/e2e/overnight_d03_d05.py
# Yeni yerel şema için açıkça incelenmiş referansı seçer; varsayılan canlı referansı değişmez:
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028
# Yerel QA'ya ek30 kurulduysa açıkça farklı referans seçilir:
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic
```

Bu testlerin review DB hazırlama adımları gece raporunda bulunur. Şema testi kendi başına native test değildir. Gerçek60sn yerel sınav kataloğu deneyi tam75/135dk native denemesinin yerine sayılmaz; kontrollü tarihli kayıtlar da gerçek ayın geçmesini beklemiş sayılmaz.

## Tarihsel öneri31: bu DUS akışında uygulanmadı

[31 rehberi](31_marathon_completion_anchor_README.md) mevcut Maraton onay fonksiyonuna ayrı bir düzeltmedir; lig tablolarını yeniden değiştirmez. Gecikmiş, duraklatılmamış ilk/ara odakta mola ve onay süresi kabul edilen gerçek odak sonuna bağlanır. Normal seansın puanı/kumu korunur. Duraklatılmış kolun gerçek sonu mevcut API'de ayırt edilemediğinden eski davranışı korunur; bütün AFK yolları kapatılmış sayılmaz.

Gece ortamında sıra27→28→29, bağımsız30 ve ardından ayrı31 olarak doğrulanır.31 canlıya uygulanmadı. Kendi gövde hash ön koşulu ve13maddelik DRYRUN'ı vardır;96izole kontrol geçti. Geçerli ve geçersiz onay,25/50, ara/final odak, idempotency ve geri alma kapsanır.31 kurulduysa geri alma önce31, ardından gerekiyorsa30 ve29→28→27 şeklindedir.31 geri alımı mevcut seans/plan/geçersizlik kararlarını silmez; yalnız gelecekteki çağrılar için eski işlevi getirir.

Yeni yerel31 paritesi açıkça `--reviewed-night-20261028-with-marathon-anchor` ile seçilir. Eski referanslar yerinde kalır. Yeni şemaya geçtiğinizde native çalıştırıcı için `E2E_REVIEWED_NIGHT=3` gerekir.
