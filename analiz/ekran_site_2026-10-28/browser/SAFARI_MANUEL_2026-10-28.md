# Safari yerel B doğrulaması — 28 Ekim 2026

Durum: **son compact Deneme UI paketiyle 72/72 tarayıcı matrisi ve dört video için kısa manuel tekrar başarılı.** Ürün kaynağında değişiklik yapılmadı. Kesin ilk-paint ve Chrome motoru doğrulanmadı.

## Güncel kaynak

Son kaynak sahibi Deniz `ca271e26-fc2c-44b6-b88f-9537f809639c`; paket `site-oct28-ui-a1`. `safari_source_fingerprint.json`, sekiz HTML/CSS/JS dosyası ile iki güncel medya manifestinin SHA-256 değerlerini taşır. Bu sekiz site kaynağı önceki turla aynıdır; iki medya manifesti yenilenmiştir. Güncel 30 ekran / 4 video / 4 posterin byte hashleri manifestleriyle eşleşir. Doğrulama yalnız `127.0.0.1:8798/__qa`, izinli Safari UUID `6D09DD83-D232-4BDC-B3F6-A6A6E339A5B8` üzerinden yapıldı. Yerel sunucu `no-store` yanıtı verir, canlı API yapılandırması kapalıdır.

## Güncel 72-case sonuç

- Başlangıç: 2026-10-28T14:35:45.361Z; bitiş: 2026-10-28T14:36:38.054Z.
- 24 sayfa × 375/1024/1440 px: **72 PASS**, 0 FAIL, 0 uyarı.
- 822 yerel kaynak/bağlantı kontrolü; taşma, locale veya JS çalışma hatası bulunmadı.
- Gerçek indirilen çıktı: `safari_final_72.json`; SHA-256 `674da386de4f342d25e2feb908ef91cbfe64cff9ec4f599f1b1588e1783666c4`.
- En erken başlığın rAF görünürlüğü kontrolüdür. Bu ölçüm kesin ilk-paint ekran kaydı olarak sunulmaz.

## Güncel dört video tekrarı

`2026-10-28T14:36:54.862Z`–`2026-10-28T14:53:54.511Z` aralığındaki **50 gerçek gözlem**, `safari_manual_final.json` dosyasındadır. SHA-256 `147b2dcf5598d8ce30074567ec30516e88843999840b5ac464aae49cb7b68f29`. Arada kullanıcı kesintisi nedeniyle uzun boşluk vardır; bu, kesintisiz performans testi değildir. `safari_manual_summary.json`, yeni sahibi ve kaynak parmak iziyle bağlanmış sayısal özettir. Gözlemci 5 saniyede bir yalnız mevcut video durumunu okur; programatik play/pause veya ürün tıklaması üretmez. Oynat/duraklat işlemleri gerçek Safari kontrolleriyle yapıldı.

| Güncel video | Oynayan örnek | Duraklatılmış örnek | Sessiz / döngü |
|---|---:|---:|---|
| `marathon-en.mp4` | 4 | 3 | evet / evet |
| `marathon-tr.mp4` | 18 | 9 | evet / evet |
| `timer-en.mp4` | 6 | 3 | evet / evet |
| `timer-tr.mp4` | 5 | 1 | evet / evet |

Dördünde de görünürken otomatik başlama ve `currentTime` ilerlemesi; gerçek tıklamayla duraklama, “oynat” etiketi ve devam sonrası yeniden ilerleme görüldü. Görünür alan dışına çıkınca oynatımın durması da gözlendi. Her kaynak için ayrı bir tam döngü beklenmedi; yeni örneklerde zamanın başa döndüğü çiftler ayrıca özet JSON'unda listelenir. Önceki paketle alınmış tam döngü kayıtları güncel paketin yerine kullanılmaz.

## Menü, SSS, dil ve hero kapsamı

Önceki 13:11–13:33 UTC turunda aynı sekiz HTML/CSS/JS kaynağıyla TR/EN menü açma, gerçek dil bağlantısı, tek açık SSS yanıtı, doğru iframe odağında Escape ile menü kapanması ve 375/1024/1440 hero okunaklılığı kontrol edildi. Bu etkileşim kaynakları değişmedi. Son 72-case turu yeni medyayla tüm sayfaları yeniden açtı; önceki SSS/menü tıklamaları bu son turda yeniden yapılmış gibi sayılmadı. Önceki turun JSON ve raporu `build/site_verification_20261028/browser_pre_compact_ui/` altında tarihlidir.

## Gerçek ekran görüntüsü kanıtları

Aşağıdaki JPEG'ler 13:30–13:31 UTC'de belgelenmiş CUA `App.getScreenshot({emit:false})` baytlarından alınmıştır. Kaynak formatı JPEG/JFIF olduğu için `.png` diye yeniden adlandırılmadı. Üçü de 2648×1898; viewport genişlikleri ve byte-hash zinciri `safari_cua_capture_manifest.json` içindedir.

- `safari-cua-tr-home-375.jpg` — 241.507 bayt.
- `safari-cua-tr-home-1024.jpg` — 348.445 bayt.
- `safari-cua-en-home-1440.jpg` — 385.970 bayt.

Bunlar tarayıcı çerçevesi/QA iframe'i içeren **hero ve yerleşim kanıtlarıdır**; son compact Deneme ekran görüntülerini veya kesin ilk boyamayı göstermez. Sekiz HTML/CSS/JS hash'i aynı olduğu için bu kapsamda korunmuştur. Manifestte güncel paket için ayrı yeniden doğrulama notu vardır. Yeni native medyanın kanıtı son 72-case matrisi, güncel iki medya manifesti ve dört video tekrarıdır.

JPEG aktarımı yalnız gerçek CUA baytlarını base64'e çevirme → belgelenmiş `App.paste` → yerel helper Blob indirmesi → dosya hash karşılaştırması yoluyla yapıldı. JPEG imzası/bitişi, canonical base64, 10 MiB ve güvenli dosya adı doğrulandı; 25/25 helper guard testi geçti. Ham görüntü/base64 metin çıktısına yazılmadı. Görüntü veya UI üretilmedi, düzenlenmedi. İlk OS PNG denemeleri başarısız olmuştu; bu sınır daha sonra gerçek JPEG indirmesiyle çözülmüştür.

## Sınırlar

- Kesin ilk-paint: **NOT VERIFIED**; yalnız rAF başlık vekili ve sonradan görsel okuma var.
- Chrome motoru: **NOT VERIFIED**; browser host kullanılamadığı için denenmedi. Kullanıcının açık Chrome sekmelerine dokunulmadı.
- Siteyi yayınlama, canlı API, form gönderimi veya hesap değişikliği yapılmadı.
- Bir noktada ön pencere kişisel n8n başlığı taşıdı: yalnız pencere başlığı kontrol edildi, içerik/URL incelenmeden duruldu. İzinli QA pencere başlığı ve yerel URL geri doğrulanınca devam edildi.
