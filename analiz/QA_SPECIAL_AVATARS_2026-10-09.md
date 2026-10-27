# PomoSprint — Özel Avatarlar ekleme ve QA

**9 Ekim 2026.** Kullanıcının `/Users/almano/Desktop/stitch_hourglass_league_avatar_series 2` klasöründeki 22 yeni görseli uygulamaya eklendi. Koleksiyonda ayrı **Özel Avatarlar / Special Avatars** bölümü vardır; her biri **500 kum tanesi**. Kayıtta yalnız mevcut yedi ücretsiz avatar seçilebilir. Yeni ücretli avatarlar kayıt listesinde bulunmaz.

**Güncel canlı durum / §35:** Kullanıcı SQL Editor'de paketi çalıştırıp “Success. No rows returned” bildirdi. 9 Ekim19:27 UTC salt okuma ve uygulamanın public katalog API'siyle doğrulandı: **49 toplam /48 aktif /22 özel /7 aktif ücretsiz**; bütün özel fiyatlar500 ve TR/EN ad/görsel/bayraklar manifestle aynı. Migration20261009190000 tek kayıttır. Eski27 avatar ve5RPC/ACL/RLS yapısı değişmedi. İleri veya DRYRUN paketini yeniden çalıştırmayın. Aşağıdaki hazırlık/native/test aşamalarının sonuçları önceki §34 kapsamıdır; canlı uygulama kullanıcıya aittir, bu takipte ajan yalnız salt okuma yaptı.

## Yapılanlar

- 22 benzersiz PNG, kaynakla aynı SHA-256 ve byte içeriğiyle `assets/avatars/` içine kopyalandı. Görseller 1024×1024; toplam 23.954.020 byte. Yeni çizim veya görsel içerik değişikliği yapılmadı. Mevcut `AvatarWidget.cacheWidth` görüntüyü gösterildiği boyuta göre çözer.
- TR/EN adlar, 500 fiyatı ve özel kimlikler gömülü katalogla/sunucu paketiyle eşleşir. Kategori `special_` ID önekinden türetilir; yeni DB kolonu veya RPC gerekmez.
- Mevcut ücretsiz, 200 kumluk, Premium sahiplik ve lig ödülü kuralları korunur. Özel avatarlar Premium hesap için de 500 kumdur; ücretsiz varsayılan veya lig ödülü sayılmaz.
- Kayıt avatar etiketleri artık ekranın seçili diliyle eşleşir. İngilizce ekranda Türkçe etiket kalması giderildi.
- Koleksiyon açıkken geç tamamlanan katalog yenilemesi artık yeni özel/lig listelerini gösterir. Ekran kapanmışsa veya hesap değişmişse eski cevap uygulanmaz; aynı kullanıcının bakiye/sahiplik güncellemesi sürer.
- Son görsel incelemede uzun İngilizce adla fiyat etiketi çakışması bulundu ve düzeltildi. Kilit/fiyat yalnız avatar alanındadır; isim ayrı altta durur. Büyük yazıda kartın yüksekliği ve sütun hesabı içeriğe yer açar. Fiyatın isimle kesişmediği ve avatar sınırlarında kaldığı bütün 22 karakter için ölçülür.
- Satın alma ve kuşanma sunucu onayından sonra uygulanır. Bakiye yetmesi sahiplik değildir; ikinci alım ikinci kez ücret düşmez.

## Avatar adları

| Türkçe | English | Kum |
|---|---|---:|
| Altın Madencisi | Gold Miner | 500 |
| Vampir Lordu | Vampire Lord | 500 |
| Dedektif | Detective | 500 |
| Kovboy | Cowboy | 500 |
| Buhar Pilotu | Steampunk Pilot | 500 |
| Firavun | Pharaoh | 500 |
| Zen Ustası | Zen Master | 500 |
| Çöl Prensesi | Desert Princess | 500 |
| Orman Perisi | Forest Fairy | 500 |
| Yıldız Büyücüsü | Star Wizard | 500 |
| Gölge Kraliçesi | Shadow Queen | 500 |
| Astronot | Astronaut | 500 |
| Kristal Prenses | Crystal Princess | 500 |
| Ronin | Ronin | 500 |
| İksir Ustası | Potion Master | 500 |
| Arkeolog | Archaeologist | 500 |
| Siber Robot | Cyber Robot | 500 |
| Alev Ruhu | Flame Spirit | 500 |
| Işık Şövalyesi | Light Knight | 500 |
| Korsan Kaptan | Pirate Captain | 500 |
| Gökyüzü Kralı | Celestial King | 500 |
| Samuray | Samurai | 500 |

