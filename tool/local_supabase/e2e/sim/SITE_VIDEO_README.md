# Yerel uygulama videosu

Bu araçlar gerçek simülatör kaydını keser; ekran üretmez, videoyu hızlandırmaz,
siteyi değiştirmez ve yayın yapmaz. Yalnız `PomoSprint QA ` ile başlayan,
açık ve kullanılabilir iOS simülatörü kabul edilir. Korunan `2CF…` cihazı
yeniden adlandırılsa da reddedilir. Simülatörü araçlar açmaz veya kapatmaz.

Repo kökünden, başka yerel terminalde kaydı başlat:

```sh
python3 tool/local_supabase/e2e/sim/record_site_video.py \
  --udid EXPLICIT_QA_SIMULATOR_UUID \
  --out-dir build/native_site_media/site-20261028
```

`READY` çıktıktan sonra root tarafından yönetilen gerçek uygulama senaryosunu
çalıştır. Senaryo bitince kayıt terminalinde **Ctrl+C** kullan. Araç yalnız
kendi `simctl` işlem grubuna SIGINT iletir; MOV'un kapanmasını bekler ve
`recording.json` dosyasına UTC başlangıç/bitiş, boyut ve SHA-256 yazar.
Başka bir terminalden SIGTERM de güvenli bitiş ister. Zorla SIGKILL kullanma.
Eski kayıtların üstüne yazılmaz; her kayıt için ayrı klasör seç.

Native senaryo loguna bu biçimde tek satırlı JSON yazar:

```text
[MEDIA_EVENT] {"kind":"scene_start","scene":"timer","at":"2026-10-28T00:00:01.000Z"}
[MEDIA_EVENT] {"kind":"tap","scene":"timer","at":"2026-10-28T00:00:02.000Z","x":196.5,"y":720,"width":393,"height":852}
[MEDIA_EVENT] {"kind":"scene_end","scene":"timer","at":"2026-10-28T00:00:05.000Z"}
```

`marathon` için de bir başlangıç, en az bir gerçek dokunuş ve bir bitiş gerekir.
Sahneler tekil, sıralı ve kesişmeden 1–120 saniye olmalıdır. `at` UTC'dir;
dokunuş noktası, gerçek tap öncesinde alınan mantıksal ekran koordinatı ve
ekranın mantıksal boyutudur. Kullanıcı adı, e-posta, token veya başka alan
eklenmez; bilinmeyen alanlar reddedilir. Örnekteki olaylar yalnız biçim
gösterimidir, kanıt veya videoda kullanılacak sahte dokunuş değildir.

Tamamlanmış kaydı kodlamak için:

```sh
python3 tool/local_supabase/e2e/sim/encode_site_video.py \
  --raw build/native_site_media/site-20261028/raw.mov \
  --meta build/native_site_media/site-20261028/recording.json \
  --events /tmp/pomosprint_native_site_video.log
```

FFmpeg/ffprobe ve FFmpeg'in `libx264`, `libwebp`, `ass`/libass desteği gerekir.
Kaydın gerçek SHA-256'sı metadata ile karşılaştırılır. Çıktılar yalnız
`build/native_site_media/final/` altındadır: `timer.mp4`, `marathon.mp4`,
WebP posterler, vektör imleç ASS dosyaları ve manifest. Timer posteri 0,5. saniyeden alınır; Maraton posteri gerçek dördüncü dokunuştan 0,5 saniye sonrasından (y sahnesinde açık planlama penceresi) seçilir. Kısa olay listesinde son uygun dokunuş kullanılır; kare video aralığına sınırlandırılır. Gerçek zaman `poster_at_seconds` alanına yazılır.
Mevcut final çıktısı için açıkça `--overwrite` gerekir.

MP4 ayarları: 540×1170, 24 fps, H.264/yuv420p, sessiz, faststart, 2 encoder
thread'i. En-boy oranı ölçekleme ve gerekirse boş kenarlarla korunur;
kırpma veya esnetme yapılmaz. Süre değiştirilmez. Beyaz/siyah imleç ve hafif
tıklama halkası yalnız logdaki gerçek dokunuşların konum ve zamanından
oluşturulan editoryal katmandır; uygulamanın kendi imleci gibi sunulmamalıdır.

Her MP4 için 262.144 bayt sınırı vardır. CRF 32, 34, 36, 38, 40 ve son çare
42 denenir. Sığmazsa araç hata verir; daha bulanık kaliteye sessizce geçmez.
Root gerçek sahneyi gözle değerlendirip gereksiz beklemeleri senaryodan
kısaltmalı ve yeni kayıt almalıdır. Küçük dosya görsel okunabilirlik kanıtı
değildir; final videolar ayrıca izlenmelidir. Bir sahne hata verirse manifest
başarıyla yazılmaz; önceki sahnenin oluşmuş dosyası tek başına tamamlandı
anlamına gelmez.

Recorder'ın UTC referansı `Recording started` satırının alınma anıdır. Gözle
doğrulanmış çok küçük hizalama farkı için `--sync-offset -0.10` gibi **-1 ile
+1 saniye** arası açık düzeltme verilebilir; varsayılan 0'dır. Bu değer olay
zamanından hesaplanan video kesim başlangıcına eklenir; manifestte saklanır.
Kayıt dışına taşan kesimler reddedilir. Manifest ham kaynak/log/metadata
hash'lerini, UTC aralıklarını, dokunuşları, kesimleri, formatı, baytları,
CRF denemelerini ve editoryal katmanı açıkça kaydeder.

Hafif çevrimdışı kontrol (cihaz/ağ/video encoder başlatmaz):

```sh
python3 -m unittest discover -s tool/local_supabase/e2e/sim -p test_site_video_tools.py -v
python3 -m py_compile tool/local_supabase/e2e/sim/record_site_video.py tool/local_supabase/e2e/sim/encode_site_video.py
```

Medya senaryosundaki dokunuşlar, `LiveTestWidgetsFlutterBinding` renkli test artısını çizmeden aynı gerçek hit-test yoluna iletilir. Device kaynaklı Down/Up olayları kullanılır; binding bayrağı başarı/hata sonrasında geri yüklenir. Bu yalnız kayıt testinin davranışıdır; uygulama veya Flutter SDK değiştirilmez. Üç widget regresyonu gerçek düğme eylemini ve bayrağın korunmasını doğrular. Yeni kayıtta artı işareti bulunmadığı ayrıca gözle denetlenmelidir.
