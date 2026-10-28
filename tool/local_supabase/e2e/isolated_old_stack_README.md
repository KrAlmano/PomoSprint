# Yalıtılmış eski sunucu QA (A8)

Bu araç yalnız `127.0.0.1` üzerinde, 27–29 kurulmamış yerel bir API oluşturur.
Paylaşılan Auth `54321` kullanılmaz; canlı proje adresi, `.env`, gerçek anahtar
ve container environment içeriği okunmaz. Bu, güncel canlı şemanın yeniden
okunduğu veya canlıda test yapıldığı anlamına gelmez.

## Ön koşullar ve başlatma

- Yerel PomoSprint PostgreSQL `127.0.0.1:54322` açık olmalı.
- `pomosprint_overnight_baseline` adlı eski referans bulunmalı. Araç, açık katalog/
  config listesi ve `auth.schema_migrations` dışındaki public/Auth/net tablolarının
  **tamamının boş** olduğunu kontrol eder. TUS constraint'te olmamalı, 27–29/31
  migration'ları ve yeni Deneme/aylık lig RPC'leri bulunmamalı. Dışarı mail gönderen
  welcome trigger'ı **disabled** olmalı. Bu koşullar bozulursa ilerlemez.
- Mevcut, önceden indirilmiş GoTrue `v2.197.0` ve PostgREST `v16.4` imajları
  kullanılır. Başka projenin container'ları veya verisi değiştirilmez.

```sh
python3 -m unittest discover -s tool/local_supabase/e2e -p test_isolated_old_stack.py -v
python3 tool/local_supabase/e2e/isolated_old_stack.py start
python3 tool/local_supabase/e2e/isolated_old_stack.py status
```

Araç, boş referansa dokunmadan `pomosprint_verify_old_20261028` adlı TEMPLATE
kopyasını oluşturur. Kullanıcı, seans veya kimlik bilgisi kopyalanmaz. Mevcut
kopya/isim/port varsa üstüne yazmaz. Kopyanın sahiplik açıklaması ve yeni
container'ların `com.pomosprint.qa=oldserver-20261028` etiketi tutulur.

| Bileşen | Yalnız loopback portu |
|---|---:|
| Uygulamanın kullanacağı gateway | 54341 |
| Yalıtılmış PostgREST | 54342 |
| Yalıtılmış GoTrue | 54343 |

GoTrue, yalnız bu kopyanın Auth şemasına, bilinen **PUBLIC yerel demo**
`supabase_auth_admin:postgres` bilgisiyle bağlanır. JWT için de Supabase'in
PUBLIC yerel demo fixture değeri kullanılır; mevcut native test demo anon
anahtarıyla uyumludur. Gerçek anahtar veya parola alınmaz.
`AUTOCONFIRM=true`; SMTP/provider/hook yapılandırılmaz, e-posta gönderilmez.
Bu davranış Mailpit onayı veya gerçek posta teslimi testi olarak sunulmamalıdır.

## Güvenli kontrol ve native senaryo

Gateway sadece `/auth/v1/…` ve `/rest/v1/…` yollarını iki sabit yerel servise
iletir. Harici Host/Origin, cross-site Fetch, yönlendirme, geçersiz/kaçışlı yol
ve 1 MiB üzeri gövde reddedilir. Token, e-posta, query string veya gövde loglanmaz.

- `GET /health`: yalnız yerel kapsam/DB adı.
- `GET /qa/v1/verify`: imzası/süresi/rolü doğrulanan JWT'nin kendi UID'si için
  sabit, salt okunur SQL kontrolü. UID veya SQL query parametresi kabul edilmez.
  Hesap adı `e2e-sim-old-…@pomosprint.local` ve yeni oluşturulmuş olmalıdır.
- `/psql` gibi keyfi SQL yolu yoktur.

Native A8 senaryosu gateway'e bağlıdır. Genel `E2eHost` yalnız ekran kaydı için
kullanılır; bu hesaplar için paylaşılan hostun SQL/onay fonksiyonları çağrılmaz.
Normal sayaç başlangıcı/iptali gerçek UI ile, rapor geçmişi ise açıkça etiketli
25 dakikalık geçmiş tamamlama RPC fixture'ıyla sınanır. Fixture, 25 dakikanın
bu senaryoda doğal olarak beklendiği anlamına gelmez. TUS'un CHECK fallback
niyeti UID anahtarlı kalıcı kayıtta korunmalı; eski DB'ye TUS kabul edilmiş gibi
yazılmamalıdır. TR/EN ve her platform sonucu ayrı kaydedilir.

## Durdurma

```sh
python3 tool/local_supabase/e2e/isolated_old_stack.py stop
```

Yalnız sahiplik açıklaması/etiketi eşleşen bu iki container, gateway süreci ve
kopya DB kaldırılır. Başlatma hatasında günlükler için çıkmış owned container
saklanabilir; `stop` ile temizlenip yeniden denenir. Referans DB, ana QA verileri,
R75 veya başka projenin servisleri silinmez. Sonuçlar ve bootstrap günlükleri
`build/verification_20261028/isolated_old/` altında kalır.
