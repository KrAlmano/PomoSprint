# Android yerel doğrulama kanıtı — 1 Kasım 2026

Cihaz `PomoSprint_QA_API36`. Her iki native tur ayrı geçici `com.pomosprint.qa.nov1android` uygulamasında, yerel Supabase ve açıkça etiketli QA hesaplarıyla koşuldu. Canlı kullanıcı veya veritabanına yazılmadı. Normal `com.pomosprint.app` uygulamasının SharedPreferences SHA-256 değeri öncesi ve sonrası aynı kaldı. Bildirimler native testte kapatıldı; bu tur bildirim teslimini doğrulamaz.

## Hedef ve Deneme ekranı

Güncel kod ve Türkçe/İngilizce ile native tur **PASS**: KPSS hedefi, dört kademe/alan seçimi, 12 KPSS tanımı, Ek sınavlar → YKS → TYT/AYT görünümü, resmî 130 dk oturumu başlatma ve yaklaşık üç saniye sonra vazgeçme, sıfır ödül ve ardından normal odak başlatıp iptal etme doğrulandı. Boş rapor ekranı iki dilde açıldı. 130 dakikanın gerçek sürede tamamlanması denenmedi. [Test günlüğü](hedef-kpss-pass.txt).

- Hedef KPSS: [TR](hedef-kpss-tr.png), [EN](hedef-kpss-en.png).
- Ek sınavlar/YKS: [TR](ek-sinavlar-yks-tr.png), [EN](ek-sinavlar-yks-en.png). Görüntüler seçili filtrelerde son kontrast düzeltmesini içerir.

## Rapor → Deneme ve süre/net içgörüsü

Yerel **eski politika** ana veritabanında ayrı yeni QA hesabı oluşturuldu. İki deneme başlangıcı kontrollü biçimde 28 ve 3 saat öncesine tarihlendi; aradaki 25 dakikalık normal seans sunucu RPC’siyle oluşturuldu. Yeni hesap ve sahip eşleşmesi, mevcut deneme/aktif seans reddi ile normal seansın son 24 saat içinde olması kontrolleri korundu. Eski politika, bu fixture’daki TYT için 6 kum verir; proposed32’deki güncel 130 kum ödülünü temsil etmez. Test hesabında 330+25 dakika gerçek sürede beklenmedi.

Android native tur **PASS**: Raporlar’daki Deneme ayrıntıları bağlantısı doğrudan Geçmiş’e açıldı; 25 dk ve 19,25 → 27,50 net içgörüsü ile ilişki açıklaması TR/EN göründü; tümü boş derslerin 0 → 0 satırları görünmedi ve iki cüzdan görüntüleme boyunca değişmedi. Bu son tur, boş dersleri filtreleyen güncel ürün koduyla tekrarlandı. [TR](icgoru-tr.png), [EN](icgoru-en.png), [test günlüğü](icgoru-pass.txt).

İlk fixture iki denemeyi 7 ve 3 saat önceye yerleştirdi. Uygulamanın en az 1 gün aralık kuralı nedeniyle içgörü oluşturulmadı ve beklenen içgörü bulunamadığı için bu deneme **FAIL** oldu ([günlük](icgoru-ilk-fixture-fail.txt)). Bu sonuç gizlenmedi; güvenlik kontrolleri gevşetilmeden yeni bir QA hesabı ve 25 saat aralıklı fixture ile yukarıdaki başarılı tur yapıldı.

## Gerçek 50 dakika — devam ediyor

Ayrı `com.pomosprint.qa.nov1r50` kimliğiyle 15:32:27’de gerçek 3000 saniyelik normal odak başlatıldı; cihaz ve sunucu rezervasyonu eşleşti, başlangıç native testi PASS. Planlı bitiş 16:22:27 (İstanbul). Başlamış kullanıcı/marker korunuyor; henüz final sonucu değildir. Başlangıçtan sonra salt okunur sorguda 0 seans/0 puan/0 kum bulundu. Gerçek emülatör kapanıp açıldıktan sonra [ara restore native testi](r50-ara-restore-pass.txt) PASS: aynı marker ve süre korundu, kalan zaman azaldı ve bitmeden ödül oluşmadı ([ekran](r50-ara-restore.png)). Test komutunun sonraki tarihsel 27–29 kaynak-hash parite adımı değişmiş öneri dosyaları nedeniyle FAIL/çıkış 1 verdi; native başlangıç sonucu bundan ayrı değerlendirilmelidir. Ayrı salt okunur DB parmak izi kontrolünde tarihsel 27/28/29+30 referansının şema, migration, katalog ve mail-trigger bölümleri 4/4 eşleşti; bu kaynak guard’ı geçen resmî parite sonucu değildir. Tamamlanma ve tekrar gönderim ancak aynı marker ile son kontrol geçerse raporlanabilir.

## Android release derlemesi

Ayrı QA kopyasında `flutter build apk --release --dart-define=SENTRY_DSN=` başarılı tamamlandı ([derleme çıktısı](qa-release-derleme-pass.txt)). Üretilen `com.pomosprint.qa.nov1android` APK 99.322.133 bayt; SHA-256 `ccf22abb43fb23f06ce95d681db26e8b114e3fcf9fbf8e6723865eb36620b8d6`. `apksigner` imzayı `CN=Android Debug` olarak doğruladı. `key.properties` kullanılmadı; APK debug anahtarıyla imzalıdır ve **mağaza imzası veya yüklenebilir AAB kanıtı değildir**. Boş `.env` ve kapalı Sentry ile yalnız derleme sınandı; release backend bağlantısı doğrulanmadı, APK hiçbir cihaza kurulmadı ve repoya eklenmedi.

## Yerel QA hesabı temizliği

Bu tura ait üç ana yerel QA hesabı (iki kontrollü içgörü fixture'ı ve R50) ile iki izole KPSS QA hesabı korundu. `auth.users` silinmesi profil üzerinden lig politikası tetikleyicisini çalıştırıyor ve onay kayıtlarını anonimleştiriyor; yan etkiler tam belirlenmediği için hiçbir hesapta silme veya rollback silme denemesi yapılmadı. Eski fixture'lara ve canlı hesaplara dokunulmadı.
