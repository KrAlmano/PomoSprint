# Android öneri32 native arşivi

Bu arşiv36 dosya (~3,3 MB) içerir; `manifest.json` kaynak yolu/kaynakSHA/çıktıSHA/bayt/dönüşümü kaydeder. `<REPO>` ve `<TMP>` özgün makine yolunun yer tutucularıdır. Resimlerin byte'ları değişmedi; log/JSONlardaki mutlak yol veCRsatırları taşınabilir hâle getirildi. Manifest ve bu indeks kendi hash'ini listelemez.

- `a1/`: Host403 hatası ve native FAIL; signupöncesi, hesapoluşmadı.
- `a2/`: ÖncekiPASS,21/21 SQL ve 8 ayrıPNG. P1 öncesi baz çizgi; a3 kodhash'i a2'ye atfedilmez.
- `a3/`: P1 sonrasıPASS,21/21 SQL,8 PNG,kısaözet ve `proof.json`. `source_proof_original.json` ilk build kanıtıdır; `proof.json` arşiv yollarına çevrilmiştir. Kaynak kodSHA'ları gerçek a3 anınıtanımlar.
- `verification/`: Öncesi/a2 sonrası/a3 sonrası32 paritesi.
- `client_validation/`:113 darFluttertesti,10 dosyaanalizi,root 7 mahremiyettesti,bağımsızP1 bulgusu ve kusuru yenidenüreten2 test. Sonuncu başarıları kusurun tekrarıdır, düzeltmenin testi değildir.

`a3/proof.json` bütün görüntü ve kanıtlara arşiv içi göreli yollarla bağlanır. `source[]` yolları proje köküne göredir; hash'leri arşivleme sırasında mevcut kaynaklarla tekrar doğrulandı. Yeni Android turu ve eski a2 ownerkoruma SQL'i bu proof'tadır. iOSkanıtı burada yoktur; soniOSsonucuroottarafından eklenecektir.
