# PomoSprint yayın, pazarlama ve Almano Apps yol haritası

**Tarih: 8 Ekim 2026.** Türkiye'de yaşayan, şirketi olmayan, başka bir işte yazılım geliştiren ve kendi hesabından birkaç uygulama yayımlamak isteyen geliştirici için hazırlandı. Platform ve vergi bilgileri resmi kaynaklardan kontrol edildi. Kanal, içerik, bütçe ve marka tercihleri öneridir; satış veya indirme garantisi değildir.

## 1. Sana önerdiğim yol

**PomoSprint ürün adı olarak kalsın; Almano Apps gelecekteki uygulamalarının ortak geliştirici markası olsun.** `pomosprint.app` PomoSprint'i anlatsın. Daha sonra Almano Apps için küçük bir portföy sitesi açıp bütün uygulamalarını oradan listeleyebilirsin. Her uygulamanın ayrı adı ve mağaza sayfası olur; geliştirici kimliği ortak kalır.

Pazarlamada ilk olarak **Instagram + TikTok + YouTube Shorts** öneriyorum. Instagram ana iletişim hesabı olsun; aynı kendi çektiğin videoyu diğer iki platforma uyarlayarak iş yükünü sınırlayalım. İlk ay reklamdan önce küçük bir gerçek kullanıcı betasıyla hangi özelliğin insanları geri getirdiğini öğrenmek daha mantıklı.

**Şirket kararını birkaç uygulama yapacak olmana göre verme.** Bireysel hesaplardan birden fazla uygulama yayımlama yolları var. Asıl karar, kişisel yasal adının mağazada görünmesini ne kadar önemsediğin ve düzenli şirket giderini karşılamak isteyip istemediğin. Apple'da bireysel hesapla Almano Apps adı altında kişisel adını gizleyemezsin. [Apple üyelik koşulları](https://developer.apple.com/help/account/membership/program-enrollment/), [Apple geliştirici adı](https://developer.apple.com/help/app-store-connect/create-an-app-record/set-your-developer-name).

Benim öncelik sıram: **isim/hesap türü kararı → üyelik ve gerçek cihaz betası → PomoSprint için organik tanıtım → kullanım verisinden öğrenme → ikinci uygulama**. Almano Apps adına başlangıçta ikinci bir yoğun içerik takvimi gerekmiyor.

## 2. Flutter derlemesi ve uygulamanın şu anki durumu

Bu istekte güncel kaynak koddan normal uygulamayı derleyip senin **iPhone 16 Plus / iOS 18.6** simülatörüne kurdum. `lib/main.dart` kullanıldı; hızlı sayaç ve hızlı kayıt bayrakları verilmedi. Uygulama **canlı Supabase'e** bağlandı, Türkçe giriş ekranı açıldı ve debugger ayrıldıktan sonra açık kaldı. Bu yerel Docker QA uygulaması değil; kendi canlı hesabınla giriş yapabilirsin.

| Bu turda yapılan kontrol | Sonuç |
|---|---|
| Xcode / Flutter iOS debug derlemesi | Başarılı; ilk derleme 23,9 sn, son açılış derlemesi 13,5 sn |
| Gerçek simülatörde açılış | PomoSprint giriş ekranı görüldü; açılışta çökme veya Flutter hata ekranı görülmedi |
| Backend | Canlı `eoosnyakvxmifmexpgxa.supabase.co`; bağlantı başlangıç logunda doğrulandı |
| Sayaç modu | Normal 25/50 dakika; `QUICK_TIMER` ve `QUICK_TIMER_SAVE` kapalı |
| `flutter analyze` | Yeniden çalıştırıldı: **No issues found**, 6,9 sn |
| Tam Flutter test paketi | Aynı gün önceki son QA'da **1222/1222** geçti; bu pazarlama turunda tekrar koşulmadı |

Önceki kapsamlı [son uygulama QA raporu](QA_APP_FINAL_2026-10-08.md), kapat/aç, çevrimdışı kayıt, tek senkronizasyon, raporlar, sosyal/arkadaşlar, puan ve lig kontrollerini içeriyor. Bu açılış turunda kişisel hesaba giriş yapıp yeni canlı seans üretmedim; o QA sonuçlarıyla bu turdaki açılış kontrolünü birbirinden ayırıyorum.

