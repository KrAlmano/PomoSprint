# Güncel dört tanıtım videosunun incelemesi

**Teknik kontroller ve bağımsız kaynak doğrulaması 4/4 geçti.** Her videonun ilk, orta, son, gerçek dokunmadan 0,1 saniye sonraki ve 0,6 saniye sonraki kareleri çıkarıldı. Toplam 20 PNG gerçekten açılıp görüntü olarak incelendi. Kaynak çekim `site-oct28-ui-a1`; güncel kurgu Deniz hesabı `ca271e26-fc2c-44b6-b88f-9537f809639c`.

| Video | Bayt | Süre (sn) | H.264 / sessiz / sınır | Kaynak paketleri |
|---|---:|---:|---|---|
| timer-tr.mp4 | 216213 | 24.791667 | PASS | 1288 / PASS |
| marathon-tr.mp4 | 203877 | 21.958333 | PASS | 1263 / PASS |
| timer-en.mp4 | 202975 | 24.833333 | PASS | 873 / PASS |
| marathon-en.mp4 | 224919 | 22.000000 | PASS | 554 / PASS |

Tüm videolar 540 × 1170, 24 fps, H.264/yuv420p; ses akışı yok ve her dosya 256 KiB sınırının altında. Özgün MOV ile kesilmiş native MP4 dosyalarının paket SHA-256 dizileri ve sabit PTS/DTS kaymaları bağımsız karşılaştırıldı. Dört video da eşleşti. Son kodlama süreleri, bildirilen sahne sürelerinden en fazla bir 24 fps karesi kadar farklı; hızlandırma bulgusu yok.

TR/EN metinleri, 09:41 saati, beş alt sekme ve 29 puan / 80 kum görüldü. TEST rozeti veya 5/10 saniye modu görünmüyor. Gerçek olay kayıtlarındaki toplam 34 dokunmanın zamanları ve koordinatları manifestle eşleşiyor. Timer imleci 50 dakika düğmesine denk geliyor; sonraki karede 50:00 ve seçili düğme görülüyor. Maraton imleci 4 seans dairesine denk geliyor; sonraki karede 4 seans, 100 dakika odaklanma, molalarla yaklaşık 115 dakika ve +5 ek puan görünüyor.

**Sunum notları:** Timer videolarının orta karelerinde duraklatma hakkı uyarısı ana düğme alanını örtüyor. Maraton videolarında beklenen başlangıç bildirimi var. Son karelerde Start/Başlat düğmesi okunuyor; geçişten kaynaklanan hafif yumuşama görülüyor. Bunlar kritik görsel hata olarak sınıflanmadı.

Manifest güncel fixture SHA'sıyla ve güncel hesapla eşleşiyor; eski hesaplar manifestte bulunmuyor. Kaynak videolar, uygulama kodu, veritabanı veya servisler bu incelemede değiştirilmedi. 52.229.976 baytlık ham MOV tekrar arşivlenmedi. Önceki kanıtlar `build/native_site_media/pre-ui-published-backup/` altında korunuyor.

Bu statik örnekler bütün bir 25/50 dakikalık seansın veya Maratonun tamamlandığını kanıtlamaz. Ayrıntılı teknik alanlar, kaynak/çıktı SHA'ları ve 20 PNG'nin hash'leri [technical_checks.json](technical_checks.json); görsel kapsam ve sonuçlar [review.json](review.json) içinde.
