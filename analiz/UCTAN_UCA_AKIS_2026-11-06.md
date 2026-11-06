# Uçtan uca akış kontrolü — 6 Kasım 2026

Bu rapor, yerel sentetik hesaplar ve izole test veritabanlarıyla yapılan uygulama ve lig çalışmalarını kaydeder. Bu testlerde üretimde hesap oluşturulmadı, gerçek kişilere e-posta gönderilmedi ve gerçek kullanıcı verileri test veritabanına kopyalanmadı. Ayrı olarak, kullanıcı izniyle canlı parola sıfırlama e-postası testi yapıldı; [e-posta raporuna](MAIL_KONTROLU_2026-11-06.md) bak. Sunucuya dağıtım yapılmadı. Testlerdeki kısa/geçmiş zamanlar doğal gerçek süre geçişi değildir. 31 numaralı paket uygulanmadı.

## iPhone: gerçek uygulama arayüzü ve yerel servis

`a5b4f9a` kaynaklı ayrı geçici worktree ve `com.pomosprint.qa.e2e` bundle kullanıldı; iPhone 17 simülatöründeki mevcut uygulama verileri silinmedi. Yeni boş test veritabanına yalnız yerel şema ve açık katalog/yapılandırma listesi kopyalandı. Ona özel Auth ve PostgREST, yalnız loopback API üzerinden sunuldu. Gerçek `main()` ile çalışan test aşağıdaki akışı **1/1** tamamladı:

- Kayıt ekranında sentetik ad/e-posta/parola ve gerekli onaylarla yeni hesap açma.
- Türkçe onboarding: yaş, YKS hedefi, önerilen dersler, görünürlük, kurallar, hedef ve ekran rehberi; ardından normal sayaç/kabuk.
- Authenticated PostgREST üzerinden kendi profilinde doğum yılı, hedef, günlük hedef ve onboarding kaydı; ders isimleri ve sıraları.
- Raporlar, Sıralama, Sosyal ve Deneme sekmelerine geçiş ve ekranların açılması.

Bu testte Auth **otomatik onay** kullandı; kayıt e-postasının gönderilmesi, Mailpit'ten doğrulama veya gerçek e-posta teslimi bu akışla doğrulanmadı. Gerçek 25/50 dakika beklenmedi; seans tamamlaması, gerçek ödül, dolu sosyal ekran, bildirim ve mağaza derlemesi native turda sınanmadı. Türkçe/iPhone testi bu koşuda İngilizce, Android, fiziksel cihaz veya gerçek sağlayıcı hesabı testinin yerini tutmaz. Geçici worktree başlangıç commit'i belirtilmiştir; diğer eşzamanlı kaynak değişiklikleri bu native turda bulunmayabilir.

İlk çalışmada gerçek kayıt ve onboarding tamamlandı; testin PostgREST sıralama kontrolü SDK'nın azalan varsayılanını kullandığı için yanlış beklenen değerle kaldı. Test yardımcısına açık `ascending: true` verilerek tekrar çalıştırıldı; bu, uygulamada bir kategori sıralama hatası değildi. İkinci çalışmada yukarıdaki sonuçlar geçti. Önceki 15 dakikalık test ortamı zaman aşımı kendi izole kaynaklarını kapattığından test yeniden boş bir klonla yapıldı.

## Lig ve sosyal: ayrı yerel veritabanları

- **Hedef/global lig 46/46:** kullanıcı verisi kopyalamayan ayrı klonda dört sentetik LGS/TUS hesabı, normal çalışma ve deneme kayıtları, iki hedef ve global görünüm, ödül/ekonomi kayıtlarının salt okumada değişmemesi kontrol edildi. Denemelerde geçmiş zamanlı fixture kullanıldı; doğal ay sonu cron veya gerçek sınav süresi beklenmedi.
- **Sosyal 19/19:** ayrı klonda beş sentetik hesapla arkadaşlık isteği ve kabul, odaklanan/denemedeki/moladaki arkadaşların görünmesi, bağlantısız hesap izolasyonu, kendine istek, engelleme ve engel kaldırma sınandı. Mola, gerçek Maraton tamamlamasıyla değil profil durumuna konan açık test fixture'ıyla üretildi. 19 sayısına klon kaynağı ve temizlik kontrolleri de dahildir.

İlk sosyal test denemesi test yardımcısının `void` yanıtı JSON olarak okumasından durdu; kendi klonu temizlendi. Yardımcı düzeltildikten sonra yukarıdaki sonuçlar geçti. Bunlar yerel PostgreSQL RPC testleridir; çok cihazlı gerçek zamanlı ağ/üretim kullanıcıları veya doğal dönem geçişi kanıtı değildir.

## Temizlik ve kanıt sınırları

Native QA bundle kaldırıldı; bu testin açtığı Auth/PostgREST container'ları, gateway ve oluşturulmuş geçici veritabanları güvenli şekilde kaldırıldı. Önceden çalışan diğer projelerin container'ları ve kullanıcı uygulaması/verileri korunmuştur. Loglar test çalıştığı makinede `/tmp/pomosprint-native-ui-e2e-final-20261106.log`, `/tmp/pomosprint-flow-global-20261106.log`, `/tmp/pomosprint-flow-social-rerun-20261106.log` yollarındadır; `/tmp` kalıcı arşiv değildir.
