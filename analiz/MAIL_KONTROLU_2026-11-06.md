# Kayıt ve parola e-postası kontrolü — 6 Kasım 2026

## Canlı kontrol ve sınırlamalar

- Safari ile Supabase Auth SMTP ayarları salt okunur incelendi: özel SMTP açık, host `smtp.resend.com`, port 587, gönderici `noreply@mail.pomosprint.app` ve görünen ad PomoSprint. SMTP kullanıcı adı/parolası okunmadı ve değiştirilmedi. `smtp.resend.com:587` EHLO 250, STARTTLS 220 ve doğrulanmış TLS 1.3 döndürdü; SMTP AUTH veya DATA gönderilmedi.
- Resend Domains sayfasında `mail.pomosprint.app` satırı **Verified** görüldü. Ana alanın DMARC, `send.mail.pomosprint.app` SPF ve `resend._domainkey.mail.pomosprint.app` DKIM TXT kayıtlarının varlığı DNS ile kontrol edildi. Yalnız kayıt varlığı gözlendi; doğruluk/teslimat bağımsız biçimde tamamlanmış sayılmaz.
- Resend Emails ekranında satırlar yüklenmedi; güncel sağlayıcı teslim durumu ve kota bu incelemede doğrulanamadı. Gmail bağlantısı `UNAUTHORIZED` nedeniyle yeniden giriş istiyor. Bu araçlardan gelen kutusu erişimi yoktur.
- Kullanıcının açıkça izin verdiği adrese **tek** parola sıfırlama isteği 22:18 Europe/Istanbul'da gönderildi; hedef `https://pomosprint.app/reset-password.html`, Supabase Auth HTTP 200. **Kullanıcı beyanına göre** e-posta gelen kutusuna ulaştı ve bağlantı yeni şifre belirleme sayfasını açtı. Ajan bağlantıya tıklamadı; kullanıcı şifre değiştirmedi. Bu nedenle gerçek parola güncellemesi, yeni parolayla giriş ve bağımsız Resend teslim kanıtı yoktur. Genel HTTP 200 tek başına hesabın varlığını veya teslimi göstermez. Kullanıcı adresi, gerçek e-posta içeriği ve token bu rapora kaydedilmedi.
- Kayıt doğrulaması için üretimde yeni hesap açılmadı, mevcut hesaba parola atanmadı veya hesap silinmedi. Dolayısıyla gerçek bir yeni hesap için kayıt doğrulama e-postasının gönderimi/alımı bu turda doğrulanmadı; yerel Mailpit testleri gerçek internet teslimi değildir.
- Sunucuda `send-welcome-email` ACTIVE v9 ve `unsubscribe` ACTIVE v10. Yalnız secret adları listelendi: `RESEND_API_KEY` adı mevcut; `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` adları yok. Bunlar Auth kayıt/sıfırlama postasından ayrı hoş geldin/tanıtım e-postası işleyişindeki eksik gönderen kimliğidir. Kullanıcı bu bilgileri daha sonra vereceği için değer uydurulmadı.

## Auth yönlendirmesi

Safari URL Configuration ilk görünümünde Site URL `https://pomosprint.app/`; ek listedeki iki görünür değer `https://pomosprint.app/confirmed.html` ve `https://pomosprint.app/*` idi. İlk bakışta Supabase'in belgelenmiş joker kuralı nokta karakteri açısından soru yarattı. Kullanıcının yetkisiyle tam reset adresini ayrı eklemek için iki girişim yapıldı; panel `Lock was stolen by another request` hatası gösterdi ve ardından URL listesinde ek kayıt doğrulanamadı. Son pending işlem sonrası sunucu durumunun ayrıca yeniden okunması gerekir; değişiklik başarıyla uygulandı denmemelidir.

Son bir salt okunur kontrol için yeni açılan ayrı Safari sekmesinde URL Configuration sayfası tam yüklenmedi ve Safari AppleEvent zaman aşımı verdi; sonuç olarak bekleyen isteğin sonunda uygulanıp uygulanmadığı tespit edilemedi. Açılan bu sekmeyi kapatma isteği de zaman aşımına uğradı; başka sekmeye dokunulmadı ve yeni kaydetme isteği gönderilmedi.

Bağımsız izole gerçek GoTrue v2.197.0 testinde aynı site URL ve görünen allowlist ile üretilen recovery bağlantısı işlendiğinde `reset-password.html` hedefine yönlendi. Auth kaynak incelemesinde Site URL ile scheme/host/port aynıysa path'in ayrı eşleşmesi aranmadığı görüldü. Üretimde kullanıcının gördüğü reset ekranı da doğru hedefe erişim için kullanıcı beyanıdır; kullanılan canlı Auth sürümü ayrıca doğrulanmadı. [Supabase yönlendirme rehberi](https://supabase.com/docs/guides/auth/redirect-urls), [Auth kaynak kodu](https://github.com/supabase/auth/blob/master/internal/utilities/request.go).

## Yerel test

`scripts` altında `landing_auth_pages`, `landing_unsubscribe_page`, `landing_waitlist_form`, `unsubscribe_function`, `welcome_email_function` ve `newsletter_mail` için Node sentetik turu: **72/72 geçti**. Gerçek sağlayıcı veya kullanıcı verisi kullanılmadı. Bu sonuç gerçek teslim, mevcut üretim Edge sürümüyle kaynak paritesi veya e-posta kimliği ayarlarının tamamlandığı anlamına gelmez.
