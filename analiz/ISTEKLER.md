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

Durum: tamamlandı — TUS/uyum paketleri `af5c338`, `52f5a02`, `cb68cff`; iOS27 TUS onboarding EN geçti. Platform gezisi I-10’da sürüyor.

Bitti sayılması için: TUS hedefi TR/EN onboarding'de seçilir. Temel tıp (Anatomi; Fizyoloji, Histoloji ve Embriyoloji; Biyokimya; Mikrobiyoloji; Patoloji; Farmakoloji) ve klinik (Dahiliye; Pediatri; Genel Cerrahi; Kadın Hastalıkları ve Doğum; Küçük Stajlar) kategorileri sunulur. Mevcut kategori limiti korunur. Segment constraint proposed/rollback/DRYRUN hazırlanır; eski sunucuda onboarding çökmez; testler geçer.

## I-02 — Deneme modu

Durum: kısmi — kod `f887933`/`d3d3ee4`, native başlangıç/vazgeçme/HTTP kesinti geçti; gerçek süre sonu ve kalan native turlar sürüyor.

Bitti sayılması için: Sunucu kataloğundan tür/süre/soru seçimi, güvenli yerel katalog, 3-2-1 başlangıç, duraklatmasız ve molasız sayaç çalışır. Sunucu onayı olmadan ödüllü deneme başlamaz. Arka plan, kapanma, yeniden açma ve vazgeçme kayıtları güvenle korunur. TYT120/165dk, AYT160/180dk, YDT80/120dk, LGS50/75dk ve40/80dk, TUS2×100/135dk resmî kaynaklarla belgelenir. YKS/TUS D−Y/4, LGS D−Y/3 doğrulanır. Normal25/50 ve Maraton bozulmaz.

## I-03 — Deneme sunucusu

Durum: tamamlandı — sunucu paketi `52f5a02`, yalnız yerel doğrulama.

Bitti sayılması için: Sunucu saatli başlat/bitir/vazgeç RPC'leri; erken bitirme, çakışma ve tekrar gönderim koruması; ayrı deneme kumu; owner-only deneme/net RLS; migration/rollback/DRYRUN ve uygulama sırası vardır. Yerel yetki, eşzamanlılık ve E2E kontrolleri geçer. Canlı eski sunucuda özellik güvenle kapalıdır. Lig şeması I-04/I-05/I-16 ile tek pakettedir.

## I-04 — Bütün ligler aylık / İstanbul 00:00

Durum: tamamlandı — tek29paketi, istemci `901e129`/`c263e4f` ve site `6d2b9f0`; aylık/İstanbul00:00 kuralları yerel testlerde doğrulandı.

Bitti sayılması için: Normal ve deneme ligi ayın1'i00:00 Europe/Istanbul'da yenilenir. 14 günlük aktif dönemden geçiş puan/ödülü korur. İstemci, site ve rehberler tutarlıdır. Çalışma günü/seri04:00 kalır. Ligle ilgili tablo değişiklikleri tek proposed pakette, rollback/DRYRUN ve sınır testleriyle sunulur.

## I-05 — Ayrı deneme ligi

Durum: tamamlandı — ayrı ekonomi/aylık oda ve güvenli avatar slotları `52f5a02`/`901e129`; yalnız yerelde doğrulandı.

Bitti sayılması için: Normalden bağımsız aylık deneme puanı/sıralama/kademeler/ödüller vardır. Yalnız tam süreli tamamlanan deneme kazanır. Özel avatar kategori/slotları, gerçek görsel gelene kadar güvenli yer tutucu destekler. Eksik görsel yayını bozmaz; gerçekte olmayan ödül gösterilmez.

## I-06 — Denemelerim ve netler

Durum: tamamlandı — kod/birim testleri, iOS18 `o2_04` ve Android `o2_08` ayrı ayrı 1/1 + yerel parite geçti; 29 net, rotasyon, kayıt, ekonomi değişmezliği ve haftalık bağımsız SQL karşılaştırması temiz. İki TYT geçmişi kontrollü fixture'dır; 330 dakika gerçek beklenmedi.

