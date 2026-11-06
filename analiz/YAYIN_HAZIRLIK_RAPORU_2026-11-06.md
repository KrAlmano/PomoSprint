# PomoSprint yayın hazırlığı ve kontrol raporu — 6 Kasım 2026

## Sonuç ve kapsam

Uygulama ve sunucu için **yayına hazır olduğu henüz doğrulanmadı**. Özellikle normal seans ödülünün sunucuda doğrulanması canlıda eksik; yaş kontrolünün de kapsam sınırları var. Aşağıdaki yerel düzeltmeler üretime kendiliğinden geçmez: mobil kod için yeni dağıtım, önerilen sunucu değişiklikleri için ayrıca gözden geçirilmiş geçiş gerekir.

Bu rapor belirtilen dört 6 Kasım kanıt raporunu özetler. Bu çalışma kapsamında canlıya sunucu paketi kurulmadı, 31 uygulanmadı ve üretim kullanıcı verisi değiştirilmedi. Yereldeki site güncellemeleri canlıda yayımlanmış sayılmamalıdır. Canlıyı salt okunur incelemek, tüm kullanıcı akışlarının veya güvenlik sınırlarının uçtan uca doğru olduğunu tek başına kanıtlamaz.

## Öncelikli açık konular

1. **Normal seansların ödül doğrulaması:** Canlıda 34 kurulu değil ve `unverified_session_daily_cap=null`. Sunucu başlangıcı doğrulanmamış sahte normal seanslara ödül verilebilmesi riski devam ediyor. Kullanıcının seçtiği “çevrimdışı çalışmayı kaydet, puan ve kum verme” politikası canlıda etkin değil. [34 incelemesi](lig_guvenlik_2026-11-06/README.md).
2. **Yaş kontrolü:** Mevcut sunucu, doğum yılı boşken onboarding'in tamamlanmasını tamamen engellemiyor. Yerelde hazırlanan 35, bu durumu kısmen ele alır; onboarding tamamlanmamış hesapların bazı RPC'leri çağırmasını veya yanlış yaş beyanını engellemez. Sadece doğum yılı ile gerçek 13. doğum günü kesin tespit edilemez. **35 canlıda kurulu değil.** [35 kapsamı](../supabase/proposed/35_onboarding_birth_year_guard_README.md).
3. **Deneme geçmişinin sayfalaması:** Eski sunucu aynı `started_at` değerini paylaşan kayıtları sayfa sınırında atlayabilir. Yeni istemcide eksik olabilecek geçmiş için uyarı ve yerelde v2 sunucu taslağı hazır; **v2 canlıya uygulanmadı**. Eski mobil uygulamalar uyarıyı da almaz. [Sayfalama kanıtı](RAPOR_VERI_BUTUNLUGU_2026-11-06.md).
4. **E-posta teslimi:** Resend ekranında `mail.pomosprint.app` doğrulanmış, SPF/DKIM başlıkları mevcut ve Free plan görünüyordu. Gönderim geçmişi yüklenmedi; gerçek e-posta teslimi, kullanılan kota ve SMTP bu turda doğrulanmadı. Test e-postası da gönderilmedi.
5. **Kötüye kullanım sınırları:** Bazı API'lerde hesap başına kota var; bu, bütün uçlarda IP/bot sınırlaması veya sürpriz maliyete karşı tam koruma anlamına gelmiyor. Bekleme listesinde genel hız sınırı ve yanıtlardan adres varlığını tahmin etme riski açık kalıyor.

## Canlı bağlantılar ve veri güvenliği

- `pomosprint.app` için yönlendirmeler takip edildiğinde incelenen **20/20 sayfa HTTP 200** döndü. Belirtilen eski kaynak ve bazı görsellerin hash karşılaştırması eşleşti. Son yerel görseller ve lig açıklamaları bu canlı kontrol sırasında yayımlanmış değildi.
- Supabase Auth sağlık uç noktası, anonim sınav ve avatar katalogları HTTP 200 döndü. İncelenen özel tablolara anonim okuma HTTP 401 verdi. Kontrol edilen 13 tabloda RLS açık, 13 tabloda anon tablo SELECT kapalı; beş deneme/lig tablosunda authenticated doğrudan INSERT/UPDATE/DELETE kapalı bulundu. İncelenen seans, Deneme ve Maraton RPC overload'larında anonim EXECUTE kapalıydı.
- Seçilen profil, seans, kategori, deneme ve arkadaşlık okuma politikalarında sahip/arkadaş koşulları görüldü. Bu, tüm politikaların veya gerçek iki farklı hesabın bütün erişim yollarının canlıda doğrulandığı anlamına gelmez.
- `auth.users.encrypted_password` dolu değerlerinin bcrypt biçiminde olduğu, anon/authenticated rollerin bu alanı okuyamadığı parola değerleri alınmadan incelendi. Gerçek parolaların gücü, kullanıcı cihazları ve tüm olası saldırılar değerlendirilmedi.
- Başlatma kotası için 33 numaralı işlevin kurulu olduğu ve hash'inin eşleştiği kaydedildi. [Ayrıntılı canlı kontroller](GUVENLIK_BAGLANTI_KONTROLU_2026-11-06.md).