Derleme logunda Google giriş eklentisinin ileride Flutter'ın zorunlu tutacağı UIScene yaşam döngüsüne geçişiyle ilgili bir uyarı var. Mevcut derlemeyi veya açılışı engellemedi. Sonraki Flutter/eklenti yükseltmesinde takip edilmeli; bu istekte bağımlılık değiştirilmedi.

Tekrar açmak için proje kökünde:

```sh
flutter run -d BEA55019-D5C3-420F-90F2-0B0CBD5690CF -t lib/main.dart
```

Kanıtlar: son açık ekran (ham çıktı §37 temizliğinde kaldırıldı), ilk derleme/açılış logu (ham çıktı §37 temizliğinde kaldırıldı), son etkileşimli açılışın araç çıktısı (ham çıktı §37 temizliğinde kaldırıldı), analiz logu (ham çıktı §37 temizliğinde kaldırıldı), son ortam özeti (ham çıktı §37 temizliğinde kaldırıldı).

**Mağaza yayını için kalanlar:** Apple üyeliği ve imzalı derleme/provisioning, gerçek cihaz kontrolleri, Apple giriş sağlayıcısı yapılandırması, mağaza metinleri/inceleme ve senin en son vereceğin gerçek geliştirici kimliği/adres bilgileri. Bunları tamamlanmış saymıyorum. RevenueCat/Plus da mevcut satış özelliği değil; sonra eklenebilir. Simülatörde çalışan debug derlemesi, mağazaya gönderilecek imzalı IPA değildir.

## 3. Hangi hesapları açmak mantıklı?

Aşağıdaki kullanıcı adları **adaydır**; müsaitliği veya marka hakkı doğrulanmadı. Hesaplar bu çalışma sırasında açılmadı.

| Hesap / alan | Öneri | Kullanım |
|---|---|---|
| PomoSprint Instagram | `@pomosprint`, olmazsa tutarlı `@pomosprintapp` | Ana ürün hesabı: Reels, kısa rehberler, beta haberleri, kullanıcı soruları |
| PomoSprint TikTok | Aynı ad | Kısa gerçek ekran demoları ve çalışma alışkanlığı içerikleri |
| PomoSprint YouTube | Aynı ad | Shorts; zamanla bir kurulum ve Maraton rehberi |
| Almano Apps sosyal adı | `@almanoapps` adayını kontrol et | Geliştirici hikâyesi ve sonraki uygulamalar; ayda bir anlamlı gelişme yeterli |
| Almano Apps domain | `.com`, `.app` veya `.dev` seçeneklerini araştır | Basit portföy, uygulamalar, destek ve kuruluş bilgileri; henüz satın alma yok |
| PomoSprint sitesi | Mevcut `pomosprint.app` | Ürün, özellikler, destek ve yayın aşamasına uygun katılım bağlantısı |
| LinkedIn | Mevcut kişisel profil uygunsa | Geliştirme hikâyesi ve küçük beta duyurusu; ayda iki paylaşım |

Başlangıçta Discord, Telegram ve WhatsApp grubu açmayı zorunlu görmüyorum. Düzenli birlikte çalışma talebi oluşursa topluluk açılır; aksi halde moderasyon işi çıkar. Reddit, Indie Hackers ve Product Hunt İngilizce ürün/erişilebilir beta hazır olduğunda ikinci aşama olabilir. Topluluk kurallarına uyup ürünün geliştiricisi olduğunu açıkça belirterek geri bildirim iste.

İlk profil metni taslağı:

> 25/50 dk odaklan. Maratonla mola ritmini koru.  
> Çalışmanı raporlarda gör, arkadaşlarınla devam et.  
> Erken erişim: pomosprint.app

Üç sabit gönderi: **PomoSprint nedir?**, **Maraton nasıl işler?**, **Nasıl deneyebilirim?** Öne çıkanlar: Başla, Maraton, Raporlar, SSS. Hesapları ayrı parolalar, iki aşamalı doğrulama ve güvenli kurtarma bilgileriyle yönetmeni öneriyorum.

