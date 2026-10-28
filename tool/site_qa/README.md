# Yerel, salt okunur Safari QA önizlemesi

Bu araç `landing/` klasörünü localhost üzerinden gösterir. Ürün dosyalarını değiştirmez; `.env` okumaz, Auth/API/e-posta çağrısı yapmaz. Ayrı açık8798 sunucusuna dokunmaz. Çalıştırmak için proje kökünden:

```sh
python3 tool/site_qa/server.py --port 8799
```

Python3.11 veya üstü yeterlidir; Node yalnız isteğe bağlı JS sözdizimi kontrolünde kullanılır. Başka paket kurulumu gerekmez.

Safari'de `http://127.0.0.1:8799/__qa` açılır. Varsayılan port8799'dur; yalnız8797–8799 veya izole test için0 kabul edilir. Port0 seçilirse gerçek adres terminalde yazdırılır. Bağlama adresi her zaman `127.0.0.1`dir; host/DB/API adresi parametresi yoktur. Port kullanılıyorsa araç durur, mevcut süreci öldürmez. Kendi başlattığınız süreci Ctrl-C ile kapatın.

## Koruma sınırları

- Yalnız GET/HEAD; POST/PUT/PATCH/DELETE/OPTIONS405 olur. HTTP kanıtları ve ekran görüntüleri sunucuya gönderilmez.
- `/js/config.js` yanıtı her zaman `window.PomoSupabase=null` olur. Kaynak dosya aynı kalır. CSP bağlantı, script, medya ve frame'i yalnız kendi origin'ine sınırlar; form, object ve base kapalıdır.
- Traversal, çift kodlama, gizli/underscore/node_modules yolları ve Auth/REST/functions/API/storage yolları reddedilir. Yalnız izinli statik dosya türleri servis edilir.
- MP4 GET tek Range isteğini boyuta sınırlar; içerik parça parça okunur. HEAD Range'i yok sayar. ETag/If-Range, suffix/açık uç/aralık dışı416 davranışı korunur.
- QA sayfasının kendi iframe ölçümleri ürün butonlarını tıklamaz ve form göndermez. Manuel iframe'de gerçek kullanıcı etkileşimi ayrı bir kontroldür. Sonuçlar tarayıcı belleğinde kalır; isteğe bağlı yerel Blob indirmesi yapılır.
- PNG/JPEG yardımcıları yalnız kullanıcı tarafından yapıştırılan base64 verisinin imzasını, kanonik kodlamasını,10MiB sınırını ve güvenli dosya adını denetleyerek yerel Blob indirir. Yeniden görsel üretmez veya bir sunucuya yüklemez.

## Kullanım ve test

“Run read-only checks” gerçek sayfa envanterini375/1024/1440px iframe genişliklerinde ölçer. Kaynak ve link denetimleri yalnız aynı origin'e GET/HEAD kullanır. Dış kurum, mağaza, e-posta veya telefon bağlantıları takip edilmez. Matrisin bitmesi bütün sonuçların geçtiği anlamına gelmez; JSON'daki `failed_cases`, `failures` ve `warnings` okunmalıdır. Başlık görünürlüğü rAF ölçümü gerçek paint-timing/video kanıtı değildir.

```sh
#15 gerçek HTTP/Range güvenlik kontrolü;8799'u kısa süre açar ve kapatır:
python3 -m unittest tool/site_qa/test_server.py -v
node --check tool/site_qa/qa.js
node --check tool/site_qa/probe.js
```

Test yalnız kendi8799 sunucusunu kapatır. Tarayıcı açmaz, CUA kullanmaz ve ürün/SQL/Flutter işlemi yapmaz. Safari'deki menü, video autoplay/reduced-motion ve gerçek görsel kalite kontrolleri ayrıca insan veya CUA incelemesi gerektirir.

İlk taşınabilir sürümde15 HTTP/Range kontrolü, iki JS sözdizimi kontrolü ve README'deki gerçek CLI komutunun8799 üzerinde GET200 yanıtı doğrulandı. Test POST'ları yalnız `/__qa` üzerinde yöntem reddini sınar; ürün formu veya API çağrısı yapılmaz. Yeniden çalıştırma kanıtları `build/site_qa/` altında tutulabilir.
