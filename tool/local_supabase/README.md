# Canlı Supabase'in yerel kopyası

Canlı projenin (`Pomodoro App`, ref `eoosnyakvxmifmexpgxa`) şemasının birebir
yerel kopyası. Test hesapları **yalnızca burada** açılır. Docker'da çalışan,
canlıya bağlı olmayan ayrı bir Supabase projesidir (`project_id =
"pomosprint-local"`).

- Şema: `supabase/migrations/20261004120000_live_snapshot.sql`. 4 Ekim 2026'da
  canlı katalogdan salt okuma sorgularıyla üretildi (33 fonksiyonun
  `pg_get_functiondef` çıktısı, tablolar, kısıtlar, index'ler, RLS,
  politikalar, tablo/kolon/fonksiyon yetkileri, `auth.users` dahil
  trigger'lar, `pg_cron` işleri, extension'lar).
- Referans verisi: `supabase/seed.sql` (avatar kataloğu, 27 satır). Kullanıcı
  verisi kopyalanmadı.
- Postgres imajı canlıyla aynı: `17.6.1.147` (`supabase/.temp/postgres-version`).
- Repodaki `supabase/migrations` **kullanılmaz**; canlıyla uyuşmuyor.

> Her komutta `--workdir tool/local_supabase` ver. Bu projeyi `supabase link`
> ile canlıya **bağlama**. Kökteki `supabase/` klasörü için AGENTS.md'deki
> `db push` / `db reset` yasağı geçerli; buradaki `db reset` yalnızca yerel
> Docker veritabanını sıfırlar.

## Kurulum (bir kez)

```sh
brew install supabase/tap/supabase       # resmi tap
open -a Docker                            # Docker Desktop açık olmalı
supabase start --workdir tool/local_supabase   # ilk açılışta imajlar iner (birkaç dakika)
python3 tool/local_supabase/create_test_users.py
```

## Günlük komutlar

| İş | Komut |
|---|---|
| Başlat | `supabase start --workdir tool/local_supabase` |
| Durdur (veri kalır) | `supabase stop --workdir tool/local_supabase` |
| Durdur ve veriyi sil | `supabase stop --workdir tool/local_supabase --no-backup` |
| Şemayı ve veriyi sıfırla | `supabase db reset --workdir tool/local_supabase` (snapshot + seed yeniden yüklenir, test hesapları silinir) |
| Durum, URL'ler, anahtarlar | `supabase status --workdir tool/local_supabase` (`-o env` ile değişken olarak) |
| SQL | `psql postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio | <http://127.0.0.1:54323> |
| E-postalar (Mailpit) | <http://127.0.0.1:54324> |
| Test hesapları | `python3 tool/local_supabase/create_test_users.py [adet]` |
| Duman testi | `python3 tool/local_supabase/smoke_test.py` |
| Parite (yerel = canlı?) | `tool/local_supabase/parity_check.sh` |
| Öneri zinciri (kopyada) | `tool/local_supabase/proposed_chain_check.sh` (ayrıntı aşağıda) |

| Hizmet | Adres |
|---|---|
| API (Kong) | `http://127.0.0.1:54321` |
| Veritabanı | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` |
| Studio | `http://127.0.0.1:54323` |
| Mailpit | `http://127.0.0.1:54324` |

Anahtarlar Supabase CLI'nin herkese açık **yerel demo** anahtarlarıdır (her
yerel kurulumda aynı, canlıda geçmez): `supabase status` `ANON_KEY` ve
`SERVICE_ROLE_KEY` değerleri. Uygulama eski tip JWT `ANON_KEY`'i kullanır.

Docker portları `0.0.0.0`'a açılır: aynı ağdaki cihazlar da erişebilir
(veritabanı parolası `postgres`). Güvenmediğin ağda `supabase stop` ile kapat.

## Test hesapları

`create_test_users.py`, uygulamadaki kayıtla aynı `auth.signUp` metadata'sını
gönderir; yerelde e-posta onayı kapalı olduğu için hesap hemen giriş yapar.
`handle_new_user` profili, `give_default_avatars` varsayılan avatarları açar.

