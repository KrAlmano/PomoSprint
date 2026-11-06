# Genel uçtan uca kontrol — 6 Kasım 2026

## Sonuç

Kayıt, giriş ve parola kurtarma ayrı yerel gerçek Auth/Mailpit ortamında; yeni hesap ve ana ekran gezinmesi iPhone simülatöründe ayrı QA uygulaması ve veritabanında; lig ve sosyal senaryoları sentetik SQL ortamlarında test edildi. Kullanıcının izniyle bir canlı parola kurtarma e-postası gönderildi. Bunlar henüz bütün platformları, gerçek cihazları veya tüm canlı kullanıcı senaryolarını kapsamaz. Uygulamanın mevcut canlı sunucu güvenlik ve hukuki eksikleri nedeniyle koşulsuz yayın onayı verilmez.

## Yapılan kontroller

- Gerçek yerel GoTrue v2.197.0 + Mailpit ile kayıt, doğrulamadan önce girişin reddi, kayıt e-postasını doğrulama, giriş, parola kurtarma e-postası, yeni parola ayarlama, eski parola reddi, yeni parola ile giriş ve tek kullanımlık bağlantı testi geçti. Bu ortam boş ve dış ağa kapalıdır; gerçek posta alıcısı veya üretim verisi yoktur. [Yerel kayıt raporu](KAYIT_EPOSTA_YEREL_2026-11-06.md).
- Canlı Supabase'e kullanıcının izin verdiği adrese tek kurtarma isteği gönderildi; Auth HTTP 200 döndü. Kullanıcı gelen kutusunda e-postayı gördüğünü ve bağlantının şifre belirleme sayfasını açtığını bildirdi. Gerçek parola değiştirilmedi; gerçek yeni hesap doğrulama e-postası bu turda denenmedi. [Canlı e-posta raporu](MAIL_KONTROLU_2026-11-06.md).
- Ayrı uygulama kimliği ve boş yerel Auth/PostgREST ile iPhone 17 simülatöründe gerçek `main()` üzerinden kayıt, onboarding, profil/kategoriler ile Raporlar/Sıralama/Sosyal/Deneme ekranlarının açılması **1/1** geçti. Native tur otomatik e-posta onaylıdır; gerçek gönderimi kanıtlamaz. [Uçtan uca akış raporu](UCTAN_UCA_AKIS_2026-11-06.md).
- Hedef/global normal ve deneme ligi **46/46**; beş sentetik hesapla arkadaşlık ve durum senaryosu **19/19**. Bunlar izole veritabanı/RPC testidir; mola profili fixture, doğal dönem kapanışı ve gerçek süreli çalışma değildir. Ayrıntılar aynı [akış raporunda](UCTAN_UCA_AKIS_2026-11-06.md).
- Flutter Auth/kayıt UI hedefli testleri **58/58**, site/e-posta işlevlerine yönelik hedefli Node testleri **72/72**, tüm `scripts` Node testleri **178/178**. Flutter analizi temiz; son genel test turu **1.617 başarılı, 5 isteğe bağlı ekran görüntüsü testi atlandı**. Bir önceki genel tur bilgisayar yükünü azaltmak için durdurulmuştu; bu sonuç yerine kullanılmadı.

## Kalanlar

- Canlı `send-welcome-email` işlevinin kaynakta beklediği gönderen ad ve adresine ait secret adları mevcut değil; kullanıcının bu yasal bilgileri daha sonra vereceği biliniyor. Kayıt doğrulama/kurtarma SMTP'sinden ayrı tanıtım/hoş geldin işlevi bunlar olmadan tamamlanmış sayılamaz.
- Kullanıcının önceki isteği üzerine gerçek eski hesap şifresi değiştirilmedi; gerçek kayıt doğrulama e-postası, gerçek cihazlar, Apple/Google girişleri, bildirimler, gerçek 25/50 dakikalık seans ve doğal ay sonu lig geçişi bu turda doğrulanmadı.
- 34 ödül koruması, 35 yaş koruması ve onboarding/rapor önerileri canlıda uygulanmadı. Eski kullanıcılar ve kuyruklar için geçiş çalışması ile [güvenlik](GUVENLIK_DUZELTME_2026-11-06.md) ve [hukuk](HUKUKI_VE_MAGAZA_KONTROLU_2026-11-06.md) raporlarındaki diğer işler sürer. 31'e dokunulmadı.
- Canlı Supabase redirect ayarını ayrı URL ile güncelleme girişimleri panel kilidi yüzünden başarıyla doğrulanmadı; yeniden okumada da panel zaman aşımı yaşandı. Kullanıcının gerçek sıfırlama bağlantısı şifre ekranına ulaştı, bu da o testin yönlendirmesini doğrular. Ayrıntılar [e-posta raporunda](MAIL_KONTROLU_2026-11-06.md).

Geçici QA uygulaması ve bu işin oluşturduğu veritabanı/servisler ve worktree kaldırıldı. Başka projelerin süreçleri ve cihaz verileri değiştirilmedi.
