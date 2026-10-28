# 31 — Duraklatılmamış Maraton için sabit mola/onay sınırı

**Yalnız öneridir; canlıya veya ana yerel QA veritabanına uygulanmadı.** Normal çevrimdışı seans kabulü ve ödül formülü değişmez. Duraklatılmış Maratonun AFK sorunu tamamen çözülmüş değildir.

## Sorun ve kapsam

Eski dokuz parametreli `complete_marathon_study_session`, ilk/ara odak geç gönderildiğinde kabul anından başlayan yeni 300+60 saniyelik pencere oluşturur. Uygulama ilk odak bitiminden uzun süre sonra açılsa bile yeni pencere alınabilir. Ayrı klonda, 7 dakika önce bitmiş 25 dakikalık odak için bu davranış yeniden üretildi. Bu davranış `AGENTS.md §5.7`'deki eski sözleşmeyle uyumludur, ancak kullanıcının istediği odak sonrası 5+1 dakika üst sınırını uzatır.

Yeni davranış yalnız `p_was_paused=false` kayıtlarındadır:

- Normal alt RPC kabul ettikten sonra, aynı `user_id` ve `client_uuid` ile kayıtlı `study_sessions.completed_at` okunur. Mola sonu bu zaman+300, onay sonu bu zaman+360 saniyedir.
- 10 saniye geç kabulde yaklaşık 290 saniye mola kalır. Mola bitmiş ancak onay süresi dolmamışsa yalnız kalan onay penceresi vardır.
- Kabul anı onay sonuna eşit veya daha geçse normal seans/puan/kum korunur. Maraton `is_invalid=true`, `marathon_invalid=true`, `marathon_presence_invalid=true`, ek Maraton puanı0 olur. Yeni gate oluşturulmaz. Mevcut istemci bu yanıtta planı temiz durdurur.
- İlk kayıt/sonraki tekrar aynı profil kilidi içindedir. Aynı UUID tekrarında eski kayıtlı sonuç kullanılır; yeni pencere/ödül üretilmez. Son odaktan sonra mola gerekmediği için yeni ara-odak süre denetimi uygulanmaz.
- Mevcut gate veya onay makbuzları topluca yeniden yazılmaz. Önceden kabul edilmiş planlar kendi eski makbuzlarıyla biter.

## Açık kalan duraklatma sınırı

`p_was_paused=true` için eski kabul-anı çıpası **bilinçli olarak korunur**. İstemci `resumeAt` ile gerçek sayaç bitişini ilerletir; mevcut normal RPC'ye ise ilk `started_at` gider ve kayıtlı `completed_at` başlangıç+25/50 dakika olur. Meşru7 dakika duraklatma ile7 dakika gecikmiş gönderimi bu dokuz parametre ayıramaz. Körlemesine eski kayıt sonuna çıpalamak meşru duraklatmayı yanlışlıkla geçersiz sayar.

Duraklatılmış25 dakikanın mevcut normal tabanpuanı4, kumu20 kalır. Gerçek duraklatmayı güvenilir biçimde ayıran tam çözüm, sunucunun yönettiği start/pause/resume kayıtları ve beklenen bitiş gerektirir. Bu paket yeni RPC, istemciden güvenilir kabul edilen bitiş zamanı veya böyle bir kayıt sistemi eklemez. Dolayısıyla **bütün Maraton AFK yollarının kapandığı iddia edilmemelidir**.

`p_was_paused` istemciden gelen mevcut bir alandır; sunucu gerçek bir duraklatmayı bağımsız olarak tasdik etmez. Özel bir istemci bu alanı `true` göndererek eski kola girebilir. Paket, resmi istemcinin duraklatılmamış geç-kabul yolunu daraltır; kötü niyetli bütün istemcilere karşı tam süre tasdiki sağlamaz.

## Uygulama ve geri alma

İlgili üç dosyanın başındaki `\echo`/`\quit` korumaları bilinçlidir. SQL Editor'de çalıştırılacaksa yalnız bu psql satırları çıkarılır.

1. Güncel sunucu fonksiyonunu ve yetkilerini salt okuyarak kontrol et. Beklenen mevcut9 parametreli gövde MD5: `177a238a9aa8a4ffd3738b2865120568`. Farklıysa otomatik ilerleme.
2. `31_marathon_completion_anchor_dryrun.sql`: yeni gövde, yetkiler, normal/özel ödül gövdeleri ve tüm mevcut seans/plan/makbuzların korunması için13 kontrol; sonunda kasıtlı `DRYRUN_RESULT` hatası her şeyi geri alır.
3. Sonuç uygun ve kullanıcı yetkisi varsa `31_marathon_completion_anchor.sql`. Definer/ACL/imza korunur; yalnız fonksiyon ve kendi `20261028050000` migration kaydı değişir.
4. Geri alma gerekiyorsa `31_marathon_completion_anchor_down.sql`. Yalnız beklenen yeni MD5 `21bcbc553a8accbde9ebb061517c174a` varsa eski gövde döner. Mevcut seans, geçersiz plan ve makbuzlar silinmez veya yeniden geçerli yapılmaz. Geri alma eski geç-gönderim pencere politikasını yeni çağrılar için geri getirir.

Bu paket mevcut Maraton onay paketini gerektirir; 27/28/29 veya30 tablolarını ve bu paketlerin fonksiyonlarını yeniden tanımlamaz. Aktif doğal süre testleri sürerken ana QA şemasına uygulanmaz. Yayın sırası ve canlı yetkisi kök raporda ayrıca ele alınır.