Bitti sayılması için: Tarih, başlangıç-bitiş, tür, süre ve terminal durum görülebilir. Ders bazında doğru/yanlış/boş doğrulanır, net otomatik hesaplanır; sonra girme/düzenleme desteklenir. Netler ekonomiyi etkilemez; yetki ve tekrar gönderim testleri geçer.

## I-07 — Süre–net içgörüleri

Durum: kısmi — içgörü modeli, D-04 eşleme ve yetersiz veri testleri `901e129` ile geçti. `b37899e` eksik geçmişten sahte 0 dakika gösterimini ve eski yanıtın yeni toplamı ezmesini düzeltti: önce 3 FAIL, sonra 3/3 ve ilgili ekran/eşleme paketi 11/11 PASS. Bu düzeltmelerle son native ekran doğrulaması bekliyor.

Bitti sayılması için: Çalışma kategorileri deneme derslerine tutarlı eşlenir. Yeterli karşılaştırılabilir veriyle süre ve net değişimi açıklanır; yetersiz veri yanıltıcı neden-sonuç iddiası üretmez. TR/EN, tarih aralığı ve eşleme testleri geçer.

## I-08 — Sosyal durumlar

Durum: tamamlandı — üç durumun testleri, iOS18 ve Android sekiz hesaplı gözlem turları geçti. Native test kaynağı `01bf20f` içinde; her tur tek gözlemci cihaz ve sekiz ayrı yerel hesap kullanır.

Bitti sayılması için: Odaklanıyor/Molada/Denemede TR/EN görünür. Molada yalnız Maraton içindir. Gizlilik ve engelleme korunur; geç kalmış normal iptal deneme durumunu silemez. Her durum birim testi ve çok hesaplı yerel E2E ile doğrulanır.

## I-09 — Giriş logosu

Durum: tamamlandı — `af5c338`/`cb68cff`; mevcut logo, ölçülü decode ve küçük/tema testleri geçti.

Bitti sayılması için: Üst saat mevcut uygulama logosuyla değişir. Açık/koyu tema, küçük ekran ve büyük yazıda taşma olmaz; yeni logo tasarlanmaz.

## I-10 — Kayıt/onboarding native E2E

Durum: sürüyor — iOS27 yedi hedef tek turda, Android yedi hedef ayrı doğrulanmış koşularda geçti. iOS18 gerçek25 dakika + uygulama kapanışı/final kayıt doğrulandı. Android2×25 gerçekMaraton3351sn/50dk/12puan/40kum/son+2bonus,rapor/lig/idempotency ile geçti. iOS27gerçek135Deneme ve iOS18gerçek50 bekliyor; kısa tamamlayıcı native turlar sürüyor.

I-10h: Aynı yeni hesapta kayıt/onay/giriş/onboarding → gerçek normal25 → raporlar → TUS başlangıç/vazgeçme senaryosu `0b9802e` ile hazır; native sonuç henüz yok. [İlk kullanım QA planı ve korumaları](QA_ILK_KULLANIM_2026-10-28.md).

Bitti sayılması için: iOS18.6, en az bir tam iOS27 turu ve Android API36'da yeni kayıt → yerel Mailpit onayı → giriş → dil/hedef onboarding (TUS dahil tüm hedefler) → ilk normal seans → ilk deneme doğrulanır. Gerçek zamanlı koşular ile kontrollü fixture koşuları raporda ayrılır; kanıtlar kaydedilir.

## I-11 — Kum saati performansı

Durum: tamamlandı — `80f7ab2`; iki yaşam döngüsü hatası ve gerçek asset ölçümü raporlandı, boyut/tempo değiştirilmedi.

Bitti sayılması için: Kare/yeniden çizim ölçümü alınır. Yalnız ölçülebilir kazanım varsa davranışı koruyan değişiklik yapılır; yoksa dokunmama gerekçesi ve ölçüm yazılır.

