# supabase/proposed — canlıya uygulanmamış öneriler

> **Canlı durum (5 Ekim 2026):** 12 → 15 → 16 → 19 (yalnızca A) → 13 → 14 →
> 20 → 21 → 22 → 23 → 24 → 25 → 26 bu sırayla **canlıya uygulandı**
> (kullanıcı onayıyla `supabase db query --linked --project-ref`, `postgres`
> rolü). Her adımda DRYRUN maddelerinin hepsi `true`, ardından aşağıdaki
> tablodaki md5/katalog doğrulamaları tuttu. Uygulama sonrası canlı şema yerel
> zincirle satır satır aynı (bilinçli farklar: 19 B yok, kopyaya özgü
> eklentiler). Ürün düğmeleri varsayılanda (`unverified_session_daily_cap`
> null, lig ödül/terfi 1/1/1). **Bekleyen:** 19 B (site onay alanlarını
> gönderdikten sonra) ve 13'ün KVKK-20 2. aşaması. 01–11 uygulanmadı; 03, 05
> ve 07'yi artık UYGULAMAYIN (14 ve 22 geçersiz kıldı). Geri alma: aşağıdaki
> ters sıra. Yerel kopya (`tool/local_supabase`) aynı hâle getirildi ve
> `parity/` taban dosyaları yenilendi; `proposed_chain_check.sh` bu
> hâlden çalıştırılınca md5 ön koşullu adımlarda durur (zincir uygulanmış).

Bu klasör Supabase CLI tarafından **uygulanmaz** (`supabase db push` yalnızca
`supabase/migrations/` okur). Buradaki dosyalar, gövdesi canlıda repodakinden
farklı olan ya da ürün kararı gerektiren düzeltmelerdir. Her `.sql` dosyası
`\quit` ile başlar: psql'de hiçbir şey çalıştırmadan çıkar, SQL editörde
sözdizimi hatası verir. Yanlışlıkla çalıştırılamaz.

## Neden doğrudan migration değil?

Repodaki migration'lar canlı şemanın tamamını içermiyor ve bazı
fonksiyonların canlı gövdesi farklı (ör. `complete_study_session` canlıda
`coins_earned` döndürüyor; `process_weekly_leagues` canlıda lig ödülü
dağıtıyor). Canlı gövdeyi bilmeden repodaki eski sürümden
`CREATE OR REPLACE` yazmak canlıyı **geriletir**.

## Genel uygulama yöntemi

1. Canlı şemanın yedeğini alın: `supabase db dump --schema public -f dump.sql`
   (ve `--schema auth` trigger tanımları için).
2. Dosyanın başındaki **ADIMLAR** bölümündeki `pg_get_functiondef` sorgusuyla
   canlı gövdeyi alın.
3. Değişiklikleri canlı gövdeye uygulayıp `supabase/migrations/` altına
   **yeni zaman damgalı** bir dosya olarak ekleyin (`\echo`/`\quit`
   satırlarını kopyalamayın).
4. Staging/branch projesinde uygulayın; `supabase/tests/run_local.sh` ve
   staging'e karşı `node scripts/security_regression_test.js` çalıştırın.
5. Canlıya uygulayın.

## Dosyalar ve uygulama sırası

### Canlıya hazır paketler: TEK SIRA 12 → 15 → 16 → 19 → 13 → 14 (→ 20 → 21 → 22 → 23 → 24 → 25 → 26)

İlk altı paket canlı tanımlardan (3 Ekim 2026, `pg_get_functiondef`) yazıldı,
`11`'e bağımlı değildir ve **yalnızca bu sırayla** uygulanır. 20–25 (5 Ekim
2026, test ajanı bulguları) zincir UYGULANMIŞ hâlin gövdelerinden yazıldı ve
14'ten SONRA gelir; md5 ön koşulları zincirdeki gövdeleri bekler. 26 (segment
genişletme) bağımsızdır: canlı hâlde de zincirden sonra da uygulanabilir;
tabloda sonda. Her adım SQL
Editor'de iki çalıştırmadır: (1) DRYRUN dosyası olduğu gibi yapıştırılır;
öneriyi ve senaryoları geri alınan bir transaction'da çalıştırır ve bilinçli
bir `DRYRUN_RESULT >> ...` hatasıyla biter; her madde `true` olmalı.
(2) Ardından ana dosya `\echo`/`\quit` satırları silinerek çalıştırılır.
Bir adım beklenen sonucu vermezse SONRAKİNE GEÇMEYİN.