### Platformların bağlantı ayrıntıları

TikTok'ta yalnız Business hesabına geçmek hemen web linki açılacağı anlamına gelmiyor. Resmi yardım sayfasında **1.000 takipçi veya Registered Business Account** koşulu var; özellik bölge/hesap uygunluğuna bağlı olabilir. Link açılana kadar sitedeki adresi videoda ve profil metninde göster. [TikTok profil bağlantıları](https://support.tiktok.com/en/getting-started/setting-up-your-profile/linking-another-social-media-account).

YouTube Shorts açıklaması ve yorumundaki URL'ler tıklanabilir değil. Çağrı **“Kanal profilindeki bağlantıdan katıl”** olsun. [YouTube bağlantı kuralları](https://support.google.com/youtube/answer/13748639?hl=en).

## 4. PomoSprint'i nasıl anlatmalı?

İlk hedef kitle önerim **Türkiye'de ders çalışan yetişkin üniversite öğrencileri**. KPSS hazırlananlar ve masa başında çalışanlar sonraki içerik denemeleri olabilir. İlk ay herkese ayrı kampanya hazırlamak yerine bir grubun dilini öğrenelim.

Ana mesaj: **“25 dakika odaklan, mola ritmini koru, ilerlemeni gör.”** Bunu gerçek ürünle gösterelim:

| Gösterilecek fayda | İçerikteki gerçek özellik |
|---|---|
| Başlamayı kolaylaştırmak | Kategori seçip 25 veya 50 dakikalık seans başlatmak |
| Çalışma planını sürdürmek | 2/3/4 seanslık Maraton; arada 5 dk mola, sonra 1 dk içinde Buradayım onayı |
| Çalışmayı görünür kılmak | Günlük, haftalık ve aylık raporlar |
| Arkadaşlarla birlikte devam etmek | Arkadaş ekleme; Odaklanıyor ve yalnız Maraton molasında Molada durumu |
| Küçük bir oyun duygusu | Gerçek kurallara bağlı puan, avatar ve ligler |

Ligler şu an başlangıç hazırlığına bağlı; 25 farklı aktif kullanıcı ve sonraki tam 14 günlük dönem şartı var. “Hemen haftalık lig kazan” gibi bir tanıtım mevcut davranışla çelişir. Plus satın alınabiliyormuş veya bir seansla kupa açılıyormuş gibi anlatmayalım.

Videolar için 15–35 saniye, dikey 9:16, okunur altyazı ve tek çağrı öneriyorum. İlk iki saniyede bir sorun, sonra gerçek ekran işlemi, sonunda katılım yolu gösterilsin. Bu süreler benim üretim önerim; platform zorunluluğu değil.

Mevcut imleçli simülatör kayıtlarını kısa kesitlere çevirebilirsin. Süreyi sıkıştırırsan **“Hızlandırılmış görüntü”** yaz; beş saniyede gerçek 25 dakika puanı kazanıldığı izlenimi oluşmasın. Özel e-posta, arkadaş kodu ve rapor verilerini paylaşmadan önce uygun örnek hesap kullan.

### İlk on video fikri

| Başlangıç cümlesi | Gösterilecek işlem |
|---|---|
| “Derse başlamak en zor kısım mı?” | 25 dk seçip Başlat |
| “Beş dakikalık molan yarım saate dönüyor mu?” | Maraton molası ve Buradayım |
| “Bugün iki, üç, dört seans: hangisi?” | Maraton popup seçimi |
| “Bugün ne kadar çalıştığını tahmin etme.” | Günlük rapor |
| “Her işe 50 dakika ayırmak zorunda değilsin.” | 25/50 seçimi |
| “Arkadaşın da şu an odaklanıyor mu?” | İzinli iki örnek hesapta sosyal ekran |
| “Seansı kapatıp geri açarsam?” | Gerçek kapat/aç davranışı |
| “Bu hafta hangi gün daha düzenliydin?” | Haftalık/aylık rapor |
| “Bu kum saatlerini neden yaptım?” | Geliştirici ve avatar hikâyesi |
| “İlk PomoSprint kullanıcılarından biri olmak ister misin?” | Ürün özeti ve gerçek beta/bekleme listesi yolu |

