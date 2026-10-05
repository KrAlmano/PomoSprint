# Yerel test hesapları (yalnızca `tool/local_supabase` kopyası)

Bu dosyadaki hesaplar ve şifreler **yalnızca Docker'daki yerel Supabase
kopyasında** (`http://127.0.0.1:54321`) vardır; canlı projede geçmez ve
canlıda açılmaz. `supabase db reset --workdir tool/local_supabase` hepsini
siler.

| Hesaplar | Şifre | Açan |
|---|---|---|
| `test1@pomosprint.local` … `testN@pomosprint.local` | `local_api.py` → `TEST_PASSWORD` | `create_test_users.py` |
| `e2e-sim-<senaryo>-<koşu>@pomosprint.local` | `SimE2e-Yerel2026` | Simülatör uçtan uca testleri (`integration_test/`, sabit `kE2ePassword` in `integration_test/support/e2e.dart`) |

`e2e-sim` şifresi uygulamanın şifre kuralına uyar (en az 6 karakter, küçük
ve büyük harf, rakam): kayıt testi (a1) onu kayıt ekranına yazar, diğer
senaryolar API ile açılan hesaba giriş ekranından girer.

`<senaryo>`: `kayit`, `kpss` (a), `sayac` (b), `seans` (c, f), `arkadas-a`,
`arkadas-b` (d), `silme` (e; test sonunda silinir), `host` (g, h, i: elle
koşulan simülatör senaryoları). `<koşu>`: `E2E_RUN_ID` (vars. `AAGGSSddss`).

Koşulardan kalan hesapları silmek (yerel kopya):

```sh
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "delete from auth.users where email like 'e2e-sim-%@pomosprint.local'"
```