## I-12 — Güncel ekran görüntüleri

Durum: kısmi — gerçek TR/EN Deneme, net/yatay, sosyal ve TUS onboarding karelerine ek olarak güncel hedef/Global lig kareleri alındı; lig görseli siteye değiştirilmeden kopyalandı. Kaynak ve hash manifesti mevcut. iOS18 `media_y_01` gerçek normal/Maraton sahnelerini kaydetti; son video kodlama/yayın paketi ve nihai görsel kontrol henüz tamamlandı sayılmıyor.

Bitti sayılması için: Yerel örnek hesaplarla Deneme, Denemelerim, deneme ligi, TUS, sosyal (6–8 aktif örnek) ve siteye gereken ekranlar gerçek uygulamadan alınır. Kişisel canlı veri/sır içermez; QA/demo niteliği raporlanır.

## I-13 — Site güncellemesi

Durum: kısmi — `6d2b9f0` ile yerel rota/medya ve 155 Node testi geçti; `f2c6a7d` mevcut 21 özel avatarın eksik site görsellerini tamamladı ve Node paketi 158/158 geçti. Gerçek yeni medya sahneleri alındı; son video paketi ve Safari UI otomasyonu henüz doğrulanmadı. Son Safari denemesi `cgWindowNotFound` ile engellendi; deploy yapılmadı.

Bitti sayılması için: Deneme/TUS/süre–net anlatımı ve "Çalıştığın süre netine nasıl yansıyor?" mesajı eklenir. Yerel PDF bulguları uygulanır: hero≤300ms ve hedef kitle; okunur ekranlar; Bronz–Elmas merdiven+açılır detay; silik kum saati yalnızhero; POST form ve geniş yasal link alanları; gerçek avatar sayısı; Kumu akıt açıklaması; marka+amaç title/H1; sameAs içermeyen Organization; aylık ilk10 boş durum testi. Sahte kullanıcı/yorum/tarih/mağaza rozeti eklenmez. Yerel responsive/a11y/link ve npm testleri geçer; deploy yapılmaz.

## I-14 — Devir belgeleri

Durum: sürüyor — AGENTS/README/PROJECT_CONTEXT/PROJE_DEVIR/API rehberleri güncellendi; nihai sonuçlar ve commit bekliyor.

Bitti sayılması için: AGENTS.md, PROJE_DEVIR.md, README ve sunucu rehberleri yeni sözleşmeleri, eski sunucu uyumunu, gerçek testleri, kurulumu ve bekleyen kullanıcı işlerini açıklar. Uygulanmamış proposed paket canlıymış gibi yazılmaz.

## I-15 — Keşif testleri / gözden kaçanlar

Durum: sürüyor — düzeltmeler ayrı alt maddelerde;07:00’a kadar keşif devam edecek.

Bitti sayılması için: Kalan sürede uygulama/site baştan sona incelenir; saptanan her ek hata I-15a… olarak kaydedilir, kapsamlı regresyonla düzeltilir. Çevrimdışı, lifecycle, erişilebilirlik, çeviri, boş/hata durumları ve performans kontrolleri gerçek kanıtla raporlanır.

## I-16 — Hedef kategorisine göre lig ve global sıralama

Durum: tamamlandı — `52f5a02`, `d963fcc`, `901e129`, `c263e4f`; yerel oda izolasyonu, global görünüm, ertelenmiş hedef ve aylık geçiş doğrulandı.

Bitti sayılması için: LGS, YKS, TUS, KPSS, dil, üniversite ve iş hedefleri normal/deneme liglerinde kendi gruplarında yarışır; ayrıca tüm kullanıcıların global sıralaması vardır. Odalar/sıralamalar sunucuda ayrılır. Yetersiz aktif kategoride güvenli hazırlık politikası belgelenir. Ay ortası hedef değişiminde puan korunur, yeni kategori gelecek dönem uygulanır. Tek şema geçişi/rollback/DRYRUN ve yerel izolasyon/geçiş testleri geçer.

