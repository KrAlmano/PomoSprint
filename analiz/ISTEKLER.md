# Gece çalışma listesi — 27/28 Ekim 2026

Başlangıç: `036fa60`. Dal: `codex/gece-2026-10-27`. Bitiş: **28 Ekim 2026 07:00 Europe/Istanbul**.

Durumlar: bekliyor / sürüyor / tamamlandı / kısmi / karar bekliyor. Tamamlandı işareti yalnız gerçekten çalıştırılmış kontroller ve commit kaydıyla verilir.

## Çalışma sınırları

- Yalnız yerel Supabase ve yerel test hesapları; canlı servise istek, veri yazma, deploy, push, main commit, merge, rebase ve hard reset yok.
- `.env` dosyaları okunmaz; sırlar, sertifikalar, keystore ve `.claude/settings.local.json` commit'e girmez.
- Her commit öncesi `flutter analyze` ve `flutter test`; site değiştiyse ayrıca `cd scripts && npm test`.
- Her yeni madde öncesi `analiz/DENETIM.md` okunur; ❌ D-xx bulguları önceliklidir. Denetçi dosyası değiştirilmez ve commit'e alınmaz. `../Pomodoro-denetim` kullanılmaz.
- iOS 18.6/27 için yeni QA cihazları ve `PomoSprint_QA_API36` Android AVD kullanılabilir. `HocamMacVar · iPhone 17` korunur. Kanıtlar `analiz/ekran_gece_2026-10-28/` altında tutulur.
- Puan/kum/seri/lig sunucuda hesaplanır. Seans veya deneme sessizce silinmez. 13–17 veli izni ve mevcut yaş/13 altı engeli değişmez.
- 07:00'da yeni iş başlatılmaz; güvenli sonuç ve `GECE_RAPORU_2026-10-28.md` commit edilip durulur.

## I-01 — TUS hedefi

Durum: bekliyor.

Bitti sayılması için: TUS hedefi TR/EN onboarding'de seçilir. Temel tıp (Anatomi; Fizyoloji, Histoloji ve Embriyoloji; Biyokimya; Mikrobiyoloji; Patoloji; Farmakoloji) ve klinik (Dahiliye; Pediatri; Genel Cerrahi; Kadın Hastalıkları ve Doğum; Küçük Stajlar) kategorileri sunulur. Mevcut kategori limiti korunur. Segment constraint proposed/rollback/DRYRUN hazırlanır; eski sunucuda onboarding çökmez; testler geçer.

## I-02 — Deneme modu

Durum: bekliyor.

Bitti sayılması için: Sunucu kataloğundan tür/süre/soru seçimi, güvenli yerel katalog, 3-2-1 başlangıç, duraklatmasız ve molasız sayaç çalışır. Sunucu onayı olmadan ödüllü deneme başlamaz. Arka plan, kapanma, yeniden açma ve vazgeçme kayıtları güvenle korunur. TYT120/165dk, AYT160/180dk, YDT80/120dk, LGS50/75dk ve40/80dk, TUS2×100/135dk resmî kaynaklarla belgelenir. YKS/TUS D−Y/4, LGS D−Y/3 doğrulanır. Normal25/50 ve Maraton bozulmaz.

## I-03 — Deneme sunucusu

Durum: bekliyor.

Bitti sayılması için: Sunucu saatli başlat/bitir/vazgeç RPC'leri; erken bitirme, çakışma ve tekrar gönderim koruması; ayrı deneme kumu; owner-only deneme/net RLS; migration/rollback/DRYRUN ve uygulama sırası vardır. Yerel yetki, eşzamanlılık ve E2E kontrolleri geçer. Canlı eski sunucuda özellik güvenle kapalıdır. Lig şeması I-04/I-05/I-16 ile tek pakettedir.

## I-04 — Bütün ligler aylık / İstanbul 00:00

Durum: bekliyor. I-05 ve I-16 ile birlikte tasarlanır.

