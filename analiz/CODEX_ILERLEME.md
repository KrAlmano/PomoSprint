# Codex ilerleme kaydı

Tarih: **27 Ekim 2026**

Çalışma dalı: **`codex/gece-2026-10-27`**

Başlangıç commit’i: **`5f99f90f8e1837f0b6ea7b12752bf7d7eed2434f`**

## Başlangıç durumu

Bu kayıt, gece çalışmasından önce birikmiş commitlenmemiş değişikliklerin başlangıç noktasıdır. Dal `main` üzerindeki `5f99f90` commit’inden açıldı; bu belge yazılmadan önce **574 dosya yolu** değişikliği vardı. Sayı yeni/değişen dosyalarla silinenleri birlikte kapsar. Bu dosyalar tek gecede yazılmış yeni bir geliştirme değildir; önceki oturumların çalışmaları ve temizlikleri birlikte kaydediliyor.

### Uygulama (`lib/`)

- **Maraton:** 2/3/4 seans planlama penceresi, animasyonlu ilerleme kartı, yalnız molada gösterilen fincan, 5 dakika mola ve ardından 60 saniye içinde “Buradayım” onayı eklendi. `marathon_progress`, `marathon_presence`, plan/ilerleme/mola widget’ları yeni; sayaç ve kalıcı durum kodu bunlara bağlandı. Ana ekran ve yatay görünüm sadeleştirildi; yatayda duraklatma hakkı ve uygun kontroller korunuyor.
- **Seans ve hesap güvenliği:** `main_shell`, `supabase_service`, `session_queue` ve `timer_persistence` içinde Maraton bilgisi, onay makbuzu, çevrimdışı gönderim, idempotency ve hesap değişiminde eski yanıtı engelleyen owner/epoch kontrolleri genişletildi.
- **Normal süre ve QA temizliği:** Normal derlemeler 25/50 dakika kullanıyor. Eski QUICK/SAVE başlatma ve kısa kayıt yolları, `local_test_mode.dart`, `lib/dev/` girişleri ve kullanılmayan `text_util.dart` kaldırıldı. Eski hızlandırılmış kalıcı kayıtlar normal seans olarak gönderilmiyor; açıkça seçilen kısa widget simülasyonu testlerde kalıyor.
- **Sosyal ve lig:** Tek Odaklanıyor/Molada listesi, kırmızı/yeşil animasyonlu durum noktası ve 30 saniyelik yenileme var. Yeni `league_backend.dart` ile v2/legacy uyumu; 25 kişilik oda, hazırlık/14 günlük dönem, uygunluk ve çevrimdışı güvenli varsayılanlar eklendi. Gereksiz kişisel sıra/terfi bandı kaldırıldı, lig adları düzeltildi.
- **Avatarlar:** Ayrı Özel Avatarlar bölümü, 21 adet 500 kumluk avatar, kayıtta yalnız ücretsiz temel avatarlar; Ronin kaldırma/eski kayıt için güvenli yedek görsel. Koleksiyonda görsel/ad/fiyat hizası ve hesap değişimi sırasında satın alma/kuşanma güvenliği düzeltildi.
- **Onboarding, dil, reset ve bildirim:** Yedi adımlı onboarding’e ekran rehberi ve taslak/seçim kontrolleri eklendi. TR/EN ARB ve üretilen çeviriler güncellendi. Yerel test posta kutusu ile gerçek şifre sıfırlama ayrımı açıklanıyor. Maraton mola bildirimi, bildirim işlemlerinin sıralanması ve exact/inexact alarm yedeği güncellendi.

### Testler (`test/`, `integration_test/`)

- Maraton planı/ilerleme/onay/mola/bildirim/kuyruk, TR/EN ve yatay düzen; lig başlangıcı/çevrimdışı varsayılanlar; sosyal mola, özel avatar, onboarding rehberi, aylık çalışma günü ve eski hızlandırılmış kayıt regresyonları eklendi.
- Mevcut hesap/seans, backend config, erişilebilirlik, responsive düzen ve sunucu uyumluluk testleri genişletildi.
- Native kayıt/onboarding/seans/arkadaş/ayar/bildirim senaryoları güncellendi; görünür sayaç dokunma senaryosu ve Maraton bildirim yardımcısı eklendi. Eski hızlı/tek seferlik testler kaldırıldı. `g/i/m` senaryoları normal süreli bağımsız akışa çevrildi; simülatör temizliğinden sonra yeniden native çalıştırılmadı.
- Son tam Flutter sonucu **9 Ekim: 1291 PASS, 5 isteğe bağlı ekran görüntüsü testi atlandı**, analiz temiz. Aynı gün Android release ve iOS imzasız release derlendi. Bunlar bu checkpoint sırasında yeniden çalıştırılmış testler değildir. **27 Ekim: 133/133 Node testi** ve ayrı canlı servis/site kontrolleri geçti; mobil uçtan uca test yapılmadı.