Manifest: [special_catalog.json](../assets/avatars/special_catalog.json). Kaynak görsellerin toplu önizlemesi: contact sheet (ham çıktı §37 temizliğinde kaldırıldı).

## Test sonucu ve kapsam

Son fiyat yerleşimi düzeltmesinden sonra **246/246 odaklı test** ve **1254 PASS / 5 SCREENSHOTS opt-in atlaması** tam suite sonucu alındı; yeni analiz temizdir. Atlanan beş test yalnız isteğe bağlı görsel üretimidir, iş mantığı testi değildir. Yeni özel avatar testleri 37 senaryodur: manifest/fiyat/erişim, TR/EN altı boyut ve büyük yazı, 499/500 onay düğmesi, kayıt seçimi, eski cache önceliği, geç katalog/hesap değişimi/dispose davranışı ve tüm 22 avatar için TR/EN × dikey/yatay × yazı x1/x2 fiyat-ad kesişmeme ölçümü.

Kanıt: son odaklı log (ham çıktı §37 temizliğinde kaldırıldı), son tam log (ham çıktı §37 temizliğinde kaldırıldı), son analiz (ham çıktı §37 temizliğinde kaldırıldı), komut/süre özeti (ham çıktı §37 temizliğinde kaldırıldı). Önceki 234/1242 ve 238/1246 koşuları ilgili istemci düzeltmelerinden önceki tarihsel kanıttır; sonuçlar birbirine eklenmez.

iPhone 16 Plus / iOS 18.6 **simülatöründe gerçek native `main()` koşusu 1/1 geçti**: uygulamanın açılışı, profil → koleksiyon, TR/EN ilk/son karakterler, OS yatay/dikey yön değişimi, 1000→500 kum satın alma, ikinci alımda aynı bakiye, kuşanma ve sunucudan yeniden profil okuma; kayıt seçicisinde kaydırılarak yedi ücretsiz avatarın tamamı ve sıfır özel avatar doğrulandı. `QUICK_TIMER=false`, `QUICK_TIMER_SAVE=false`. Kanıt: son native log (ham çıktı §37 temizliğinde kaldırıldı), özet (ham çıktı §37 temizliğinde kaldırıldı), sekiz gerçek görüntü (ham çıktı §37 temizliğinde kaldırıldı). Dikey ve yatay İngilizce görüntüde önceki isim/fiyat çakışması giderildi.

İlk iki native deneme lazy Finder ve geçici başarı SnackBar'ını beklemeyen test dokunması nedeniyle başarısızdı; ürün çökmesi veya RPC hatası değildi. Bu loglar korunur. Sonraki ilk başarılı native koşu, görsel fiyat düzeltmesinden önceydi; son native koşu yeni düzeni içerir ve önceki Text hit-test uyarısı yoktur. Fixture yalnız izole DB'de yenilendi.

Backend **118/118** gerçek izole kontrol ve ayrı **10/10 true DRYRUN** geçti:

- 22 avatarın her birinde 500 kum alımı, kuşanma, tekrar alım ve ücretli avatarı kayıt metadata'sından seçme girişiminin temel avatara çekilmesi.
- 499 kum reddi / tam 500 kum kabulü; Premium hesabın aynı fiyatı ödemesi.
- Başka kullanıcının sahipliğini görememe/kuşanamama; anon, UID'siz oturum ve doğrudan fiyat/sahiplik/profil avatarı yazımının reddi.
- Aynı avatarın eşzamanlı alımı tek düşüm; 750 kumla iki farklı alımın yalnız birinin kabulü; eşzamanlı normal seans +20 kumunun korunması.
- DRYRUN tam geri alma, temiz down eski katalog/geçmişi birebir geri getirme, satın alınmış/kuşanılmış avatar varsa down'ın veri kaybetmeden durması.

Backend hesapları yalnız izole `auth.users` içinde sentetik kullanıcı ve gerçek profil trigger'larıyla oluşturuldu. Auth sağlayıcısı/e-posta teslimi bu testin parçası değildir. Native smoke da pre-issued yerel QA oturumu kullanır; mağaza akışı ve gerçek PostgREST RPC sınanır, kullanıcı giriş sağlayıcısı sınanmış sayılmaz.

Kanıtlar: backend sonuçları (ham çıktı §37 temizliğinde kaldırıldı), backend alt raporu (ham çıktı §37 temizliğinde kaldırıldı), final native DB alım/kuşanma (ham çıktı §37 temizliğinde kaldırıldı), istemci ilk koşusu (ham çıktı §37 temizliğinde kaldırıldı), bağımsız inceleme (ham çıktı §37 temizliğinde kaldırıldı). Ana yerel DB paritesi 498 fingerprint satırı/13 kategori ve 27 avatarla saklanan canlı referansa aynı kaldı; kapanışta yeni tam canlı fingerprint okunmadı. Canlıya yalnız salt okuma yapıldı; kullanıcı verisi/kum/seans veya RPC değişmedi.