Bitti sayılması için: Normal ve deneme ligi ayın1'i00:00 Europe/Istanbul'da yenilenir. 14 günlük aktif dönemden geçiş puan/ödülü korur. İstemci, site ve rehberler tutarlıdır. Çalışma günü/seri04:00 kalır. Ligle ilgili tablo değişiklikleri tek proposed pakette, rollback/DRYRUN ve sınır testleriyle sunulur.

## I-05 — Ayrı deneme ligi

Durum: bekliyor. I-04 ve I-16 ile birlikte tasarlanır.

Bitti sayılması için: Normalden bağımsız aylık deneme puanı/sıralama/kademeler/ödüller vardır. Yalnız tam süreli tamamlanan deneme kazanır. Özel avatar kategori/slotları, gerçek görsel gelene kadar güvenli yer tutucu destekler. Eksik görsel yayını bozmaz; gerçekte olmayan ödül gösterilmez.

## I-06 — Denemelerim ve netler

Durum: bekliyor.

Bitti sayılması için: Tarih, başlangıç-bitiş, tür, süre ve terminal durum görülebilir. Ders bazında doğru/yanlış/boş doğrulanır, net otomatik hesaplanır; sonra girme/düzenleme desteklenir. Netler ekonomiyi etkilemez; yetki ve tekrar gönderim testleri geçer.

## I-07 — Süre–net içgörüleri

Durum: bekliyor.

Bitti sayılması için: Çalışma kategorileri deneme derslerine tutarlı eşlenir. Yeterli karşılaştırılabilir veriyle süre ve net değişimi açıklanır; yetersiz veri yanıltıcı neden-sonuç iddiası üretmez. TR/EN, tarih aralığı ve eşleme testleri geçer.

## I-08 — Sosyal durumlar

Durum: bekliyor.

Bitti sayılması için: Odaklanıyor/Molada/Denemede TR/EN görünür. Molada yalnız Maraton içindir. Gizlilik ve engelleme korunur; geç kalmış normal iptal deneme durumunu silemez. Her durum birim testi ve çok hesaplı yerel E2E ile doğrulanır.

## I-09 — Giriş logosu

Durum: bekliyor.

Bitti sayılması için: Üst saat mevcut uygulama logosuyla değişir. Açık/koyu tema, küçük ekran ve büyük yazıda taşma olmaz; yeni logo tasarlanmaz.

## I-10 — Kayıt/onboarding native E2E

Durum: bekliyor.

Bitti sayılması için: iOS18.6, en az bir tam iOS27 turu ve Android API36'da yeni kayıt → yerel Mailpit onayı → giriş → dil/hedef onboarding (TUS dahil tüm hedefler) → ilk normal seans → ilk deneme doğrulanır. Gerçek zamanlı koşular ile kontrollü fixture koşuları raporda ayrılır; kanıtlar kaydedilir.

## I-11 — Kum saati performansı

Durum: bekliyor.

Bitti sayılması için: Kare/yeniden çizim ölçümü alınır. Yalnız ölçülebilir kazanım varsa davranışı koruyan değişiklik yapılır; yoksa dokunmama gerekçesi ve ölçüm yazılır.

## I-12 — Güncel ekran görüntüleri

Durum: bekliyor.

Bitti sayılması için: Yerel örnek hesaplarla Deneme, Denemelerim, deneme ligi, TUS, sosyal (6–8 aktif örnek) ve siteye gereken ekranlar gerçek uygulamadan alınır. Kişisel canlı veri/sır içermez; QA/demo niteliği raporlanır.

## I-13 — Site güncellemesi

Durum: bekliyor.

Bitti sayılması için: Deneme/TUS/süre–net anlatımı ve "Çalıştığın süre netine nasıl yansıyor?" mesajı eklenir. Yerel PDF bulguları uygulanır: hero≤300ms ve hedef kitle; okunur ekranlar; Bronz–Elmas merdiven+açılır detay; silik kum saati yalnızhero; POST form ve geniş yasal link alanları; gerçek avatar sayısı; Kumu akıt açıklaması; marka+amaç title/H1; sameAs içermeyen Organization; aylık ilk10 boş durum testi. Sahte kullanıcı/yorum/tarih/mağaza rozeti eklenmez. Yerel responsive/a11y/link ve npm testleri geçer; deploy yapılmaz.

