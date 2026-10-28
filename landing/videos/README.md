# Gerçek native videolar

Güncel dört dosya `20261028/` altında, [manifest](manifest-20261028.json) ile kayıtlıdır. [Medya rehberi](../screenshots/README.md) cihaz,hesap,dil,gerçek zaman,kaynak ve imleç yöntemini açıklar.

`worker.js` yalnız bu dörtMP4 için256KiB sınırlı Range yanıtı üretir. Normal200/HEAD/304/404 ile206/416/If-Range/cache güvenlik davranışı Node testleriyle sınanır. Daha büyük dosya için sınırı sessizce yükseltmeyin.

TamMOV `build/` altında geçicidir; arşivdeki kaynakMP4 bölümleri stream-copy ile alınmış ve orijinal paketSHA/PTS/DTS dizisiyle doğrulanmıştır. Üretim veya mağaza yayını yapılmadı.