## Yerel doğrulama aracı

`tool/local_supabase/e2e/overnight_marathon_anchor.py` yalnız sabit isimli `pomosprint_night_marathon31` klonunda çalışır. Kaynak `pomosprint_night_backend` şemasından ve açık katalog/config listesinden alınır; Auth/profil/kullanıcı seansları kopyalanmaz. Klon önceden varsa işlem reddedilir; yalnız bu çalışmanın oluşturduğu klon sonunda silinir.

```sh
python3 tool/local_supabase/e2e/overnight_marathon_anchor.py --phase before --wait-baseline-ack
python3 tool/local_supabase/e2e/overnight_marathon_anchor.py --phase after
```

İlk komut eski davranışta bilinçli başarısız güvenlik beklentisi üretir; varsayılan300 saniyeyi gerçekten bekleyerek geç odak için sonradan onay alınabildiğini gösterir. İkinci komut öneri/DRYRUN/rollback, sınırlar, değişmez tekrarlar, aynı anda kabul, normal25/50, duraklatılmış istisna ve altı son-odak bonusunu denetler. Önceki onaylı odakların metadata geçmişi yalnız klonda kontrollü fixture'dır; native doğal süre kanıtı değildir. Ödüller public normal/Maraton tamamlama RPC'leriyle hesaplanır.

`full_plan()` bonus matrisinde önceki odak eşlemeleri ve ACK'ler kontrollü geçmiş fixture'ıdır; gerçek bekleyiş veya gerçek onay çağrısı sayılmaz. Bundan ayrı 25 dakikalık ilk odağın ve50 dakikalık ikinci/ara odağın300 ve350 saniye gecikme senaryolarında gerçek `confirm_marathon_presence` çağrısı yapılır. Bu yeni kapının kabul edilmiş odak sonuna+300/+360 bağlı olduğu, onayın açık pencereye düştüğü ve aynı aday UUID'sinin ikinci çağrısının özgün makbuzu döndürdüğü doğrulanır.50 dakikalık ara odağın420 saniye geç kabulü, kendisine ait12 normal puan ve20 kumu koruyarak geçersiz plan ve yeni gate yok sonucu verir.

Sonuçlar `build/overnight_backend/marathon_anchor_before.json` ve `marathon_anchor_after.json` içindedir. Ayrı native süreç kanıtı ve bilinen sınırlar: [Maraton kapanış raporu](../../analiz/QA_MARATON_KAPANIS_2026-10-28.md).

28 Ekim yerel sonuç: eski davranışta6 başarılı kontrol ve1 beklenen güvenlik beklentisi hatası; ayrıca değişmeyen300 saniye gerçekten beklendikten sonra eski pencere için onay kabul edildi. İlk öneri turu73/73; gerçek onay kapsamı eklenmiş son tekrar **96/96 kontrol**, içerilen DRYRUN doğrulamasında **13/13 koşul** başarılıdır. Klonlar kaldırıldı. Son log `/tmp/pomosprint_marathon_anchor_after_extended.log`, yapılandırılmış sonuç `build/overnight_backend/marathon_anchor_after.json`. Bu sonuç kontrollü SQL/RPC testidir; doğal25/50 dakika native çalışması veya canlıya uygulama değildir.

## Ayrı yerel parite modu

31 gerçekten uygulandıktan sonra, önceki modları değiştirmeden şu açık mod kullanılır:

```sh
tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-marathon-anchor
```

Bu mod27/28/29+30+31 için `reviewed_night_20261028_marathon_anchor.json` referansını seçer. Otomatik mod seçimi veya mevcut veritabanından referans güncelleme komutu yoktur.31 uygulanmamışken bu modun şema ve migration farkıyla başarısız olması beklenir; o durumda30 modu geçerli kalır.

Referans,30 referansının kopyasında yalnız31 ileri/down/DRYRUN dosyalarının üç SHA256'sı, `20261028050000|marathon_completion_anchor` migration'ı ve tek fonksiyonun kanonik gövde farkıyla türetildi.113 fonksiyonun sayısı değişmez; yeni `func` özeti `a2b241b2e1ba8a73811e5b8421e009be` olur. Diğer bütün referans alanları aynıdır. Kaynak tahrifi, yanlış referans kimliği ve örtük mod geçişini de kapsayan **14/14 parite birim kontrolü** geçti; önceki8 kontrol korundu.

İzolasyon kanıtı: ana yerel QA'nın30 referansına tam salt-okuma uyumu doğrulandı. Ayrı boş `pomosprint_night_parity31` klonuna yalnız şema/katalog/config/migration metadata'sı kopyalandı. Klonun önce/sonra farkı tek `complete_marathon_study_session` satırı ve tek migration'dır; hesap/seans verisi kopyalanmadı, klon kaldırıldı. PostgreSQL'in `pg_cron` uzantısı yalnız `postgres` veritabanında kurulabildiği için klonda iki açık fark kaldı: `ext` içindeki `pg_cron` ve `extver` içindeki sürümü. Diğer11 şema kategorisi, katalog, migration ve mail-trigger durumları referansla birebirdir. Klon testinde bu sınırlama gizlenmedi; gerçek parite komutu extension kontrollerini gevşetmez. Kanıtlar: `build/overnight_backend/parity31_derivation.json` ve `parity31_clone_proof.json`.
