# Android yerel doğrulama kanıtı — 1 Kasım 2026

Kapanışta yalnız bu turun `nov1r50`, `nov1android` ve `nov1onboarding` QA uygulamaları emülatörden kaldırıldı; normal `com.pomosprint.app` korundu. Bu turun yerel QA hesapları, hesap silme tetikleyicilerinin yan etkileri tam incelenmediğinden korunmuştur.

Cihaz `PomoSprint_QA_API36`. Her iki native tur ayrı geçici `com.pomosprint.qa.nov1android` uygulamasında, yerel Supabase ve açıkça etiketli QA hesaplarıyla koşuldu. Canlı kullanıcı veya veritabanına yazılmadı. Normal `com.pomosprint.app` uygulamasının SharedPreferences SHA-256 değeri öncesi ve sonrası aynı kaldı. Bildirimler native testte kapatıldı; bu tur bildirim teslimini doğrulamaz.

## Hedef ve Deneme ekranı

Güncel kod ve Türkçe/İngilizce ile native tur **PASS**: KPSS hedefi, dört kademe/alan seçimi, 12 KPSS tanımı, Ek sınavlar → YKS → TYT/AYT görünümü, resmî 130 dk oturumu başlatma ve yaklaşık üç saniye sonra vazgeçme, sıfır ödül ve ardından normal odak başlatıp iptal etme doğrulandı. Boş rapor ekranı iki dilde açıldı. 130 dakikanın gerçek sürede tamamlanması denenmedi. [Test günlüğü](hedef-kpss-pass.txt).

- Hedef KPSS: [TR](hedef-kpss-tr.png), [EN](hedef-kpss-en.png).
- Ek sınavlar/YKS: [TR](ek-sinavlar-yks-tr.png), [EN](ek-sinavlar-yks-en.png). Görüntüler seçili filtrelerde son kontrast düzeltmesini içerir.

## Rapor → Deneme ve süre/net içgörüsü

Yerel **eski politika** ana veritabanında ayrı yeni QA hesabı oluşturuldu. İki deneme başlangıcı kontrollü biçimde 28 ve 3 saat öncesine tarihlendi; aradaki 25 dakikalık normal seans sunucu RPC’siyle oluşturuldu. Yeni hesap ve sahip eşleşmesi, mevcut deneme/aktif seans reddi ile normal seansın son 24 saat içinde olması kontrolleri korundu. Eski politika, bu fixture’daki TYT için 6 kum verir; proposed32’deki güncel 130 kum ödülünü temsil etmez. Test hesabında 330+25 dakika gerçek sürede beklenmedi.

Android native tur **PASS**: Raporlar’daki Deneme ayrıntıları bağlantısı doğrudan Geçmiş’e açıldı; 25 dk ve 19,25 → 27,50 net içgörüsü ile ilişki açıklaması TR/EN göründü; tümü boş derslerin 0 → 0 satırları görünmedi ve iki cüzdan görüntüleme boyunca değişmedi. Bu son tur, boş dersleri filtreleyen güncel ürün koduyla tekrarlandı. [TR](icgoru-tr.png), [EN](icgoru-en.png), [test günlüğü](icgoru-pass.txt).

İlk fixture iki denemeyi 7 ve 3 saat önceye yerleştirdi. Uygulamanın en az 1 gün aralık kuralı nedeniyle içgörü oluşturulmadı ve beklenen içgörü bulunamadığı için bu deneme **FAIL** oldu ([günlük](icgoru-ilk-fixture-fail.txt)). Bu sonuç gizlenmedi; güvenlik kontrolleri gevşetilmeden yeni bir QA hesabı ve 25 saat aralıklı fixture ile yukarıdaki başarılı tur yapıldı.

## Gerçek 50 dakika — tamamlandı

