# Yerel site videosu araçları — 28 Ekim 2026

Kaynaklar: `tool/local_supabase/e2e/sim/record_site_video.py`,
`encode_site_video.py`, `test_site_video_tools.py`, `SITE_VIDEO_README.md`.

İlk hazırlıkta **16/16**, gerçek encoder/poster düzeltmeleri sonrasında **18/18 hafif çevrimdışı kontrol geçti.** İki komutun `--help` çıktısı ve
Python `py_compile` da başarılı. Testler gerçek simülatör, ağ veya FFmpeg
işlemi başlatmadı; subprocess boyut reddi testi mock kullandı.

Kontroller: yalnız adı `PomoSprint QA ` ile başlayan açık/kullanılabilir
simülatör, korunan `2CF…` UUID reddi, hedef dizin/symlink sınırı, katı olay
alanları, UTC ve monoton zaman, iki tamamlanmış sahne, gerçek tap zorunluluğu,
sınır dışı/NaN/bool koordinat reddi, en-boy/koordinat dönüşümü, ASS vektör
üretimi, kaydın dışına taşan sahnenin encode edilmemesi ve CRF42 sonrasında
256 KiB sınırının hata vermesi. Hata halinde video başarılı sayılmaz.

Çıktı sözleşmesi: gerçek kayıt `raw.mov` + UTC/byte/SHA metadata; final
540×1170 / 24fps / H264 / yuv420p / sessiz / faststart. Ölçekleme en-boy
oranını korur, gerekiyorsa kenar bırakır; hız değiştirilmez. İmleç ve hafif
tıklama halkası kaydedilen gerçek tap zaman/koordinatından üretilen editoryal
katmandır. CRF adayları32/34/36/38/40/42, iki encoder thread'i; her MP4 en fazla
262.144 bayt. Başarılı dosya boyutu tek başına görsel kalite kanıtı değildir.

İlk gerçek y çekimi 1/1 native + yerel parite kontrolünden geçti. İlk encoder denemesinde bu FFmpeg sürümünün `.5` zaman değerini kabul etmemesi poster üretimini durdurdu; `0.5` düzeltmesinden sonra her iki video CRF32 ile üretildi (210.984 ve 204.422 bayt). Kaynak hash değişmedi. Görsel incelemede LiveTestBinding'in renkli test işareti de görüldü; bu ilk çıktı final site videosu sayılmadı.

Renkli işaret üretmeden gerçek device olayını ileten medya helper'ının 3/3 widget testi geçti. Maraton posterinin açık planlama penceresinden seçilmesi 18. araç regresyonuyla doğrulandı. Temiz ikinci native çekim ve son görsel değerlendirme hâlâ bekliyor. Site asset/deploy dosyalarına araçlar dokunmaz; kullanım ve log şeması ilgili README'dedir.

## Final kayıt — y3

İlk y1 ve y2 değerlendirmeleri tarihseldir. Final, geçici iOS18.6 iPhone16 cihazındaki **y3** koşusudur: `/tmp/pomosprint_ios18_media_y_03.log`,1/1 native + yerel27/28/29+30 paritesi geçti. Gerçek ham kayıt `build/native_site_media/site-20261028-final/raw.mov` (10.458.539 bayt), SHA-256 `b5a86705e2e49cea893e3d04980a71f6ca52dbeb2b0af13858498eb2305ef51a`.

Y2'de renkli test artısı giderilmişti, fakat duraklatma bildirimini beklemeden tıklayan test yardımcısı kısa bir otomatik kaydırma yapabiliyordu. Y3, gerçek bildirimin kapanmasını bekler ve Devam düğmesinin kaydırmadan erişilebilir olduğunu doğrular. Ürün arayüzü veya sayaç hızı değiştirilmedi. Final videoda duraklatma öncesi/sonrası, devam sayacı ve planlama kareleri gözle kontrol edildi: kategori şeridi görünür, büyük test artısı yok, beyaz imleç doğru gerçek hedef üzerindedir.

| Final | Bayt | Kaydedilen sahne | Format |
|---|---:|---:|---|
| Pomo |205761|24,594618sn|540×1170,24fps,H.264/yuv420p,sessiz,CRF32|
| Maraton |199294|20,463947sn|540×1170,24fps,H.264/yuv420p,sessiz,CRF32|

İki MP4 tam `ffmpeg -f null` çözümlemesinden geçti. `ffprobe` süreleri24,583333/20,458333sn; manifestin gerçek UTC sahne aralığına farkları bir kareden küçüktür. Video/poster hashleri [yayın manifestinde](../landing/videos/manifest-20261028.json), ham kayıt ve olay logu hashleriyle birlikte tutulur. Zaman/konum,8 Pomo ve9 Maraton gerçek dokunuşundan gelir. Video hızlandırılmadı; dönem veya seans tarihi değiştirilmedi. İki seans gösterim sonunda iptal edildi, kayıt/puan/kum üretilmedi.

Mevcut üç TR video alanındaki dosyalar ve posterleri yenilendi; URL yolları Worker izin listesi için korunur, HTML `?v=20261028` ile önbelleği yeniler. Ekran düzeni ve otomatik/sessiz/görünürken döngü davranışı korunur. Yeni manifest hash ve cache-query Range testleri eklendi. Safari otomasyonu hâlâ doğrulanamadığından bu kaynak/codec/kare kontrolü gerçek Safari autoplay testi diye sunulmaz. Deploy yapılmadı; D-06 yayın sırası geçerlidir.

Safari 01:08TR tekrar denemesi: `cua.getApp(com.apple.Safari)` yine `cgWindowNotFound` döndürdü. Chrome veya başka tarayıcı açılmadı; yeni yerel video oynatımı için Safari PASS iddiası yoktur.