- `test1@pomosprint.local`, `test2@pomosprint.local` (`create_test_users.py 5`
  ile `test5`'e kadar).
- Parola: `local_api.py` → `TEST_PASSWORD` (yalnızca bu yerel kopya;
  `LOCAL_TEST_PASSWORD` ortam değişkeniyle değiştirilebilir).
- Betik var olan hesaba dokunmaz; `db reset` sonrası yeniden çalıştır.
- Google / Apple girişi yerelde kapalı; yalnızca e-posta + parola.

`smoke_test.py`: anon ile `get_points_config`, `get_league_zones`, `avatars`;
test1 ile kategori → `complete_study_session` (`started_at = şimdi - 25 dk`) →
aynı `client_uuid` ile `duplicate` → bitmemiş seans reddi
(`session_not_finished`) → profil puan/kum → `get_my_league_ranking`;
test1 ↔ test2 arkadaşlık. Veriyi bırakır; son seans 25 dakikadan yeniyse seans
adımını atlar.

## Uygulamayı yerel kopyaya bağlama

`--dart-define` ile `SUPABASE_URL` **ve** `SUPABASE_ANON_KEY` birlikte
verilince `.env` yerine bunlar kullanılır (`lib/services/backend_config.dart`).
Bu durumda Sentry kapalıdır (`--dart-define=SENTRY_DSN=…` verilmedikçe);
yalnızca biri verilirse bulut bağlantısı kapalı kalır (yerel adresle canlı
anahtar karışmasın diye).

- **VS Code:** Çalıştır ve Hata Ayıkla → `PomoSprint (yerel Supabase)` (iOS
  simülatörü) ya da `PomoSprint (yerel Supabase, Android emülatör)`.
- **Komut satırı:**

  ```sh
  ANON=$(supabase status --workdir tool/local_supabase -o env | sed -n 's/^ANON_KEY="\(.*\)"$/\1/p')
  flutter run --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY="$ANON"
  ```

- Android emülatöründe bilgisayar `10.0.2.2`'dir:
  `--dart-define=SUPABASE_URL=http://10.0.2.2:54321`.
- Gerçek cihaz: Mac'in yerel ağ IP'si (`http://192.168.x.y:54321`), cihaz aynı
  ağda olmalı.
- iOS: `Info.plist`'te `NSAppTransportSecurity` → `NSAllowsLocalNetworking`
  (yalnızca yerel ağa http; App Store'da kabul edilir).
- Debug derlemesinde sayaç 5/10 sn olduğu için sunucu seansı
  `session_not_finished` ile reddeder (canlıdaki gibi). Puan akışını
  `smoke_test.py` ile ya da gerçek cihazda `--profile` ile dene.

## Parite doğrulaması

`parity/fingerprint_lines.sql` canlıda ve yerelde aynı metinle çalışan,
yalnızca katalog okuyan parmak izi sorgusudur (kategoriler: `ext`, `extver`,
`schema`, `defacl`, `func` (gövde md5'i, SECURITY DEFINER, sahip, yetki),
`rel` (RLS, FORCE, tablo yetkisi), `col` (tip, varsayılan, identity,
generated, kolon yetkisi), `con`, `idx`, `pol`, `trg` (etkinlik durumu dahil),
`cron`, `pub`).

```sh
tool/local_supabase/parity_check.sh          # özet: kategori başına satır sayısı + md5
tool/local_supabase/parity_check.sh --diff   # fark varsa satır satır (parity/live_lines.tsv'ye göre)
```

Canlı taraf `parity/live_summary.tsv` ve `parity/live_lines.tsv`'dedir (betik
canlıya bağlanmaz). 4 Ekim 2026 sonucu: 13 kategorinin 13'ü aynı (89 kolon,
37 kısıt, 28 index, 18 politika, 33 fonksiyon md5, 11 tablo yetkisi, 8
trigger, 2 cron işi, 6 varsayılan yetki, 7 extension ve sürümleri, 2 yayın);
`live_lines.tsv`'nin md5'i canlıdaki aynı sorguyla eşit (249 satır).

**Canlı değişince:**
1. Canlıya uygulanan SQL'i (ör. `supabase/proposed/12_…`) aynı sürüm adıyla
   `supabase/migrations/` altına kopyala; `supabase db reset --workdir tool/local_supabase`.
2. Canlı özeti tazele: `parity_check.sh --print-summary-sql` çıktısını SQL
   Editor'de (ya da MCP `execute_sql`, salt okuma) çalıştır; `(k, n, h)`
   satırlarını sekmeyle `parity/live_summary.tsv`'ye yaz.
3. `parity_check.sh` → hepsi `aynı` olmalı. Sonra
   `parity_check.sh --local-lines > parity/live_lines.tsv`.

Ek denetimler: avatar kataloğu satır md5'i (`seed.sql` başında) ve trigger'ın
yerelde kapalı olduğu betikte ayrıca sınanır.

## Öneri zincirini kopyada sınama

`proposed_chain_check.sh`, bu kopyanın `public`, `auth` ve
`supabase_migrations` şemalarını (şema + veri) aynı Postgres'te ayrı bir
veritabanına (`CHAIN_DB`, vars. `pomosprint_chain`) alır; ana kopya
(`postgres`) değişmez, `parity_check.sh` geçmeye devam eder. pg_cron yalnızca
`postgres`'te kurulabildiği için kopyada `cron.job` / `schedule` /
`unschedule` taklit edilir. Sonra `supabase/proposed/README.md`'deki sırayla
(12 → 15 → 16 → 19 → 13 → 14 → 20 → … → 25) her adımda önce DRYRUN'u, sonra
dosyayı postgres rolüyle (SQL Editor'deki gibi) uygular; yeni adımların
DRYRUN gövdesini ana dosyayla karşılaştırır ve `_down` dosyalarını ters
sırada uygulayıp şemanın önceki adımla birebir aynı olduğunu denetler.

```sh
tool/local_supabase/proposed_chain_check.sh                          # hepsi; sonda kopya silinir
CHAIN_DB=pomosprint_chain NO_DOWN=1 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh   # zincir + 20–25 hâli kalır
CHAIN_DB=pomosprint_base UNTIL=0 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh      # yalnız kopya (canlı hâl)
psql postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain -X -f supabase/tests/proposed_20_25_bulgu_repro_local.sql
supabase/tests/proposed_20_25_race_local.sh postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain
```

Kopyalar işin sonunda `DROP DATABASE ... WITH (FORCE)` ile silinmeli (ya da
betik `KEEP_DB` olmadan bir kez çalıştırılır).

### İstemciyi zincir kopyasına bağlamak (`REST_PORT`)

`REST_PORT` (yalnızca `KEEP_DB` ile) kopyaya bağlı ayrı bir PostgREST
konteyneri (`<CHAIN_DB>_rest`; yerel REST'in imajı, rolleri ve yerel demo JWT
anahtarıyla) açar. Giriş (Auth) ana kopyada kalır: aynı anahtarla imzalı oturum
kopyada da geçer; kullanıcının `auth.users` satırı kopyaya ayrıca aktarılır
(kopyadaki `handle_new_user` tetiklenir). Ana kopyanın REST'i değişmez.

```sh
CHAIN_DB=pomosprint_chain_client NO_DOWN=1 KEEP_DB=1 REST_PORT=54331 tool/local_supabase/proposed_chain_check.sh
flutter test tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart   # ESKİ + YENİ
CHAIN_DB=pomosprint_chain_client DROP_ONLY=1 tool/local_supabase/proposed_chain_check.sh  # konteyner + kopya silinir
```

`client_compat_e2e_test.dart` uygulamanın karar kodunu (`LeagueSnapshot`,
`LeagueRules`, `reconcileOnboardingCategories`, `equipAvatarWithDefaultUnlock`,
`normalizeFriendCode`, `serviceErrorCodeOf`) iki sunucuya gerçek HTTP ile
çalıştırır; kendi `compat-…` hesaplarını açıp sonda iki veritabanından da siler.
5 Ekim 2026: 18/18 (ESKİ 9, YENİ 9).

## Bilinçli farklar

| Fark | Neden |
|---|---|
| `after_insert_marketing_subscribers` trigger'ı yerelde **devre dışı** (`tgenabled = 'D'`); `invoke_send_welcome_email()` gövdesi canlıyla aynı | Gövde canlı `send-welcome-email` Edge Function'ına `net.http_post` atar; yerel kopya canlıya istek göndermez. Bülten onaylı kayıtta `marketing_subscribers` satırı yine açılır |
| E-posta onayı kapalı, yönlendirmeler yerel (`config.toml`) | Test hesabı onay beklemeden giriş yapar. E-postalar Mailpit'e düşer |
| Google / Apple sağlayıcıları kapalı | Native idToken girişi canlı istemci kimlikleri ister |
| Edge Function yok (`/functions/v1/*` → 404) | İstemci hesap silmede 404'ü görüp `delete_own_account` RPC'sine düşer (canlıdaki gibi) |
| `supabase_migrations.schema_migrations` yalnızca `20261004120000` kaydını içerir (canlıda 39 kayıt) | Geçmiş değil şema kopyalanır |
| `supabase_realtime_messages_publication` sahibi `postgres` (canlıda `supabase_admin`) | Yerel Realtime açmadığı için migration açıyor; parmak izi sahibi içermez |
| Veri: yalnızca `avatars` | Kullanıcı verisi (profil, seans, lig, arkadaşlık, abonelik, bekleme listesi, `auth.*`) kopyalanmaz. `leagues` satırları çalışma sırasında açılır |
| Auth / PostgREST / Realtime servis sürümleri CLI'nin varsayılanları | Postgres imajı ve extension sürümleri canlıyla aynı; servis sürümleri farklı olabilir |
| `pg_cron` işleri yerelde de çalışır | Yalnızca yerel veriye dokunur (`process_weekly_leagues`, `activity_feed` temizliği) |
