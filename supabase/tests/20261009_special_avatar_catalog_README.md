# Özel Avatarlar katalog paketi — 9 Ekim 2026

**Durum: 9 Ekim 2026'da kullanıcı SQL Editor'de uyguladı; canlı doğrulandı.** Paket22 avatar ekledi; tanesi500 kum. Kurulum sonrası49 toplam/48 aktif/22 özel/7 aktif ücretsiz, live read-only16/16 ve public REST25/25. Canlı kanıt (ham çıktı §37 temizliğinde kaldırıldı), API kanıtı (ham çıktı §37 temizliğinde kaldırıldı), [devir §35](../../PROJE_DEVIR.md). İleri/DRYRUN dosyalarını aynı canlıda yeniden çalıştırmayın; dosyalardaki NOT APPLIED yorumları kurulum öncesi exact paket arşividir. Özel bayraklar `false/false/false/true`; yeni tablo/kolon/RPC/yetki veya kayıt seçeneği yok.

| Dosya | Amaç |
|---|---|
| [İleri migration](../migrations/20261009190000_special_avatar_catalog.sql) | Yalnız 22 `avatars` satırı ve bu paketin migration geçmişi |
| [DRYRUN](20261009_special_avatar_catalog_dryrun.sql) | Aynı gövdeyi transaction içinde sınar; son bilinçli hata her şeyi geri alır |
| [Down](../rollbacks/20261009190000_special_avatar_catalog_down.sql) | Edinilmemiş/kuşanılmamış ve değiştirilmemiş 22 satırı kaldırır; kullanıcı verisini kaybetmemek için aksi durumda durur |
| [Manifest](../../assets/avatars/special_catalog.json) | Kimlik, TR/EN ad, görsel, fiyat ve kaynak/hash eşleşmesi |
| Backend kanıtları (ham çıktı §37 temizliğinde kaldırıldı) | Güncel canlı salt okuma ve gerçek yerel RPC sonuçları |

## Güncel canlı sözleşme

9 Ekim kurulum öncesi salt okumada katalog 27 satırdı; kurulum sonrası49/aktif48 doğrulandı. Önceki katalogdaki 8 `is_default` kaydından yalnız 7'si aktif ve ücretsizdir. `get_avatar_catalog` RPC yoktur: istemci `avatars` tablosunu okur. `purchase_avatar(text)` profil satırını kilitler, 500 kum bedelini göreli/koşullu düşer, tekrar alımı ücretsiz idempotent döndürür. `set_equipped_avatar(text)` sahiplik ister. `handle_new_user` ve `sanitize_profile_insert` ücretli `special_` kimliğini kayıtta kabul etmez. `give_default_avatars` yalnız aktif varsayılanları açar.

İleri dosya, bu beş fonksiyonun güncel gövde hash'lerini ve mevcut katalog hash'ini doğrular. Katalog/fonksiyon değişmişse veya paket zaten kurulmuşsa işlemi durdurur. Eski dosyaları körlemesine yeniden uygulamayın; yeni salt okuma ve inceleme gerekir.

## Tamamlanan canlı uygulama sırası (tarihçe; yeniden çalıştırmayın)

Kök [AGENTS.md §2.4](../../AGENTS.md) gereği canlı SQL kullanıcı tarafından Supabase SQL Editor'de çalıştırılır. Hazırlık sırasında ajan yalnız canlı **salt okuma** yaptı. Ardından kullanıcı SQL Editor'de ileri paketi uyguladı ve “Success. No rows returned” bildirdi; bu sonuç yeni canlı okumayla bağımsız doğrulandı. Kullanıcının DRYRUN çıktısı bu takip mesajında sunulmadı; önceki yerel10/10 test canlı DRYRUN sonucu diye yazılmaz.

