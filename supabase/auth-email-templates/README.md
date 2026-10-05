# Supabase Auth e-posta şablonları

Supabase panelinde (Authentication → Emails → Templates) elle tutulan
şablonların repodaki kopyası. Panelde değiştirince buraya da yaz.

Gönderim: özel SMTP, Resend (`smtp.resend.com`, gönderen
`noreply@mail.pomosprint.app`, alan adı Resend'de Ireland / eu-west-1,
5 Ekim 2026'da doğrulandı). DNS (Cloudflare): `resend._domainkey.mail` TXT,
`send.mail` ve `rsend.mail` CNAME (yalnız DNS), `_dmarc` TXT `p=none`
(Cloudflare DMARC Management raporları).

| Şablon | Konu | Gövde | Not |
|---|---|---|---|
| Reset password | `PomoSprint: şifreni sıfırla` | `reset-password.html` | Bağlantı `token_hash` biçiminde: `landing/js/reset-password.js` kodu yalnızca form gönderilince harcar, e-posta güvenlik tarayıcılarının önceden tıklaması bağlantıyı bozmaz. Uygulamanın `redirectTo`'su (implicit `#access_token`) şablon değişince kullanılmaz ama sayfa iki akışı da destekler. |
| Confirm sign up | `PomoSprint: e-posta adresini onayla` | Panelde (Türkçe, `{{ .ConfirmationURL }}` → `confirmed.html`) | Konu panelde İngilizce kalmıştı. |

## Tanıtım e-postaları (5 Ekim 2026 durumu)

`send-welcome-email` repodaki sürümle yayında (sürüm 9). `MAIL_SENDER_NAME` /
`MAIL_SENDER_ADDRESS` Edge secret'ları **bilinçli olarak tanımlı değil**:
kullanıcı gönderen kimliğini (6563 / Ticari Elektronik İletiler Yönetmeliği,
tanıtım e-postasında gönderenin tanıtılması) şimdilik paylaşmak istemedi, bu
yüzden hoş geldin e-postası gönderilmiyor (fonksiyon 500 döner, satır
sahiplenilmez). Bülten (`scripts/send_newsletter.js`) de gönderilmemeli.
Açmak için: iki secret'ı tanımla (fonksiyon yeniden deploy gerekmez).
Kayıt onayı ve şifre sıfırlama (Auth) bu şarttan etkilenmez; çalışıyor
(5 Ekim, Resend'de "Delivered", anahtar: yalnız gönderme yetkili
"PomoSprint sending").