## Platform paketleri ve kapanış

Son fiyat düzeltmesinden sonra normal `lib/main.dart` kaynaklı **Android debug APK** ve **iOS debug simülatör paketi** yeniden başarıyla derlendi. Her ikisi gerçek 25/50 dakikalık sayaç bayraklarıyla hazırlanmıştır; ardından normal iOS sürümü kişisel BEA simülatörüne kuruldu. Paketlerdeki 22 PNG ve manifest kaynakla birebir aynı SHA-256/içeriktedir. Yeni bağımlılık veya servis eklenmedi.

| Kontrol | Sonuç / kanıt |
|---|---|
| Android `assembleDebug` | PASS; son log (ham çıktı §37 temizliğinde kaldırıldı) |
| Normal iOS simülatör build | PASS; son log (ham çıktı §37 temizliğinde kaldırıldı) |
| Komut, bayrak ve süre | platform özeti (ham çıktı §37 temizliğinde kaldırıldı) |
| Her iki pakette 22 görsel + manifest | paket varlık doğrulaması (ham çıktı §37 temizliğinde kaldırıldı) |
| Final native satın alma ve izole DB temizliği | V2 kapanış (ham çıktı §37 temizliğinde kaldırıldı) |
| Yalnız kendi bridge/simülatör temizliği | root kapanış (ham çıktı §37 temizliğinde kaldırıldı) |

Paketler `build/app/outputs/flutter-apk/app-debug.apk` ve `build/ios/iphonesimulator/Runner.app` içindedir. Bu tur Android emülatöründe native dokunma akışı veya yeni imzalı mağaza paketi üretilmedi; Android için derleme ve ortak Flutter testleri doğrulandı. iOS simülatör akışı fiziksel cihaz/sağlayıcı/mağaza testi değildir. İlk platform logları fiyat düzeltmesinden öncedir; yukarıdaki `price_final` dosyaları son kaynak içindir. Önceden mevcut Android SDK XML sürüm uyarısı ilk build'i engellemedi; bu avatar işi bağımlılık/SDK yükseltmesi yapmadı.

Kendi geçici clone/REST54362/bridge54363 ve QA simülatörü kaldırıldı. QA sırasında ana yerel DB, kişisel BEA ve diğer projenin HMV simülatörü/servisleri korundu. Son kurulum aşamasında BEA'ya yalnız normal canlı uygulama kuruldu. Kök `.env` SHA-256 kaynakta ve iki normal pakette aynı; içeriği rapora dökülmedi. Normal kullanıcı uygulamasının binary'si yenilendi; uygulama verisi açıkça silinmedi ve QA fixture/yerel kullanıcı kurulumuyla değiştirilmedi. Site, canlı ekonomi/seans, commit/push veya mağaza yayını yok. Önceki §33 operasyonel açıklar bu avatar eklemesiyle kapanmış sayılmaz.

## Canlı katalog kurulumu ve doğrulama

Normal istemci kurulum adımı tamamlandı: iPhone 16 Plus/iOS18.6 BEA simülatöründe güncel `lib/main.dart`, canlı Supabase ve gerçek25/50dk ile TR giriş ekranında açık bırakıldı. Kurulu bundle'da 22 yeni PNG kaynak hash'leriyle doğrulandı. Flutter `d` ile ayrıldıktan sonra Runner çalışmaya ve giriş ekranını göstermeye devam etti. Kayıtlı auth oturumu yoktu; hesap/seans oluşturulmadı, kullanıcı verisi açıkça temizlenmedi. Kurulum kanıtı (ham çıktı §37 temizliğinde kaldırıldı), launch log (ham çıktı §37 temizliğinde kaldırıldı), son görüntü (ham çıktı §37 temizliğinde kaldırıldı). Plugin'in mevcut lifecycle deprecation uyarısı açılışı engellemedi; SDK/bağımlılık yükseltmesi yapılmadı. Bu kurulum canlı özel katalog satırlarını eklemez.

[AGENTS.md §2.4](../AGENTS.md) talimatı: **“Canlıya yazan SQL'i kullanıcı Supabase SQL Editor'de çalıştırır.”** Bu nedenle yerel test başarısı canlıya kurulum diye raporlanmaz.

**Kurulum öncesi verilen yönerge (ileri paket kurulumu tamamlandı; kullanıcı DRYRUN çıktısı görülmedi; tekrar çalıştırılmaz):**