1. Önce [DRYRUN](20261009_special_avatar_catalog_dryrun.sql) dosyasının tamamını SQL Editor'de çalıştırın. Sonuç bilerek `DRYRUN_RESULT >>` hatasıdır. **T01–T10 hepsi `true`** olmalıdır. Başka hata veya `false` varsa ileri dosyayı çalıştırmayın. DRYRUN hesap oluşturmaz veya e-posta göndermez.
2. İleri dosyadan önce yeni normal istemciyi kurun: görseller Flutter uygulama paketindedir, sunucu satırları tek başına eski binary'ye yeni PNG dosyalarını eklemez. Bu tur normal Android/iOS derlemeleri hazırlandı ve son normal iOS sürümü BEA iPhone16Plus/iOS18.6 simülatörüne kuruldu; TR giriş ekranında canlıya bağlıdır. Başka cihazlarda da yeni görselleri içeren normal istemciyi kullanın. Güncel kaynakla normal `flutter run` gerçek 25/50 dk ve canlı backend kullanır. Eski 27 satırlık sunucu kataloğu yeni istemciyle uyumludur.
3. Ardından yalnız [ileri migration](../migrations/20261009190000_special_avatar_catalog.sql) dosyasının tamamını çalıştırın. Kök `db push/reset` kullanmayın. Bekleyen diğer paketleri bu işin parçası olarak uygulamayın.
4. Son durumu salt okunur sorguyla doğrulayın; yeni uygulamada koleksiyonu tekrar açınca katalog tazelenir:

```sql
select count(*) as catalog_total,
       count(*) filter (where id like 'special\_%' escape '\') as special_total,
       count(*) filter (where is_default and is_active and cost_coins=0) as signup_choices
from public.avatars;
-- Beklenen: 49 / 22 / 7

select id,name_tr,name_en,cost_coins,is_default,is_premium_only,is_league_award,is_active
from public.avatars where id like 'special\_%' escape '\' order by sort_order;
-- Her satır: 500 / false / false / false / true

select version,name from supabase_migrations.schema_migrations
where version='20261009190000';
```

## Yerel doğrulama kapsamı

Backend sonuçları (ham çıktı §37 temizliğinde kaldırıldı): **118/118**; ayrı SQL DRYRUN koşulları **10/10 true**. İzole DB `pomosprint_special_avatar_20261009`, REST `127.0.0.1:54362`. Ana yerel kopya veya gerçek kullanıcı verisi değişmedi.

- Her 22 avatar için TR/EN katalog/görsel/fiyat/flag eşleşmesi; ücretli kayıt metadata'sının temel avatara çekilmesi; 500 kumla alım, kuşanma ve tekrar alım.
- 499 kum reddi, 500 kum sınırı, premium hesapta da aynı 500 fiyat; başka kullanıcının sahipliği görünmez ve kuşanılamaz.
- Anonim alım/kuşanma, UID'siz oturum, doğrudan fiyat/unlock/profil avatarı yazımı reddedilir.
- Aynı avatarı eşzamanlı iki alım bir kez ücretlendirir. 750 kumla iki farklı 500'lük avatarın yalnız biri alınır. Normal seansın eşzamanlı +20 kumu ezilmez.
- DRYRUN ve temiz down eski katalog/profil/seans/sahiplik/fonksiyon/geçmiş snapshot'ını birebir korur. Satın alınmış özel avatar varken down değişiklik yapmadan reddedilir.

Auth sağlayıcı/e-posta teslimi bu test değildir: sentetik kullanıcılar yalnız izole `auth.users` tablosuna eklenerek gerçek profil/kayıt trigger'ları çalıştırıldı. Yerel signed JWT ile gerçek PostgREST RPC'leri çağrıldı. Native smoke ayrıca ana QA raporunda raporlanır.

## Geri alma sınırı

Down, özel avatar edinilmiş veya profil tarafından kuşanılmışsa **bilerek reddedilir**. Sahiplik kayıtlarını veya kullanıcı kumunu silerek zorlamayın. Kullanılmış koleksiyonu geçici kapatmak gerekirse yeni, incelenmiş bir pasifleştirme paketi hazırlayın; bu dosya otomatik kum iadesi/hesap değişikliği yapmaz.