## I-17 — Karşılama ve onboarding

Durum: tamamlandı — `af5c338`/`cc27330`; guide/yaş/dil testleri, iOS27yedihedef ve Androidyedihedef ayrıkoşularda geçti.

Bitti sayılması için: Akıcı kısa ekranlar25/50, Maraton, Deneme, kategori/global lig, kum/avatar, arkadaş durumları, rapor ve süre–net içgörülerini açıklar. Yaş adımı ve13altı engeli değişmez; küçük/yatay ekran kontrolleri geçer.

## I-18 — TR/EN seçim ve eksiksiz çeviri

Durum: kısmi — ARB/scan/runtime/diyalog bildirim testleri ve ilgili commitler geçti; iki platformun son ekran turları sürüyor.

Bitti sayılması için: Kayıt sonrası/onboarding başında TR/EN sorulur, Ayarlar'dan değişir. Yeni/eski görünür metinler, hata/bildirim/boş durum/rapor ve sunucu katalog/kategori/lig adları yerelleşir. ARB anahtar eşitliği ve koda gömülü görünür metin tarama testi vardır; eksikler düzeltilir, gerekli teknik/özel isim istisnaları gerekçelidir.

## I-19 — Birleşik çalışma süresi, ayrı deneme raporu

Durum: tamamlandı — `607595a`/`59f1995` ve `f82f999`; karışık veri, 04:00/ay/TZ/outbox, uzun geçmiş ve ayrı ekonomi testleri geçti. iOS18 `w_start_02` ve `w_resume_01` ayrı ayrı 1/1 + parite PASS: gerçek 25 dakika HTTP503 sırasında diskte korundu, farklı OS sürecinde tek kayıt/ödül kabul edildi; günlük/haftalık/aylık native raporlar bağımsız SQL ile eşleşti. Son toplam 430 dakikanın 405 dakikası kontrollü önceki geçmiş, yalnız 25 dakikası doğal bekleyiştir. Normal 22 puan/80 kum ve değişmeyen Deneme 66 puan/12 kum doğrulandı. TUS/Maraton doğal final kontrolleri ayrıca I-10’da sürüyor.

Bitti sayılması için: Denemelerim/net/içgörü ayrı bölüm; toplam çalışma süresi Pomodoro+Maraton+tamamlanmış deneme olur. Tamamlanan deneme sunucuda çalışma günü/seriye katkı verir. Normal puan/kum/lig yalnızPomodoro+Maraton; deneme ekonomisi ayrıdır. Deneme süresi derslere dağıtılmaz, ayrıDeneme satırıdır. Pomodoro/Maraton/deneme sayıları ve gün/hafta/ay toplamları çift sayılmaz. Karışık veri, vazgeçme politikası,04:00/ay sınırı, saat dilimi ve geç gelen offline kayıt testleri geçer.

## I-20 — Son doğrulama listesi

Durum: kısmi — DOGRULAMA_MATRISI hazır; sabah raporuna son kanıtların aktarılması bekliyor.

Bitti sayılması için: Sabah raporunda I-16…I-19 için her testin neyi kanıtladığı, gerçek sonuçları, eksik kapsamı ve ilgili commitleri ayrı bir bölümde açıklanır.

## I-15a — Yerel şema kopyasında ops bağımlılığı

Durum: tamamlandı — yerel düzeltme ve regresyonlar `52f5a02`.

Bitti sayılması için: Yerel zincir kopyası `handle_new_user` bağımlılığı olan `ops` şemasını da içersin; gerçek kayıt fikstürü ve eski/yeni SQL zinciri tekrar geçsin. Canlıya müdahale edilmez.

## I-15b — Lig engelleme yönleri

Durum: tamamlandı — yerel düzeltme ve regresyonlar `52f5a02`.