1. [DRYRUN](../supabase/tests/20261009_special_avatar_catalog_dryrun.sql) dosyasının tamamı SQL Editor'de çalıştırılır. Son bilinçli `DRYRUN_RESULT >>` hatası rollback demektir; T01–T10 hepsi `true` olmalı.
2. İleri paket öncesi yeni normal uygulama kurulmalıdır. PNG dosyaları uygulama paketindedir; eski binary yeni katalog satırlarından dosya indiremez. Son normal build'ler hazırdır ve BEA simülatöründe normal iOS kurulum adımı tamamlandı; başka cihazlarda güncel kaynakla `flutter run` gerçek 25/50 dk kullanır. Yeni istemci eski 27 satırlık sunucuyla uyumludur.
3. Sonra yalnız [ileri paket](../supabase/migrations/20261009190000_special_avatar_catalog.sql) çalıştırılır. Paket güncel canlı katalog ve beş fonksiyonun hash'ini denetler; değişmişse veya zaten kurulmuşsa durur.
4. [SQL kullanım rehberindeki](../supabase/tests/20261009_special_avatar_catalog_README.md) salt okuma ile toplam49 / özel22 / aktif ücretsiz7, tüm fiyatlar500 ve güvenli bayraklar doğrulanır. Yeni uygulamada koleksiyon tekrar açılınca katalog tazelenir.

[Down](../supabase/rollbacks/20261009190000_special_avatar_catalog_down.sql) yalnız bu satırlar hiç edinilmemiş/kuşanılmamışsa çalışır; mevcut sahiplik veya kum iadesini silerek zorlanmaz. Kök `db push/reset`, eski/bekleyen diğer paketler uygulanmaz.

## Kullanıcı kurulumu sonrası canlı kontrol — §35

Management API kanıtı (ham çıktı §37 temizliğinde kaldırıldı): **16/16** koşul geçti. Transaction `READ ONLY`; katalog/migration/geçerli beş fonksiyon/ACL, kolonlar, RLS/grant/constraint/trigger incelendi. Kullanıcı verisi veya yeni hesap/seans okunup üretilmedi; purchase/equip veya SQL migration/DRYRUN tekrar çağrılmadı. Önceki27 katalog satırı created_at dahil aynı, fonksiyonlar ve yetki yapısı aynı. Yeni tüm katalogMD5 `5e80e532aa71a325edd1d76e96183fb5`.

Public REST kanıtı (ham çıktı §37 temizliğinde kaldırıldı): yalnız mevcut public anon ile **iki GET /25 koşul** geçti. Tam katalog49; uygulamadaki `is_active=true` sorgusu48 satır verir (eski pasif tomato_basic dışarıda), özel22 ve aktif ücretsiz7. Her22 satır manifestle TR/EN ad, PNG yolu,500 fiyatı, bayrak ve sıra olarak tam eşleşir. Bu GET'ler satın alma veya kullanıcı giriş sağlayıcısı testi değildir. Önceki1254/full,118/backend ve native1 bu takipte yeniden koşulmadı.

Kullanıcının “Success. No rows returned” bildirimi ileri paketin commit/INSERT/NOTIFY işlemleri için normal sonuçtur; kurulum durumu yalnız bu mesajdan varsayılmadı, canlı migration ve satırlar bağımsız okundu. Kullanıcı DRYRUN çıktısı bu takipte paylaşılmadı; önceki yerel10/10 başarısını canlıda koşulmuş saymayın.

Yerel54322 kapalı olduğu için yeni yerel okuma (ham çıktı §37 temizliğinde kaldırıldı) yapılamadı. Docker yeniden başlatılmadı, yerel DB veya eski parite referansı kendiliğinden güncellenmedi;498/13/27 geçmiş kanıttır ve yeni49canlı ile eşitlik iddiası değildir. İstemci kodu/binary/`.env` veya kişisel simülatör bu takipte değiştirilmedi. Yeni normal istemci §34'te kuruludur; koleksiyon tekrar açılınca `refreshAvatarCatalog` ile güncel public listeyi alır. Bu takipte kişisel ekran cache yenilemesi veya canlı kullanıcı satın alımı yapılmış sayılmaz.

Kullanıcının sonraki önizleme talebinde mevcut normal BEA uygulaması tekrar öne getirildi; TR giriş ekranı screenshot/native AX ile görüldü. Yeni derleme/hesap/seans/test koşusu yok. Kurulu22 PNG/manifest ve ortam hash'i bağımsız salt dosya kontrolüyle aynı: açılış (ham çıktı §37 temizliğinde kaldırıldı), görüntü (ham çıktı §37 temizliğinde kaldırıldı), devir§35.3.
