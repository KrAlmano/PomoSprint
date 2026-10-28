# A görsel inceleme — 28 Ekim 2026

Yalnız aşağıdaki 12 mevcut PNG'yi `view_image` ile açıp inceledim. Ek olarak ilk ve üçüncü görüntünün alt gezinme alanlarını yan yana gösteren, yalnız analiz amaçlı `external/tmp/pomosprint_A_nav_contact.png` hazırladım. Kaynak resimler değiştirilmedi; native uygulama, adb, katalog, proxy veya repo üzerinde işlem yapılmadı.

İncelenen karelerde klavye, beklenmeyen hata/çökme ekranı, kaybolmuş alt gezinme veya kalıcı görünen bileşen çakışması saptamadım. Bu sonuç yalnız seçilen statik kareler içindir; animasyon, etkileşim, erişilebilirlik kontrastı veya diğer ekranlar için görsel onay sayılmaz.

Kök: `analiz/ekran_dogrulama_2026-10-28/`

| Açılan PNG | Gözlenen |
|---|---|
| `android-official/e2e-ad-official-history-en.png` | EN düğmeler ve geçmiş; TUS Clinical/Basic100 soru / 135 dk, LGS Quantitative40 / 80 dk; Abandoned/No reward açık. Beş alt sekme eksiksiz. Uzun geçmiş doğal olarak aşağı devam ediyor. |
| `ios-official-retry/e2e-ad-official-history-tr.png` | TR karşılıklar doğru; TUS100 / 135, LGS Sayısal40/80; Vazgeçildi/Ödül yok okunuyor. Avatar ve üst puan/kum alanları hizalı. |
| `android-short-retry/e2e-ad-net-offline-en.png` | EN çevrimdışı uyarı tam okunuyor: sonuç cihazda saklanıp bağlantı gelince gönderilecek. Beş sekme görünür, klavye yok. Üstte önceki kartın bir bölümü scroll konumu nedeniyle kesiliyor.1 dk / 0 ödül kısa fixture davranışı. |
| `ios-short-retry2/e2e-ad-nets-lgs-verbal-tr.png` | TR kayıtlı geçmiş ve “Netlerin kaydedildi” bildirimi; kalıcı taşma görünmüyor. Kadraj scroll nedeniyle YDT/AYT kartlarını gösteriyor, adına rağmen LGS Sözel başlığı görünür değil. Kaydet bildirimi alttaki düzenleme düğmesini kısmen örtüyor. |
| `verify-android-reports-positive/e2e-ad-daily-tr.png` | Normal seans 1, tamamlanan Maraton 0, deneme 1; Deneme 2 sa 15 dk + Matematik 25 dk birlikte 160 dk. Deneme süresinin derslere dağıtılmadığı açıklaması okunuyor. Beş sekme ve TR etiketler düzgün. Toplam/hedef halkası bu scroll kadrajında değil. |
| `verify-ios-reports-positive/e2e-ad-weekly-en.png` | EN Session types:4 regular / 0 marathon / 1 exam; açıklama ve bağlantı sarılarak sığıyor, Mathematics 1 h 40 m görünüyor. Sağdaki “Monthly Tracking” sekmesinin sonu sağ kenarda kesiliyor. |
| `verify-android-leagues-a5/e2e-af-study-global-en-private.png` | Global açıklaması, ay sonu sayacı, sıralama ve puanlar okunuyor. English UI içinde “QA Deneme Geçmişi/QA Gerçek Maraton” gibi TR sahte kullanıcı adları var; bunlar çevrilmeyen arayüz metni değil. Özel peer'ın globalden yokluğunu tek kareyle tanımlayamazken testin SQL/RPC karşılaştırması bunu doğrulamıştı. |
| `verify-ios-leagues-final/e2e-af-exam-segment-tr-private.png` | Gizli satır “Kullanıcı”, kimlik/avatar yok;15 puan ve sıra korunmuş. Deniz LGS kendi satırı görünür. Bronz Lig, dönem sonu ve az kullanıcı açıklaması sığıyor. Deneme ligi avatarlarının hazırlanıyor açıklaması mevcut; uydurma ödül görseli gösterilmiyor. |
| `verify-android-social-a7/e2e-af-tr-privacy-off.png` | TR Odaklanıyor/Denemede/Molada etiketleri; odak/deneme kırmızı, mola yeşil noktalar. Gizlilik kapalı aktör çıkarıldıktan sonra yedi arkadaş kartı okunur, boşluklar/hizalar düzgün. |
| `verify-ios-social-retry/e2e-af-en-focus-ended.png` | EN Focusing/Taking an exam/On break doğru. İlk kartın üstü scroll başlığı arkasında kısmen kalmış; diğer kartlar ve beş sekme okunur. Bu kare bütün listeyi üstten sunan bir promosyon kadrajı değil. |
| `verify-android-old-a8/e2e-a8-old-en-exam-unavailable.png` | Eski sunucuya uygun “Practice mode is coming soon” ve bağlantı gereksinimi açıklaması İngilizce. YKS/LGS/TUS seçenekleri, TYT 120 soru / 165 dk ve net formülü görünür; etkin başlatma uydurulmamış. Klavye/çökme ekranı yok. |
| `verify-ios-insights/e2e-insight-positive-tr.png` | “İlişkili çalışma kategorilerinde 25 dk; Türkçe neti 19,25 → 27,50” doğru ve okunur. Takip eden 0 dk / 0 → 0 kartları da görünür; fixture diğer dersleri açıkça 0 sonuçla doldurduğu için bunları eksik veri hatası olarak sınıflandırmadım. Bu karede nedensellik uyarısı görünmüyor; ayrı uyarı PNG'sini bu 12'li incelemede açmadım. |

## Takip noktaları

1. **Küçük sekme görünümü:** EN iOS haftalık raporda sağdaki “Monthly Tracking” tam görünmüyor. Kaynakta bu alan yatay `SingleChildScrollView` olarak tasarlanmış (`reports_screen.dart`, `_buildTabBar`); statik kareden sekmenin erişilemez olduğu söylenemez. Yatay kaydırma davranışının varlığı bu görsel kırpılmayı açıklıyor, ama B için seçili sekme/etiket bütünüyle görünür bir kadraj seçilmeli. Ürün değişikliği yapmadım.
2. **QA kanıtı ≠ site medyası:** Kısa deneme karelerinde1 dk / 0 ödül, teknik QA adları, scroll ile kesilmiş kartlar ve kaydet bildirimi var. Bunlar kısa yerel test için doğru; mevcut A görüntüleri B'ye doğrudan taşınmamalı. B'nin ayrı tek Deniz hesabı, gerçek katalog, başa alınmış scroll ve Snackbar/klavye guard'ı bu sınırlara yöneliktir.
3. **İçgörü fixture sunumu:** Gerçek 25 dk / 19,25 → 27,50 kartı açık.0 dk / 0 → 0 kartlarını yanlış hesap diye işaretlemiyorum; bu fixture tüm derslere sonuç girdi. B'de kısmi/gerçekçi ders sonuçlarıyla hedef içgörünün öne çıkması daha anlaşılır bir gösterim sağlar; filtre/ürün özelliği eklenmedi.

Görsel blocker saptamadım. EN rapor sekme kenarı ve QA çekim kadrajı/sunum sınırlamaları rapora taşınmalıdır. On iki kare dışındaki PNG'ler, landscape/büyük yazı düzenleri ve videolar bu incelemeye dahil değildir.
