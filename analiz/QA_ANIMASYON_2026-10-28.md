# Kum saati — 27/28 Ekim yerel ölçümü

`integration_test/p_hourglass_profile_test.dart`, iOS18.6 QA iPhone16, gerçek Lottie dosyası, debug derleme,393×852 mantıksal ekran ve60Hz. Native tur **1/1 geçti**. Bu izole widget ölçümüdür; tam uygulama, fiziksel cihaz, pil veya releaseFPS kanıtı değildir.

| Durum | Örnek süre | Ölçülen kare | Build p99 | Raster p99 |16,67ms üstü |
|---|---:|---:|---:|---:|---:|
|Çalışıyor|26.0sn|1561|3.315ms|1.32ms|0|
|Duraklatıldı|3.0sn|181|0.8ms|1.507ms|0|
|Gizli|3.0sn|0|Nonems|Nonems|0|
|Hareket azaltılmış|3.0sn|181|0.757ms|1.739ms|0|

Hareketli durumda controller açıktır; duraklatılmış ve hareketi azaltılmış durumda kapalıdır. Gizli TickerMode altında yeni kare yoktur. Test harness görünür durağan hallerde de engine frame üretebildiği için181kareyi animasyonun sürdüğünün kanıtı saymıyoruz; controller/pendingcallback ayrı ölçüldü.

Ölçüm belirgin framebudget sorunu göstermediğinden görsel, boyut, tempo veya yeni rendercache değiştirilmedi. İki gerçek yaşam döngüsü hatası düzeltildi: dosya yüklenmeden başlatmada durationnull hatası ve hareketi azaltma açıldığında sürmekte olan kategori sarsıntısının devam etmesi. Beş widget regresyonu bu durumları, duraklat/devam, gizliTickerMode ve seans süresinden bağımsız görseli doğrular. İkinci hata düzeltmesi gereksiz sarsıntı ticklerini sıfıra indirir; genel performansta öncesi/sonrasıFPS artışı iddia edilmez.