### Site (`landing/`)

- Ana sayfa ve Özellikler’e gerçek uygulama ekranları, Maraton anlatımı, dönüşümlü görsel/metin düzeni; ekran görüntüleri, imleçli Pomo/Maraton videoları ve posterleri eklendi.
- Telefon çerçevesi oranı ve boşlukları düzeltildi. Videolar görünürken sessiz döngüde oynuyor; duraklatma, hareket azaltma ve hata halinde poster davranışları korunuyor.
- Özellikler’de kaybolan içerik/başlık sorunu giderildi; beş kupalı lig avatarı bırakıldı, dekoratif noktalar ve yinelenen SSS sorusu kaldırıldı. Lig metinleri ve TR/EN destek bağlantıları güncellendi.
- Worker’a sınırlı video Range/If-Range desteği eklendi; cache/güvenlik başlıkları, ortak HTML parçaları ve sitemap güncellendi. Reset sayfası geçici sunucu/429/bozuk yanıtı süresi dolmuş bağlantı gibi işlemiyor.
- `scripts/test/` altında auth sayfası testleri genişletildi; özellik görünürlüğü, medya ve Worker Range testleri eklendi. Bu farkta bülten/Edge Function kaynaklarına yeni gönderim özelliği eklenmedi.

### Sunucu (`supabase/`)

- Maraton mola görünürlüğü, ek ödül ve zorunlu devam onayı için üç migration ile rollback/DRYRUN/rehberler eklendi. Devir kayıtlarına göre **8 Ekim’de canlıya uygulandı**: 300 saniye mola, 60 saniye onay; 25 dakikalık 2/3/4 seansa +2/+3/+5, 50 dakikalığa +4/+6/+10 bonus.
- Lig başlangıcı paketi: 25 kişilik mevcut uygun odaya ilk puanlı seansla yerleşme, aktif kullanıcı eşiği ve 14 günlük dönem, terfi/ödül/düşme şartları. **8 Ekim’de canlıya uygulandı.**
- Özel avatar kataloğu ve sahipsiz Ronin’in güvenli kaldırılması için ileri/geri/DRYRUN paketleri eklendi. **9 Ekim’de kullanıcı SQL Editor ile uyguladı**; katalog 48 toplam/47 aktif/21 özel/7 aktif ücretsiz.
- Önceden repoda bulunan `report_submission_lock` paketinin uygulama durumu ve rehberi güncellendi; bu farkta fonksiyon gövdesi yeniden değiştirilmedi. Kilit **8 Ekim’de canlıya uygulanmıştı**.
- Sunucu/mailing rehberleri ve yerel şema parite referansları güncellendi. **27 Ekim işi salt okuma kontrolüdür:** veritabanı, Auth, cron, Resend ve Cloudflare incelendi; canlı veri/ayar veya migration değiştirilmedi.

### Dokümanlar ve diğerleri