İlk ay 10 fikri ve iyi gelen iki fikrin yeni açılışını kullanarak **12 ana video** üretmek yeterli. Aynı videoyu üç kanala yüklemek 36 ayrı çekim gerektirmez.

## 5. İlk 30 gün ve beta planı

Takvim sosyal hesapları kurmaya karar verdiğin gün başlar. Mağaza onayı gecikirse takvimde indirme çağrısı yerine bekleme listesi kullanılır. Katılım formu ve e-posta akışı gerçek gönderimle doğrulanmadan büyük trafik yönlendirmeyelim.

| Dönem | Yapılacaklar | Beklenen çıktı |
|---|---|---|
| Gün 1–7 | Ad müsaitliği, profil ve site bağlantısı; başlangıç, mola ve beta videosu; küçük çalışma toplulukları için tanıtım taslağı | 3 video, 3 sabit gönderi, tutarlı ürün mesajı |
| Gün 8–14 | Maraton planı, rapor ve 25/50 videosu; beta hazırsa ilk 5 gönüllü; Story'de çalışma zorluğu sorusu | İlk akış sorunları ve kullanıcıların kullandığı kelimeler |
| Gün 15–21 | Arkadaşlar, kapat/aç, haftalık rapor videosu; beta dalgalarını büyüt; bir uygun içerik üreticisi için işbirliği taslağı | Nelerin geri dönüş sağladığına dair ilk işaretler |
| Gün 22–30 | Geliştirici videosu + iki iyi konunun yeni açılışı; mağaza hazırsa çağrıları güncelle; sonuç raporu çıkar | Gelecek ay için 3 somut öncelik |

Haftalık iş yükünü yaklaşık **4–6 saat** tut: toplu çekim, üç videonun düzenlenmesi, kapak/yükleme, kısa yorum/geri bildirim kontrolü ve yarım saat sonuç incelemesi. Almano Apps için ayrıca günlük içerik üretme.

İlk beta için **15–30 gönüllü** benim plan önerim; beşer kişilik dalgalar destek yükünü azaltır. Görevler: giriş/kayıt → normal seans → ertesi gün rapor → arkadaş ekleme → uygun zamanda iki seanslık Maraton. Üç soru: Nerede duraksadın? Yarın açman için sebep ne? Mevcut yöntemine göre ne kolaylaştı?

