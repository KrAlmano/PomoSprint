# 28 Ekim 2026 — TUS, Deneme ve birleşik aylık lig paketleri

**Durum: yalnız yerelde hazırlanmıştır; canlıya uygulanmadı.** Gece boyunca canlı Supabase'e okuma/yazma isteği yapılmaz. Yeni uygulama eski sunucuda Deneme için güvenli hazırlık/kapalı görünümünü kullanır; eski normal seans/Maraton sürer.

## Uygulama sırası

| Sıra | Önce geri alınan kontrol | İleri | Geri alma |
|---|---|---|---|
| 1 | `27_tus_segment_dryrun.sql` | `27_tus_segment.sql` | `27_tus_segment_down.sql` |
| 2 | `28_exam_core_dryrun.sql` | `28_exam_core.sql` | `28_exam_core_down.sql` |
| 3 | `29_monthly_competitions_dryrun.sql` | `29_monthly_competitions.sql` | `29_monthly_competitions_down.sql` |

Dosyalar bu klasördedir. İleri/down başındaki `\echo` ve `\quit` satırları yanlışlıkla CLI uygulamasını önler. Sabah kullanıcı incelemesinde SQL Editor için yalnız bu iki satır kaldırılır. DRYRUN olduğu gibi çalıştırılır; sondaki **`DRYRUN_RESULT` hatası bilinçli rollback** sonucudur. Her Txx sonucu `true` olmalıdır. Her DRYRUN, kendi önceki paketleri kurulmuş durumda çalıştırılır. Bir adım başarısızsa devam edilmez. **Toplu `db push/reset` yoktur.**

27, altı eski hedefin tamamını koruyup `tus` ekler. 28, 8 Ekim sonrası normal başlatma/sosyal/tamamlama gövde parmak izlerini denetler. Kaynaklar 27 Ekim kontrolünden sonra yeniden canlıdan okunmadığından sabah canlı tanımla eşleştirme gerekir; uyuşmazlıkta guard kaldırılmaz, paket yeniden incelenir.

## Deneme ve ekonomi

Tam API: [EXAM_API_CONTRACT.md](EXAM_API_CONTRACT.md). Katalog: [exam_catalog_v1.json](exam_catalog_v1.json); resmî süre/soru/net kaynakları: [Sınav kaynakları](../../analiz/SINAV_KAYNAKLARI_2026-10-28.md).

- Her denemenin sunucu başlangıcı, bitişi ve tam katalog sürümü değişmez snapshot'tır. Başlangıçtan önce 3-2-1 istemcide; başlangıç isteği aynı kalıcı UUID ile yeniden denenir.
- Sunucuya erken tamamlama, başkasının denemesi, üst üste seans ve tekrar ödül reddedilir. Normal başlangıç/deneme başlangıcı/tamamlama aynı profil satırını kilitler. Normal tamamlamanın INSERT trigger'ı deneme aralığıyla çakışırsa bütün ekonomik transaction geri alınır.
- Ödül varsayımı: tam süreli her **5 dakika için 1 deneme puanı**, her **25 dakika için 1 deneme kumu**, aşağı yuvarlama. Bunlar katalog snapshot'ındadır. Normal puan/kum cüzdanına eklenmez; netler sonucu değiştirmez.
- Vazgeçme `abandoned` ve sunucunun ölçtüğü `elapsed_seconds` ile geçmişte saklanır. Sayı, toplam çalışma süresi, seri veya ekonomi kazandırmaz. Tam süre dolmuşsa vazgeçme isteği güvenli/idempotent tamamlamaya döner.
- Kapanma ve arka plan süreyi durdurmaz; uygulama açıldığında aynı sunucu zamanlarıyla devam edilir. Bu, kullanıcının fiziksel dikkatini ölçen bir cihaz tasdiki değildir.
- Tamamlanan deneme toplam çalışma dakikası ve 04:00 çalışma günü serisine katkı verir; Pomodoro/Maraton ekonomisiyle karışmaz. Süre derslere paylaştırılmaz. Raporlar ayrıca tamamlanmış denemeleri birleştirir.
- Net satırı dersin tam soru toplamını karşılar, boşlar açıkça kaydedilir. Eksik ders sonucu “0 net” diye uydurulmaz; gönderilmeyen ders korunur. Negatif net geçerlidir. Sahip dışındaki istemci deneme/net okuyamaz veya yazamaz.
- TUS'ta yedi temel ve dört klinik resmî test grubu vardır. “Küçük Stajlar” için uydurma soru kotası yoktur. Fizyoloji/Histoloji/Embriyoloji birleşik çalışma kategorisi, aynı süreyi iki farklı dersin kanıtı yapmaz.

## Tek aylık lig geçişi

