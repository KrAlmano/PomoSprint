# iOS öneri32 native arşivi

21 dosya, yaklaşık6,4 MB. `manifest.json` kaynak ve arşivSHA-256 larını/baytları kaydeder. Loglardaki makine yolu `<REPO>`/`<TMP>` olarak taşınabilirleştirildi; PNG byte'ları değişmedi. Manifest/indeks kendi hash'ini içermez.

- `a1/`: NativeFAIL günlüğü,8 PNG ve iOSbildirim izni görüntüsü. TR/EN erkenbitiriş/net/duplicate/report geçti; finalnormalbaşlat adımı izin yanıtı beklediğinden bütünkoşuFAIL sayılır.
- `a2/`: Root'un son native PASS günlüğü,8 PNG,independent_sql.json ve proof.json. Türkçe5 sn+İngilizce5 sn, planlanan 10800 sn,0 dakika ve 0 ödül; report1→2, normalodakbaşlat/iptalPASS.

A2 process exit 0 root tarafından tool session24677 için bildirildi; native günlük ayrıca All tests passed içerir. SQL21/21 arşivleyen ajan tarafından final DB'de salt okunur çalıştırıldı. Kaynakhash'leri arşivlemeanında dondurulmuşAndroida3 hash'leriyle eşleşti; bunlar binary'den çıkarılmış hash değildir.

Arşivleyenajan hiçbir iOS cihaz/uygulama işlemi yapmadı. Root bu cihazı siteçekimine devraldı. `.env`,APIkey,defines,token,hamSharedPreferences ve buildbinary'si arşive alınmadı.