Apple üyeliği, imzalı build ve dış beta incelemesinden sonra TestFlight kullanılabilir. Davet gerçek olduğunda paylaşılır; üyelik alınmadan aktif beta varmış gibi duyurmayalım. [TestFlight](https://developer.apple.com/testflight/), [beta çalışma akışı](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/).

Yeni Google Play kişisel hesapları için üretim erişimi öncesinde **en az 12 testçinin 14 gün kesintisiz kapalı teste katılmış olması** gerekiyor; ardından başvuru değerlendirilir. Bizim simülatörlerdeki test hesaplarımız bu resmi testi karşılamaz. Android hazırlığı iOS betası sürerken paralel başlayabilir. [Google'ın güncel test şartı](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en).

## 6. Bütçe, ölçüm ve mağaza tanıtımı

**İlk ay organik başlamanı öneriyorum.** Üyelik, gerçek cihaz ve geri bildirim öncelikli. Ücretli reklamı indirilebilir sürüm, çalışan mağaza sayfası ve temel ölçüm hazır olduğunda küçük bir deney olarak düşünelim.

| Bütçe seçeneği | Benim önerdiğim harcama sınırı | Amaç |
|---|---:|---|
| İlk organik dönem | 0 TL reklam | İçerik ve gerçek kullanıcı öğrenmesi |
| İlk küçük ücretli deney | 1.000–2.000 TL toplam | Tek kanal, tek yetişkin hedef kitle, iki video |
| Sonraki deney | En fazla 5.000 TL toplam | Ölçüm işe yarıyorsa tek bir kanal veya küçük işbirliği |

Bunlar piyasa fiyatı veya indirme maliyeti tahmini değil, **önerilen üst sınırlar**. Platformun gerçek minimumu uygun değilse zorla bütçe büyütmek gerekmez. Plus henüz satışta olmadığından ilk reklam harcamasını geri kazanacağımızı varsayamayız.

Apple Ads Türkiye'de destekleniyor; uygun ülkede indirilebilir App Store uygulaması gerekiyor. Yayından sonra arama niyetine yönelik bir seçenek olabilir. İlk aşamada tek bir reklam kanalını öğrenmek yeterli. [Apple Ads bölgeleri](https://ads.apple.com/app-store/countries-and-regions), [uygulama uygunluğu](https://ads.apple.com/app-store/help/get-started/0052-solve-setup-and-access-issues).

Basit içerik tablosunda tarih, kanal, konu, izlenme, profil ziyareti, link tıklaması, katılım ve anlamlı geri bildirimi tut. Üründe ilk seans tamamlama ve 7 günlük geri dönüşe bakmak isteriz; otomatik pazarlama atfı kurulmuş gibi davranmayalım. Örnek link:

```text
https://pomosprint.app/?utm_source=instagram&utm_medium=organic_social&utm_campaign=beta_2026_10&utm_content=maraton_mola
```

UTM eklemek tek başına analitik kurmaz; mağaza üzerinden uygulama davranışını otomatik eşleştirmez. Mevcut site analitiğinin bu alanları okuyabildiği ayrıca kontrol edilmeli. [Google UTM rehberi](https://support.google.com/analytics/answer/10917952?hl=en).

İlk ayın hedefleri: 12 video, 15–30 gerçek beta katılımcısı, 10 anlamlı geri bildirim ve ilk seansı bitiremeyenlerin sebeplerini öğrenmek. Bunlar şirket hedefi önerisidir; ölçülmüş sektör ortalaması değildir. Takipçi sayısından önce tekrar kullanımı izle.

Mağaza görsellerinin sırası: **normal odak → Maraton → raporlar → arkadaşlar → avatar/lig**. TR/EN metinler gerçek özelliklere uysun. Yayın ve yeterli trafik sonrası Apple Product Page Optimization ve Google Store Listing Experiments ile bir görsel/metin değişikliğini karşılaştırabiliriz. [Apple deneyleri](https://developer.apple.com/help/app-store-connect/create-product-page-optimization-tests/run-a-test), [Google Play deneyleri](https://support.google.com/googleplay/android-developer/answer/12053285?hl=en).

SEO için mevcut Pomodoro anlatımını kullan; sonra gerçekten yararlı Maraton ve rapor rehberleri eklenebilir. Şu an siteye yeni içerik, reklam veya takip SDK'sı eklemedim. Trafik büyürken [Supabase/Resend kapasite raporundaki](QA_FREE_PLAN_CAPACITY_2026-10-08.md) hesap bazlı ölçümler de izlenmeli; reklam trafiğini ücretsiz plana sınırsızmış gibi planlamayalım.

### Müzik ve ücretli tanıtım

Temiz ana videoda kendi sesini veya sessiz ekran kaydını kullan; platforma uygun sesi sonradan ekle. TikTok/Meta müzik izninin başka platformda otomatik geçerli olduğunu varsayma. TikTok kendi ürününü tanıtırken de ticari içerik açıklaması istiyor. [TikTok açıklama ayarı](https://support.tiktok.com/en/business-and-creator/creator-and-business-accounts/promoting-a-brand-product-or-service), [ticari müzik](https://support.tiktok.com/en/business-and-creator/creator-and-business-accounts/commercial-use-of-music-on-tiktok).

Türkiye'de **1 Ağustos 2026** yürürlüklü değişiklikle menfaat karşılığı influencer paylaşımında açık **Reklam/Tanıtım** ibaresi gerekiyor. Yalnız belirsiz bir işbirliği etiketiyle yetinmeyelim. Çocukların kişisel verilerle profillenerek hedefli reklamı da yasak; ilk ücretli denemeyi yetişkin kitleyle sınırlamak önerimin bir parçası. [Ticaret Bakanlığı güncel açıklaması](https://www.ticaret.gov.tr/haberler/aldaticici-reklam-ve-haksiz-ticari-uygulamalarla-mucadelede-yeni-donem-basliyor).

## 7. Almano Apps adı ve mağazada görünen kimlik

**Almano Apps** okunur ve farklı uygulamalara uygun bir çatı adı. Görünen yazımda iki kelime, kullanıcı adında `almanoapps` kullanabilirsin. Bu isim ticari açıdan benim önerim; marka/domain/sosyal ad araştırması tamamlanmadı. Harcamadan önce [TÜRKPATENT araştırması](https://www.turkpatent.gov.tr/arastirma-yap) ve benzer isimler kontrol edilmeli. Domain veya sosyal kullanıcı adı almak marka tescili sağlamaz.

| Hesap / yapı | Görünen kimlik | Senin tercihin açısından |
|---|---|---|
| Apple bireysel | Kişisel yasal geliştirici/satıcı adı | En düşük kuruluş yükü; kişisel adı gizlemez |
| Türkiye'de şahıs işletmesiyle Apple | Apple sole proprietor için bireysel kayıt ister | Şahıs işletmesi açmak ad görünürlüğünü çözmez |
| Gerçek tüzel kişilik + Apple organizasyon | Satıcı şirket unvanı; uygun kayıtlı ticari ad geliştirici adı olabilir | Kişisel ad yerine kuruluş kimliği isteyen yol |
| Google Play kişisel | Almano Apps geliştirici adı seçilebilir; yasal ad/ülke/e-posta ayrıca açık | Marka görünür, kişisel kimlik yine gizlenmiş olmaz; monetizasyonla adres de açık |
| Google Play organizasyon | Kuruluş kimliği ve herkese açık iletişim alanları | Şirket doğrulaması gerekir; mutlak anonimlik değildir |

[Apple kayıt şartları](https://developer.apple.com/help/account/membership/program-enrollment/), [Apple geliştirici adı](https://developer.apple.com/help/app-store-connect/create-an-app-record/set-your-developer-name), [Google herkese açık bilgiler](https://support.google.com/googleplay/android-developer/answer/13628312?hl=en).

Apple organizasyon için gerçek tüzel kişilik, D‑U‑N‑S, yetkili başvurucu, kuruluş domainiyle e-posta ve çalışan kuruluş sitesi ister. Tek ortaklı limited bunun değerlendirilebilecek örneğidir; **tek ortaklı limited ile şahıs işletmesi aynı yapı değildir**. Sadece Almano Apps adı, domain veya D‑U‑N‑S numarası tüzel kişilik yaratmaz. [Apple D‑U‑N‑S açıklaması](https://developer.apple.com/support/D-U-N-S/), [Ticaret Bakanlığı şirket bilgileri](https://dabm.ticaret.gov.tr/ic-ticaret/sirketler/sirket-bilgiler).

Apple'da organizasyonun farklı görünen geliştirici adı ilk uygulama eklenirken seçilir; belgede sonradan normal düzenlemeyle değiştirilemediği belirtiliyor. İsmi bu aşamadan önce netleştirmek mantıklı. Satıcı alanındaki yasal kuruluş unvanı yine kalır. [Geliştirici adı ayarı](https://developer.apple.com/help/app-store-connect/create-an-app-record/set-your-developer-name).

### Daha sonra hesap türünü değiştirebilir miyiz?

Apple bireyselden organizasyona geçişi Support başvurusuyla değerlendiriyor; kurucu/ortak kurucu, D‑U‑N‑S ve kuruluş evrakı gerekebilir. [Apple üyelik dönüşümü](https://developer.apple.com/help/account/membership/updating-your-account-information/).

Google'ın **güncel** resmi belgesinde kişiselden organizasyona dönüşüm destekleniyor: kuruluş sitesi, organizasyon Payments profili, D‑U‑N‑S/evrak ve iletişim doğrulaması gerekiyor. Dönüşüm sonrası yeni uygulama göndermeden en az 72 saat bekleme belirtiliyor. Eski “hiç dönüştürülemez” cevaplarına göre plan yapmayalım. [Google dönüşüm akışı](https://support.google.com/googleplay/android-developer/answer/16260648?hl=en).

AB dağıtımında trader statüsüne göre adres/telefon/e-posta da gösterilebilir. Şirket markası kullanmak bütün kamusal yasal bilgileri ortadan kaldırmaz. [Apple DSA gereklilikleri](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements).

Üyelik bedelleri resmi genel fiyatla Apple **99 USD/yıl**, Google Play **25 USD tek sefer**. Daha önce gördüğün 1.029 TL Apple tutarını güncel ödeme ekranından doğrulamadım; satın alma anındaki bölgesel tutarı esas al. Aynı hesapta farklı uygulamalar için yeni kayıt açılır; her uygulama için yeniden geliştirici üyeliği alınmaz. [Apple üyelik](https://developer.apple.com/help/account/membership/program-enrollment/), [Apple uygulama kaydı](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app), [Google başlangıç](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en).

## 8. Türkiye'de şirket ve vergi seçimi

**Birkaç uygulama yayımlamak tek başına şirket kurma zorunluluğu sonucu doğurmaz; gelir elde ederken uygun vergi yolu gerekir.** Şirketi olmayan gerçek kişiler için koşulları uygunsa 20/B değerlendirilir. Vergi dairesinden istisna belgesi, Türkiye'deki uygun banka hesabı, kapsam içi tüm hasılatın o hesapta tahsili ve banka bilgisinin bir ay içinde bildirimi gerekir. Banka **%15 stopaj** yapar. GİB'in 2026 resmi infografiğinde eşik **5.300.000 TL**; uygulama başına ayrı limit değildir. Şart kaybı/eşik aşımı halinde ilgili yılın bu kazançları bütünüyle yıllık beyana girer. Kurumlar vergisi mükellefleri bu gerçek kişi istisnasından yararlanamaz. [GİB 2026 infografiği](https://cdn.gib.gov.tr/api/gibportal-file/file/getFileResources?objectKey=arsiv%2Fyardim-kaynaklar%2Finfografikler%2Fpdfs%2F2026_sosyal_ic_ureticiligi.pdf).

Elektronik uygulama paylaşım/satış platformlarından ücretli uygulama, uygulama içi satış, abonelik ve rehberdeki diğer gelirler kapsam içinde değerlendirilebilir. AdMob, doğrudan sponsor, web aboneliği gibi farklı ödeme akışlarını otomatik aynı kapsamda saymıyorum; ödeyen/aracı ve sözleşme incelenmeli. [GİB rehberi, özellikle §10–11 ve §18](https://cdn.gib.gov.tr/api/gibportal-file/file/getFileResources?objectKey=arsiv%2Fonceki-dokumanlar%2F2025_sosyal_icerik.pdf). Rehberdeki eski yıllık tutar yerine yukarıdaki 2026 infografiği kullanıldı.

| Senaryo | Değerlendirme |
|---|---|
| Kişisel adın görünmesi kabul edilebilir; düşük sabit gider öncelikli | Bireysel mağaza hesapları + gelir akışına uygunluğu doğrulanan 20/B yolu |
| Apple'da kişisel adın görünmemesi kesin öncelik | Gerçek tüzel kişilik + organizasyon hesabı; tek ortaklı limited için mali müşavirden kuruluş ve yıllık gider teklifi |
| Sadece birkaç uygulama yayımlamak istiyorsun | Ortak geliştirici hesabı/markası yeterli olabilir; sayı tek başına limited kurma sebebi değil |
| İleride ortak/ekip, başka ticari hizmetler veya farklı tahsilatlar olacak | Şirket yapısı, sözleşmeler ve gelirlerin birlikte değerlendirilmesi |

Limitedin geliri için kişisel 20/B'yi kullanamayız. Muhasebe, beyan, sicil ve olası SGK yüklerini güncel teklif ile karşılaştır; bu rapor uydurma bir aylık şirket maliyeti vermiyor. Mağaza hizmet komisyonu ile %15 banka stopajı ayrı kalemlerdir.

Mali müşavire götürülecek kısa soru listesi: Mevcut bordrolu işim varken bu faaliyet için SGK sonucu nedir? Store payout/IAP/abonelik akışım 20/B'ye uygun mu? Reklam ve web gelirleri hangi kapsamda? Limitedin kuruluş ve toplam yıllık gideri ne? Gelirler hangi hesapta, hangi belgelerle tutulmalı?

İş yerinin emlak alanında olması tek başına izin/hak sahipliği garantisi değil; sen yazılım geliştiriyorsun ve sözleşme şartlarını bilmiyoruz. Yan iş, fikri haklar, gizlilik ve rekabet maddelerini incele. Kişisel cihaz/zaman/hesaplarla, işveren kodu/verisi olmadan geliştirme ayrımını koru; gerekiyorsa yazılı netleştir. Şirket kurmak bu sözleşme konusunu çözmez. [TBK §396 resmi metin](https://mgm.adalet.gov.tr/Resimler/SayfaDokuman/181020191500286098.pdf), [FSEK §18 resmi metin](https://agri.ktb.gov.tr/Eklenti/135532%2C5846-sayili-fikir-ve-sanat-eserleri-kanunupdf.pdf?0=).

## 9. İkinci ve sonraki uygulamaları nasıl yönetelim?

Her ürünün ayrı adı, bundle/package kimliği, mağaza kaydı, kullanıcı/veri sınırı ve destek açıklaması olsun. Almano Apps portföyünde hepsi listelenebilir. Dil, tema, bildirim, hata takibi gibi öğrendiklerini tekrar kullanmak mantıklı; PomoSprint'in kullanıcı ve seans verilerini diğer ürünle kendiliğinden birleştirmeyelim. Teknik ortaklık gerektiğinde ayrı karar verilir.

İkinci ürünün büyük geliştirmesine geçmeden PomoSprint'in ilk gerçek beta geri bildirimini almanı öneriyorum. Kendi ölçülebilir karar koşullarını koy: kritik yayın engelleri kapandı mı, ilk kullanıcılar seans bitirebiliyor mu, destek yükü yönetilebilir mi, bir hafta sonra geri geliyorlar mı? Böylece aynı belirsizlikleri iki ürüne taşımayız.

Bugünkü uygulanabilir sıra:

1. Kişisel mağaza adı mı, kuruluş adı mı istediğini netleştir; gizlilik kesin öncelikse Apple üyeliğini organizasyon yolu için planla.
2. Almano Apps ve PomoSprint aday adlarının marka/domain/sosyal müsaitliğini kontrol et.
3. Gerekirse mali müşavirle 20/B ve limitedi karşılaştır; iş sözleşmesini incele.
4. Doğru hesapla Apple üyeliği, imzalama ve gerçek cihaz/TestFlight betasını tamamla.
5. PomoSprint sosyal hesaplarında haftada üç içerikle başla; çağrı gerçek yayın aşamasına uysun.
6. Android'in gerçek cihaz doğrulaması/kapalı testini paralel planla.
7. İlk ay sonuçlarını gördükten sonra reklam, Plus/RevenueCat ve ikinci uygulama sırasını belirle.

## 10. Bu çalışma sırasında kaydedilenler

Güncel uygulama derlendi ve canlıya bağlı normal sürüm simülatörde açık bırakıldı. Bu rapor, geliştirici/şirket kaynak notları (ham çıktı §37 temizliğinde kaldırıldı) ve ayrıntılı pazarlama takvimi (ham çıktı §37 temizliğinde kaldırıldı) yerel proje klasöründe kaydedildi. Devir belgeleri güncellendi.

Bağımsız son inceleme (ham çıktı §37 temizliğinde kaldırıldı), resmi kaynakları, dosya bağlantılarını ve derleme/önceki QA kapsamı ayrımını kontrol etti; önemli ek hata bulunmadı.

Uygulamaya yeni özellik, siteye değişiklik veya canlı veritabanına yazım yapılmadı. Sosyal hesap, şirket, marka/domain kaydı, reklam, dış kişilere mesaj, mağaza yayını veya GitHub push yapılmadı. Bu dosya karar verip uygulayabileceğin planı içeriyor; hesabın doğrulanmış üyelik türü, marka müsaitliği ve kişisel hukuki/vergi sonuçları tamamlanmış kabul edilmedi.
