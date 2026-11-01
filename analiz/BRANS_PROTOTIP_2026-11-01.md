# Alan denemesi prototipi — 1 Kasım 2026

> **Tarihsel kayıt:** Kullanıcının sonraki isteği üzerine prototip kodu ve ayrı simülatör uygulaması kaldırıldı. Aşağıdaki anlatım geçmiş önizlemeye aittir; şu anda çalıştırılabilir bir özellik değildir.

Kullanıcı özelliği önce prototip olarak görmek istiyor. Bu çalışma gerçek özellik veya yayın onayı değildir. `lib/prototypes/branch_preview_main.dart` bağımsız bir önizleme girişidir; normal `lib/main.dart` akışına bağlanmaz. Sınav ve ders seçeneklerini uygulamanın yerel varsayılan kataloğundan okur; hesap, ağ, Supabase, kum cüzdanı veya rapor servisini başlatmaz. Veriler bellektedir, uygulama kapatılınca kaybolur.

- Taslak seçenekler: 25/50/75 dakika için sırasıyla örnek 20/40/60 deneme kumu; lig puanı yok. Bunlar gerçek ödül değildir.
- Deneme turu görmek için önizleme sayacı açıkça belirtilen **5 saniyeye** iner. Gerçek uygulamanın 25/50 dakikalık süreleri değiştirilmedi.
- Örnek doğru ve yanlışlardan boş ve net hesaplanır; sonuç hiçbir yere kaydedilmez. Soru sayısı 1–200 aralığında doğrulanır.
- Kullanıcı incelemesi sonrasında gerçek uygulamaya alınıp alınmayacağına ve gerçek sunucu/veri sözleşmesine ayrıca karar verilir. Paket 31 uygulanmadı; herhangi bir canlıya alma yapılmadı.

Deneme ekranındaki kart ve sekme görünümleri ve raporların dönem sekmeleri kaynak kodda sadeleştirildi; hesaplama veya veri akışı değiştirilmedi. Kayıtlı normal uygulama bu oturumda bu değişikliklerle yeniden yüklenmedi.

## Güvenli cihaz önizlemesi

Simülatördeki önizleme, `/tmp/pomosprint-branch-preview-20261101` içindeki geçici proje kopyasından ayrı `com.pomosprint.qa.branchpreview` bundle kimliğiyle açıldı. Normal `com.pomosprint.app` ve HocamMacVar üzerine yükleme yapılmadı. Bu geçici dizin kalıcı bir kurulum yolu değildir; normal proje kimliğiyle prototip hedefini çalıştırmak mevcut uygulamanın üzerine yükleyebilir. Tek iOS simülatörü ve tek Android AVD korunur.

## Testler

- `flutter analyze`: temiz.
- Tam `flutter test --concurrency=2`: **1506 geçti**, isteğe bağlı ekran görüntüsü üretimine ait **5 atlama**. Sonrasında ödül ifadesi örnek olduğunu daha açık belirtecek biçimde yerelleştirildi; ilgili prototip testleri ve analiz tekrarlandı.
- Türkçe ve İngilizce widget testleri süre/kum seçeneklerini, 1–200 soru doğrulamasını, örnek sayaç akışını, boş/net hesabını ve SharedPreferences'a yazılmadığını sınadı. Bunlar gerçek ödül, sunucu veya rapor kaydı testleri değildir.
- iPhone 17 simülatöründe ayrı bundle derlendi ve başlangıç ekranı görsel olarak kontrol edildi. Bağımsız önizleme girişi Türkçeye sabittir; İngilizce bu girişte elle seçilemez, widget testiyle kontrol edildi. Esas uygulamaların Documents, Preferences ve Application Support dizinlerinin içerik hash'leri, ilk önizleme öncesi ve sonrasında değişmedi; bu kontrol tüm cihaz verilerinin veya keychain'in kanıtı değildir.
- Daha önceki tam QA sonuçları ve hâlâ açık canlı ödül güvenliği, iOS kayıt ve diğer yayın kısıtları için [önceki QA raporu](QA_2026-11-01.md) ve [güvenlik notuna](OFFLINE_ODUL_GUVENLIK_NOTU_2026-11-01.md) bak. Bu prototip bu konuları çözmez.
