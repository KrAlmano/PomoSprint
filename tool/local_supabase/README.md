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
- Sayaç her derlemede (debug dahil) gerçek süreli (25/50 dk). Hızlı deneme
  `--dart-define=QUICK_TIMER=true` ile 5/10 sn'dir ve bu seanslar sunucuya
  gönderilmez. Puan akışını beklemeden denemek için aşağıdaki simülatör
  senaryosu (c) ya da `smoke_test.py`.

## Simülatörde uçtan uca test

Uygulama **gerçek `main()`** ile iOS simülatöründe açılır ve bu yerel kopyaya
bağlanır (`integration_test/`, Flutter `integration_test`). Arayüz Türkçe'ye
sabitlenir (`LanguageService.deviceLocale`); her testin başında oturum
kapanır ve SharedPreferences silinir. `SUPABASE_URL` yerel değilse testler
başlamadan düşer.

Ön koşullar: yerel kopya açık (`supabase start --workdir tool/local_supabase`),
simülatör iPhone 16 Pro / iOS 18.6 (`7B8AF086-0864-42FD-B4D8-37A782C3F6B9`,
kapalıysa betik açar), Xcode 27 (`DEVELOPER_DIR`; betik varsayılanı
`/Applications/Xcode.app/Contents/Developer`).

```sh
tool/local_supabase/e2e/sim/run_sim_e2e.sh            # a b c d e
tool/local_supabase/e2e/sim/run_sim_e2e.sh c          # yalnızca biri
```

Betik `e2e_host.py`'yi (yalnızca 127.0.0.1) başlatır: test ortasında ekran
görüntüsü (`xcrun simctl io … screenshot` → `analiz/ekranlar/e2e-*.png`) ve
yerel veritabanında **salt okuma** psql doğrulaması (`build/e2e_sim/psql.log`).
Her dosyayı ayrı `flutter test integration_test/<dosya> -d <UDID>
--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…
--dart-define=E2E_HOST_PORT=… --dart-define=E2E_RUN_ID=…` ile koşturur, sonda
`parity_check.sh` çalıştırır (testler yalnızca veri yazar). Günlükler
`build/e2e_sim/<dosya>.log`. Hesaplar ve şifre: `e2e/ACCOUNTS.md`.

| Dosya | Senaryo | Doğrulama |
|---|---|---|
| `a_register_onboarding_test.dart` | (a1) Kayıt ekranı (ad, e-posta, şifre, iki zorunlu onay) → onboarding: yaş, YKS → kategori adımında YKS dersleri otomatik seçili (Matematik, Fizik dahil 8) → görünürlük → kurallar → hedef → kabukta sayaç ve YKS çipleri. (a2) KPSS: sunucu `kpss`'i tanımıyor (`proposed/26` yok), onboarding hatasız, segmentsiz biter | psql: `profiles` (ad, doğum yılı, segment, hedef, görünürlük, onboarding), `categories` sırası, `auth.users` onay metadata'sı |
| `b_timer_layout_test.dart` | Sayaç 402x874 (iPhone 16 Pro, güvenli alanlı) | BAŞLAT ekranda ve alt gezinmenin üstünde, kaydırmasız; 25/50 aynı satırda; kum saati görünür; taşma yok |
| `c_session_points_test.dart` | (c) Uygulama kapalıyken biten seans: girişten sonra ağaç kapatılır, `TimerPersistence`'a (gerçek biçim, sahip = kullanıcı kimliği) 26 dk önce başlamış 25 dk'lık çalışan seans yazılır, uygulama yeniden açılır. (f) Lig | Diyalog 5 puan / 20 kum, kaydedilememe ve saat metni yok; üst çubuk PUAN 5 / KUM 20; psql `study_sessions` + profil toplamları (5 / 20 / 25 dk / seri 1); Raporlar'da bugün 25 dk; Sıralama > Lig'de "(Sen)" ve `get_my_league_ranking` sırası |
| `d_friends_visibility_test.dart` | A API ile (onboarding tamam, görünür); uygulamada B, A'nın koduyla istek → A API ile kabul → B'nin listesinde A → A `start_study_session` → B'nin canlı akışında A → Sıralama > Arkadaşlar | psql `friendships` (pending → accepted), B olarak `get_live_friends`; ekranda "(Sen)" |
| `e_settings_delete_test.dart` | Profil > Gizlilik ve yasal; Hesabımı Sil | Kullanım Şartları, Gizlilik, KVKK, Gizlenen kullanıcılar, Hesabımı Sil var; "Hesap silme hakkında", "Verilerimin kopyasını iste" yok. Silme sonrası giriş ekranı; psql'de `auth.users`, `profiles`, `categories` satırı yok |

