# Supabase Auth e-posta şablonları

Supabase panelinde (Authentication → Emails → Templates) elle tutulan
şablonların repodaki kopyası. Panelde değiştirince buraya da yaz.

Gönderim: özel SMTP, Resend (`smtp.resend.com`, gönderen
`noreply@mail.pomosprint.app`, alan adı Resend'de Ireland / eu-west-1,
5 Ekim 2026'da doğrulandı; alan adı/DNS 7 Ekim'de yeniden okundu). DNS (Cloudflare): `resend._domainkey.mail` TXT,
`send.mail` ve `rsend.mail` CNAME (yalnız DNS), `_dmarc` TXT `p=none`
(Cloudflare DMARC Management raporları).

| Şablon | Konu | Gövde | Not |
|---|---|---|---|
| Reset password | `PomoSprint: şifreni sıfırla` | `reset-password.html` | Bağlantı `token_hash` biçiminde: `landing/js/reset-password.js` kodu yalnızca form gönderilince harcar, e-posta güvenlik tarayıcılarının önceden tıklaması bağlantıyı bozmaz. Uygulamanın `redirectTo`'su (implicit `#access_token`) şablon değişince kullanılmaz ama sayfa iki akışı da destekler. |
| Confirm sign up | `PomoSprint: e-posta adresini onayla` | Panelde (Türkçe, `{{ .ConfirmationURL }}` → `confirmed.html`) | Konu panelde İngilizce kalmıştı. |

Tablodaki konular ve gövdeler repodaki şablon kopyalarıdır. 7 Ekim salt
okuma denetiminde paneldeki Auth şablonları/SMTP alanları yeniden
okunamadı; gerçek yeni gönderimle ayrıca doğrulanmalı.

## Tanıtım e-postaları (7 Ekim 2026 durumu)

Canlı `send-welcome-email` sürüm 9; 7 Ekim denetimi başında repo ile aynıydı.
Bu oturumda repoya eklenen hata düzeltmeleri henüz deploy edilmedi.
`MAIL_SENDER_NAME` /
`MAIL_SENDER_ADDRESS` Edge secret'ları **bilinçli olarak tanımlı değil**:
kullanıcı gönderen kimliğini (6563 / Ticari Elektronik İletiler Yönetmeliği,
tanıtım e-postasında gönderenin tanıtılması) şimdilik paylaşmak istemedi, bu
yüzden hoş geldin e-postası gönderilmiyor (fonksiyon 500 döner, satır
sahiplenilmez). Bülten (`scripts/send_newsletter.js`) de gönderilmemeli.
Açmak için: iki secret'ı tanımla ve aşağıdaki düzeltmeleri içeren yeni
fonksiyonu deploy et. Bu QA oturumunda canlı secret/ayar/deploy değişmedi.
Kayıt onayı ve şifre sıfırlama (Auth) bu şarttan etkilenmez. 5 Ekim'deki
parola sıfırlama e-postasının "Delivered" kaydı 7 Ekim panel okumasında
da görüldü; bu, yeni kayıt onayının bugün teslim edildiği anlamına gelmez.
"PomoSprint sending" anahtarı yalnız gönderme yetkilidir; panelde son
kullanımı 2 gün önce görünür.

7 Ekim yerel welcome düzeltmeleri: e-posta eşleşmesi atomik sahiplenme
filtresinde yapılır (yanlış payload gerçek abonenin mailini engellemez);
e-posta filtresi PostgREST yıldız jokerine karşı kaçışlı/sabit uçlu `imatch`
regex kullanır; provider isteği 10 saniye ile sınırlıdır, ağ/provider hatasında işaret
geri alınır. Geri alma DB hatası gizlenmez (`500 Database error`). Aynı
kayıt yeniden denenince `Idempotency-Key: welcome-subscriber/<id>` kullanılır;
[Resend anahtarı 24 saat korur](https://resend.com/docs/dashboard/emails/idempotency-keys),
fonksiyonun yeni abonelik kabul penceresi 1 saattir. Bu otomatik bir yeniden
deneme zamanlayıcısı değildir; webhook/çağrı yeniden yapılırsa güvenlidir.

## 7 Ekim salt okuma ve yerel QA kanıtı

- Resend paneli: `mail.pomosprint.app` Verified; DKIM, `send.mail` ve
  `rsend.mail` kayıtları Verified/DNS Only; gönderim açık, alım kapalı,
  bölge Ireland (`eu-west-1`). Genel DNS sorgusu da kayıtları doğruladı.
- Son 15 gün: 1 parola sıfırlama e-postası, Delivered (panelde 2 gün önce),
  %100 teslimat, 0 bounce ve 0 complaint. Örnek sayısı yalnızca 1;
  gelen kutusu/spam yerleşimi veya bugünkü yeni gönderim doğrulanmış sayılmaz.
- Canlı secret metadata: `RESEND_API_KEY` mevcut, iki `MAIL_SENDER_*` yok.
  Değerler okunmadı/kaydedilmedi.
- Yerel izole Auth + Mailpit: onaysız giriş reddi, gerçek yeniden onay,
  reset bağlantısı, eski/yeni parola, tek kullanımlık reset ve hesap
  varlığını gizleme dahil 9/9 geçti. Üretime e-posta gönderilmedi.
- Welcome regresyonları 15/15; tüm ağsız Node paket testleri 74/74 geçti.
  Unsubscribe düzeltmeleri de repoda var, canlı sürüm 10'dan farklıdır;
  onun deploy'u da bekliyor.

Adres, mesaj gövdesi ve anahtar değeri içermeyen kanıtlar:
[`analiz/qa_evidence_20261007/backend/email/`](../../analiz/qa_evidence_20261007/backend/email/).
