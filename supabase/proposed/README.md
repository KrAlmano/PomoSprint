# supabase/proposed — canlıya uygulanmamış öneriler

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

Ön koşul (hepsi için): `supabase/proposed/11_audit_fixes_unapplied.sql (canlıda YOK)`
canlıda uygulanmış olmalı (`my_friend_ids`, `study_day_of`,
`study_day_start`, `category_limit`, completed_at trigger'ı).

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
| 11 | `15_monthly_leaderboard_study_month.sql` (+ `_down`, `_dryrun`) | P2 | Aylık sıralamada 'bu ay' = çalışma ayı (started_at, profil dilimi, 04:00); Raporlar > Aylık ile aynı kural. CANLI gövdeden yazıldı; `11`'e bağımlı değil. Uygulanınca istemcide `nextMonthlyLeaderboardReset` 04:00'e. | MH-1, X2 |
| 12 | `16_categories_order_and_privileges.sql` (+ `_down`, `_dryrun`) | P3 | Yeni ve arşivden çıkan kategori sona; tek seferlik sıra eşitliği çözümü; DELETE politikası/yetkisi kaldırılır, UPDATE yalnız 5 kolona. CANLI gövdeden yazıldı; `11`'e bağımlı değil. | CAT-07, CAT-10 |
| 13 | `14_gizlilik_sosyal.sql` (+ `_down`, `tests/proposed_14_gizlilik_sosyal_dryrun.sql`) | P1/P2 | Sunucu tarafı engelleme ve arkadaş yönetimi, kullanıcı bildirimi + operatör araçları, nötr görünen ad ve tek kelimelik ad maskesi, görünürlük varsayılan kapalı, anon sıralama sınırı, activity_feed durdurma, onay kayıt defteri, saklama işleri (pg_cron), bülten onayı RPC'leri. CANLI gövdeden yazıldı; `11`'e bağımlı değil, `11` §2 / `07` A-B-E / `03`'ü kapsar. `15` istenirse ondan ÖNCE. Ayrıntı: aşağıda "Öneri 14". | PLAY-04, PLAY-05, ACC-06, KVKK-01, KVKK-03, KVKK-06, KVKK-10, ACC-13, KVKK-09 |

`15` ve `16` diğerlerinden farklı olarak doğrudan uygulanmaya hazırdır: canlı
tanımlar (3 Ekim 2026) esas alındı, DRYRUN dosyaları geri alınan bir
transaction'da senaryoları çalıştırır (yerel bir taklitte doğrulandı: tümü
`true`, eski tanımla `false`). Önce `_dryrun.sql`'i SQL Editor'de çalıştırın,
sonra ana dosyanın `\echo`/`\quit` satırlarını silip çalıştırın.

**Bağımsız öneri (ön koşulu yok):**