- `AGENTS.md`, `README.md`, `PROJECT_CONTEXT.md` ve `PROJE_DEVIR.md` ürün, kurulum, canlı SQL durumu, çalışma geçmişi ve son servis kontrolüne göre güncellendi. `analiz/` altında Maraton/lig/site/avatar/temizlik/operasyon/kapasite/pazarlama raporları eklendi; eski raporların silinen ham kanıt bağlantıları düzeltildi.
- Eski ham QA JSON/log/fixture ve ekran görüntülerinin silinmesi de bu checkpoint’in parçası. İnsan tarafından okunabilir raporlar ve anlamlı test kaynakları korunuyor.
- `assets/avatars/` altında 21 özel PNG ve katalog manifesti eklendi. Kullanılmayan eski lig tasarım kaynakları repo dışındaki tasarım arşivine taşındı. Orijinal kaynaklar korunmuştu; Ronin ürün kataloğunda yok.
- Kullanılmayan macOS/Linux/Windows/web uygulama şablonları ve `.metadata` kayıtları kaldırıldı; mobil ürün Android/iOS, site `landing/` altında.
- VS Code başlatma profilleri yalnız normal/profile/release `lib/main.dart`; terminal Xcode yolu hizalandı. `.gitignore` yerel QA runtime, ham çıktı ve Python cache’lerini dışlıyor.
- `pubspec.yaml` şablon yorumları temizlendi. Zaten kullanılan `shared_preferences_platform_interface`, testte disk davranışını denetlemek için doğrudan dev dependency olarak tanımlandı; lock dosyasında sınıflandırması güncellendi.
- Yerel Supabase rehberi ve native çalıştırıcılar güncellendi; hazır test hesabı envanteri, hızlı kayıt/tek seferlik araçlar ve geçici CLI dosyası kaldırıldı. Bağımsız lig kontrolü ve Sentry audit kaynağı korunuyor. Silinen simülatörler, Docker test verileri ve gitignore altındaki derleme dosyaları Git commit’inin içinde taşınan veriler değildir.

### Çalışmaların kime ait olduğu

Bu konuşmanın 9–10 Ekim bölümünde Ronin kaldırma/hizalama, eski QA yollarının ve dosyalarının temizliği, ilgili test/doğrulama ve doküman güncellemelerini ben ve alt ajanlarım yaptık. 27 Ekim’deki son işimiz canlı servislerin salt okuma kontrolü ve raporlanmasıdır; bu checkpoint hazırlığı dal, envanter, bu belge ve commit ile sınırlıdır.

Önceki Maraton, lig ve site çalışmalarının geçmiş Codex/ajan oturumlarına ait olduğu devir raporlarında kayıtlıdır. Henüz commitlenmemiş ortak çalışma ağacı nedeniyle, her satırı belirli bir yazara yalnız Git üzerinden kesin atfetmiyorum.

## Yarım kalanlar

- **Operasyonel güvenlik:** Sentry’nin iç içe breadcrumb/request verisi maskelemesi ve HTTP500 otomatik yakalama eksikleri; canlı alarm/sembol çözümleme doğrulaması; doğrudan bekleme listesi POST’unda sunucu onay/limiter; `register_session_start` kota yarışı; gerçek Maraton kill switch ve hosted staging ayrımı. Önceki§33 bulguları kapanmış sayılmıyor.
- **Apple ve mağaza:** Apple Auth kapalı; gerçek Google/Apple/fiziksel cihaz doğrulaması, uygun Apple imzalama/provisioning, IPA/TestFlight/mağaza işleri ve beyanlar tamamlanmış değil. Son cihaz temizliğinden sonra hazır simülatör yok.
- **E-posta ve kimlik:** Welcome için `MAIL_SENDER_NAME`/`MAIL_SENDER_ADDRESS`, geliştirici/veri sorumlusu ve resmî adres kullanıcıdan son aşamada bekleniyor. İlgili yasal yer tutucular duruyor. Kaynaktaki welcome/unsubscribe düzeltmeleri canlıya tamamen taşınmış kabul edilmemeli; 27 Ekim’de yeni mail/reset teslimi denenmedi.
- **Hesap silme:** `delete-account` Edge Function dağıtılmamış. Mevcut RPC yedeği var; Apple token iptalinin tamamlandığı iddia edilmiyor.
- **Site içeriği:** 21 adet 500 kumluk özel avatar kategorisi site anlatımına henüz eklenmedi.
- **SQL tarihçesi:** Bazı uygulanmış paketlerin başındaki eski “NOT APPLIED/pending” yorumları hazırlık döneminden kalıyor. Güncel durum sunucu rehberi ve devir§26/35/37/38’de; bu yorumlara bakarak migration’ları tekrar çalıştırma. Kök migration klasörü canlı geçmişle birebir baseline değildir; kör `db push/reset` yapılmamalı.
- **Bu kaydın kapsamı:** Checkpoint almak eksikleri düzeltmek veya bütün testleri yeniden koşmak değildir. Gece geliştirmeleri bu başlangıçtan sonra ayrı değişiklikler olarak yapılmalı.

## Commit kapsamı ve sır denetimi

Kullanıcı talebiyle tek commit mesajı: **`chore: gece öncesi başlangıç noktası`**. Commit bu çalışma dalına alınacak; `main` üzerine commit veya push yapılmayacak.