| Adım | Önce DRYRUN | Sonra dosya | Beklenen sonuç |
|---|---|---|---|
| 1 | `tests/proposed_12_delete_own_account_dryrun.sql` | `12_delete_own_account.sql` | DRYRUN 14/14 `true`. Sonra `md5(pg_get_functiondef('public.delete_own_account()'::regprocedure))` = `e8775df60c020a1df5f03a6cb7a49d1e` |
| 2 | `15_monthly_leaderboard_study_month_dryrun.sql` | `15_monthly_leaderboard_study_month.sql` | DRYRUN T1–T6 `true` (6/6; BİLGİ satırı yalnızca karşılaştırma). Sonra `get_public_monthly_leaderboard(integer)` md5 = `3865c94b1bdb69161d576354ffcff6c2`. İstemcide `nextMonthlyLeaderboardReset` 04:00'e |
| 3 | `16_categories_order_and_privileges_dryrun.sql` | `16_categories_order_and_privileges.sql` | DRYRUN 13/13 `true`. Sonra `categories`'te `Categories delete policy` yok; authenticated'da DELETE yok, UPDATE yalnız 5 kolonda; `create_category` md5 = `a18e2ad9af94c786a4e7d97f9b252d50` |
| 4 | `tests/proposed_19_waitlist_consent_token_dryrun.sql` | `19_waitlist_consent_token.sql` (A bölümü; B site onay alanlarını gönderdikten SONRA, ayrı) | DRYRUN 12/12 `true` (A + B). Sonra `waitlist`'te `marketing_consent`, `consent_text_version`, `consented_at`, `unsubscribe_token` kolonları ve `waitlist_set_consent_time` trigger'ı |
| 5 | `tests/proposed_13_sunucu_butunluk_dryrun.sql` | `13_sunucu_butunluk.sql` | DRYRUN 50/50 `true` (14 uygulanmışsa `proposed/13 ön koşulu: ...` ile durur). Sonra `select public.get_app_config();` çalışır ve md5'ler: `handle_new_user()` `92dcc142fbec96ca2fb79a7aa3d14289`, `add_friend_by_code(text)` `eab30b000bbd223a3eef0af8e9900b30`, `respond_friend_request(uuid,boolean)` `785731c7b2c628d65a5f9e84a60be5d5`, `handle_newsletter_subscription()` `ecf943e2d250d60989ca04bd79e90152` (14'ün ön koşulu tam bunları bekler) |
| 6 | `tests/proposed_14_gizlilik_sosyal_dryrun.sql` | `14_gizlilik_sosyal.sql` | DRYRUN `T00 özet 67/67: true` (13 yoksa `proposed/14 ön koşulu: önce proposed/13 ...`). Sonra `select * from cron.job;` içinde `privacy_retention_daily` (`17 3 * * *`), `ops` şemasında 14 fonksiyon, `select * from ops.open_user_reports;` çalışır |
| 7 | `tests/proposed_20_lig_donemi_dryrun.sql` | `20_lig_donemi.sql` | DRYRUN 15/15 `true` (zincir yoksa `proposed/20 ön koşulu: ...`). Sonra `league_memberships.carry_points` var; `app_config`'te `league_award_min_members`, `league_award_min_points`, `league_promotion_min_points` (= 1); md5: `ensure_user_in_league(uuid,integer)` `8fd1f1a6fa0af892c73a8f37456ee29d`, `process_weekly_leagues()` `094ff2f6076341f33cf6cbabad297cae`, `get_league_ranking(uuid)` `b49f8d84ac55437f1d45ea7dcab362ea` |
| 8 | `tests/proposed_21_seans_kilit_gec_bonus_dryrun.sql` | `21_seans_kilit_gec_bonus.sql` | DRYRUN 10/10 `true` (20 yoksa `proposed/21 ön koşulu: önce proposed/20 ...`). Sonra `complete_study_session(...)` md5 = `f0f2b9bcc09ae8440a66d889b5f22fcc` |
| 9 | `tests/proposed_22_avatar_satin_alma_dryrun.sql` | `22_avatar_satin_alma.sql` | DRYRUN 9/9 `true`. Sonra md5: `purchase_avatar(text)` `38689aed887865e04bc6c23db8daeb32`, `set_equipped_avatar(text)` `5a3e3e513a9fbf41619f842cdffc8a96` |
| 10 | `tests/proposed_23_kategori_butunluk_dryrun.sql` | `23_kategori_butunluk.sql` | DRYRUN 13/13 `true`. Sonra `categories`'te `enforce_category_rules` trigger'ı; `setup_onboarding_categories(jsonb)` jsonb döner (md5 `4721be2abe083a358e59867e8a11251e`); `create_category` `728c31888e49ef9cd230d900ef75ca5e`, `enforce_category_limit()` `7d0575e8b353d4b2658414ff300f022c` |
| 11 | `tests/proposed_24_onboarding_profil_dryrun.sql` | `24_onboarding_profil.sql` | DRYRUN 9/9 `true`. Sonra `profiles`'ta `enforce_minimum_age` trigger'ı; `select count(*) from ops.proposed24_social_feed_reset;` (görünürlüğü kapatılan, onboarding'i bitmemiş profiller) |
| 12 | `tests/proposed_25_sosyal_erisim_dryrun.sql` | `25_sosyal_erisim.sql` | DRYRUN 9/9 `true`. Sonra authenticated'da `leagues` / `league_memberships` SELECT yok; `rotate_friend_code()` var (md5 `ad91379e137be7dcf51d0cb535a3d4c8`) |
| 13 | `tests/proposed_26_segment_genisletme_dryrun.sql` | `26_segment_genisletme.sql` (bağımsız; canlı hâlde de) | DRYRUN 9/9 `true` (kısıt beklenen tanımda değilse `proposed/26 ön koşulu: ...`). Sonra `profiles_user_segment_check` = `user_segment = ANY (ARRAY['lgs','yks','kpss','language','university','work'])` |

Ürün/hukuk kararları ilgili adımdan ÖNCE: 13 için UX-01 düğmesi
(`app_config.unverified_session_daily_cap`, varsayılan `null` = bugünkü
davranış), 14 için görünürlük varsayılanı, nötr ad, saklama süreleri ve Apple
istemci ön koşulu (aşağıda "Öneri 14").
20 için ödül/terfi düğmeleri (varsayılan bugünkü kural; önerilen 3/25/25,
istemci metinleriyle birlikte), 21 için geç seans bonusu kuralı (dosyada "o
günün serisi"; alternatifi "bonus yok"). Ayrıntı aşağıda "Öneriler 20–25".

**Geri alma (ters sıra):** `26_segment_genisletme_down.sql` → `25_sosyal_erisim_down.sql` → `24_onboarding_profil_down.sql`
→ `23_kategori_butunluk_down.sql` → `22_avatar_satin_alma_down.sql`
→ `21_seans_kilit_gec_bonus_down.sql` → `20_lig_donemi_down.sql`
→ `14_gizlilik_sosyal_down.sql` → `13_sunucu_butunluk_down.sql`
→ `19_waitlist_consent_token_down.sql` → `16_categories_order_and_privileges_down.sql`
→ `15_monthly_leaderboard_study_month_down.sql` → `12_delete_own_account_down.sql`.
Her `_down` bir önceki adımdaki şemaya birebir döner (veri kaybı notları her
dosyanın başında). `14_down` 13 uygulanmış hâle döner; `13_down` 14 hâlâ
yerindeyse hiçbir şey yapmadan durur. `20_down` 21 yerindeyse durur; 22–25
birbirinden ve 20/21'den bağımsızdır (yalnızca zincire dayanır), ama ters
sıra her zaman güvenlidir.

**Sıra neden böyle?**
- `14`, `handle_new_user` ve `add_friend_by_code`'u `13`'ün gövdesi üzerine
  kurar (13'ün friend_code yeniden denemesi, Crockford kodu, deneme sınırı,
  ad içerik denetimi, bekleyen istekte id olmaması korunur; 14'ün nötr adı,
  onay kaydı, engel kontrolleri eklenir) ve 13'ün yardımcılarını kullanır.
  Bu yüzden 14'ün md5 ön koşulu 13 UYGULANMIŞ gövdeleri bekler; 13 de kendi
  ön koşuluyla 14'ten sonra uygulanmayı reddeder (yoksa 14'ün değişikliklerini
  sessizce ezerdi).
- `26` yalnızca `profiles_user_segment_check`'e dokunur; ön koşulu kısıtın
  canlı tanımıdır (zincirdeki hiçbir adım onu değiştirmez). `26_down`
  'kpss'/'language' satırlarını NULL yapıp eski kısıtı kurar.
- `15`, `14`'ten önce: 14 iki aylık sıralama gövdesini de tanır; 14'ten sonra
  15 uygulanamaz (dönüş tipi farklı).
- `12`, `13`'ten önce: 12 `delete_own_account`'u `pg_temp`'li yazar; 13'ün
  aynı fonksiyondaki `ALTER ... SET search_path` satırı o zaman etkisizdir.
  12 hiç uygulanmazsa 13 canlı gövdeye `pg_temp` ekler ve `13_down` md5 ile
  tanıyıp geri alır.
- `16` ve `19` diğerleriyle çakışmaz; küçük ve bağımsız oldukları için önce.
- 12, 15, 16, 19 atlanabilir (kalanların sırası aynı kalır); 13 atlanırsa 14
  uygulanamaz.
- 20–25 zincirin (14 dahil) SONRASINA yazıldı: md5 ön koşulları 13/14
  uygulanmış gövdeleri bekler (`complete_study_session` 13'ün,
  `get_league_ranking` 14'ün gövdesi). 21, 20'nin `carry_points` kolonuna
  dayanır; 22, 23, 24, 25 tek başına da uygulanabilir.

**Yerel doğrulama (gerçek kopya):** `tool/local_supabase/proposed_chain_check.sh`.
Yerel Supabase'in (Docker, canlıyla birebir; `parity_check.sh`) `public`,
`auth` ve `supabase_migrations` şemalarını şema + veriyle ayrı bir
veritabanına (`pomosprint_chain`) kopyalar, ana kopyaya dokunmaz; zinciri
(12 → … → 14) ve 20–25'i her adımda önce DRYRUN'la uygular, DRYRUN'lara
gömülü gövdelerin ana dosyalarla aynı olduğunu ve 25 → 20 `_down`
dosyalarının şemayı birebir geri getirdiğini denetler. 5 Ekim 2026 sonucu:
14/14, 6/6, 13/13, 12/12, 50/50, 67/67, 15/15, 10/10, 9/9, 13/13, 9/9, 9/9,
9/9 (26) `true`; yedi `_down` önceki şemaya birebir döndü. 26 ayrıca canlı
hâldeki kopyada (`UNTIL=0`) DRYRUN 9/9, uygula → yeniden uygula (ön koşulla
durur) → `_down` → şema (kısıtlar, geçmiş) birebir aynı. Test bulguları için
`supabase/tests/proposed_20_25_bulgu_repro_local.sql` (geri alınan
transaction; canlı / zincir / zincir + 20–25 hâllerinde 'BUG' / 'düzgün') ve
`supabase/tests/proposed_20_25_race_local.sh` (iki bağlantılı eşzamanlılık;
yalnızca kopya veritabanında).

**Yerel doğrulama (taklit taban):** `supabase/tests/proposed_sira_run_local.sh` (yerel, tek
kullanımlık Postgres 16+; `PG*` ortam değişkenleri). Taban
`tests/proposed_sira_local_stub.sql`: canlıdan salt okunarak kuruldu; public'teki
33 fonksiyonun md5'i ve kolon/kısıt/index/politika/yetki/trigger parmak izleri
canlıyla aynı. Script her adımda DRYRUN'u, sonra dosyayı uygular, sıra dışı
kullanımı dener (13'ten önce 14; 14'ten sonra 13 ve 14) ve geri alma
zincirinde her `_down` sonrası şema dökümünü önceki adımla karşılaştırır.
3 Ekim 2026 sonucu: DRYRUN 14/14, 6/6, 13/13, 12/12, 50/50, 67/67 `true`;
sıra dışı üç deneme ön koşulla durdu; altı `_down`un hepsi önceki şemaya
birebir döndü. Ayrıca 13 DRYRUN canlı hâlde 50/50, 14 DRYRUN 15'siz (yalnız 13)
67/67, 12'siz 13 → 14 → 14_down → 13_down tabana döndü.

**Paket özetleri**

| Dosya | Öncelik | Amaç |
|---|---|---|
| `12_delete_own_account.sql` | P1 KVKK | Hesap silinince yabancı anahtarı olmayan, e-postaya bağlı kişisel veriyi de siler (`waitlist`, `user_id`'si boş `marketing_subscribers` satırı; yalnızca doğrulanmış e-postada); `search_path`'e `pg_temp`. Diğer tablolar canlıda zaten cascade ile siliniyor (3 Ekim'de FK'ler okunarak doğrulandı). |
| `15_monthly_leaderboard_study_month.sql` | P2 (MH-1, X2) | Aylık sıralamada 'bu ay' = çalışma ayı (started_at, profil dilimi, 04:00); Raporlar > Aylık ile aynı kural. |
| `16_categories_order_and_privileges.sql` | P3 (CAT-07, CAT-10) | Yeni ve arşivden çıkan kategori sona; tek seferlik sıra eşitliği çözümü; DELETE politikası/yetkisi kaldırılır, UPDATE yalnız 5 kolona. |
| `19_waitlist_consent_token.sql` | P2 (6563 / KVKK-11) | Bekleme listesine ticari ileti onay kaydı (`marketing_consent`, `consent_text_version`, sunucuda yazılan `consented_at`) ve kişiye özel `unsubscribe_token`. A geriye uyumlu; B, site onay alanlarını gönderdikten SONRA anon INSERT'i yalnızca onaylı satıra ve üç kolona daraltır. |
| `13_sunucu_butunluk.sql` | P1 | **Ürün kararı gerekir (UX-01), ama karar düğmesi kapalıyken canlı davranışı değiştirmeden uygulanabilir.** UX-01: `register_session_start` + `session_starts`; `complete_study_session` eşleşen sunucu başlangıcında `started_at`'i sunucudan alır (`start_verified`), doğrulanmamış seanslara `app_config.unverified_session_daily_cap` (vars. `null`). Lig dönemi: kapanmış döneme ait geç seans lig puanı almaz (`league_period_closed`). `handle_new_user` friend_code çakışmasında yeniden dener; Crockford arkadaş kodu, saatlik deneme sınırı, bekleyen istekte id yok (KVKK-17). `profiles.email` boşaltılır (KVKK-20, 2. aşama dosya sonunda). `app_config` + anon okunabilir `get_app_config()` (UX-08). 10 SECURITY DEFINER'a `pg_temp`. `profiles.name`/`categories.name` içerik trigger'ı, `start_study_session` doğrulaması. İstemci sözleşmesi dosya başında. |
| `14_gizlilik_sosyal.sql` | P1/P2 (PLAY-04, PLAY-05, ACC-06, KVKK-01, KVKK-03, KVKK-06, KVKK-10, ACC-13, KVKK-09) | Sunucu tarafı engelleme ve arkadaş yönetimi, kullanıcı bildirimi + operatör araçları, nötr görünen ad ve tek kelimelik ad maskesi, görünürlük varsayılan kapalı, anon sıralama sınırı, activity_feed durdurma, onay kayıt defteri, saklama işleri (pg_cron), bülten onayı RPC'leri. `11` §2 / `07` A-B-E / `03`'ü kapsar. Ayrıntı: aşağıda "Öneri 14". |
| `20_lig_donemi.sql` | P2 (t4-F2, t4-F3, t4-F5, t4-F6, t4-F7, t4-F8, t4-F10) | Terfi/düşme hedefi aynı dönem sonlu oda (yarılanmış odaya girmez); taşınanın `joined_at`'ı = taşınma; bitmiş odaya yerleştirme yok; kademe başına yerleştirme kilidi (eşzamanlı ilk seanslar aynı odaya, 30 sınırı); `carry_points` (oda bitişi ile cron arası seansların puanı yeni döneme); ligsiz satırda `member_count` 0; `league_promotion` tarihi TR günü; ödül/terfi düğmeleri (varsayılan bugünkü kural). |
| `21_seans_kilit_gec_bonus.sql` | P1 (t1-01, t1-05, t4-F5) | `complete_study_session` başta profil kilidi: iki cihazdan eşzamanlı çakışan seans `overlap`, aynı `client_uuid` `duplicate` (puan/kum/lig iki kat sayılmaz); geç seans kendi gününün serisiyle; oda bitişinden sonra biten seans `carry_points`'e (`league_points_next_period`). |
| `22_avatar_satin_alma.sql` | P2 (t4-F1, t4-F9) | `purchase_avatar` profil kilidi + göreli koşullu düşüm (300 kumla 400'lük alım ve +20 kum ezilmesi biter; `05`'in yerini alır); sonradan eklenen varsayılan avatar kuşanılır. |
| `23_kategori_butunluk.sql` | P2 (t2-03, t2-06, t2-07) | Onboarding yeniden denenince seansız eski kategoriler arşive (TR/EN çift yok), geçersiz öğe çağrıyı düşürmez, `{created, restored, skipped_*, archived}` döner; büyük/küçük harf duyarsız tekil ad, renk/ikon doğrulaması (yalnız yazılan alan); kategori yazımları kullanıcı başına kilitli (limit aşılmaz). |
| `24_onboarding_profil.sql` | P1/P2 (t2-01 sunucu, t2-05) | 13 yaş sınırı sunucuda (`birth_year_under_minimum_age`); onboarding'i bitmemiş eski profillerde görünürlük seçim yapılana kadar kapalı (14'ün varsayılanını eskiye taşır). |
| `25_sosyal_erisim.sql` | P2 (t3-LG5, t3-K1) | `leagues` / `league_memberships` doğrudan okunamaz (yalnız RPC); `rotate_friend_code()` (24 saatte bir). |
| `26_segment_genisletme.sql` | P2 (t2-04) | `profiles_user_segment_check`'e `kpss` ve `language` (YDS/YÖKDİL/IELTS/TOEFL) eklenir. Bağımsız; istemci 26'dan önce de çalışır (23514'te segmentsiz tamamlar). |

### Eski öneriler (01–10): `11`'e bağlı, canlıya göre yeniden yazılmalı

Ön koşul (hepsi için): `supabase/proposed/11_audit_fixes_unapplied.sql (canlıda YOK)`
canlıda uygulanmış olmalı (`my_friend_ids`, `study_day_of`,
`study_day_start`, `category_limit`, completed_at trigger'ı). Bu dosyalar
canlı gövdelerden yazılmadı; yukarıdaki sıraya dahil DEĞİLDİR ve 14'ün
kapsadığı bölümleri (`03`, `07` A-B-E, `11` §2) 14'ten sonra UYGULANMAZ.

| Sıra | Dosya | Öncelik | Amaç | Bulgular |
|---|---|---|---|---|
| 1 | `01_complete_study_session.sql` | P0 kritik | completed_at tabanlı 'overlap' kontrolünü kaldırır, geç gelen eski seansın seriyi bozmasını önler, gün sorgularını index'li aralığa çevirir, puan sabitlerini tek kaynağa alır. Ek: `validate_study_session_timing` için alt sınır + PS00x SQLSTATE (istemci hazır olunca). | BACKEND-01, DATA-02, STATS-V01, TIMER-V02, TIMER-06, BACKEND-24, BACKEND-09, BACKEND-27, BACKEND-26, BACKEND-18, BACKEND-08 |
| 2 | `04_cleanup_unconfirmed_duplicate_identity.sql` | P1 güvenlik | E-postayı parametreden değil oturumdan alır; başkasının onaysız kaydı silinemez. | AUTH-V03 |
| 3 | `03_public_leaderboards.sql` | P1 KVKK | Herkese açık sıralamada sosyal görünürlüğü kapatanlar listelenmez, adlar 'Ad S.' biçiminde. Aylık sıralama referansı ve 'senin durumun' RPC'si. | LANDING-V02, DATA-17 |
| 4 | `02_process_weekly_leagues.sql` | P1 | Haftalık lig devri: uuid değişkenler, deterministik sıra, küçük lig kuralları, dönem sonu tek kaynak (7/14 gün kararı), Pazar 23:59 yarışı, cron. | SOCIAL-02, BACKEND-04, SOCIAL-08, SOCIAL-V03, SOCIAL-23, BACKEND-V03 |
| 5 | `05_purchase_avatar.sql` | P2 | Çift harcamayı önleyen kilit ve atomik düşüm; makine-okunur hata kodları. | BACKEND-07 |
| 6 | `07_social.sql` | P2 | activity_feed RLS gizlilik tercihine uyar; get_live_friends tekilleşir; get_friends_feed düzeltilir; start_study_session girdileri doğrulanır ve seans kimliği saklanır; arkadaş kodu normalize edilir. | BACKEND-19, BACKEND-14, BACKEND-22, BACKEND-26, SOCIAL-20, TIMER-22 |
| 7 | `06_profiles_rls.sql` | P2 | profiles yalnızca kendi satırı + kolon bazlı SELECT; study_sessions SELECT politikası repoya. İstemci arkadaş listelerini RPC'den okuduktan SONRA. | BACKEND-05, BACKEND-12, STATS-14 |
| 8 | `09_categories.sql` | P3 | Kategori adı 1-40 karakter, büyük/küçük harf duyarsız benzersizlik (önce veri temizliği), RPC'lerde tek kaynaklı limit, `update_category`. | AUTH-19, BACKEND-28, AUTH-18 |
| 9 | `08_privileges.sql` | P3 | Fonksiyonlar varsayılan olarak anon'a kapalı; extensions kullanan fonksiyonların search_path'i. | BACKEND-25 |
| 10 | `10_data_fixes.sql` | P3 | Sahip olunmayan ücretli avatarlar, görseli olmayan avatar, abone e-postalarının normalizasyonu. Kullanıcıya görünür; ürün kararıyla. | SOCIAL-15, AUTH-21, DATA-25, SOCIAL-27, LANDING-08 |

`01` ile `07`'nin D bölümü birlikte düşünülmeli: `01`'deki DEĞİŞİKLİK 5,
`07`'deki `active_session_client_uuid` kolonuna dayanır.

## Öneri 14: gizlilik ve sosyal güvenlik (sunucu)

`14_gizlilik_sosyal.sql` canlı tanımlardan (3 Ekim 2026, PG 17.6) yazıldı ve
`13` UYGULANMIŞ duruma göre yeniden temellendirildi (sıra: 12 → 15 → 16 → 19
→ 13 → 14). İlk adımı 13'ün yardımcılarının varlığını ve değiştireceği 13
fonksiyonun `md5(pg_get_functiondef)` değerini denetler (`handle_new_user`,
`add_friend_by_code`, `respond_friend_request`,
`handle_newsletter_subscription` için 13 uygulanmış değerler); 13 yoksa ya
da araya başka bir değişiklik girdiyse hiçbir şey yapmadan durur. Yerel
taklitte (`tests/proposed_sira_run_local.sh`) doğrulandı: 13'ten sonra DRYRUN
67/67 `true` (15'li ve 15'siz); T63–T67 13'ün korunan değişikliklerini sınar
ve 14'ün eski (13'ten habersiz) gövdeleriyle düşer; `14_down` sonrası şema 13
uygulanmış hâlle birebir aynı.

13 ile birleşen davranış: kayıtta ad adayları temizlenir, yasaklıysa ya da
e-posta yerel kısmıyla aynıysa sıradakine geçilir, hiçbiri uygun değilse
nötr ad (`Pomo 1234`); arkadaş kodu 13'ün Crockford üreticisiyle ve çakışmada
yeniden denenerek yazılır; `profiles.email` yazılmaz. (13'ün üstüne 13'ten
habersiz 14 uygulansaydı yasaklı adla kayıt `profile_name_not_allowed` ile
düşerdi.) İstemcinin yedek profil yolunda e-posta, 13 `NEW.email`'i
boşalttığı için JWT'deki `email` talebinden okunur;
`ops.neutralize_email_derived_names` e-postayı `auth.users`'tan okur.

**Kapsadığı / geçersiz kıldığı öneriler:** `11` §2 (`remove_friend`,
`cancel_friend_request`, `get_outgoing_friend_requests`, `get_my_friends`,
`get_incoming_friend_requests`; aynı yanıt sözleşmesiyle, engel filtreli),
`07` A (activity_feed RLS), B (`get_live_friends`) ve E (makine-okunur
`code`), `03` (aylık sıralama ve maskeleme). 14'ten sonra bunları
UYGULAMAYIN (engel filtresini geri alırlar). `12` ile çakışmaz
(`delete_own_account`'a dokunmaz; bekleme listesinin hesap silmede
temizlenmesi `12`'de). `15` 14'ten önce (14 iki ay kuralını da tanır);
14'ten sonra uygulanamaz ve gerekmez.

### SQL Editor çalıştırma sırası (14'e özgü adımlar)

Genel sıra yukarıdaki "Dosyalar ve uygulama sırası" tablosudur; 14, 13'ten
SONRA 6. adımdır.

1. Ürün/hukuk kararları: görünürlük varsayılanı (KVKK-01), nötr ad, saklama
   süreleri (onay kaydı 1 yıl, bekleme listesi 12 ay, onaysız kayıt 7 gün).
2. **İstemci ön koşulu (Apple):** `providerFirstNameUpdate` `^Pomo \d{4}$`
   adını da varsayılan saymalı; yoksa Apple ile ilk girişte `givenName`
   yazılmaz (Apple adı yalnızca ilk girişte verir). Bu istemci değişikliği
   canlı sunucuya bağımlı değil, 14'ten önce yayınlanabilir.
3. `tests/proposed_14_gizlilik_sosyal_dryrun.sql` → `DRYRUN_RESULT >> T00 özet 67/67: true ...`
   (ön koşul tutmazsa `proposed/14 ön koşulu: ...` hatası: 13 uygulanmamış ya
   da gövde değişmiş).
4. `14_gizlilik_sosyal.sql` (`\echo`/`\quit` satırları silinerek).
   Migration geçmişine `20261003194000 privacy_social` yazılır.
5. Doğrulama: AGENTS.md §2.3 sorguları, `select * from cron.job;`
   (`privacy_retention_daily`, `17 3 * * *`), `select * from ops.open_user_reports;`.
6. (İsteğe bağlı, ürün kararı) mevcut e-posta türevi adlar:
   önizleme sorgusu `ops.neutralize_email_derived_names` üstünde; uygulama
   `select ops.neutralize_email_derived_names();`.
7. Geri alma: `14_gizlilik_sosyal_down.sql` (yeni tablolar silinir; başlığını
   okuyun). 13 uygulanmış hâle döner; 13'ü de geri almak için ardından
   `13_sunucu_butunluk_down.sql`.

Supabase advisor yeni dört tabloda "RLS açık, politika yok" (INFO) gösterir:
bilinçli, istemci bu tablolara yalnızca RPC ile erişir. `ops` şemasını
Settings > API > Exposed schemas'a EKLEMEYİN.

### İstemci sözleşmesi (14 canlıya uygulandıktan SONRA bağlanacak)

Oturum yoksa tüm yeni RPC'ler `not authenticated` (P0001) fırlatır.
Yanıtlar jsonb; istemci `code` alanına bakar, `message` (yalnızca
`add_friend_by_code` / `respond_friend_request`, Türkçe) yedektir.

| RPC | Parametreler | Başarı | Hata `code`'ları |
|---|---|---|---|
| `block_user` | `p_user_id uuid` | `{success:true, code:'blocked', removed_friendship:bool}`. Arkadaşlık ve aradaki istekler iki yönde silinir; engellenene bildirim gitmez | `not_found` (null/bilinmeyen id), `self`, `limit_reached` (1000 engel) |
| `unblock_user` | `p_user_id uuid` | `{success:true, code:'unblocked'}`; arkadaşlık geri gelmez | `not_blocked` |
| `get_my_blocks` | — | tablo `id, name, avatar_id, blocked_at` (yeniden eskiye) | — |
| `remove_friend` | `p_friend_id uuid` | `{success:true, code:'removed'}` (iki yön, bekleyen istekler dahil) | `not_friends` |
| `cancel_friend_request` | `p_to_user_id uuid` | `{success:true, code:'cancelled'}` | `not_found` |
| `get_outgoing_friend_requests` | — | tablo `id, name, avatar_id, created_at` | — |
| `add_friend_by_code` (değişti) | `p_code text` (13: boşluk/tire/alt çizgi/nokta atılır, büyük harf, O→0, I/L→1; 8 karaktere kadar) | `{success:true, code:'accepted', auto_accepted:true, friend:{id,name,avatar_id,lifetime_points,total_minutes}}` ya da `{success:true, code:'request_sent', auto_accepted:false, friend:{name,avatar_id}}` (13, KVKK-17: kabul edilmeden id yok) | `not_found` (seni engelleyen kişi de dahil, yanıt aynı), `self_add`, `blocked` (sen engelledin), `already_friends`, `already_pending`, `cooldown` (reddedildikten sonra 7 gün), `rate_limited` (13: saatte 20 deneme, ya da 14: saatte 20 bekleyen istek; `message` farklı) |
| `respond_friend_request` (değişti) | `p_from_user_id uuid, p_accept bool` | `{success:true, code:'accepted'\|'rejected'}` | `not_found` (istek yok ya da taraflardan biri engelli) |
| `get_my_friends`, `get_incoming_friend_requests`, `get_live_friends` | aynı | Dönüş aynı; iki yönlü engel filtresi | — |
| `get_my_league_ranking` (değişti) | — | Mevcut kolonlar + `id uuid`, `is_blocked bool`. Engellediğin üyenin satırı kalır (sıra/bölge), `name` ve `avatar_id` NULL | — |
| `get_public_monthly_leaderboard` (değişti) | `p_limit int` | Mevcut kolonlar + `id` (oturumsuz NULL), `is_blocked`. Oturumsuz en çok 10 satır ve maskeli ad (tek kelime: `Ahm…`), oturumlu en çok 100 | — |
| `get_public_alltime_leaderboard` (değişti) | `p_limit int` | `is_premium` çıktı; anon çağıramaz. İstemci/site kullanmıyor | — |
| `submit_user_report` | `p_target_user_id uuid, p_place text, p_reason text, p_details text = null` | `{success:true, code:'reported', duplicate:false, report_id}`; aynı kişiye 24 saatte açık bildirim varsa `{success:true, code:'duplicate', duplicate:true, report_id}` | `invalid_place`, `invalid_reason`, `not_found`, `self`, `rate_limited` (24 saatte 10) |
| `set_marketing_consent` | `p_enabled bool, p_text_version text = null` | `{success:true, code:'subscribed'\|'unsubscribed', subscribed}`. Açınca abonelik satırı (daha önce abone olduysa hoş geldin e-postası tekrar gitmez); kapatınca satır ve aynı adresin bekleme listesi kaydı silinir. Metadata `newsletter`/`marketing_consent` güncellenir. Google/Apple dahil | `invalid_input`, `email_not_confirmed`, `email_in_use`, `rate_limited` (24 saatte 20 değişiklik) |
| `get_my_marketing_consent` | — | `{subscribed:bool, subscribed_at, email_confirmed:bool}` | — |
| `accept_legal_documents` | `p_terms_version text, p_privacy_version text` | `{success:true, code:'recorded'\|'unchanged', terms_version, privacy_version}` (Google/Apple ilk girişi ya da metin sürümü değişince) | `invalid_input`, `rate_limited` |

`p_place`: `league`, `monthly`, `friends_ranking`, `live_feed`, `friends_list`,
`friend_request`, `other`. `p_reason`: `offensive_name`, `offensive_content`,
`harassment`, `spam`, `impersonation`, `other`. `p_details` kırpılır, en çok 500
karakter. Kayıt metadata'sına yeni isteğe bağlı anahtar: `show_in_social_feed`
(bool; onboarding'de açık seçim için), `handle_new_user` okur.

Mevcut istemciye etkisi (bağlantı yapılmadan): `RankingEntry.fromRow` `id`'yi
zaten okuyor; lig ve aylık sıralamada gizleme/bildirim kimlikle çalışmaya
başlar. Engellenen satırda `name` NULL olduğundan bugünkü istemci
`userDefault` metnini gösterir. `friends_sheet` tanımadığı `code`'larda
Türkçe arayüzde `message`'ı, İngilizcede genel metni gösterir.

### Operatör (SQL Editor)

```sql
select * from ops.open_user_reports;                       -- açık bildirimler, en eski önce
select ops.reset_display_name('<hedef uuid>');             -- uygunsuz adı 'Pomo 1234' yap
select ops.resolve_user_report('<bildirim uuid>', 'actioned', 'ad sıfırlandı');
select ops.resolve_user_report('<bildirim uuid>', 'dismissed', 'ihlal yok');
select * from public.consents where email_hash = ops.email_hash('<e-posta>') order by seq;  -- onay ispatı
select ops.run_privacy_retention();                        -- saklama işini elle çalıştır
select ops.purge_expired_waitlist(interval '30 days');     -- lansman e-postasından sonra
```
Hesabı askıya alma: Dashboard > Authentication > Users > Ban. Yeni bildirim
için otomatik uyarı yok; görünüm düzenli kontrol edilmeli (gerekirse ileride
Edge Function ile e-posta).

Görünen ad / ders adı için sunucu tarafı içerik filtresi ve
`start_study_session` girdi sınırları (PLAY-05'in o kısmı) `13`'te
(`profiles.name`/`categories.name` trigger'ları); 14 bunlara dayanır.
Kapsam dışı (ayrı iş): bekleme listesinde çift onay, `profiles`'ta askıya
alma kolonu.

## Öneriler 20–25: test ajanı bulguları (5 Ekim 2026)

Dört test ajanının (t1 seans/puan, t2 onboarding/kategori, t3 görünürlük,
t4 lig/avatar) sunucu bulguları yerel kopyada yeniden üretildi
(`tests/proposed_20_25_bulgu_repro_local.sql`, `tests/proposed_20_25_race_local.sh`)
ve üç hâlde sınandı: canlı (= ana yerel kopya), zincir (12 → … → 14) ve
zincir + 20–25. Zincirin zaten düzelttiği bulgular için yeni dosya yazılmadı.

| Bulgu | Canlı | Zincirden sonra | Çözen |
|---|---|---|---|
| t1-01 eşzamanlı çakışan seans iki kez sayılıyor (medium) | BUG | BUG | 21 |
| t1-02 / t3-L7 `start_study_session` süre/ad sınırsız | BUG | düzgün | 13 (B) |
| t1-03 duplicate yanıtı ilk kaydın puanını döndürüyor | belge | belge | AGENTS.md §5.2/§5.3 düzeltildi |
| t1-05 geç seans bugünkü serinin bonusunu alıyor | BUG | BUG | 21 (ürün kararı: o günün serisi) |
| t1-06 yeni oda ilk dönemde 7–14 gün | bilgi | bilgi | ürün kararı; AGENTS.md §6.4 belgelendi |
| t1-07 24 saatten eski seans kalıcı ret | bilgi | bilgi | ürün kararı (13'ün `register_session_start`'ı ile pencere genişletilebilir) |
| t1-08 `ensure_user_in_league` `pg_temp` yok | BUG | düzgün | 13 (H) |
| t2-01 görünürlük seçilmeden onboarding (high, sunucu kısmı) | BUG | düzgün (yeni kayıt) | 14 (C) + 24 (eski, bitmemiş profiller); istemci ayrı |
| t2-03 onboarding kategorileri uzlaşmıyor (medium) | BUG | BUG | 23 |
| t2-04 KPSS / dil segmenti yok | bilgi | bilgi | 26 (CHECK) + istemci (hedefler, öneriler, 23514 geri düşüşü) |
| t2-05 13 yaş sınırı yalnız istemcide | BUG | BUG | 24 |
| t2-06 kategori ad/renk/ikon doğrulaması | BUG | BUG (ve kurulum tümden düşüyor) | 13 (ad) + 23 |
| t2-07 eşzamanlı kurulum limiti aşıyor | BUG | BUG | 23 |
| t2-08 timezone istemciden yazılmıyor | bilgi | bilgi | istemci işi; sunucu hazır |
| t3-K1 arkadaş kodu taranabilir (medium) | BUG | düzgün (sınır, Crockford, id yok) | 13 (D) + 25 (`rotate_friend_code`) |
| t3-AF1 `activity_feed` görünürlüğe uymuyor | BUG | düzgün | 14 (G) |
| t3-EM1 e-postadan türeyen ad maskesiz | BUG | düzgün | 14 (C, E); istemci ön koşulu Öneri 14'te |
| t3-LG5 lig tabloları doğrudan okunuyor | BUG | BUG | 25 |
| t3-F14 reddedilen hemen yeniden istek atıyor | BUG | düzgün | 14 (D, 7 gün bekleme) |
| t3-K2 `friend_code` çakışmasında kayıt düşüyor | BUG | düzgün | 13 (D) |
| t4-F1 `purchase_avatar` kayıp güncelleme (medium) | BUG | BUG | 22 |
| t4-F2 terfi eden yarılanmış odaya giriyor (medium) | BUG | BUG | 20 |
| t4-F3 tek üyeli odada şampiyonluk (medium) | BUG | BUG | 20 (düğme; varsayılan bugünkü kural, ürün kararı) |
| t4-F4 önceki döneme ait geç seans yeni döneme (medium) | BUG | düzgün | 13 (F) |
| t4-F5 bitiş ile cron arası seanslar | BUG | BUG | 20 + 21 |
| t4-F6 ligsiz satır = tek kişilik oda | BUG | BUG | 20 (+ istemci `awaitingPlacement`) |
| t4-F7 oda seçimi kilitsiz | BUG | BUG | 20 |
| t4-F8 `league_promotion` tarihi UTC | BUG | BUG (14 akışı kapatır) | 20 |
| t4-F9 sonradan eklenen varsayılan avatar | BUG | BUG | 22 |
| t4-F10 taşınanın `joined_at`'ı eski | BUG | BUG | 20 |

**Zincir + 20–25 sonrası:** tüm BUG satırları `düzgün`; yalnızca t4-F3
düğmeler açılana kadar bugünkü kuralla kalır (bilinçli).

**İstemci sözleşmesi.** İstemci (5 Ekim 2026) aşağıdakilere İLERİYE UYUMLU: aynı
kod canlıda (eski yanıt) ve 20–25 uygulanınca (yeni yanıt) doğru çalışır;
iki hâl yerelde sınandı (`test/server_20_25_client_compat_test.dart`,
`tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart`: ana kopya
ve `REST_PORT`'lu zincir kopyası). Yalnızca `league_points_next_period` (21) ve
`rotate_friend_code` (25) henüz kullanılmıyor.

**23 için sürüm notu:** 23 onboarding'i bitmemiş kullanıcıda yükte OLMAYAN
seansız aktif kategorileri arşivler. Bu istemciden önceki sürümler onboarding
yeniden denemesinde yalnız eksik kategorileri gönderiyordu; 23 uygulanınca
seçimde olan ama zaten var olan kategori arşive gider (yerelde yeniden
üretildi). Yeni istemci aktif kalacakları da gönderir
(`OnboardingCategoryPlan.rpcPayload`). 23'ü bu istemci yaygınlaştıktan sonra
uygulayın (gerekirse 13'ün `min_supported_version` düğmesiyle).

Sunucu tarafı ayrıntı:
- `complete_study_session` yanıtına `league_points_next_period` (bool) eklenir (21).
- `get_my_league_ranking`: ligsiz satırda `member_count` 0 (20). İstemci 0'ı
  "henüz odada değilsin", odasında tek kalanı "odanda şimdilik yalnızsın"
  gösterir (canlıda ömür boyu puanla ayırt eder; `LeagueSnapshot.fromRows`).
- `get_app_config()`: `league_award_min_members`, `league_award_min_points`,
  `league_promotion_min_points` (20). İstemci okur (`getLeagueRules`; PGRST202
  ya da anahtar yoksa bugünkü kural): metinler ve `isPromotionRank` /
  `zoneOf` / podyum madalyası düğmelere göre kendiliğinden değişir.
- `setup_onboarding_categories` jsonb döner:
  `{created, restored, skipped_existing, skipped_limit, skipped_invalid, archived}` (23).
- Yeni hata metinleri (23514): `category_color_invalid`, `category_icon_invalid`
  (23), `birth_year_under_minimum_age` (24). İstemci `categoryColorInvalid`,
  `categoryIconInvalid`, `underMinimumAge` koduyla anlaşılır metin gösterir
  (13'ün `*_name_not_allowed`'ı `nameNotAllowed`).
- `rotate_friend_code()` → `{success, code:'rotated'|'rate_limited', friend_code | retry_after}` (25).
- Onboarding PATCH'i `user_segment` olarak `kpss` / `language` da gönderir
  (istemci bu sürümden itibaren, 26'yı beklemeden). 26 yokken 23514
  (`profiles_user_segment_check`) → istemci aynı PATCH'i `user_segment =
  null` ile yeniden yazar; onboarding tamamlanır. 26'dan sonra hedef saklanır.
  Uçtan uca: `tool/local_supabase/e2e/t2_onboarding_categories/segment_fallback_e2e_test.dart`.

## `20261003150000_live_audit_fixes` ile ilişkisi

`supabase/migrations/20261003150000_live_audit_fixes.sql` başka bir oturumda,
canlı fonksiyon gövdeleri (`pg_get_functiondef`) esas alınarak yazıldı. O dosya
canlıya uygulanırsa bu klasördeki önerilerin bir kısmı karşılanmış olur;
uygulamadan önce aşağıdaki tabloya göre ayıklayın:

| Öneri | O dosyada karşılanan | Hâlâ açık |
|---|---|---|
| 01 | DEĞİŞİKLİK 1 (gerçek aralıkla çakışma), 2 (geç gelen seans seriyi bozmaz), 7 (feed yalnızca sosyal görünürlük açıkken); completed_at gerçek bitiş | 3 (index'li gün aralığı), 4 (puan sabitleri tek kaynak, %20 yuvarlama), 5 (aktif seans temizliği), 6 (sert günlük tavan; o dosya tavanda puan/coin'i sıfırlıyor), 8, validate_study_session_timing eki |
| 02 | Deterministik sıra, 0 puanla terfi yok, küçük lig kotası, cron saati, lig ödülü; canlı dönem **14 gün** | `league_period_end()` ile tek kaynak ve `get_points_config.league_period_days` (istemci/landing metni) |
| 03 | Sosyal görünürlük filtresi, oturumsuz çağrıda maskeleme (`mask_public_name`), İstanbul ay sınırı | O dosya `is_me` ve `total_minutes` döndürüyor ve oturum AÇIKKEN tam adı gösteriyor: K11 sözleşmesiyle çelişir, karar verin |
| 04 | Yalnızca anon EXECUTE kaldırıldı | Gövde (parametreye güvenmeme) |
| 05 | — | Tamamı |
| 06 | profiles ve diğer tablolarda yazma yetkileri daraltıldı | profiles SELECT politikası/kolon yetkisi (o dosya tablo düzeyinde SELECT veriyor) |
| 07 | get_live_friends tekilleşti | activity_feed RLS, get_friends_feed, start_study_session doğrulaması, arkadaş kodu normalizasyonu |
| 08 | Listelenen RPC'lerde anon EXECUTE kaldırıldı | Varsayılan yetkiler, liste dışı fonksiyonlar, extensions search_path |
| 09 | Arşivden çıkarma limite bağlandı | Ad kuralları, büyük/küçük harf duyarsız benzersizlik, kilit, `update_category` |
| 10 | Sahipsiz avatar: kilit AÇILARAK çözüldü; `marketing_subscribers` için `lower(email)` benzersiz index'i | tomato_basic, mevcut yinelenen e-postaların temizliği (index oluşturulmadan önce gerekli) |

## Bilinen bağımlılıklar

- `07`'deki activity_feed politikası `my_friend_ids()`'e bağlanır;
  `proposed/11_audit_fixes_unapplied_down.sql` bu durumda `my_friend_ids`'i
  silemez (bağımlılık hatası verir, sessizce bozulmaz). Önce politikayı geri
  alın.
- `01`'deki PS00x SQLSTATE değişikliği istemcinin seans hatası
  sınıflandırmasını (kalıcı/geçici) etkiler; DATA paketi hazır olmadan
  uygulamayın.