Ayrı güvenlik alt ajanının genel incelemesi otomatik inceleme tarafından durduruldu: “This content was flagged for possible cybersecurity risk”. Kesilen spesifik işlem mevcut kanıtta belirtilmediği için bu rapor onu varsaymaz. **Genel güvenlik incelemesi tamamlanmış sayılmamalıdır**; yukarıdaki sınırlı, salt okunur sonuçlar geçerliliğini korur.

## Raporlar, oturumlar ve çevrimdışı kayıt

Yerel istemcide bozuk kuyruk veya sayaç kaydı boş veri gibi kabul edilip üzerine yazılmıyor. Okunamayan yerel seans kayıtları rapor ve ret ekranlarında TR/EN uyarıyla gösteriliyor. Normal seansın başlangıcı, duraklatılması ve devamı; ayrıca Maraton duraklatma/devamı, gerekli yerel yazı doğrulanmadan yeni durum olarak uygulanmıyor. Tamamlanan normal seansın kaydı başarısız olursa yeni seansın kurtarılabilir kaydı ezmesi engelleniyor ve aynı kimlikle tekrar denenebiliyor.

Eski e-posta anahtarlı sayaç kaydı UID'ye başarıyla taşınamazsa ya da eski kaydın kaldırılması doğrulanamazsa seans açılmıyor. İki farklı kayıt varsa ikisi korunuyor ve otomatik seçim yapılmıyor. Geçici hata sonrasında uygulamanın yeniden açılması geçişi tekrar dener; bozuk veya çakışan kayıt için otomatik onarım ekranı yok, destek gerekebilir. Uyarı kalıcı bir ekran değil. Platform hem yazmayı hem eski değeri geri yüklemeyi reddederse kesin veri kurtarma garanti edilemez.

Deneme istekleri yerelde beklenen hesaba ve o hesabın yetkilendirme başlığına bağlandı. Gerçek SDK ile **yalnız loopback HTTP** kullanılarak hesap değişimi sınandı; bu, gerçek üretim hesaplarıyla test değildir. Mevcut sunucu 24 saatten eski çevrimdışı seansları reddedebildiğinden uzun süre çevrimdışı kalan kayıtlar açısından sınır sürer. [Ayrıntılı davranış ve kanıt](RAPOR_VERI_BUTUNLUGU_2026-11-06.md).

## Ligler, ödüller ve zamanlanmış işler

- Ayrı yerel QA veritabanında yalnız sentetik hesaplarla aylık lig testleri **21/21**, ayrı klonda normal/deneme ve global/hedef görünümü kontrolleri **46/46** geçti. 25 kişilik oda kapasitesi, 26. kullanıcı için yeni oda, tek üyelik, hedef ayrımı, hedef değişiminin sonraki döneme kalması, örnek terfi/düşme/avatar ve tekrarlı kapanış senaryoları kontrol edildi. Bunlar üretim kullanıcılarıyla gerçek dönem geçişi değildir.
- 34 taslağı için yerel testler, doğrulanmamış ödülsüz seansların eski lig aktiflik hesabında yanlış terfiye katkı verebilmesi riskini ortaya koydu. Önerilen paket bu geçiş riskini ele alacak şekilde yerelde sınandı; **34 canlıda kurulmadı, cap=0 etkin değil**. Eski uygulamalar ve cihaz kuyrukları için dağıtım uyumu ayrıca doğrulanmalı.
- Salt okunur incelemede üç zamanlanmış işin son kayıtlı denemesi başarılı göründü: lig **6 Kasım 00:01**, activity feed **06:00**, privacy retention **06:17** — saatler **Europe/Istanbul**. Başarı kaydı tek başına sonuçların bütün iş kurallarına uygunluğunu kanıtlamaz.
- Aylık normal/Deneme lig geçişi **1 Aralık 2026 00:00 Europe/Istanbul** için yapılandırılmıştı; `monthly_active=false`, `legacy_finalized=false`. Bu geçiş henüz doğal cron ile yaşanmadı. Kapanan aya ait çevrimdışı seans cron sonrasında gelirse lig kararı tekrar hesaplanmıyor; kullanıcı etkisi ve ürün politikası ayrıca netleştirilmeli. [Lig kanıtları](lig_guvenlik_2026-11-06/README.md).

## Web sitesi ve görsel uyumu

Deneme kataloğu ve devam eden Deneme için dört yeni site görseli, iOS iPhone 17 simülatöründe ayrı bir QA uygulamasından ve kurgusal, ağsız verilerle hazırlandı. Bunlar gerçek kullanıcı hesabıyla veya Supabase ile uçtan uca test değil. Görsellerin ölçeklenmesi ve Dynamic Island farkları [site QA kaydında](site_qa_2026-11-06/README.md) açıklanıyor.

