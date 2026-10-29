# Dynamic Island iPhone çerçeveleri ve son iki düzeltme

Ortak CSS çerçevesi TR/EN Ana Sayfa ve Özellikler’deki40gösterimde uygulanır; fotoğraf/video üstüne tek dekoratif ada gelir. Kaynak görüntülerin540×1170oranı korunur, galeride farklı köşe override’ı yoktur. İki Safari375pxörneği doğrudan görüldü; genel40ekranın tektek görsel incelenmesi iddiası yoktur.

Çerçeve yayını `23462be5-023f-4be4-9509-86b24a618e21` kullanıcının yeni “deployöncesisor” talimatından önce başlatıldı. Kullanıcı daha sonra iki düzeltmenin yayınına açıkça onay verdi. Yalnız `6cfd9b5` kaynakları ayrı geçici klasörden yayımlandı; devam eden KPSS değişiklikleri bu pakete alınmadı. Son canlı Worker sürümü `ad2fc988-4462-40ae-9333-ab0107e2138b`.

1. `reports-weekly-en.png` simülatörden yeniden çekildi. CUA’da görünen donanım adası dosyaya alınmadı; doğrudan `simctl io screenshot` kullanıldı. Orijinal sistem PNG’si `weekly-recapture/reports-weekly-en-raw.png`. Sadece boyutlandırma yapıldı; adanın üstü boyanmadı. Saat09:41,aynıDenizhesabı,29puan/80kum,4h50m/%21/35h değerleri korundu; çekim sonrası dil tekrarTürkçeye ve statusbar doğalhaline döndü.
2. `confirmed.html`, `reset-password.html`, `unsubscribe.html` CSSbağlantıları `20261028a` yerine ortak `20261028c` oldu.

Doğrulama:30webPNG’nin beklenen ada merkezinde gömülü siyah bölge olmadığı piksel kontrolüyle,3yardımcısayfanın CSSsürümü kaynak kontrolüyle doğrulandı. Node172/172 ve partial eşliği temiz. Yeniden çekim manifesti/yeniSHA’lar güncel; önceki15ENgörsel incelemesindeki weeklysatırın tarihsel olduğu açıkça işaretlendi. Yayın sonrasında altı canlı HTTP kontrolü geçti: PNG ve manifest hash’leri, üç yardımcı sayfanın CSS sürümü ve Özellikler sayfası onaylı kaynakla eşleşti. [Canlı doğrulama kaydı](approved-fix-deployment.json). Bundan sonraki dağıtımlar için yeniden kullanıcı onayı gerekir.
