# PomoSprint

Pomodoro tekniğini oyunlaştıran bir Flutter çalışma uygulaması: 25/50 dakikalık odak seansları, ders kategorileri, raporlar, seri bonusu, haftalık ligler, avatarlar ve arkadaşlarla sosyal akış. Backend Supabase (Postgres, Auth, RPC'ler, Edge Functions).

Mimari ve ekranların ayrıntılı açıklaması için: [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md)

## Klasörler

| Klasör | İçerik |
|---|---|
| `lib/` | Flutter uygulaması (`screens/`, `services/`, `models/`, `widgets/`, `l10n/`) |
| `supabase/migrations/` | Veritabanı migration'ları (up/down) |
| `supabase/functions/` | Edge Function'lar |
| `supabase/tests/` | Migration'lar için yerel SQL davranış testleri |
| `scripts/` | Güvenlik regresyon testi ve bülten gönderimi (Node) |
| `landing/` | Tanıtım sitesi (pomosprint.app) |

## Kurulum

1. Kök dizinde `.env` oluştur: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, isteğe bağlı `SENTRY_DSN`. Bu dosya uygulamaya gömülür; içine **asla** service role anahtarı koyma.
2. `flutter pub get`
3. `flutter run`

Android release AAB için `android/key.properties` gerekir; yoksa `bundleRelease` bilerek hata verir.

## Testler

```bash
flutter analyze
flutter test
```

Veritabanı güvenlik kuralları için yerel SQL testleri: `supabase/tests/security_hardening_test.sql` başlığına bak.
Canlı projeye karşı regresyon testi (geçici test hesapları açar ve siler): `cd scripts && node security_regression_test.js`
