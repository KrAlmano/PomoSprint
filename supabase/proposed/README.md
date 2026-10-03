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

`12` ve `13` diğerlerinden farklı olarak doğrudan uygulanmaya hazırdır: canlı
tanımlar (3 Ekim 2026) esas alındı, DRYRUN dosyaları geri alınan bir
transaction'da senaryoları çalıştırır (yerel bir taklitte doğrulandı: tümü
`true`, eski tanımla `false`). Önce `_dryrun.sql`'i SQL Editor'de çalıştırın,
sonra ana dosyanın `\echo`/`\quit` satırlarını silip çalıştırın.

**Bağımsız öneri (ön koşulu yok):**

| Dosya | Öncelik | Amaç |
|---|---|---|
| `12_delete_own_account.sql` (+ `12_delete_own_account_down.sql`) | P1 KVKK | Hesap silinince yabancı anahtarı olmayan, e-postaya bağlı kişisel veriyi de siler (`waitlist`, `user_id`'si boş `marketing_subscribers` satırı; yalnızca doğrulanmış e-postada); `search_path`'e `pg_temp`. Diğer tablolar canlıda zaten cascade ile siliniyor (3 Ekim'de FK'ler okunarak doğrulandı). Kuru çalıştırma: `tests/proposed_12_delete_own_account_dryrun.sql` (14 senaryo; yerel stub şemada hepsi `true`). |

`01` ile `07`'nin D bölümü birlikte düşünülmeli: `01`'deki DEĞİŞİKLİK 5,
`07`'deki `active_session_client_uuid` kolonuna dayanır.

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