Bitti sayılması için: Normal/deneme kategori liginde kullanıcıyı engelleyen kişinin kimliği de maskelensin; karşılıklı iki engel satır sayısını çoğaltmasın. Global/sosyal davranışıyla tutarlı yerel regresyon geçsin.

## I-15c — Deneme kaydında geç yanıt ve hesap sahipliği

Durum: tamamlandı — `f887933`/`bf507b0`; geç cevap, sahiplik ve disk yazım yarışları regresyonlarla doğrulandı.

Bitti sayılması için: Geç geçmiş yanıtı terminal denemeyi aktif yapamaz; yeni kaydedilmiş netleri silemez. Eski hesaptan kalan DTO yeni hesaba yazılamaz. Bozuk günlüğün ham verisi korunur ve başlangıç güvenli kapanır. `exam_audit_test.dart` ve servis testleri bu durumları doğrular.

## I-15d — Başlatma onayında lifecycle yarışı

Durum: tamamlandı — `d3d3ee4`; foreground/onay yarışları ve rezervasyon temizliği doğrulandı.

Bitti sayılması için: Normal/Maraton başlangıç onayı beklenirken uygulama inactive/paused olursa sayaç başlamaz; alınmış fakat kullanılmayan sunucu rezervasyonu bırakılır. Hesap değişiminde eski onay yeni hesaba taşınmaz. Başlatma sonrası deneme kilidi yeniden kontrol edilir.

## I-15e — İki dilde sayı ve hata durumu

Durum: tamamlandı — `cb68cff`/`1a1ca26`; sayı, ad fallback, hata ve bildirim dili kontrolleri geçti.

Bitti sayılması için: Türkçe netler virgülle, İngilizce netler noktayla biçimlenir. Sunucudan boş/yalnız boşluk ad kabul edilmez. Dil değişince açık hata ve planlı bildirim metinleri güncellenir; bildirim saati uzamaz ve iptal edilmiş alarm geri gelmez. Bilinen avatarların eksik dil adı yerel katalogdan güvenle tamamlanır.

## I-15f — Aylık rapor testlerinin doğru hafta kartını seçmesi

Durum: tamamlandı — `607595a`; tarih anahtarlı hafta kartı testleri ve eski içerik kontrolleri korundu.

Bitti sayılması için: Yeni seans özeti eklendiğinde hafta dökümü testleri ilk rastgele InkWell yerine tarih anahtarıyla gerçek hafta kartını açar. Gün, ders, bekleyen kayıt ve genişlik doğrulamaları korunur.

## I-15g — Kısmi deneme geçmişinde yanıltıcı tam toplamı önleme

Durum: tamamlandı — `607595a`; kısmi/bayat deneme geçmişi uyarısı ve retry doğrulandı.

Bitti sayılması için: Normal geçmiş okunmuş ancak deneme geçmişi okunamamışsa toplamlar doğrulanmış tam veri gibi sunulmaz. Önceki başarılı deneme verisi korunur, bayat/kısmi veri uyarısı gösterilir; başarılı yeniden denemede uyarı kalkar. Eski sunucuda özelliğin bulunmaması ağ arızası diye sunulmaz.

## I-15h — Hata izlemede iç içe kişisel veri maskeleme

Durum: tamamlandı — `cd756f1`; sentetik event/transaction ve operationalaudit geçti, remote alert kurulmadı.

Bitti sayılması için: Mevcut Sentry filtreleri e-posta, kimlik/oturum anahtarı, Authorization/cookie/body ve URL query/fragment verilerini iç içe nesnelerde de temizler; işlem/stack/satır bilgisi korunur. Transaction'lara da aynı filtre uygulanır. Gerçek kullanıcı verisi gönderilmeden sentetik regresyonlarla doğrulanır; yeni dış servis veya canlı panel değişikliği yapılmaz.

## I-15i — Deneme geçmişi ve disk yazım yarışı

Durum: tamamlandı — `bf507b0`; iki gerçek commit-yarışı FAIL→PASS, tam paket geçti.

