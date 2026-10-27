# Ronin kaldırma ve canlı test hesabı envanteri — 9 Ekim 2026

**Durum: 9 Ekim'de kullanıcı SQL Editor'de uyguladı; canlı salt okuma20/20 doğrulandı.** Ronin0, katalog48/özel21/ücretsiz7; mevcut4hesap/9seans/11kategori/42sahiplik, özgün250dk/51puan/150kum ve kayıtlı veri hash'leri korunmuş. İleri/DRYRUN dosyalarını yeniden çalıştırmayın. [Güncel kurulum kanıtı](../../analiz/qa_evidence_20261009/release_cleanup/backend/live_confirmation_summary.json).

İleri paket yalnız `special_ronin` katalog satırını kaldırır. Gerçek hesap, bakiye, seans veya sahiplik değiştirmez; yeni RPC/kolon/yetki eklemez.

| Dosya | Amaç |
|---|---|
| [İleri SQL](../migrations/20261009233000_remove_unowned_ronin.sql) | Yalnız sahipsiz/kuşanılmamış Ronin satırı ve paket geçmişi |
| [DRYRUN](20261009_remove_unowned_ronin_dryrun.sql) | Aynı gövdeyle 12 kontrol; bilerek hata verip geri alır |
| [Down](../rollbacks/20261009233000_remove_unowned_ronin_down.sql) | Ronin'in özgün satırını/tarih bilgisini geri ekler; hesap verisiyle ilgilenmez |
| [Envanter ve QA](../../analiz/qa_evidence_20261009/release_cleanup/backend/REPORT.md) | Canlı salt okuma, maskeli hesap sınıflandırması, yerel gerçek SQL sonuçları |

## Hesap temizliği kararı

Canlıda **4 Auth hesabı, 4 profil ve 9 seans** var. Hesapların hiçbirinde açık QA metadata'sı, bilinen canlı QA e-posta öneki veya yerel/sentetik test e-posta alanı bulunmadı. Hesap adında `QA`/`test` bulunması, yaşı veya eski seans olması tek başına silme delili sayılmaz. **Kesin disposable QA allowlist'i boş (`[]`)**, dolayısıyla bu SQL içinde **Auth/account DELETE yok**. Bu dört hesabı ve verilerini korumak gerekir.

Geçmiş tek canlı QA hesabı `9d294853-aac4-4674-9a63-88a25def75cb`, 8 Ekim'de zaten silindi; Auth404/profil0/kategori0/seans0 temizliği belgeli ve güncel canlı envanterde UUID yok. Tarihsel kanıt (ham çıktı §37 temizliğinde kaldırıldı). Çok hesaplı diğer test cohort'ları yerel Supabase içindi; canlı kullanıcıları temsil etmez.

Bu paket için geri alma, yalnız katalog satırı olduğundan mümkündür. Gelecekte gerçekten Auth hesabı silinecek olursa, ayrı UUID allowlist'i ve yeni inceleme gerekir; Auth hesabı/kimliği/oturumları silen bir işlem, bu katalog down'ıyla geri getirilemez. Böyle bir Auth silme adımı bu işte hazırlanmadı veya çalıştırılmadı.

## Ronin güvenlik koşulu

Güncel canlı okumada Ronin için **0 sahiplik / 0 kuşanma** bulunur. İleri işlem `avatars` tablosunu `ACCESS EXCLUSIVE` ile kilitler; katalog/RPC ön koşulunu ve sahipliği tekrar kontrol eder. Kullanıcı işlem öncesi Ronin edinmiş veya kuşanmışsa paket **durur**; gerçek kullanıcının kumunu, profilini veya sahipliğini silerek işlemi zorlamayın. Bu durumda yeni bir ürün/veri planı incelenmelidir. Şu an sahiplik bulunmadığından kum iadesi gerekmez ve SQL bakiye yazmaz.

## Tarihsel kullanıcı SQL Editor adımları — tamamlandı

Kök [AGENTS.md §2.4](../../AGENTS.md) gereği yeni canlı SQL kullanıcı tarafından Supabase SQL Editor'de çalıştırılır. Canlıdaki bu tur işlemleri yalnız `BEGIN READ ONLY`/`SELECT`/`COMMIT` idi.

1. Önce [DRYRUN](20261009_remove_unowned_ronin_dryrun.sql) dosyasının tamamını çalıştırın. Sonuç bilerek `DRYRUN_RESULT >>` hatasıdır; **T01–T12 hepsi `true`** olmalı. Başka hata veya `false` görürseniz ileri dosyaya geçmeyin. Bu DRYRUN hesap açmaz/silmez, mail veya satın alma çağrısı yapmaz.
2. Ardından yalnız [ileri SQL](../migrations/20261009233000_remove_unowned_ronin.sql) dosyasını çalıştırın. `db push/reset` veya başka bekleyen paket kullanmayın.
3. Salt okunur kontrol:

```sql
select count(*) as total,
       count(*) filter(where id like 'special\_%' escape '\') as special,
       count(*) filter(where is_active and is_default and cost_coins=0) as signup_choices
from public.avatars;
-- Beklenen: 48 / 21 / 7

select count(*) as ronin_rows from public.avatars where id='special_ronin';
-- Beklenen: 0

select version,name from supabase_migrations.schema_migrations
where version='20261009233000';
```

## Gerçek yerel testler

**24/24 SQL kontrolü ve 12/12 DRYRUN** geçti; 24 toplamın bir kontrolü DRYRUN12 sonucunu doğruladığı için bunlar 36 bağımsız test gibi sunulmaz. İzole `pomosprint_ronin_cleanup_20261009` veritabanında gerçek `purchase_avatar`/`set_equipped_avatar` çağrıları, sahiplik/kuşanma/duplicate/katalog drift guard'ları, tam rollback/down ve satın alma-kaldırma yarışı sınandı. İşlem yeni Ronin alımı sürerken kilidi bekledi, sonra edinilmiş sahipliği görünce silmeyi reddetti.

Yalnız bu ayrı clone fixture'ı değişti. Test sonunda clone kaldırıldı; o hazırlık turunda ana yerel DB'nin498 fingerprint satırı/13 kategori/27avatar paritesi saklanan referansla aynı kaldı;49/48durumuna eşitlenmedi. Sonrasında kullanıcı isteğiyle ana yerel Supabase `stop --no-backup` temizlendi. Canlı kurulum teyidinde yerel DB başlatılmadı/yeniden oluşturulmadı.
