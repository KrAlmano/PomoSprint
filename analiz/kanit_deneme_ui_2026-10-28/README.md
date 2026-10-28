# Kompakt Deneme arayüzü — sınırlı doğrulama paketi

Bu paket yalnız Deneme ekranının sadeleştirilmesini doğrular. **40 seçili Flutter testi başarılı**, **14 dosyanın Dart analizi temizdir**. Bu sayılar tüm projenin veya tüm yerel testlerin geçtiği anlamına gelmez; son genel kontrol kök ajan tarafından ayrıca yapılır.

Yeni arayüz: eşit 48 pt Yeni/Geçmiş/Lig sekmeleri, tek net kuralı kutusu, Tümü seçeneği dahil beş filtre, küçük soru/süre etiketleri ve kart başına bir başlatma düğmesi. Uzun ders paragrafları kaldırıldı. Süreler, ödüller ve sunucu sözleşmesi değişmedi. Eski anlamlı çeviri anahtarları korundu; üç kısa sekme için yeni anahtarlar ve sabit widget anahtarları kullanıldı.

Altı görünüm senaryosu TR/EN × (320 × 740 normal,320 × 740 iki kat yazı,740 × 320 yatay iki kat yazı) içerir. Kontroller eşit sekme boyutunu, en az 44 pt etkileşim alanını, taşmayan filtreleri/etiketleri ve başlatmadan önce mevcut kurallar iletişimini ölçer. Diğer seçili testler net formu, sahip değişimi, çevrimdışı kayıt, eski/yeni sunucu yetenekleri ve çeviri bütünlüğünü kapsar.

İlk geliştirme turunda görülen büyük İngilizce etiket taşması ve sekme yüksekliği düzeltildi. Filtre testinin kaydırma sonrası koordinat ölçümü de düzeltildi. Son kayıtlar [flutter-selected-final.log](flutter-selected-final.log) ve [analyze-final.log](analyze-final.log); ayrıntılı kapsam [summary.json](summary.json).

[manifest.json](manifest.json) son19 kaynak dosyasının SHA-256 değerlerini, kanıt dosyalarının hashlerini ve asıl günlüklerin hashlerini içerir. Günlüklerde yalnız mutlak depo yolu kaldırıldı; sır, ortam dosyası, ham tercih veya derleme çıktısı eklenmedi. Yerel cihaz veya veritabanına bu arşivleme adımında dokunulmadı.

Son arayüzle çekilmiş 15 Türkçe karenin bağımsız görsel incelemesi: [tr.md](../ekran_site_2026-10-28/visual_review/tr.md). Bu görsel inceleme 40 testten ayrı kanıttır.