Bitti sayılması için: Terminal vazgeçme/tamamlama veya yeni netler diske yazılırken gelen eski geçmiş yanıtı bunları tekrar pending/aktif hale getiremez. Merge+commit hesap/epoch kontrolüyle aynı işlem kilidinde yapılır; ağ isteği kilidi tutmaz.

## I-15j — Açık lig ekranının dönem ve yenileme değişimleri

Durum: tamamlandı — `c263e4f`; dönem/pull-refresh/foreground/capability regresyonları geçti.

Bitti sayılması için: Ay değişiminde açık normal/Deneme ligi bir kez yeniden yüklenir; gizli/arka plan ekranı gereksiz istek üretmez. Deneme liginde pull-to-refresh cüzdan/sırayı yeniler. Capability kapatılıp açılınca eski spinner/hata/yanıt yeni veriyi ezmez.

## I-15k — Açık pencerelerin dil değişimi

Durum: tamamlandı — `cc27330`; beş TR/EN dialog regresyonu geçti.

Bitti sayılması için: Deneme kuralları/vazgeçme, onboarding hesap silme ve kategori penceresi açıkken TR/EN değişiminde başlık/açıklama/buton/validation birlikte güncellenir. Kullanıcının yazdığı kategori adı korunur; yaş/veli kuralları değişmez.

## I-15l — Normal başlangıç kotası ve UUID tutarlılığı

Durum: tamamlandı — `901e129`; proposed30 yerelde31/31 doğrulandı ve kontrollü yerel onarımda uygulandı. Normal offline ödül politikası karar bekliyor.

Bitti sayılması için: Eşzamanlı başlangıçlar100kotayı aşamaz; aynıUUID aynı süreyle tekcreated sonucu, farklı süreyle açık kalıcı hata verir. Mevcut offline ödül politikası sessizce değiştirilmez; risk karar bekleyen olarak raporlanır.

## I-15m — Net kaydından sonra görünen geçmiş

Durum: tamamlandı — `bf507b0`; net mutation sonrası güncel remote snapshot ve görünürlük doğrulandı.

Bitti sayılması için: Başarılı net kaydı kalıcı journal ve ekranda aynı güncel sonucu gösterir; eski remote cache yenilemeyi bekleyerek yeni sonucu gizlemez. Hesap sahipliği ve geç yanıt korumaları devam eder.

## I-15n — Eşdeğer süreyi seans adedi gibi okumama

Durum: tamamlandı — `59f1995`; tek50dkseans Normal1/eşdeğer2 olarak kalır, ekranokuyucu açık25dk eşdeğeri söyler.

Bitti sayılması için: TR/EN semantiketiketi iki tamamlanmışseans izlenimi vermez; gerçekseans ve eşdeğer hesapları değişmez.

## I-15o — Deneme geri yükleme bariyeri

Durum: tamamlandı — `b692d98`; init/refresh/mutation geri yükleme yarışları önceFAIL, sonra27/27 hedefli ve1407/5 tam paket geçti.

Bitti sayılması için: Aynı hesap için concurrent initialize aynı tamamlanma bariyerini bekler. Yerel journal okunurken başka seans başlatılamaz; refresh eski boş snapshotı diske yazamaz. Hesap değişiminde eski read yeni hesabı ezmez, yeniden giren listener deadlock oluşturmaz. Fail-first ve mevcut servis regresyonları geçer.

## I-15p — Kuyruklanan Deneme başlangıcının hesap sahipliği

Durum: tamamlandı — `b692d98`; A→B kuyruk yarışında önceFAIL, düzeltmesonrası hedefli ve tam paket geçti.

Bitti sayılması için: Başlatma sahibinin UID/epoch değeri kuyruğa girmeden alınır ve çalıştırmada tekrar doğrulanır. Hesap değişince eski istek yeni hesapta deneme oluşturamaz; normal geçerli başlatma ve diğer journal işlemleri çalışır.

