# Yerel şifre recovery kontrolü — 28 Ekim 2026

Yeni g2 native senaryosu `g_review_flows_test.dart` içindedir; mevcut g
wrapper'ı kullanılır. `E2E_PLAIN_NAME='g2'` ile ayrı seçilebilir. Yeni yerel
host modülü `local_recovery.py`, endpoint `/recover-password` ve
`E2eHost.recoverLocalPassword` kullanılır. Wrapper dosyaları değiştirilmedi;
g çalıştırılırken host güncel kaynaktan yeniden başlamalıdır.

Güvenlik sınırları: yalnız `e2e-sim-recovery-<1–40 küçük harf/rakam/tire>`
@pomosprint.local, son12saatte oluşturulmuş exact e-posta/owner, sabit
Mailpit127.0.0.1:54324 ve Auth127.0.0.1:54321. Kaynak URL/parola/token/gövde
loglanmaz. Gelen recovery linkinin host/path/type/token/redirect'i doğrulanır;
doğrulama yalnız sabit yerel adrese yapılır, redirect takip edilmez. Oturum
tokenı host belleğinde kalır; native çağrı yalnız `changed` sonucunu alır.
GET /user ile owner doğrulanmadan PUT yapılmaz. Host JSON, boyut ve Origin
kontrolü uygular; yeni endpoint'e tarayıcıdan cross-origin istek reddedilir.

**10/10 çevrimdışı helper testi geçti.** Mevcut Mailpit paketi15geçti/1açık
live-skip; yeni helper önceki signup doğrulamasını gevşetmez. g/l/support
hedefli analyze temizdir.

Ayrı yeni yerel Auth hesabıyla gerçek API preflight yapıldı: signup→Mailpit
onay→recovery e-postası→token doğrulama→parola güncelleme→eski parola reddi ve
yeni parola ile aynı owner giriş **geçti**. İlk hazırlık denemesi, Auth'un
`user` sarmalayıcısı yerine doğrudan kullanıcı nesnesi döndürmesi nedeniyle
durdu; ikinci hazırlık doğru şekille geçti. Bu bilgi l'nin raw signup
dalındaki aynı varsayımı düzeltmek için kullanıldı. İki yeni yalnız yerel
recovery-preflight hesabı oluştu; mevcut hesap/probe satırları değiştirilmedi.

**Native g2 henüz çalıştırılmadı; web form UI'si de test edilmedi.** g2
uygulamadan e-posta ister, gönderildi ekranını görür, host aracılığıyla gerçek
yerel recovery/parola güncellemesini yapar; uygulamada eski parola hatasını
ve yeni parolayla aynı owner'ın açılmasını doğrular. Bu Mailpit/Auth/native
giriş zinciridir. `landing/reset-password.html` gerçek formunun Safari UI
kanıtı değildir. Üretime veya canlı e-posta sağlayıcısına istek yapılmadı.