29 hem normal hem deneme ligini ve hedef ayrımını **bir kez** oluşturur; ayrı paketler aynı lig tablosunu yeniden değiştirmez. Yeni tablolar `competition_*` ad alanındadır. Hesap silmede owner satırları FK cascade ile, yeni arşiv JSON kimlikleri private temizleme triggerıyla kaldırılır. Eski `leagues`, `league_memberships`, kazanılmış avatarlar, lifetime puan/kum, seri ve çalışma kayıtları silinmez.

- Lig ayı **Europe/Istanbul ayın 1'i 00:00** sınırıdır. Puanı hangi aya yazacağını normalde `completed_at`, denemede değişmez `ends_at` belirler. Çalışma günü ve seri **profil saat diliminde 04:00** olarak kalır. Örneğin 1 Kasım 03:30'da başlayan denemenin çalışma süresi 31 Ekim çalışma günündedir; lig puanı Kasım'dadır.
- Normal ve deneme ayrı `kind=study|exam` kayıtlarıdır. Her tür kendi hedef odasında en fazla25 kişiyle yarışır. Global sıralama bütün hedeflerin aynı tür puanını gösteren ek görünümdür; ikinci ödül/cüzdan oluşturmaz.
- İlk puanlı aktivite odaya yerleştirir. Üçten az aktif kişide hazırlık vardır. Terfi için ham sıranın ilk `floor(aktif/3)` içinde olması, en az3 çalışma günü/300dk/pozitif puan gerekir. Düşme en az10 aktif kişide son `floor(aktif/3)`; son72saatte katılan korunur. Bronz–Elmas sınırları korunur.
- Normal avatar ödülü en az10 aktif kişi, ilk3 ve aynı kişisel yeterlilikle verilir. Deneme ödül slotları15 adet `NULL` yer tutucudur; gerçek görseller/katalog gelmeden hayalî avatar açılmaz veya kuşanılmaz.
- Kurulum ayının aylık kayıtları yeniden hesaplanır; resmi yeni aylık rekabet sonraki ayın başında etkinleşir. Geçişe kadar eski dönem bakım motoru sürer. Geçiş anında son eski dönemin geçerli aktivitesi aynı yeterlilikle bir kez karara bağlanır; sonuçlar ve son üyelikler arşivlenir. Önceden kazanılmış avatar silinmez.
- İlk00:00–00:01 aralığında gelmiş yeni seans eski kademeye yerleşmişse bakım, yeni kademeye geçirir; puanı ve katılım zamanı korunur. Gecikmiş cron da kapalı ayları sırayla/idempotent işler. Eski TABLE/V2 RPC'ler korunmuş alanlarla yeni aylık veriyi döndürür.
- Ay ortasında hedef değişimi sonraki ay için tutulur. Mevcut ay hedefi/odası/puanı değişmez; global/segment sekmesine basmak hedefi değiştirmez. İlk çalışmadan önceki onboarding seçimi hemen uygulanır. İlk normal seansın aktif sunucu rezervasyonu veya ilk deneme kaydı bulunduğunda da hedef değişikliği sonraki ayı bekler; iki mod bu konuda aynı davranır. Süresi dolmuş, hiç tamamlanmamış normal rezervasyon tek başına ilk seçimi kilitlemez.
- **Kapanmış ayın çevrimdışı kayıt politikası:** Kabul edilen geç seansın gerçek bitiş tarihi korunur; çalışma geçmişi, toplamları ve o eski aya ait event kaydı eklenir. Kesinleşmiş aylık sıralama, kademe kararı ve avatar ödülü yeniden hesaplanmaz. Aynı olayı tekrar göndermek ek ödül üretmez. Bu nedenle ay kapandıktan sonra gönderilen eski seansa geriye dönük terfi veya ödül vaat edilmez.

## Geri alma ve kayıt güvenliği

Ters sıra29→28→27. 29, aktivasyondan sonra veya kaybolacak bekleyen hedef tercihi/işlenmiş sonuç varsa **reddeder**; telafi migration gerekir. 28, kaydedilmiş tek bir deneme/cüzdan varsa **reddeder**, geçmişi silmez. 27, TUS profili varsa **reddeder**, hedefi sessizce NULL yapmaz. Boş izole kopyada ileri→down şema/fonksiyon/ACL/cron eşitliği test edilir. Canlı kullanıcı verisi silinerek rollback zorlanmaz.

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
# Yeni yerel şema için açıkça incelenmiş referansı seçer; varsayılan canlı referansı değişmez:
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028
```

Bu testlerin review DB hazırlama adımları gece raporunda bulunur. Şema testi kendi başına native test değildir. Gerçek60sn yerel sınav kataloğu deneyi tam75/135dk native denemesinin yerine sayılmaz; kontrollü tarihli kayıtlar da gerçek ayın geçmesini beklemiş sayılmaz.
