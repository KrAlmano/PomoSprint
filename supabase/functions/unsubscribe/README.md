# unsubscribe Edge Function

Bülten e-postalarındaki "Abonelikten çık" bağlantısını işler. Her abonenin
`marketing_subscribers.unsubscribe_token` kolonunda tahmin edilemez bir UUID'si
var; token olmadan kimse listeden çıkarılamaz. Ek secret gerekmez.

## Link biçimi

- Sayfa: `https://pomosprint.app/unsubscribe?email=<e-posta>&token=<uuid>`
  (sayfa açılınca hiçbir şey silmez; kullanıcı butona basınca POST atar)
- Tek tık (RFC 8058): `List-Unsubscribe: <https://<proje>.supabase.co/functions/v1/unsubscribe?email=..&token=..>`
  ve `List-Unsubscribe-Post: List-Unsubscribe=One-Click`

`send-welcome-email` ve `scripts/send_newsletter.js` linkleri bu biçimde üretir.

## Davranış

- Yalnızca `POST` siler. `GET` 405 döner (e-posta güvenlik tarayıcıları linkleri
  GET ile açar; GET ile silme kullanıcıyı habersiz çıkarırdı).
- Token yoksa ya da UUID değilse 400. `email` verilirse token'ın sahibiyle
  eşleşmezse 403. Bulunamayan token için de 200 döner (adresin listede olup
  olmadığı açığa çıkmasın).
- Abone `waitlist`'ten de çıkarılır.

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
