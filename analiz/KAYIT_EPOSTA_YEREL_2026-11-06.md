# Kayıt ve e-posta akışı — yerel doğrulama

Tarih: 6 Kasım 2026. Bu rapor canlı posta teslimi veya üretim sürümünün tam uçtan uca kanıtı değildir.

`tool/local_supabase/e2e/isolated_auth_mail_smoke.py`, **GoTrue v2.197.0, PostgreSQL 17 ve Mailpit v1.31.3** için yalnız bu teste ait, dış ağa kapalı (`--internal`) Docker ağı ve boş veritabanı oluşturur. Sadece sentetik `example.com` adresi ve yerel test parolaları kullanılır; SMTP yalnız ağ içindeki Mailpit'e yöneliktir, gerçek adreslere/üretime e-posta gönderilmez. Test e-postaları, tokenlar ve parolalar rapora veya loga yazılmaz. Kullanıcının mevcut `pomosprint-local` dahil diğer proje veritabanlarına ve container'larına dokunulmaz. Test bitiminde yalnız bu testin oluşturduğu container'lar ve ağ kaldırılır.

Başarılı yerel turda şunlar doğrulandı:

- E-posta/parola ile kayıt açılır; onaydan önce parola ile giriş reddedilir.
- Mailpit'teki kayıt doğrulama bağlantısının gerçek `GET /verify` çağrısı hesabı doğrular ve `confirmed.html` adresine yönlendirir; ardından giriş aynı hesaba yapılır.
- Parola sıfırlama isteği Mailpit'e iletilir; e-postadaki bağlantı gerçekten işlenince `reset-password.html` adresine yönlendirilir ve doğru kullanıcı için kurtarma oturumu oluşur.
- Yeni parola kaydedilir; eski parola reddedilir, yenisiyle aynı hesaba giriş yapılır ve kurtarma bağlantısı tekrar kullanılamaz. Bilinmeyen bir adres için kurtarma isteği de kabul edilir.
- `flutter test --concurrency=2` ile kayıt onayları, şifremi unuttum, giriş gezinmesi, parola değişikliği yarışları/günlükleri ve dil değişimini kapsayan altı hedefli dosyada **58 test geçti**.

Yönlendirme sınırı: bu yerel örnekte `Site URL = https://pomosprint.app`, ek adresler `https://pomosprint.app/*` ve `https://pomosprint.app/confirmed.html` idi. [Supabase yönlendirme dokümanı](https://supabase.com/docs/guides/auth/redirect-urls), `*` eşleşmesinde `.` ve `/` ayırıcı der. Buna rağmen testte `reset-password.html` gerçekten seçilen hedefti. [GoTrue kaynak kodu](https://github.com/supabase/auth/blob/master/internal/utilities/request.go), Site URL ile şema, host ve port eşleştiğinde yolun wildcard kuralından bağımsız kabul edildiğini gösterir; gözlenen davranış bununla uyumludur. Bu, canlı Auth sürümü/yapılandırması veya gerçek bağlantı sonucunun aynı olduğunu kanıtlamaz.

İlk yalıtılmış kurulum denemelerinde Docker iç ağından host portuna erişilememe, PostgreSQL başlangıç yarışı ve test istemcisinin bağlantıyı erken kapatması nedeniyle hazırlık başarısızlıkları yaşandı; bu hatalar test altyapısına aitti, uygulama veya canlı kayıt hatası olarak sayılmadı. Başarılı koşu sonunda bu tura ait container/ağ kalmadığı ayrıca kontrol edildi. Ham test günlükleri `/tmp/pomosprint-isolated-auth-mail-redirect-20261106.log`, `/tmp/pomosprint-auth-ui-20261106.log` içindedir; `/tmp` kalıcı arşiv değildir.

**Doğrulanmayanlar:** Resend/gerçek SMTP gönderimi ve alıcının inbox/spam sonucu, canlı Supabase kayıt veya yönlendirme sürümü, gerçek iOS/Android cihazda mail bağlantısının açılışı, canlı şifre güvenliği yapılandırması ve Google/Apple girişi. Bunlar bu yerel testle başarılı kabul edilmemelidir. Hesap bilgisi, anahtar veya doğrulama kodu burada paylaşılmamalıdır.
