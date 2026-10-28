# pomosprint.app — TR/EN site

Bu klasör PomoSprint'in statik pazarlama, destek, yasal ve Auth yardımcı sayfaları ile önündeki küçük Worker'ı içerir. Uygulama `../lib/`, sunucu kaynakları `../supabase/` altındadır. Ana geliştirme dalı [`codex/gece-2026-10-27`](https://github.com/KrAlmano/PomoSprint/tree/codex/gece-2026-10-27); repo özeldir. Son yetki yalnız bu dala normal Git push içindir. `main` merge/push, force push ve canlı site/Supabase deploy yoktur.

## Durum ve doğruluk

28 Ekim B çalışmasının HTML/CSS, son Deneme arayüzünden alınan 30 ekran ve 4 videosu bu dalda hazırdır. Safari 72/72 ve dört videonun manuel kontrolü geçti; Chrome ortam engeli nedeniyle doğrulanamadı. Güncel site ve medya için gerçek sonuçlar [nihai doğrulama raporunda](../analiz/DOGRULAMA_RAPORU_2026-10-28.md), ilerleme [CODEX_ILERLEME](../analiz/CODEX_ILERLEME.md), kaynak/çıktı görseller [ekran listesinde](screenshots/README.md) tutulur. Eski 8/27 Ekim dosya ve tarayıcı sayıları yeni B paketinin kanıtı olarak taşınmaz.

Yeni ürün içeriğinin yayın sırası: incelenmiş 27 TUS/DUS → 28 Deneme → 29 aylık lig sunucu paketleri, ardından yeni uygulama, ardından site. Bağımsız 30 başlangıç kotası ayrı değerlendirilir. **31 kullanıcı kararı bekliyor; bu doğrulama ortamına kurulmaz.** Yeni SQL'in canlıya uygulanmadığı durumda web metnini güncellemek uygulamadaki özelliği canlıya açmaz.

29 için tarih uyarısı: resmî aylık yarış kurulum ayından sonraki ayın 1'inde 00:00 Europe/Istanbul'da etkinleşir. 31 Ekim 23:59'dan önce kurulum 1 Kasım; 1 Kasım veya sonrası kurulum 1 Aralık aktivasyonu demektir. Günlük rapor/seri sınırı profil saat diliminde 04:00 olarak kalır.

## Sayfalar ve içerik

| TR | EN | İşlev |
|---|---|---|
| `/` | `/en/` | Kısa ürün tanıtımı, üç önizleme, Maraton ve ayrı Deneme alanı, gerçek sıralama durumu, bekleme listesi |
| `/features` | `/en/features` | Tüm özellikleri ilgili gerçek ekranlarla açıklayan dönüşümlü satırlar |
| `/faq` | `/en/faq` | Görünür 14 soru/cevap ve bunlarla eşit FAQPage JSON-LD |
| `/destek` | `/en/support` | Destek, sorun giderme, hesap/veri başvuruları |
| `/privacy` | `/en/privacy` | Gizlilik politikası |
| `/terms` | `/en/terms` | Kullanım şartları |
| `/kvkk` | `/en/kvkk` | KVKK aydınlatma |
| `/hesap-silme` | `/en/delete-account` | Mağazaların hesap silme bağlantısı |

Ana sayfaya bütün özellikler yığılmaz; ayrıntılı katalog, net, içgörü, rapor ve lig ekranları Özellikler'de kalır. İki dilde bölüm ve konu eşliği korunur. TUS ve DUS hedef kitle ve sınav listesinde bulunur. Aylık kategori/global ligler, ayrı normal/Deneme ekonomisi ve İstanbul 00:00 sınırı açıkça anlatılır.

Net girişi metni güncel A2 davranışına uyar: doğru/yanlışa göre otomatik fakat elle düzenlenebilir boş sayısı; yalnız girilen derslerin kaydı; sonradan düzenleme; negatif/taşan giriş engeli. Netler puan/kum/lig değiştirmez. Tamamlanan Deneme ortak çalışma süresine katılır, ayrı satırdır; vazgeçilen Deneme ödül, çalışma süresi veya tamamlama sayısı üretmez. İçgörüler ilişkili süre ve net değişimini gösterir, nedensellik veya puan artışı vaat etmez.

Uydurma kullanıcı sayısı, yorum, çıkış tarihi, mağaza rozeti veya sahte dolu sıralama eklenmez. Yeni aylık RPC yoksa hazırlık, gerçek boş sonuçta boş durum, ağ/bozuk yanıtta açıklayıcı hata gösterilir. Eski profil-saatdilimi 04:00 sıralamasına fallback yapılmaz.

## Yerel geliştirme

Önce kök [README](../README.md) ile özel dalı klonla ve bağımlılıkları kur:

```sh
npm --prefix scripts ci
python3 landing/tools/sync_partials.py --check
npm --prefix scripts test
```

Node testleri yerel kaynak/fake DOM/Worker mock'larıdır; gerçek tarayıcı, canlı site veya kişisel posta teslim kanıtı değildir. Mobil build/test de çalıştırılacaksa kök README'deki eksikse boş `.env` asset oluşturma adımı önce uygulanır; `scripts/.env` mobil yapılandırma yerine kullanılmaz ve mevcut ortam dosyası okunmaz/ezilmez. Tarayıcı önizlemesi için production `js/config.js` ayarını açık bırakıp yalnız bir HTTP sunucusu açmak yeterli izolasyon sağlamaz: leaderboard/form/Auth JS'i canlı endpoint'e gidebilir. QA önizlemesinin dış ağ istekleri engellenmeli veya localhost'a yönlendirilmelidir; gerçek siteye mail/form/hesap işlemi yapılmaz. `.env` okunmaz/kopyalanmaz.

İç yollar uzantısızdır. Düz `python -m http.server` `/features` gibi Worker rotalarını tek başına taklit etmez; Worker semantiğini kullanan izole yerel önizlemeyle bağlantılar ve Range birlikte kontrol edilir. Bu turdaki izole önizleme, komut/port ve dış ağ engeli son raporda kayıtlıdır; yeniden çalıştırma komutu aşağıdadır.

Tarayıcı tercihi Safari'dir; sistem varsayılanı değiştirilmez. Kişisel Chrome sekmeleri okunmaz/değiştirilmez. Son kullanıcı talimatı iki tarayıcı kontrolüne ayrıca izin veriyorsa yalnız ayrılmış QA yüzeyi kullanılır ve yöntem raporlanır; Safari yeteneği yoksa başka tarayıcıya sessizce geçilmez.

## Ortak parçalar ve stil

Menü, footer ve ortak head/script satırları `_partials/` altındadır. İngilizce karşılıklar `*.en.html`; aktif menü `<body data-page="…">` ile seçilir.

```sh
python3 landing/tools/sync_partials.py
python3 landing/tools/sync_partials.py --check
```

CSS/JS değişiminde cache sürümü ortak parçalarda ve Auth yardımcı sayfalarında birlikte güncellenir. Güncel CSS sürümü `20261028b`; ortak parça eşliği kontrol edildi. `_headers` CSP'si korunur; inline JS/style eklenmez, JSON-LD veri blokları istisnadır. Fontlar ve GSAP kendi alan adından sunulur; dış CDN geri eklenmez. `_partials/`, `tools/` ve Markdown dokümanlar `.assetsignore` ile yayın dışında kalır.

Mevcut `.phone`/`.phone-screen` kullanılır. Aspect ratio ekran kutusunda 540/1170'dir; padding'li dış telefona sabit yükseklik veya oran verilmez. `object-fit: contain` ile ekran kırpılmaz. Eşli ekran grupları 960px altında metnin altına, 420px altında tek telefona iner. Küçük yazı/taşma ve dikey akış yine gerçek 375/1024/1440 tarayıcı görünümüyle değerlendirilir.

## Yeni native medya sözleşmesi

B çekimi tek iPhone 16 / iOS 18.6 simülatörü, aynı kurgusal yerel Deniz hesabı ve aynı veri kümesiyle tamamlandı. TR sayfalar TR, EN sayfalar EN uygulama ekranı kullanır. Durum çubuğu çekim sırasında 09:41, dolu pil, Wi-Fi 3 ve hücresel 4 olarak override edilir; çekim sonunda kaldırılır. Hesap yalnız yerel QA'dır; pazarlama referansı veya gerçek kullanıcı topluluğu değildir.

Web çıktıları `screenshots/20261028/<scene>-{tr,en}.png`, her biri **540×1170**. Ham native PNG'ler `analiz/` altında saklanır; gerçek ölçüleri PNG başlığından okunur. Yeniden boyutlandırma gerçeği gizlenmez: ham kaynak ve türetilmiş web çıktı dosyaları ayrı SHA-256, ölçü ve dosya yolu ile manifestte bulunur. İki farklı eski çözünürlük/set karıştırılmaz. Filtrelenmiş veya çizilmiş uygulama ekranı kullanılmaz.

15 sahne × 2 dil = 30 PNG:

| Grup | Sahne dosya kökü |
|---|---|
| Odak | `timer`, `marathon-plan` |
| Deneme | `exam-catalog`, `exam-running`, `exam-history`, `exam-results`, `exam-insights` |
| Raporlar | `reports-daily`, `reports-weekly`, `reports-monthly` |
| Ligler | `league-category`, `league-global`, `league-exam` |
| Sosyal/koleksiyon | `social`, `avatar-collection` |

Sayaç ve Maraton videoları iki dilde `videos/20261028/{timer,marathon}-{tr,en}.mp4`; aynı köklü WebP posterlerle toplam 4 MP4 + 4 poster. Gerçek zaman korunur, hızlandırma yoktur. Küçük dokunma/imleç açıklaması varsa yalnız gerçek native tap koordinatları/zamanlarından üretilir; işletim sisteminin kaydettiği imleçmiş gibi sunulmaz. Sessiz H.264/yuv420p ve web uyumlu boyut/PTS gerçek encoder kanıtıyla doğrulanır. Kullanılan gerçek süre, kaynak/çıktı hash'leri ve transform manifestte tutulur.

Deneme videosu opsiyoneldir. Gerçek çekim/encode doğrulanana kadar HTML'de olmayan MP4/poster yoluna bağlanılmaz; `exam-running` PNG tam fallback'tir. İki dilde gerçek Deneme videoları eklenirse dosya envanteri, HTML, manifest ve test beklenen listesi birlikte açıkça genişletilir; eksik dosyayı atlayan test eklenmez.

Her video `data-demo-video`, lazy `data-src`, `autoplay muted loop playsinline preload="none"` ve gerçek screenshot fallback kullanır. Yerleşik kontroller yoktur. `main.js` yalnız görünürken oynatır; arka planda durur, reduced-motion'da gerçek görüntü gösterir, tıklama/Space/Enter ile kullanıcı duraklatır ve erişilebilir play/pause etiketi güncellenir. Autoplay reddi/yükleme hatası sayfayı boş bırakmaz. Yeni dosyalarla Safari otomatik oynatma, duraklatma/devam ve döngü davranışı ayrıca sınandı.

**Worker bağımlılığı:** `worker.js` Range allowlist'i yeni dört MP4 yoluna güncellenmiştir; `landing_worker_range.test.mjs` ile gerçek dosyalar birlikte doğrulanmalıdır. Mevcut bounded okuma sınırı **256KiB**'dir; daha büyük dosya için sınırı sessizce artırma. Encoder küçültme/gerçek streaming kararı ayrıca incelenir. Normal 200/HEAD/304/404 ve 206/416 güvenlik/cache/ETag kuralları korunur.

Referansı kalmayan 27 eski yayın görseli ve videosu çıkarıldı; ham tarihsel kanıt `analiz/` altında korunur. `screenshots/README.md` cihaz/OS/saat/hesap/tarih ve dosya listesini içerir. JSON manifestler `screenshots/manifest-20261028.json` ve `videos/manifest-20261028.json` olmalıdır; gerçek dosyalardan üretilir, placeholder hash/sayı yayımlanmaz.

## Kontrol kapsamı

Otomatik medya sözleşmesi şunları doğruladı:

- 30 gerçek PNG başlığı ve bütün web medya ölçülerinin 540×1170 olması.
- 4 sessiz MP4 ve 4 static WebP posterin binary ölçüleri; kaynak/çıktı SHA-256 ve aynı demo owner.
- HTML medya referanslarının bulunması, kullanılan bütün app medyasının referanslı olması; kullanılmayan/eski dosya kalmaması.
- TR/EN dosya son eklerinin sayfa diliyle eşliği; iki dilde bölüm sayısı ve feature konu eşliği.
- Gerçek native kaynakların ölçü/hash eşleşmesi; manifest yalnız iddia olarak bırakılmaz.
- Mevcut playback/visibility/reduced-motion/keyboard ve Worker Range regresyonları korunur.

Bu kontroller görsel içeriği OCR ile tercüme etmez; gerçek native dil ve boş olmayan tutarlı hesap UI'sı capture testleri/manual inceleme ile doğrulanır. Safari’de 24 TR/EN sayfa 375/1024/1440 genişlikte açıldı: 72/72 kontrol geçti. Dört videonun manuel oynatma kontrolü 50 gözlemle kaydedildi. Menü/SSS/dil etkileşimleri, aynı HTML/CSS/JS kaynaklarının önceki turunda kontrol edildi. Kesin ilk-paint filmi kaydedilmedi; Chrome otomasyon host’u kullanılamadığı için Chrome doğrulanmadı. Sayfa kanıtları `analiz/ekran_site_2026-10-28/browser/` altındadır.

## Auth, formlar ve yasal sınırlar

- `reset-password`, `confirmed`, `unsubscribe` iki dilli yardımcı sayfalardır; `?lang=tr|en` veya tarayıcı dili kullanır. Tokenlar log/analitik/ekran kanıtına taşınmaz. Şifre sıfırlama dış hatayı geçersiz token diye genellemez; onay sayfası parametresiz başarı iddia etmez.
- Bekleme listesi `method="post"` ve önceden işaretsiz ayrı ticari ileti onayıyla çalışır. Sunucu consent/limiter eksikleri görsel düzenlemeyle çözülmüş sayılmaz. Yerel site QA'sında gerçek e-posta gönderilmez.
- Mağaza ve uygulamanın bağlı olduğu yasal/destek URL'leri korunur. Veri sorumlusu kimliği/adresi ve gönderen kimliği kullanıcı tarafından en son verilecektir; `data-fill-in="KVKK-15"` yer tutucuları gerçek bilgi gelmeden tamamlandı sayılmaz. Tasarım çalışması bu bilgileri uydurmaz.
- Hukuki metin değişikliği iki dilde sürüm/tarih ve uygulama onay sürümleriyle koordine edilir; bu B medya/özellik güncellemesi hukuki kimlik onayı değildir.

Deploy komutu bu çalışma için verilmez/çalıştırılmaz. Branch push, yerel preview veya yeni medya commit'i canlı site yayını değildir.

Yeni32 AYT erken bitiş, dört test seçimi ve özel deneme adı/notu metinleri de iki dilde bulunur.32 sunucu paketi ayrıca incelenip kurulmadan ve yeni uygulama yayımlanmadan bu açıklamalar canlıya deploy edilmez. Site verisi ayrı `pomosprint_site32_dus` DB/API54361 üzerinde yedi kurgu hesapla hazırlanır; review SQL test kişilerinin verisi kopyalanmaz. Gerçek sosyal kullanıcı adı/kullanım sayısı iddiası yoktur.


## Tekrar çalıştırılabilir güvenli önizleme

```sh
python3 tool/site_qa/server.py --port 8799
```

Komut repo kökünden çalışır; `http://127.0.0.1:8799/__qa` matris ve manuel önizleme sağlar. [Araç rehberi](../tool/site_qa/README.md) izolasyon ve test sınırlarını açıklar. Statik kaynaklar canlıya gitmez; GET/HEAD dışında yazı kabul edilmez. Bu yardımcı üretim sitesi değildir ve deploy edilmez. Safari sonuçları `analiz/ekran_site_2026-10-28/browser/` altında; Chrome bu oturumda otomasyon host'u kapalı olduğu için doğrulanmadı.