Süre (5 Ekim 2026, bu makine): ilk Xcode derlemesi ~2 dk, sonraki her
dosya 45–90 sn (derleme ~20–40 sn + test); `a`–`e` birlikte ~6 dk.

### Elle koşulan senaryolar (g, h, i)

Normal debug derlemesi (`flutter build ios --simulator --debug
--dart-define=SUPABASE_URL=http://127.0.0.1:54321
--dart-define=SUPABASE_ANON_KEY=<yerel ANON_KEY>`) kurulur; hazır hesap:
`python3 tool/local_supabase/e2e/sim/create_host_account.py <etiket>`
(`e2e-sim-host-<etiket>@pomosprint.local`). Simülatör Claude Code'un
simülatör aracıyla (ya da elle) sürülür; her adımda ekran görüntüsü.

- **(g) Bildirim izni.** İzin durumunu sıfırlamak için yalnızca uygulamayı
  kaldırıp kur (`xcrun simctl uninstall <UDID> com.pomosprint.app`). Profil >
  "Bildirimler ve kilit ekranı sayacı" aç → iOS izin penceresi → *Allow* →
  anahtar açık (`e2e-bildirim-izni.png`, `e2e-bildirim-acik.png`). Kaldır-kur,
  *Don't Allow* → anahtar kapalı, kırmızı açıklama ve "Ayarları aç"
  (`e2e-bildirim-reddedildi.png`).
- **(h) Sunucu kesintisi.** Seans sürerken `docker stop
  supabase_kong_pomosprint-local` (yalnızca API ağ geçidi) → seans biter →
  diyalog "cihazına kaydedildi…", turuncu bekleyen seans bandı
  (`e2e-kesinti-kuyruk.png`); uygulama kapatılıp açılır → kabuk önbellekten
  açılır, bant sürer (`e2e-kesinti-acilis.png`); `docker start …` → kuyruk
  yeniden deneme zamanlayıcısıyla (≤30 sn) gönderilir, PUAN 5 / KUM 20, bant
  kalkar (`e2e-kesinti-toparlandi.png`, psql'de `study_sessions` satırı).
  Çıkış yapmış kullanıcı kesintide giriş denerse "İnternet veya sunucu
  bağlantısı kurulamadı" (`e2e-kesinti-giris.png`); ağ geçidi açılınca aynı
  ekrandan giriş olur (`ensureCloud` giriş anında yeniden dener). Sonunda
  `docker ps` ile kong'un çalıştığını doğrula.
- **(i) Kilit ekranı.** Bildirimler açıkken BAŞLAT → simülatörü kilitle
  (LOCK) → Canlı Etkinlik: kategori, "Odaklanıyorsun", geri sayım ve ilerleme
  çubuğu (`e2e-kilit-ekrani.png`; ilk seferde iOS "Allow Live Activities"
  sorar: `e2e-kilit-ekrani-izin.png`). Kilitli ekranda sistem saniyeleri
  `--` gösteriyor (uygulama `Text(timerInterval:)` veriyor; dakika her
  dakika azalıyor); kilit açıkken bildirim merkezinde tam `MM:SS`
  görünür.

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
(12 → 15 → 16 → 19 → 13 → 14 → 20 → … → 25 → 26) her adımda önce DRYRUN'u, sonra
dosyayı postgres rolüyle (SQL Editor'deki gibi) uygular; yeni adımların
DRYRUN gövdesini ana dosyayla karşılaştırır ve `_down` dosyalarını ters
sırada uygulayıp şemanın önceki adımla birebir aynı olduğunu denetler.

```sh
tool/local_supabase/proposed_chain_check.sh                          # hepsi; sonda kopya silinir
CHAIN_DB=pomosprint_chain NO_DOWN=1 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh   # zincir + 20–26 hâli kalır
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