| Dosya | Öncelik | Amaç |
|---|---|---|
| `12_delete_own_account.sql` (+ `12_delete_own_account_down.sql`) | P1 KVKK | Hesap silinince yabancı anahtarı olmayan, e-postaya bağlı kişisel veriyi de siler (`waitlist`, `user_id`'si boş `marketing_subscribers` satırı; yalnızca doğrulanmış e-postada); `search_path`'e `pg_temp`. Diğer tablolar canlıda zaten cascade ile siliniyor (3 Ekim'de FK'ler okunarak doğrulandı). Kuru çalıştırma: `tests/proposed_12_delete_own_account_dryrun.sql` (14 senaryo; yerel stub şemada hepsi `true`). |
| `13_sunucu_butunluk.sql` (+ `13_sunucu_butunluk_down.sql`) | P1 | **Ürün kararı gerekir (UX-01), ama karar düğmesi kapalıyken canlı davranışı değiştirmeden uygulanabilir.** UX-01: `register_session_start` + `session_starts`; `complete_study_session` eşleşen sunucu başlangıcında `started_at`'i sunucudan alır (`start_verified`), doğrulanmamış seanslara `app_config.unverified_session_daily_cap` (vars. `null` = bugünkü davranış). Lig dönemi: kapanmış döneme ait geç seans lig puanı almaz (`league_period_closed`), `league_memberships.period_started_at` trigger'larla. `handle_new_user` friend_code çakışmasında yeniden dener; Crockford arkadaş kodu, saatlik deneme sınırı, bekleyen istekte id yok (KVKK-17). `profiles.email` boşaltılır (KVKK-20, 2. aşama dosya sonunda). `app_config` + anon okunabilir `get_app_config()` (UX-08). 10 SECURITY DEFINER'a `pg_temp`. `profiles.name`/`categories.name` içerik trigger'ı, `start_study_session` doğrulaması. İstemci sözleşmesi dosya başında. Kuru çalıştırma: `tests/proposed_13_sunucu_butunluk_dryrun.sql` (50 senaryo); yerel taklit `tests/proposed_13_local_stub.sql` (canlı gövdelerle md5 eşit) üzerinde 50/50 `true`, geri alma sonrası md5'ler canlıyla aynı. |
| `19_waitlist_consent_token.sql` (+ `19_waitlist_consent_token_down.sql`) | P2 (6563 / KVKK-11) | Bekleme listesine ticari ileti onay kaydı (`marketing_consent`, `consent_text_version`, sunucuda yazılan `consented_at`) ve kişiye özel `unsubscribe_token`. İki aşama: A geriye uyumlu (site yalnızca e-posta gönderse de çalışır); B, site onay alanlarını gönderdikten SONRA anon INSERT'i yalnızca onaylı satıra ve üç kolona daraltır. Kuru çalıştırma: `tests/proposed_19_waitlist_consent_token_dryrun.sql` (12 senaryo; yerel stub şemada hepsi `true`). |

`01` ile `07`'nin D bölümü birlikte düşünülmeli: `01`'deki DEĞİŞİKLİK 5,
`07`'deki `active_session_client_uuid` kolonuna dayanır.

## Öneri 14: gizlilik ve sosyal güvenlik (sunucu)

`14_gizlilik_sosyal.sql` canlı tanımlardan (3 Ekim 2026, PG 17.6) yazıldı.
İlk adımı değiştireceği 13 canlı fonksiyonun `md5(pg_get_functiondef)`
değerini denetler; araya başka bir değişiklik girdiyse hiçbir şey yapmadan
durur. Yerel taklitte (`tests/proposed_14_local_stub.sql`, fonksiyon md5'leri
canlıyla aynı) doğrulandı: DRYRUN 62/62 `true` (canlı ve `15` uygulanmış
hâl), 10 mutasyonun hepsini yakalıyor; ileri + geri sonrası şema durumu
(fonksiyon gövdeleri, yetkiler, politikalar, trigger'lar, cron) birebir aynı.

**Kapsadığı / geçersiz kıldığı öneriler:** `11` §2 (`remove_friend`,
`cancel_friend_request`, `get_outgoing_friend_requests`, `get_my_friends`,
`get_incoming_friend_requests`; aynı yanıt sözleşmesiyle, engel filtreli),
`07` A (activity_feed RLS), B (`get_live_friends`) ve E (makine-okunur
`code`), `03` (aylık sıralama ve maskeleme). 14'ten sonra bunları
UYGULAMAYIN (engel filtresini geri alırlar). `12` ile çakışmaz
(`delete_own_account`'a dokunmaz; bekleme listesinin hesap silmede
temizlenmesi `12`'de). `15` 14'ten önce uygulanabilir (14 iki ay kuralını
da tanır); 14'ten sonra uygulanamaz ve gerekmez.

### SQL Editor çalıştırma sırası

1. (İsteğe bağlı) `15`: önce `15_..._dryrun.sql`, sonra `15_...sql`. 14'ten ÖNCE.
2. `tests/proposed_14_gizlilik_sosyal_dryrun.sql` → `DRYRUN_RESULT >> T00 özet 62/62: true ...`
   (ön koşul tutmazsa `proposed/14 ön koşulu: ...` hatası; öneriyi uyarlayın).
3. Ürün/hukuk kararları: görünürlük varsayılanı (KVKK-01), nötr ad, saklama
   süreleri (onay kaydı 1 yıl, bekleme listesi 12 ay, onaysız kayıt 7 gün).
4. **İstemci ön koşulu (Apple):** `providerFirstNameUpdate` `^Pomo \d{4}$`
   adını da varsayılan saymalı; yoksa Apple ile ilk girişte `givenName`
   yazılmaz (Apple adı yalnızca ilk girişte verir). Bu istemci değişikliği
   canlı sunucuya bağımlı değil, 14'ten önce yayınlanabilir.
5. `14_gizlilik_sosyal.sql` (`\echo`/`\quit` satırları silinerek).
   Migration geçmişine `20261003194000 privacy_social` yazılır.
6. Doğrulama: AGENTS.md §2.3 sorguları, `select * from cron.job;`
   (`privacy_retention_daily`, `17 3 * * *`), `select * from ops.open_user_reports;`.
7. (İsteğe bağlı, ürün kararı) mevcut e-posta türevi adlar:
   önizleme sorgusu `ops.neutralize_email_derived_names` üstünde; uygulama
   `select ops.neutralize_email_derived_names();`.
8. Geri alma: `14_gizlilik_sosyal_down.sql` (yeni tablolar silinir; başlığını okuyun).

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
| `add_friend_by_code` (değişti) | `p_code text` (boşluk/küçük harf normalize) | `{success:true, code:'request_sent'\|'accepted', auto_accepted, friend:{id,name,avatar_id,…}}` | `not_found` (seni engelleyen kişi de dahil, yanıt aynı), `self_add`, `blocked` (sen engelledin), `already_friends`, `already_pending`, `cooldown` (reddedildikten sonra 7 gün), `rate_limited` (saatte 20 bekleyen istek) |
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

Kapsam dışı (ayrı iş): görünen ad / ders adı için sunucu tarafı içerik
filtresi ve `start_study_session` girdi sınırları (PLAY-05'in o kısmı),
bekleme listesinde çift onay, `profiles`'ta askıya alma kolonu.

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