## I-15q — Gerçek süreç testinde kurulumun korunması

Durum: kısmi — çalıştırıcılarda Flutter'ın varsayılan test sonu kaldırması kapatıldı. iOS18 `r25_resume_02`, gerçek 25 dakikadan sonra ayrı süreçte tek kayıt/olay/ödül ve native plist tamamlanma işaretiyle 1/1 + parite geçti. TUS135 ara geri açılışı aynı başlangıç/bitişi korudu fakat henüz tamamlanmadı; diğer uzun final tekrarları sürüyor. Eski silinmiş koşular başarı sayılmıyor.

Bitti sayılması için: Çok fazlı testler `--no-uninstall` ile aynı uygulama verisini korur; gerçekten farklı süreçte doğru owner/UUID/zamanlar okunur. Eski silinmiş koşular başarı sayılmaz. Test aşamaları ve son doğrulama ayrı raporlanır.

## I-15r — Ekran kanıtının geçerli PNG olması

Durum: tamamlandı — `c0ae947`;12/12 hedefli hostregresyonu, yeni nativeçekimler ve mevcutPNGgeçerlilik kontrolü geçti.

Bitti sayılması için: Çekim ve boyutlandırma hataları, zaman aşımı, boş dosya, bozuk PNG/CRC açık hata döndürür. Yalnız doğrulanmış yeni görsel hedef dosyaya yazılır; eski dosya yeni başarılı çekim diye kullanılamaz. Geçerli mevcut kanıtların baytları değiştirilmez.

## I-15s — Süre–net içgörüsünde eksik veya eski çalışma verisi

Durum: kısmi — `b37899e` ile iki hata giderildi, üç yeni regresyon ve tam 1413 test geçti. Güncel kodla o2 tekrarı ve pozitif aa içgörü TR/EN native turu geçti; ek Android içgörü turu planlı.

Bitti sayılması için: İlk okuma başarısızsa sayısal süre–net yorumu üretilmez ve mevcut iki dilli hata/yeniden dene metni gösterilir. Daha önce yüklenmiş veri hata halinde korunur ve bayat olduğu açıkça belirtilir. Aynı hesapta daha yeni istek ve hesap değişimi eski yanıtı geçersiz kılar. Hata, başarılı yeniden deneme, cache ve yanıt sırası regresyonları geçer; native Deneme ekranı tekrar kontrol edilir.

## I-15t — Sitede özel avatarların doğru gösterilmesi

Durum: tamamlandı — `f2c6a7d`: 21 eksik görsel eklendi; Node 158/158, katalog/görsel eşleşmesi ve tam Flutter 1416 testi geçti. Deploy yapılmadı.

Bitti sayılması için: Uygulamanın mevcut 21 özel avatarı, sitenin mevcut WebP boyut ve şeffaflık standardında aynı görünümle bulunur. Yeni çizim veya avatar eklenmez. Aktif katalogdaki görsel yolları, özel avatarların sıralama/podyum yolu ve güvensiz ID yedeği test edilir; site testleri geçer. Kaynak ve çıktı boyut/hash bilgileri kaydedilir; deploy yapılmaz.

## I-15u — HTTP kesinti testinde sunucu saati başlığı

Durum: tamamlandı — `de7668a` yerel test proxy'sinin ikinci Date başlığı eklemesini kaldırdı; regresyon önce FAIL, düzeltme sonrası proxy 10/10 PASS. Düzeltilmiş proxy ile iOS18 `w_start_02` ve `w_resume_01` ayrı ayrı 1/1 + parite geçti: 1505 duvar saati saniyesi, diskte tek bekleyen kayıt, 5402→17335 farklı OS süreci ve bağlantı sonrası tek kayıt/lig olayı. Günlük/haftalık/aylık SQL eşitliği doğrulandı. Önceki 405 dakika kontrollü veridir; ürün veya cihaz saati değiştirilmedi. [Native kanıt](QA_NATIVE_GECE_2026-10-28.md).

