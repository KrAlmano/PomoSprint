# Rapor ve net girişi iOS önizleme kanıtı — 1 Kasım 2026

Bu dört ekran, ayrı `com.pomosprint.qa.reportpreview` QA uygulamasıyla, `HocamMacVar · iPhone 17` simülatöründe (iOS 27.0) çekildi. Normal PomoSprint / HocamMacVar uygulaması veya hesapları değiştirilmedi; canlı Supabase, gerçek hesap ve gerçek kullanıcı verisi kullanılmadı.

Önizleme, uygulamanın güncel `lib/screens/reports_screen.dart`, `lib/screens/exam_screen.dart`, `lib/widgets/exam_results_dialog.dart`, `lib/widgets/shell_navigation.dart` ve `lib/widgets/shell_app_bar.dart` bileşenlerini kullanır. Bunlar ayrı QA kabuğuna yerleştirildi; görünüm üretim uygulamasının gerçek etkileşimli kullanıcı yoluyla test edilmiş olduğunu kanıtlamaz. Sunucular ve kayıtlar yalnız bellek içi fake servislerdendir: örnek TYT ve AYT sonuçları, 29 puan ve 80 kum kurgudur. Fixture ve geçici QA giriş kaynağı `/tmp/pomosprint-reports-preview-20261101/lib/preview_reports_main.dart` ve `/tmp/pomosprint-reports-preview-20261101/lib/preview_support/` altındaydı; `/tmp` kalıcı bir proje kaynağı değildir.

Rapor geçmişinde AYT Matematik (25 doğru, 6 yanlış) ve ayrı TYT kaydı; sonuç girişinde TYT Türkçe ve 29 doğru / 7 yanlış / 4 boş örneğiyle Temel Matematik görünür. Ekran raporları gerçek uygulama testine eşdeğer değildir.

Ham dosyalar `xcrun simctl io … screenshot` ile **1206 × 2622 px** kaydedildi; çentik veya Dynamic Island pikselleri bulunmaz. Web türevleri telefonda ölçeklenirken ayrı üretilir. Dört karede geçici durum çubuğu override ile 09:41, pil %100 charged, Wi-Fi 3 ve hücresel sinyal 4 kullanıldı (iOS 27 yeşil şarj göstergesi). Çekim sonunda `simctl status_bar … clear` yapıldı ve `list` boş döndü. Cihazın dili/kalıcı ayarları değiştirilmedi.

| Ham ekran | SHA-256 |
|---|---|
| [exam-results-en.png](native/exam-results-en.png) | `a4f6fb3dbb5f012938a4ed06b1d8c434ad70c459994284c70e0c4ffe6a91b7a1` |
| [exam-results-tr.png](native/exam-results-tr.png) | `23358d59a3a1521a17fc4f4681666eed7ab853112d2d4cd4b7d927fdda98c716` |
| [reports-exam-history-en.png](native/reports-exam-history-en.png) | `9de4da96d75ac5e6710ac191b4d605b618c4485dc473ac9cb22a8af637fab51d` |
| [reports-exam-history-tr.png](native/reports-exam-history-tr.png) | `a8cecb0aa3f1c9f5e2709a6c619e8db92c3174a45d4f2d05bc6b183cc66a4fb6` |
