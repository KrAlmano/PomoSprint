# Gerçek süreli gece QA — 8 Ekim 2026

Koşu `overnight1008_05`: **GEÇTİ**. 80/80 bağımsız son kontrol geçti. Bu rapor manager tarafından gerçek sonuç dosyalarından otomatik üretildi; bitiş beklenmeden başarı varsayılmadı.

Çekirdek ve ek seans ledger kayıtları, gerçek süreler ve gece kontrol listesi bağımsız doğrulamayı geçti.

Yerel Supabase, Pro iOS simülatörü ve Android emülatörü; üç ayrı Auth/API gözlem hesabıyla toplam beş yeni kimlik. Odaklar gerçek 25/50 dk, mola 300 sn ve onay 60 sn. Son çalışma sınırı `2026-10-08T04:00:00+00:00`; kullanıcı Plus önizlemesi korunur.

Okunabilen gerçek DB toplamı: **8 kayıt / 250 dakika / 58 puan / 160 kum**. Çekirdek senaryo beklentisi 6 kayıt/200 dakika/48 puandır; ek seansların dinamik UUID ledger kontrol sonuçları JSON içindedir. Sabit çekirdek toplam bütün gecenin sonucu sayılmadı.

| Hesap | Seans | Dakika | Puan | Kum |
|---|---:|---:|---:|---:|
| 1 | 4 | 125 | 29 | 80 |
| 2 | 4 | 125 | 29 | 80 |
| 3 | 0 | 0 | 0 | 0 |
| 4 | 0 | 0 | 0 | 0 |
| 5 | 0 | 0 | 0 | 0 |

Bu 04:00 TR sonrası devam koşusudur. Önceki run04 aylık UI testinin toplamı günlük ısı haritası etiketi gibi araması yüzünden durdu; önceki 14 gerçek kayıt/500dk/114puan/280kum silinmedi. O koşudaki gerçek gün sınırı ve timeout kanıtları kendi dosyalarında kalır. Bu yeni beş hesaplı koşu gün sınırı veya timeout tekrarlandı sayılmaz; iki gerçek25×2Maraton, iki normal50, iptaller, ek odaklar, sosyal/rapor/sıralama ve07TR sonu ayrıca doğrulanır.

Sosyal için boş yanıtın biçimsel olarak geçmesi yeterli sayılmadı: her aktörün molasında diğer aktör odakta kalırken beş Auth hesabının tam durum haritası zorunlu denetlendi; moladaki kullanıcıyı dört arkadaşı görmeli. Örnek timestamp'leri active_social_presence içindedir. Bu kanıt API durumudur; yeni Molada UI görüntüsü alınmış sayılmaz.

Bu devam koşusunda başlangıç zamanı, gerçek geçen süre, normal/Maraton puanı, zamanında mola onayı, iptal, çalışma günü, rapor UUID/kategori toplamları ve hesap izolasyonu ayrı kontrol edilir. Duraklatma cezası, yanıtsız mola sonunda ilk seansın korunması ve gerçek 04:00 TR geçişi önceki run04 kanıtlarıdır; bu koşuda tekrarlandı sayılmaz. Bağımsız API oturumlarının kendi seansları, arkadaş kimlikleri ve bitişte sosyal presence sonuçları `api_facts` içindedir; eksik veya başarısız kontrol geçilmiş sayılmaz.

Örnekleme kapsamı ayrıca denetlendi: beş hesaplı API 138 örnek, en büyük aralık 60.861 sn (sınır150); sunucu config 28 örnek, en büyük aralık 301.72 sn (sınır360). Başlangıç ve hedef bitişe yakın örnekler zorunludur; tek başarılı örnek bütün gecenin doğrulaması sayılmaz. Ayrıntılı timestamp kapsamı `sampling_coverage` içindedir.

Ham cihaz başlangıcı ile DB başlangıcı arasında SessionQueue/ServerClock HTTP Date saat düzeltmesi uygulanır. Her UUID için iki zaman ve gözlenen fark kaydedildi; yerel başlık yuvarlama payı en fazla 2 saniyedir. Gerçek cihaz elapsed süresinin ve sunucu seans aralığının 1500/3000 saniye koşulları ayrıca kontrol edilir; bu pay odak süresini kısaltmaz.

Gerçek OS process kill/background testi yapılmadı; native yön/orientasyon ve gerçek sekme geçişleri ayrı UI kanıtıdır. Fiziksel cihaz, canlı DB ve mağaza yayını bu turun kapsamında değildir. Canlıya okuma/yazma yapılmadı. Parola/e-posta/JWT rapora kaydedilmedi.

Kanıt klasörü: `analiz/qa_evidence_20261008/overnight_real/run05`. Giriş dosyaları `final_rollup.json`, `overnight_state.json`, `native_framework_summary.json`, `cleanup.json`, API/DB/config-watch JSONL ve native loglardır.

Başlangıç doğrulaması: 1174/1174 Flutter testi (0 atlama), temiz analiz, 18/18 host kontrolü; iOS ve Android debug derlemeleri geçti. Ayrıntılar üst kanıt klasöründedir.

İlk başlatma girişimi beş Auth hesabı ve arkadaş ağından sonra görüntü yolu hatasıyla durdu; tamamlanmış seans yoktu. Yol düzeltildi ve temizliği doğrulandı. Sonraki iki girişim Android yazılım çizicisinin işlemci yükü nedeniyle ilk 25 dk tamamlanmadan durduruldu; ikisinde de 0 kayıt ve sahip süreçlerin temizliği doğrulandı. Önceki kanıtlar silinmedi.

Son test aracı düzeltmesinden sonra tam Flutter paketi yeniden geçti: 1176 test, 0 atlama; SCREENSHOTS=true, concurrency=1, 211.0 sn. Önceki 44 PNG hash değiştirmeden korundu. Yeni iki TR/EN vaka aylık toplamı günlük ısı haritası etiketi sanma hatasını doğrular. Ayrıntı flutter_full_revalidation.json ve flutter_full_screenshots_enabled.log.

Bu koşudaki Android yatay görüntüsü yerleşim tamamlandıktan sonra görsel okundu: kum saati, sayaç, duraklatma hakkı, duraklatma ve durdurma düğmeleri doğru görünüyor. Önceki girişimlerde geçiş ortasında alınan görüntü son yerleşimin kanıtı sayılmadı; test görüntüsü öncesi bekleme düzeltildi.

Uzun gece testinde yalnız test binding çizimi seyreltilir: odak beklerken yaklaşık saniyede bir kare, etkileşim sırasında daha sık kare. Live binding gerçek Timer/DateTime kullanır; fake saat, süre atlatma ve ürün animasyonu değişikliği yoktur. Bu koşu animasyon akıcılığı ölçümü sayılmaz. Android için süreç özelinde LP_NUM_THREADS=2 kullanılır; [Mesa resmi açıklaması](https://docs.mesa3d.org/envvars.html#lp-num-threads).

Görsel kanıt: 46 çekim olayı, 44 benzersiz ana PNG yolu. Tekrarlanan adlar eski PNG üzerine yazabiliyordu; yerel arşivleyici başladıktan sonra 46 yeni olayın bytes/hash/zamanı ayrı korundu. İlk gözlemde 0 mevcut PNG korundu; 0 önceki üzerine yazılmış olay geri getirilemedi ve ayrı görsel kanıt sayılmadı. Olay sayısı korunan benzersiz görüntü sayısı değildir. Arşiv ayrıntıları archived_screenshots/archive_events.jsonl ve archive_status.json; uygulama/native host değiştirilmedi.