Bitti sayılması için: Proxy yukarı akışın tek Date başlığını korur; birleşmiş iki tarih ile uygulamanın saat ölçümünü bozmaz. Uzun koşu yalnız düzeltilmiş proxy üzerinden yapılır. Bu test aracı hatası ürün hatası diye raporlanmaz; iptal edilen ilk derleme başarılı test sayılmaz.

## I-21 — 06:30 QA cihazı ve geçici dosya temizliği

Durum: planlandı — kullanıcının gece ek isteği.

Bitti sayılması için: Testler tamamlandıktan sonra06:30civarında bu gece oluşturulan QAcihazlarından yalnız biriPhone (iOS18.6) ve birAndroid emülatörü bırakılır; kendi iOS27QA cihazı silinir. Başka projeye ait korumalıHocamMacVar cihazına dokunulmaz. Geçici indirme/scratch dosyaları ve kullanılmayan ek kod/varlıklar ayıklanır; kanıtlar, düzeltme regresyonları, aktif ürün kodu ve kullanıcının mevcut dosyaları korunur. Silinenler ve kalan cihazlar sabah raporunda açıkça listelenir.

## Sabah teslimi

`analiz/GECE_RAPORU_2026-10-28.md`: yapılanlar/commitler; eksikler/nedenler; varsayımlar; gerçek test sayıları ve cihaz senaryoları; proposed dosya+sıra+DRYRUN; bekleyen site deploy'u; D-xx durumu; kullanıcının sonraki adımları. Görseller gelene kadar deneme ligi avatarları yer tutucudur.

## I-15y — Kapalı Maratonda geç ilk kabulün mola süresini uzatması

Durum: sürüyor — yalnız yerel inceleme ve31proposed tasarımı. Mevcut9parametreli MaratonRPCilkbitmişodağıgeçkabul ettiğinde5+1pencereyi kabulsaatinden başlatıyor; böylece istenen AFKüst sınırı uzayabilir. Duraklatılmamış odakta kabul edilen gerçekcompleted_at çıpasıyla sınırlama hazırlanıyor. Bitmişnormalödülkorunacak, gecikmişplanbonusalamayacak.

MevcutAPI'de meşru uzun duraklatma ile geç gönderim ayrılamaz: p_was_paused=true için aynıçıpayızorlamak haksızplaniptaliyapar.31bu kolueskidavranıştakorur; **duraklatılmış MaratonAFKriski çözülmüş sayılmayacak**. Tamgüvence sunucuda start/pause/resume kaydı gerektirir ve sonraki tasarımkararıdır. Canlıya/anaQA'ya henüzuygulanmadı. ABgerçekprocessprobe hazırlığıvehangi koşturmanın hangi sunucuylaolduğuayrıraporlanacak.


## I-15z — Saat dilimi değişiminde geçmiş gününün sözleşmesi

Durum: **karar bekliyor** — sabit profil diliminde04:00/ay/DST kanıtları var; seyahatte rapor günü güncel dilime göre yeniden gruplanırken kabul edilmiş lig günü ve seri tarihi saklı kalıyor. Süre/puan kaybı veya çökme tespit edilmiş değildir. Politika değiştirmek veya eski veriyi yeniden yazmak yerine ayrım [kapsam incelemesinde](QA_SAAT_DILIMI_SINIRI_2026-10-28.md) belgelendi.

Bitti sayılması için: kabul gününü koruma, güncel dilime göre yeniden gruplama veya dönem boyunca sabit hesap dilimi seçeneklerinden biri açıkça seçilir. Aynı hesapta normal, Maraton, tamamlanmış/vazgeçilmiş Deneme ve bekleyen çevrimdışı kayıt ile İstanbul→New York→İstanbul testi; tamamlama öncesi/sonrası,04:00 ve ay sınırı, seri/lig gün sayısı ve tek ödül beraber doğrulanır. Geçmiş veri/ödül kullanıcı kararı olmadan yeniden yazılmaz.
