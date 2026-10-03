# supabase/

| Klasör | İçerik | CLI uygular mı? |
|---|---|---|
| `migrations/` | Yalnızca İLERİ migration'lar, her sürüm için TEK dosya. | Evet (`supabase db push`) |
| `rollbacks/` | Geri alma betikleri (`*_down.sql`). Her birinin başında risk notu var. | Hayır |
| `proposed/` | Canlı gövdesi bilinmeyen fonksiyonlar için önerilen düzeltmeler. Bkz. `proposed/README.md`. | Hayır |
| `tests/` | Yerel, tek kullanımlık Postgres'te migration zinciri + ASSERT'li davranış testleri (`tests/run_local.sh`; canlı şemaya göre yazılmış `20261003150000_live_audit_fixes` varsayılan olarak atlanır, onun için `tests/20261003_live_audit_fixes_dryrun.sql`). | Hayır |
| `functions/` | Edge Functions. `unsubscribe` JWT doğrulaması KAPALI deploy edilmeli: bkz. `functions/unsubscribe/README.md`. | `supabase functions deploy` |

## Önemli uyarılar (3 Ekim 2026'da canlıya karşı doğrulandı)

- **Gerçek kaynak canlı veritabanıdır.** Canlı projenin (`eoosnyakvxmifmexpgxa`)
  migration geçmişinde, farklı isimlerle uygulanmış ~36 migration var
  (`20260731130431_secure_rpcs_use_auth_uid` … `20260812234652_cleanup_league_cron_test_data`).
  Bu repodaki `20260809021500` … `20260809033000` ve `20260928120000_security_hardening`
  dosyaları canlı geçmişte **YOK** ve içerikleri canlıdan farklı. Bunlar tarihçe
  olarak duruyor; yeni bir ortama uygulamayın.
- **Canlıya uygulanan son migration:** `migrations/20261003150000_live_audit_fixes.sql`
  (canlı fonksiyon gövdeleri esas alınarak yazıldı, 28 senaryoluk geri alınan test
  `tests/20261003_live_audit_fixes_dryrun.sql` ile doğrulandı, geçmişe kaydedildi).
  Acil geri alma: `rollbacks/20261003150000_live_audit_fixes_down.sql`.
- `proposed/11_audit_fixes_unapplied.sql` canlıya UYGULANMADI (başındaki durum
  notuna bakın). İçindeki `remove_friend`, `cancel_friend_request`,
  `get_outgoing_friend_requests`, `reorder_categories`, `get_my_category_limit`
  canlıda yok; istemci bunlar olmadan çalışacak şekilde yedek yola düşer.
- **Canlıya yazma akışı:** canlı tanımı oku (`pg_get_functiondef`, `pg_policies`,
  yetkiler) → migration + rollback + kendini geri alan DRYRUN test dosyası yaz →
  Supabase SQL Editor'de önce DRYRUN (sonunda `DRYRUN_RESULT` hatası beklenir),
  sonra migration. Repodaki eski sürümlerden `CREATE OR REPLACE` yazmayın.
- **`supabase db push` ÇALIŞTIRMAYIN** (geçmiş eşitlenmeden eski dosyaları
  yeniden uygular). Önce aşağıdaki baseline adımı yapılmalı.
- `rollbacks/` içindeki betikler geri alınamaz veri silebilir; uygulamadan
  önce başlıklarını okuyun.
- Edge Functions: `unsubscribe` ve `send-welcome-email` JWT doğrulaması KAPALI
  deploy edilir (ikisi de isteği kendisi doğrular). Repodaki sürümler canlıdan
  yenidir; deploy adımları kök dizindeki rapordadır.

## Baseline (BACKEND-17) — önerilen tek seferlik iş

1. `supabase link --project-ref <proje>`
2. `supabase db dump --schema public -f supabase/migrations/<tarih>_baseline.sql`
   (auth trigger'ları için `--schema auth` çıktısındaki yalnızca
   `on_auth_user_created` benzeri trigger/fonksiyon tanımlarını ekleyin).
3. Mevcut migration sürümlerini canlıda uygulanmış olarak işaretleyin:
   `supabase migration repair --status applied <sürüm> ...`
4. Yeni ortam (staging) baseline + sonraki migration'larla kurulabilir hale
   gelir; `tests/run_local.sh` stub yerine baseline ile çalıştırılabilir.
