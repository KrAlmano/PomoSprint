# unsubscribe Edge Function

Bülten e-postalarındaki "Abonelikten çık" bağlantısını işler. Her abonenin
`marketing_subscribers.unsubscribe_token` ya da `waitlist.unsubscribe_token`
kolonunda tahmin edilemez bir UUID'si var; token olmadan kimse listeden
çıkarılamaz. Ek secret gerekmez. Waitlist token yolu için `proposed/19` A
kolonları gerekir (5 Ekim kaydında canlıda).

## Link biçimi

E-posta adresi bağlantıya konmaz (istek günlüklerine ve tarayıcı geçmişine
düşmesin); token tek başına yeterlidir.

- Sayfa: `https://pomosprint.app/unsubscribe?token=<uuid>`
  (sayfa açılınca hiçbir şey silmez; kullanıcı butona basınca POST atar)
- Tek tık (RFC 8058): `List-Unsubscribe: <https://<proje>.supabase.co/functions/v1/unsubscribe?token=<uuid>>`
  ve `List-Unsubscribe-Post: List-Unsubscribe=One-Click`

`send-welcome-email` ve `scripts/send_newsletter.js` linkleri bu biçimde üretir.
Daha önce gönderilmiş e-postalardaki `?email=..&token=..` bağlantıları da
çalışır: fonksiyon e-postayı token'ın sahibiyle karşılaştırır, sayfa ise
adresi okuduktan sonra adres çubuğundan siler.

## Davranış

- Yalnızca `POST` siler. `GET` 405 döner (e-posta güvenlik tarayıcıları linkleri
  GET ile açar; GET ile silme kullanıcıyı habersiz çıkarırdı).
- Token yoksa ya da UUID değilse 400. `email` verilirse token'ın sahibiyle
  eşleşmezse 403. Bulunamayan token için de 200 döner (adresin listede olup
  olmadığı açığa çıkmasın).
- Her iki token türü de aynı e-posta adresinin bütün yazımlarını iki listeden
  çıkarır. `waitlist` ham `UNIQUE(email)` nedeniyle case farkıyla birden çok
  kayıt içerebilir; hepsi kaldırılır. Büyük/küçük harf farkı dikkate alınmaz.
- Eşleme sabitlenmiş ve metakarakterleri kaçışlanmış `imatch` regex ile yapılır;
  `%`, `_`, `*` veya regex metakarakterleri başka adresleri eşlemez. `ilike`
  kullanılmaz: PostgREST `*` karakterini `%` jokerinin takma adı olarak işler.
- Önce diğer liste, sonra token sahibinin listesindeki aynı adresin diğer
  kayıtları, en son token sahibi silinir. Her silme hatası 500 döner ve token
  sahibi korunur. Aynı linkle yeniden denenebilir; yanlış başarı gösterilmez.

7 Ekim 2026 QA'da repoya bu düzeltmeler eklendi; bu çalışma canlı deploy
yapmadı. Ağsız testlerde waitlist-only token, iki yönde hata ve yeniden
deneme, eski bağlantı biçimi, case-variant kayıtlar, üç silme aşaması ve joker
karakterli e-posta sınandı. GET/OPTIONS e-posta tarayıcısı istekleri silmez.
Gerçek yerel PostgREST GET sorgularında `*` takma adı ve `imatch` doğrulandı;
kanıt `analiz/qa_evidence_20261007/site/postgrest_filter_readonly.json`.

## Deploy (JWT doğrulaması KAPALI olmalı)

Sayfa ve e-posta istemcilerinin tek tık isteği `Authorization` başlığı
göndermez. Bayraksız bir deploy tüm abonelikten çıkma bağlantılarını 401'e
düşürür.

```bash
supabase functions deploy unsubscribe --no-verify-jwt
```

CLI yoksa: Supabase Dashboard > Edge Functions > unsubscribe > Code'a
`index.ts`'i yapıştırıp Deploy; Details'te "Verify JWT" kapalı kalmalı.

## Doğrulama (silme yapmaz)

- Token'sız POST → 400
- `GET` → 405
- Rastgele UUID token ile POST → 200 (hiçbir satır silinmez)

Yerel birim testi (canlıya dokunmaz; Supabase istemcisi sahte):
`cd scripts && npm test`
