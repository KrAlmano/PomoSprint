# delete-account Edge Function

Uygulama içi hesap silme (App Store 5.1.1(v), Google Play). Sign in with Apple
ile bağlı hesapta önce Apple token'ını iptal eder, sonra kullanıcıyı siler.

**Durum (7 Ekim 2026 QA): canlıya deploy edilmedi.** Canlı Edge listesi ana QA
oturumunda salt okunarak doğrulandı; bu kaynaktaki düzeltmeler yayınlanmadı.
İstemci önce bu fonksiyonu çağırır; 404 (deploy edilmemiş) veya 5xx alırsa
canlıdaki `delete_own_account` RPC'sine düşer. Uygulama bugün de hesabı ve
doğrulanmış e-postaya bağlı kayıtları siler; Apple token iptali bu fonksiyon
ve Apple yapılandırması hazır olduğunda devreye girer.

## Akış

1. Kullanıcı yalnızca çağıranın JWT'sinden alınır (`admin.auth.getUser(jwt)`).
2. Hesapta Apple kimliği varsa ve istekte `apple_authorization_code` geldiyse:
   `.p8` anahtarıyla ES256 `client_secret` üretilir, kod
   `appleid.apple.com/auth/token`'da refresh token'a çevrilir,
   `/auth/revoke` (`token_type_hint=refresh_token`) ile iptal edilir.
   Kod yoksa (kullanıcı Apple doğrulamasından vazgeçti, Android) ya da secret'lar
   yoksa iptal **atlanır** ve yanıtta `apple.status = "skipped"` + `reason` döner;
   uygulama kullanıcıya Ayarlar > Apple Hesabı > Apple ile Giriş > PomoSprint >
   Kullanmayı Durdur talimatını gösterir.
3. E-postası doğrulanmış hesapta `waitlist` ve `user_id`'si boş
   `marketing_subscribers` satırları silinir (`proposed/12` ile aynı
   `lower(btrim(email))` kuralı). Case farkları ve çevredeki ASCII boşluklar
   kabul edilir; e-posta metakarakterleri kaçışlanmış, sabitlenmiş `imatch`
   filtresiyle literal eşlenir. PostgREST `ILIKE` içindeki `*` alias'ı veya
   SELECT'in 1000 satır sınırı başka kayıtları hedefleyemez/eşleşmeyi atlayamaz.
   Temizlikte DB/ağ hatası olursa Auth kullanıcısı silinmeden
   `500 {error: "delete_failed", apple}` döner. Kullanıcı aynı JWT ile veya
   istemcinin mevcut SQL yedeğiyle işlemi yeniden deneyebilir.
4. `admin.auth.admin.deleteUser(uid)`: geri kalan her şey cascade ile silinir
   (AGENTS.md §5.6).

İstemci tarafı: `SupabaseService.deleteUserAccount` (`lib/services/supabase_service.dart`).
iOS'ta silmeden hemen önce `SignInWithApple.getAppleIDCredential(scopes: [])` ile
taze kod alınır (kod 5 dakika geçerli ve tek kullanımlık).

## İstek / yanıt

```
POST /functions/v1/delete-account
Authorization: Bearer <kullanıcının access token'ı>
{"apple_authorization_code": "..."}        // isteğe bağlı

200 {"deleted": true, "apple": {"status": "revoked" | "skipped" | "not_applicable", "reason"?: "..."}}
400 {"error": "invalid_payload"}
401 {"error": "not_authenticated"}   405 {"error": "method_not_allowed"}
500 {"error": "delete_failed", "apple": {"status": "...", "reason"?: "..."}}
```

Gövdesiz POST geçerlidir. Bozuk JSON, nesne olmayan gövde veya string olmayan
`apple_authorization_code` 400 döndürür ve silme başlamaz. Gövdedeki kullanıcı
kimliği/e-posta alanları silinecek hesabı değiştirmez; hedef yalnızca JWT'dir.

Fonksiyon **404 döndürmez**; istemci 404'ü "deploy edilmemiş", 5xx'i "çalışamadı"
sayıp `delete_own_account` RPC'sine düşer (5xx gövdesindeki `apple` durumu
korunur). 401/405 yedeğe düşmez.

## Secret'lar

Apple Developer > Certificates, Identifiers & Profiles > Keys: "Sign in with
Apple" yetkili bir anahtar oluşturun (`AuthKey_<KEY_ID>.p8`, bir kez indirilir),
Primary App ID olarak `com.pomosprint.app` seçin.

```bash
supabase secrets set \
  APPLE_TEAM_ID=AQGX8BJMYJ \
  APPLE_KEY_ID=<KEY_ID> \
  APPLE_CLIENT_ID=com.pomosprint.app
supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_<KEY_ID>.p8)"
```

`.p8` dosyasını repoya, `scripts/.env`'e ya da kök `.env`'e koymayın. Secret'lar
eksikse fonksiyon yine siler, yalnızca Apple iptalini atlar.

## Deploy (JWT doğrulaması AÇIK kalmalı)

```bash
supabase functions deploy delete-account
```

`--no-verify-jwt` **kullanmayın**: fonksiyon yalnızca oturum açmış kullanıcının
kendi hesabını siler. CLI yoksa: Dashboard > Edge Functions > Deploy a new
function > `delete-account`, `index.ts`'i yapıştırın; "Verify JWT" açık kalsın.

## Ağsız kaynak doğrulaması

```bash
cd scripts
node --test test/delete_account_function.test.mjs
npm test
```

7 Ekim kaynak koşusu: **25/25**. Gerçek `index.ts`, sahte Supabase Auth/DB ve
tamamen sahte Apple HTTP ile yürütülür. JWT/kimlik izolasyonu, malformed/boş
istek, doğrulanmamış e-posta güvenliği, case/metakarakter ve 1000 satır sınırı,
temizlik/silme hata-retry, Apple kimliği/kod/config ve token/revoke sonuçları
denetlenir. ES256 client secret imzası yalnızca testte üretilen geçici anahtarla
doğrulanır. Gerçek hesaba, Apple'a veya başka ağa istek gönderilmez.

Bu test, fiziksel cihazda Apple girişini/izin iptalini, Edge gateway JWT
doğrulamasını veya kaynak değişikliğinin canlıya deploy edildiğini doğrulamaz.

## Dağıtım sonrası doğrulama (gerçek silme ayrı test hesabıyla)

- Authorization başlığı olmadan POST → 401 (gateway)
- `GET` (geçerli JWT ile) → 405
- Gerçek silme yalnızca test hesabıyla; Apple iptali için iOS release/TestFlight
  build'inde Apple ile açılmış bir test hesabı gerekir. Sonra iPhone'da
  Ayarlar > Apple Hesabı > Apple ile Giriş listesinde PomoSprint görünmemeli.
