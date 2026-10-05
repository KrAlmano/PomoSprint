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
