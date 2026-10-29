# KPSS yerel sunucu kanıtı

- SQL:242/242, [sql-results.json](sql-results.json).
- Ağsız guard/oracle/host/parite:74/74.
- Salt okunur parity:5/5, şema/migration/katalog/welcome/politika.
- Yerel ham SQL: `build/isolated32_kpss/20261028T195601Z-416360a4/`.
- İncelenmiş referans: [reviewed_exam32_kpss_20261028.json](../../tool/local_supabase/parity/reviewed_exam32_kpss_20261028.json).
- Kaynak sonuç dosyası SHA256: `c0baf64ef70ab6ae22a0c613aeb362a4e501201bc66e0f11781f3f67284528da`.
- Başarısız ilk tur korunmuştur: `build/isolated32_kpss/20261028T195453Z-32f7381f/`; fixture gizlilik beklentisi düzeltildi.
- Canlıya, ana DB'ye, DUS review/site DB'lerine yazılmadı;31 kurulmadı.
- Bu kanıt kontrollü SQL fixture'larıdır, native veya gerçek130dakika testi değildir.

## Uygulama ve native kapsamı

- [Tam uygulama kapısı](full-gate/manifest.json): analiz temiz, Flutter 1493 PASS / 5 isteğe bağlı PNG atlaması, Node 173/173, ortak parçalar temiz. Ürün kaynakları bundan sonra değişmedi; yalnız native testin zaman/uyarı yönetimi düzeltildi.
- [iOS tanı arşivi](ios_diagnostics/README.md): **NATIVE_NOT_VERIFIED** durumundaki ilk girişimlerdir. Dört kısmi TR görüntü ve başarısız denemeler, sonraki başarıdan ayrı tutulur.

- [29 Ekim son iOS turu](ios/manifest.json): TR/EN PASS, 8 PNG; orijinal tercihler aynı.
- [Kapanış ve normal uygulama](closure/manifest.json): son test analizi temiz, Node173, partials, normal build/install/launch ve taslak korunması PASS.