`.env`, `scripts/.env`, anahtar/sertifika/keystore dosyaları ve `.claude/settings.local.json` staging’e alınmayacak. Yerel ortam dosyalarının içerikleri bu belgeye yazılmadı. Ignore altındaki özel runtime/ham kanıtlar zorla eklenmeyecek. Commit öncesi `git diff --cached --name-only` ile dosya listesi ve staging’deki gerçek dosya içerikleri iki ayrı taramayla kontrol edildi: yasak dosya ve gerçek ayrıcalıklı sır bulunmadı. Kamuya açık yerel demo anon anahtarları ve açıkça sentetik test değerleri gerçek üretim sırrı sayılmıyor.

Staging özeti: **575 dosya yolu; 105 değişiklik, 119 ekleme, 351 silme**. `git diff --cached --check`, önceden var olan üç Maraton SQL dosyasında ve pazarlama raporunda satır sonu boşlukları bildiriyor. SQL gövdelerinin kayıtlı parmak izini değiştirmemek ve bu checkpoint’i mevcut durumun kaydı olarak tutmak için bunlar normalleştirilmedi; bulgu işlevsel test sonucu değildir. Bu commit hazırlığında uygulama testleri yeniden çalıştırılmadı.


## Gece çalışması — 27/28 Ekim 2026

### Varsayımlar

- İş yalnız `codex/gece-2026-10-27` dalında ve yerel servis/QA hesaplarıyla yapılır; canlı okuma/yazma, deploy ve push yapılmaz. `.env` içerikleri okunmaz.
- Deneme yeni bir sekmedir; normal 25/50 ve Maraton akışı yerinde kalır. Eski sunucu deneme capability'si sunmuyorsa katalog incelenebilir, ödüllü deneme başlayamaz.
- TUS için 11 ders önerisi gösterilir; mevcut ücretsiz 8 aktif kategori sınırı korunur. KPSS ve dil hedefleri de ayrı lig kategorilerini temsil eder. Yaş/veli izni kuralları değiştirilmez.
- Vazgeçilen deneme tarihçe/durum olarak saklanır; tamamlanan deneme sayısına, toplam çalışma süresine, seri, puan ve kuma katılmaz. Tamamlanan deneme tek kez çalışma süresine ve sunucuda 04:00 çalışma gününe katılır.
- Deneme ödülü katalogdan belirlenir: tam süreli her 5 dakika için 1 deneme puanı, her 25 dakika için 1 deneme kumu (tam sayı). Normal cüzdan/puanla birleşmez; oran daha sonra yalnız sunucu kataloğundan değişebilir.
- Netler yalnız kullanıcı beyanı/kişisel rapordur; resmî sınav yerleştirme puanı değildir ve ekonomiyi değiştirmez. Resmî standart oturum süreleri uygulanır; kişiye özel ek süre hakkı uydurulmaz.
- Az nüfuslu hedef liginde güvenli hazırlık/ödül yeterlilik politikası sunucu tarafından uygulanır; kategori karışımıyla oda doldurulmaz. Ay ortasında hedef değiştirmek o ayın lig kategorisini değiştirmez.
- Yeni deneme ligi görselleri gelene kadar güvenli mevcut/generik yer tutucu kullanılır; eksik varlık yayınlanmaz ve hayalî kazanılmış avatar gösterilmez.
- Native gerçek süre testleri ile kontrollü eski başlangıç/tarih fixture testleri ayrı raporlanır. Yeni hızlı üretim modu eklenmez.

### İlerleme

- **22:27 — kapsam kaydı, commit `7bcbb4a`:** `analiz/ISTEKLER.md` I-01…I-20, kabul ölçütleri ve gece sınırları eklendi. Öncesinde `flutter analyze` temiz; `flutter test --reporter expanded`: **1261 geçti, 5 atlandı, 0 hata** (49 sn). İlk stage listesi yalnız istek dosyası; sır ve denetçi dosyası yok. Başlangıç checkpoint'i `036fa60` değişmedi.
- Alt ajan sahiplikleri: backend proposed paketleri/yerel SQL; yeni Deneme model-servis-ekran-testleri; site ve resmî sınav kaynakları. Kök ajan ortak onboarding/dil/shell/sosyal/rapor entegrasyonları, native ortam ve commit kontrollerini yürütür. `DENETIM.md` başlangıç okumasında D-xx bulgusu yok.
