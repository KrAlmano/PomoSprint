# Site yayın raporu — 28 Ekim 2026

Kullanıcının “canlı site eski, Deneme ekranları yok; tüm siteyi güncelle” isteğiyle **pomosprint.app yayımlandı**. Önceki çalışma GitHub yedeğiydi; bu tur mevcut Cloudflare Worker’ına gerçek dağıtım yapıldı. Mobil uygulama veya Supabase dağıtımı yapılmadı.

## Yayındaki içerik

- Ana sayfa: güncel beş sekmeli uygulama görüntüleri, Maraton ve ayrı Deneme tanıtımı.
- Özellikler: TYT/AYT/YDT, LGS Sözel/Sayısal, TUS Temel/Klinik ve DUS; Denemelerim, doğru/yanlış/otomatik boş, başlık/not, AYT erken bitişi, süre–net içgörüleri ve kategori/global ligler.
- TR/EN: 30 güncel uygulama ekranı, 4 sessiz döngü video ve 4 poster. Tüm medya gerçek yerel örnek hesaplardan; gerçek kullanıcı veya kullanım sayısı iddiası yok.
- Destek, hesap silme ve Pomodoro rehberindeki eski Apple giriş, İngilizce bağlantı, mağaza yayımlanma ve ikinci duraklatma cümleleri düzeltildi.
- Gizlilik/KVKK veri listeleri, yeni hedefleri ve özel Deneme verilerini açıklar. Mevcut hukuki sebepler, kayıt onay sürümü ve kullanıcıdan beklenen kimlik/adres bilgileri değiştirilmedi; bu bir hukuk onayı değildir.
- İngilizce arama/sosyal metadata güncellendi. Ana/Özellikler/SSS ve mevcut sayfa düzeni korundu.

## Dağıtım

- Kaynak commit: `1a58014`.
- Worker: `pomosprint-website`.
- Önceki sürüm: `840fd4f1-0779-493a-ad5b-e41fcd27a3c3` (8 Ekim).
- Yeni sürüm: **`e1bb6541-5794-4241-ab5e-66ded59a9298`**, yüzde 100 trafik.
- Cloudflare zamanı: 28 Ekim 2026 21:19:31 İstanbul.
- 86 yeni/değişmiş statik varlık yüklendi; `--keep-vars` kullanıldı. Mevcut ASSETS bağlaması ve alan adları korundu.
- Önce `wrangler deploy --dry-run --keep-vars` başarılı oldu. Son dağıtım `deployments list` üzerinden ayrıca doğrulandı.
- [Dağıtım kaydı](site_yayin_2026-10-28/deployment.json).

## Doğrulama

- Node: **172/172**, ortak HTML parça kontrolü temiz.
- Canlı GET: **156/156** kontrol. 20 HTML sayfası ve 111 statik kaynak; mevcut HTML içeriği, yeni Deneme metinleri, tüm dosyaların hashleri, güvenlik başlıkları, özel yolların 404 olması, http/www yönlendirmeleri ve dört videonun 206/416 byte-range cevapları.
- HTML’de Cloudflare’ın mevcut Web Analytics scripti ve tek satır sonu ekleniyor. İlk ham karşılaştırmanın 20 farkı saklandı; yalnız bu gözlenen ek çıkarılınca 20 sayfa da kaynakla birebir eşleşti. 111 statik dosyada ham hash doğrudan eşleşti. Başka bir içerik farkı gizlenmedi.
- [Canlı HTTP sonuçları](site_yayin_2026-10-28/live_http.json), [ham farklar](site_yayin_2026-10-28/live_http_raw_comparison.json), [Node günlüğü](site_yayin_2026-10-28/node-tests.log).

## Canlı Safari kontrolü

- TR/EN Ana Sayfa, Özellikler ve SSS × 375/1024/1440 px: **18/18 görsel kontrol**.
- Dört videoda gerçek oynama ve duraklat/devam etiketleri gözlendi. Mobil menü, Escape, dil geçişi, Özellikler bağlantısı ve SSS tek açık cevap davranışı çalışıyor.
- Deneme/DUS kataloğu, net ekranları ve telefon çerçeveleri güncel; gözlenen karelerde taşma/kırpılma yok.
- Aylık sıralama, yeni RPC canlı sunucuda henüz yokken beklenen “hazırlanıyor” açıklamasını gösteriyor; sahte puan veya sürekli yükleme yok.
- [Gözlem kaydı](site_yayin_2026-10-28/safari/README.md) ve 3 gerçek Safari JPEG'i saklandı. Kesin ilk-paint, konsol temizliği, Chrome ve fiziksel cihaz iddiası yok.

## Kapsam sınırı

Site, yayın hazırlığındaki uygulamayı tanıtır. Yeni sunucu paketleri ve 31 bu işlemde kurulmadı. Uygulamanın mağaza yayını, gerçek cihaz denemesi, yasal kimlik/gönderen bilgileri ve daha önce belgelenmiş operasyon işleri ayrıca kalır. Gerçek e-posta/form gönderimi veya kullanıcı hesabı değişikliği yapılmadı. Git yalnız `codex/gece-2026-10-27` dalındadır; main/merge/force yok.