## I-14 — Devir belgeleri

Durum: bekliyor.

Bitti sayılması için: AGENTS.md, PROJE_DEVIR.md, README ve sunucu rehberleri yeni sözleşmeleri, eski sunucu uyumunu, gerçek testleri, kurulumu ve bekleyen kullanıcı işlerini açıklar. Uygulanmamış proposed paket canlıymış gibi yazılmaz.

## I-15 — Keşif testleri / gözden kaçanlar

Durum: bekliyor.

Bitti sayılması için: Kalan sürede uygulama/site baştan sona incelenir; saptanan her ek hata I-15a… olarak kaydedilir, kapsamlı regresyonla düzeltilir. Çevrimdışı, lifecycle, erişilebilirlik, çeviri, boş/hata durumları ve performans kontrolleri gerçek kanıtla raporlanır.

## I-16 — Hedef kategorisine göre lig ve global sıralama

Durum: bekliyor. I-04/I-05 ile **tek lig sunucu paketi**.

Bitti sayılması için: LGS, YKS, TUS, KPSS, dil, üniversite ve iş hedefleri normal/deneme liglerinde kendi gruplarında yarışır; ayrıca tüm kullanıcıların global sıralaması vardır. Odalar/sıralamalar sunucuda ayrılır. Yetersiz aktif kategoride güvenli hazırlık politikası belgelenir. Ay ortası hedef değişiminde puan korunur, yeni kategori gelecek dönem uygulanır. Tek şema geçişi/rollback/DRYRUN ve yerel izolasyon/geçiş testleri geçer.

## I-17 — Karşılama ve onboarding

Durum: bekliyor.

Bitti sayılması için: Akıcı kısa ekranlar25/50, Maraton, Deneme, kategori/global lig, kum/avatar, arkadaş durumları, rapor ve süre–net içgörülerini açıklar. Yaş adımı ve13altı engeli değişmez; küçük/yatay ekran kontrolleri geçer.

## I-18 — TR/EN seçim ve eksiksiz çeviri

Durum: bekliyor.

Bitti sayılması için: Kayıt sonrası/onboarding başında TR/EN sorulur, Ayarlar'dan değişir. Yeni/eski görünür metinler, hata/bildirim/boş durum/rapor ve sunucu katalog/kategori/lig adları yerelleşir. ARB anahtar eşitliği ve koda gömülü görünür metin tarama testi vardır; eksikler düzeltilir, gerekli teknik/özel isim istisnaları gerekçelidir.

## I-19 — Birleşik çalışma süresi, ayrı deneme raporu

Durum: bekliyor.

Bitti sayılması için: Denemelerim/net/içgörü ayrı bölüm; toplam çalışma süresi Pomodoro+Maraton+tamamlanmış deneme olur. Tamamlanan deneme sunucuda çalışma günü/seriye katkı verir. Normal puan/kum/lig yalnızPomodoro+Maraton; deneme ekonomisi ayrıdır. Deneme süresi derslere dağıtılmaz, ayrıDeneme satırıdır. Pomodoro/Maraton/deneme sayıları ve gün/hafta/ay toplamları çift sayılmaz. Karışık veri, vazgeçme politikası,04:00/ay sınırı, saat dilimi ve geç gelen offline kayıt testleri geçer.

## I-20 — Son doğrulama listesi

Durum: bekliyor.

Bitti sayılması için: Sabah raporunda I-16…I-19 için her testin neyi kanıtladığı, gerçek sonuçları, eksik kapsamı ve ilgili commitleri ayrı bir bölümde açıklanır.

## Sabah teslimi

`analiz/GECE_RAPORU_2026-10-28.md`: yapılanlar/commitler; eksikler/nedenler; varsayımlar; gerçek test sayıları ve cihaz senaryoları; proposed dosya+sıra+DRYRUN; bekleyen site deploy'u; D-xx durumu; kullanıcının sonraki adımları. Görseller gelene kadar deneme ligi avatarları yer tutucudur.
