# Parola değişikliğinde oturum davranışı — yerel doğrulama

Tarih: 6 Kasım 2026. Kontrol, `public.ecr.aws/supabase/gotrue:v2.197.0` ve PostgreSQL 17 ile sıfırdan oluşturulan, yalnız test için ayrılmış Docker ağı ve boş veritabanında yapıldı. Yalnız sentetik hesaplar kullanıldı; canlı Auth, gerçek hesap, kullanıcı verisi veya üretim anahtarları kullanılmadı.

İki hesap için ayrı oturumlar oluşturuldu; aşağıdaki değerler HTTP durum kodlarıdır:

| Deneme | Parola güncelleme | Ana oturum refresh | Geçici oturum refresh |
| --- | --- | --- | --- |
| Güncelleme geçici oturumla yapıldı | 200 | 400 | 200 |
| Güncelleme ana oturumla yapıldı | 200 | 200 | 400 |

İlk senaryoda kalan geçici oturum `local` kapsamıyla kapatıldı: çıkış **204**, sonraki geçici refresh **400** döndü. Bu, ilk yaklaşımda parola güncellemesinin cihazın ana refresh oturumunu da geçersizleştirebildiğini; ana oturumla güncelleme yapılan kontrol senaryosunda ise ana refresh oturumunun korunduğunu gösterir. Kodu, yüklü cihaz SDK'sını veya gerçek sağlayıcı yapılandırmasını uçtan uca test etmez.

Kurulum sırasında test istemcisi ve PostgreSQL `search_path` ayarı nedeniyle iki hazırlık denemesi başarısız oldu; sonuçlar yukarıdaki başarılı testlerden alınmıştır. Testin kendisi doğal cihaz süresi, farklı Auth sürümleri, ağ kesintisi, MFA, eski oturumda nonce zorunluluğu, web BroadcastChannel veya canlı ortam davranışını kanıtlamaz. Test için açılan iki container ve yalnız onlara ait Docker ağı işlem bitiminde kaldırıldı. Diğer çalışan container'lara dokunulmadı.