Sitedeki diğer 28 Ekim görselleri ve videolarının tamamı bu turda yeniden çekilip uygulamayla piksel piksel karşılaştırılmadı. Bu nedenle tüm sitenin uygulamayla birebir uyumlu olduğu söylenemez. Yeni yerel görseller ve site düzenlemeleri ayrıca yayımlanmadıkça canlı siteyi değiştirmez.

## Testler ve sınırlar

- Rapor, istatistik, deneme ve kuyruk ilk hedefli turu **144/144**; Deneme SDK sahiplik/sayfalama turu **36/36**; başka bir birleşik hedefli tur **44/44** geçti. Bunlar kısmen aynı testleri içerir, toplam alınmamalıdır.
- Diyalog, uyarı ve çeviri turu **24/24**; eski anahtar taşıma ve bozuk sayaç birim/widget turu **14/14** geçti. Saklama hataları gerçek fiziksel disk doldurularak değil, yerel SharedPreferences taklidiyle sınandı.
- Yerel PostgreSQL denemesinde aynı zaman damgalı 101 Deneme kaydının eski uçta 100, v2'de 101 döndüğü gösterildi. Yerel DRYRUN/rollback ve farklı sahip kontrolleri de sınandı. Auth ve şemanın ilgili olmayan bölümleri taklittir; gerçek Supabase Auth/PostgREST ve canlı şema paritesi değildir.
- `scripts` için npm audit 0 bilinen açık; `pubspec.lock` içindeki 132 hosted Dart paketi için OSV toplu sorgusu 0 eşleşme bildirdi. Bunlar tüm olası açıkları veya native Swift/Gradle bağımlılıklarının tamamını kapsamaz.
- Android API 36 emülatöründe, ayrı uygulama kimliği ve sahte backend kullanan debug derlemesi kuruldu; çevrimdışı Deneme kataloğunda TYT, AYT ve YDT kartları açıldı. [Ekran görüntüsü](site_qa_2026-11-06/native/android-exam-catalog-qa-tr.png). Gerçek hesap, canlı servis ve sınav tamamlama akışı bu kontrolde kullanılmadı. Emülatör ilk açılırken Android System UI geçici yanıt vermeme uyarısı gösterdi; sonrasında kayboldu. QA paketi kaldırıldı ve yalnız bu test için açılan emülatör kapatıldı.
- Son kaynak durumunda `flutter analyze` temiz; `flutter test --concurrency=2` **1.590 başarılı, 5 atlanan, 0 başarısız**. Atlananlar isteğe bağlı ekran görüntüsü alma testleridir. Site ve sunucu `scripts` Node testleri **178/178**; site Worker için dağıtım yapmayan `wrangler deploy --dry-run --keep-vars` başarılıdır.
- iOS `flutter build ios --release --no-codesign` başarılı; üretilen `Runner.app` 55,2 MB olarak raporlandı. Bu imzasız derlemedir, mağaza indirme boyutu veya imzalı cihaz kurulumu olarak değerlendirilmez.
- Fiziksel iOS/Android cihazlarda gerçek disk doluluğu, işletim sisteminin uygulamayı öldürmesi, gerçek cihaz bildirimleri ve gerçek çok hesaplı üretim akışı; ayrıca gerçek Google/Apple girişi, hosted staging, Sentry canlı alarm teslimi ve imzalı mağaza dağıtımı bu turda doğrulanmış sayılmıyor.

## Yayından önce sıradaki karar ve doğrulamalar

1. 34 ve çevrimdışı ödül politikasının eski mobil sürüm ve kuyruklarla uyumluluğunu, 35'in kapsam eksiklerini ve Deneme sayfalama paketini ayrı ayrı gözden geçir; canlı şemaya geçiş ancak uygun rollout ve geri alma planıyla ele alınmalı.
2. Canlı doğal ay geçişini ve geç kalan çevrimdışı kayıtların lig etkisini doğrula; test ortamındaki sentetik sonucu canlı cron kanıtı sayma.
3. Resend üzerinden yetkili bir gerçek teslim testi ve kota/SMTP kontrolü yap; kullanıcıya gönderilmiş e-posta varmış gibi raporlama.
4. Yeni mobil sürümün imzalı iOS/Android dağıtımını, gerçek cihaz bildirimlerini ve güvenlik/yaş akışlarının tamamını ayrıca doğrula. Site görsellerinin tamamı için güncel ekranlarla karşılaştırma yap ve yeni site kaynaklarının dağıtım durumunu kontrol et.

Kaynaklar: [canlı bağlantı ve güvenlik](GUVENLIK_BAGLANTI_KONTROLU_2026-11-06.md), [rapor ve veri bütünlüğü](RAPOR_VERI_BUTUNLUGU_2026-11-06.md), [lig ve sunucu paketleri](lig_guvenlik_2026-11-06/README.md), [site görselleri](site_qa_2026-11-06/README.md).
