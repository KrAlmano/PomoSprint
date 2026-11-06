# Güvenlik düzeltmeleri ve kalan işler — 6 Kasım 2026

Bu çalışma canlı kullanıcılar veya gerçek hesaplarla müdahale içermez. Ana kaynakta yapılan istemci değişiklikleri, mağazaya dağıtılan bir sürüm değildir. 31 uygulanmadı; yeni SQL adayları canlıya kurulmadı. Önceki [güvenlik ve bağlantı raporu](GUVENLIK_BAGLANTI_KONTROLU_2026-11-06.md) ve [hukuki inceleme](HUKUKI_VE_MAGAZA_KONTROLU_2026-11-06.md) geçerliliğini korur.

## Yerelde düzeltilenler

1. **Şifre değiştirirken hesap/oturum değişimi:** Önceki akış paylaşılan Auth istemcisinde yeniden giriş yapıp parola güncelliyordu. Gecikmiş yanıtla başka kullanıcı oturumunun değişmesi veya yanlış kullanıcı verisiyle karışması gerçek SDK ve loopback/sentetik Auth testiyle yeniden üretildi. Yeni uygulama geçici kimlik doğrulamayı ayrı bellek içi istemcide yapar, beklenen hesap ve oturum kimliğini kontrol eder ve güncellemeyi mevcut cihaz oturumunun JWT'siyle izole istemcide yapar. Aynı oturumda JWT yenilenirse son güncel snapshot kullanılır. İstek gönderildikten sonra yanıtın kaybı, sunucu hatası veya hesap değişimi gerçekleşirse işlem sonucu kesin başarısız varsayılmaz; kullanıcıya değişmiş olabileceği TR/EN bildirilir. Normal doğrulanabilir Auth redleri ve ek doğrulama ihtiyacı ayrı gösterilir.
2. **Auth sunucusunun oturum davranışı:** Yalıtılmış gerçek GoTrue v2.197.0 testinde geçici oturumla yapılan parola güncellemesinin asıl oturumun refresh yetkisini iptal ettiği; asıl oturumla güncellemede asıl oturumun korunduğu gösterildi. [Ayrıntı ve sınırlar](PAROLA_AUTH_YEREL_2026-11-06.md). Test gerçek üretim Auth sürüm ve yapılandırmasını doğrulamaz.
3. **Hata verisi:** Sentry olaylarında URL yoluna gömülü bazı token, OTP ve JWT'ler ile serbest metindeki `current_password`/`new_password` gibi değerler maskelenir. Şifre değiştirme sırasında sağlayıcı hatasının ham içeriği cihaz günlüğüne yazılmaz. Sentetik test kapsamı tüm olası kişisel veri ve gizli bilgi biçimlerini ispatlamaz; canlı Sentry gönderimi yapılmadı.
4. **Onboarding hata uyumu:** Yeni sunucu adayı `23514/onboarding_required` döndürdüğünde yeni istemci bekleyen seansı kalıcı ret saymak yerine kuyrukta bırakır. Diğer 23514 hatalarının mevcut davranışı korunur. Sunucu adayı canlıda olmadığı için mevcut üretim koruması değişmez.

Şifre akışında Supabase SDK'nın webde aynı host için BroadcastChannel kullanması nedeniyle geçici doğrulama istemcisi webde engellendi; ürün iOS/Android hedeflidir. Geçici oturumun ağ kopması veya gecikmiş giriş yanıtı halinde uzak sunucuda iptal edildiği garanti değildir. PUT sunucuya ulaşmışsa sonradan hesap değişimi veya ağ kopması parolayı geri almaz. Aynı oturum snapshot alındıktan sonra tekrar yenilenirse eski JWT reddedilebilir; bu durumda işlem hata verir. Sunucu ek doğrulama/nonce isterse kullanıcıya yeniden giriş açıklaması sunulur; gerçek Auth ayarı, mevcut şifre zorunluluğu ve fiziksel cihaz davranışı bu turda doğrulanmadı.

## Yalnız yerelde hazırlanmış sunucu adayı

[Onboarding etkinlik koruması](../supabase/proposed/20261106_onboarding_activity_guard_README.md), 35 ön koşuluyla yeni seans başlangıcı, seans kaydı ve Deneme başlangıcında tamamlanmış onboarding arar. İzole sentetik PostgreSQL/RPC, dry-run ve geri alma kontrolleri geçti. Mevcut ve geçmiş gerçek kullanıcı verilerine dokunulmadı. Eski mobil sürümler hatayı kalıcı sayabilir; eksik profilli eski hesaplar, aktif Denemeler, diğer RPC'ler, 24 saat sınırı ve canlı şema uyumluluğu ayrıca çözümlenmelidir. Bu aday 35'i veya gerçek yaş doğrulamasını tek başına tamamlamaz; doğum yılı kullanıcı beyanıdır.

## Kalan canlı riskler

- **Ödül güvenliği:** 34 aktif değil; doğrulanmamış seanslardan ödül riski devam ediyor. Eski main kaynaklı istemciler doğrulanmış başlangıç makbuzu oluşturmadığı için 34'ün kapısını doğrudan açmak gerçek çalışmaların puanını da engelleyebilir. Güvenli geçiş ve geri alma sınırları [ödül raporunda](ODUL_GUVENLIK_DOGRULAMASI_2026-11-06.md).
- **Yaş/erişim:** 35 ve yeni etkinlik adayı canlıda değil; yaş kapısı ve onboarding atlatma riski devam ediyor. Diğer uçlar için yetkilendirme ayrıca incelenmeli.
- **Bekleme listesi:** Doğrudan anonim INSERT yolu ve bunun 409/yük suistimali riskleri için [yerel aday ve kademeli geçiş](../supabase/proposed/waitlist_rpc_abuse_guard_20261101_README.md) hazır; site ve canlı RPC henüz değiştirilmedi. Genel kota tüm bot saldırılarına karşı yeterli koruma değildir.
- Önceki Deneme geçmişi sayfalama sunucu adayı da canlıya uygulanmadı. Gerçek kullanıcılarla iki hesap arası üretim E2E, gerçek Sentry teslimi, mağaza imzalı derleme ve fiziksel cihazlar bu turda doğrulanmadı.

## Testler

Son kaynak durumunda `flutter analyze` temiz, `flutter test --concurrency=2` **1.617 başarılı / 5 isteğe bağlı ekran görüntüsü testi atlandı / 0 başarısız**; `scripts` Node testleri **178/178**. Hedefli testler: parola/Sentry **72/72**; onboarding kuyruğu **50/50**; seans/Maraton **51/51**; Node Edge işlevleri **64/64**. Aynı testler kısmen birbirini kapsar, sayılar toplanmamalıdır. Auth gerçek-sunucu testi yalnız izole yerel Docker ağında ve sentetik hesaplarla yapıldı, test container'ları/ağı temizlendi.