Ayrı `com.pomosprint.qa.nov1r50` kimliğiyle 15:32:27’de gerçek 3000 saniyelik normal odak başlatıldı; cihaz ve sunucu rezervasyonu eşleşti ([başlangıç](r50-baslangic-pass.txt)). 16:22:27’de doğal süre doldu ve aynı marker ile final testi **PASS** oldu ([günlük](r50-final-pass.txt), [ekran](r50-final.png)). Salt okunur sunucu sorgusu tek 50 dakikalık seans, 12 temel puan, 0 bonus, 20 normal kum ve tek lig olayı doğruladı. Aynı işlemi tekrar gönderme ikinci puan/kum üretmedi; seansın başlama/bitiş zamanı, çalışma günü ve lig dönemi atfı kontrol edildi. Bu, cihaz bildirim teslimi testi değildir.

Başlangıçtan sonra salt okunur sorguda 0 seans/0 puan/0 kum bulundu. Gerçek emülatör kapanıp açıldıktan sonra [ara restore native testi](r50-ara-restore-pass.txt) PASS: aynı marker ve süre korundu, kalan zaman azaldı ve bitmeden ödül oluşmadı ([ekran](r50-ara-restore.png)). Normal Android uygulamasının SharedPreferences özeti test öncesi ve sonrası aynı kaldı.

Başlangıç, ara ve final native testleri PASS; her sarmalayıcının sonraki tarihsel 27–29 kaynak-hash parite adımı değişmiş öneri dosyaları nedeniyle **FAIL/çıkış 1** verdi. Native sonuçlar bu guard başarısızlığından ayrı değerlendirilmelidir. Ayrı salt okunur DB parmak izi kontrolünde tarihsel 27/28/29+30 referansının şema, migration, katalog ve mail-trigger bölümleri 4/4 eşleşti; bu kaynak guard’ı geçen resmî parite sonucu değildir.

## Android release derlemesi

Ayrı QA kopyasında `flutter build apk --release --dart-define=SENTRY_DSN=` başarılı tamamlandı ([derleme çıktısı](qa-release-derleme-pass.txt)). Üretilen `com.pomosprint.qa.nov1android` APK 99.322.133 bayt; SHA-256 `ccf22abb43fb23f06ce95d681db26e8b114e3fcf9fbf8e6723865eb36620b8d6`. `apksigner` imzayı `CN=Android Debug` olarak doğruladı. `key.properties` kullanılmadı; APK debug anahtarıyla imzalıdır ve **mağaza imzası veya yüklenebilir AAB kanıtı değildir**. Boş `.env` ve kapalı Sentry ile yalnız derleme sınandı; release backend bağlantısı doğrulanmadı, APK hiçbir cihaza kurulmadı ve repoya eklenmedi.

## Yerel QA hesabı temizliği

Ana yereldeki iki kontrollü içgörü fixture hesabı, R50 hesabı ve daha sonra oluşturulan onboarding hesabı ile izole KPSS veritabanındaki iki QA hesabı korundu. `auth.users` silinmesi profil üzerinden lig politikası tetikleyicisini çalıştırıyor ve onay kayıtlarını anonimleştiriyor; yan etkiler tam belirlenmediği için hiçbir hesapta silme veya rollback silme denemesi yapılmadı. Eski fixture'lara ve canlı hesaplara dokunulmadı.

## Android kayıt ve YKS onboarding

Ayrı `com.pomosprint.qa.nov1onboarding` uygulamasıyla yalnız `a1` native senaryosu **PASS**: yeni yerel QA kaydı, zorunlu/isteğe bağlı onaylar, yerel Mailpit doğrulaması, giriş, yaş ve YKS hedefi, önerilen kategoriler, sosyal görünürlük, kurallar, günlük hedef, ekran rehberi, sayaç ve sunucudaki profil/kategori kayıtları doğrulandı. [Günlük](onboarding-a1-pass.txt), [kategoriler](onboarding-yks-kategoriler.png), [rehber](onboarding-rehber.png), [sayaç](onboarding-sayac.png). Mailpit yerel test hizmetidir; gerçek Resend e-posta teslimi denenmedi. Testten sonra eskimiş tarihsel 27–29 kaynak-hash guard’ı FAIL olduğundan wrapper çıkış kodu 1’dir; başarılı native test ile bu uyarı farklı sonuçlardır. Bu yeni yerel QA hesabı da korunur; canlıya veya diğer hesaplara dokunulmadı.
