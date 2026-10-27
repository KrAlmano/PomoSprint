# 28 Ekim gece — yerel ekonomi, RLS ve kota tekrar denetimi

Bu rapor normal profil ekonomisi, avatar sahipliği ve §33'te kalan sunucu risklerini kapsar. **Canlı servis isteği0.** `.env` okunmadı, anaQA veritabanının kullanıcı profilleri incelenmedi. `pomosprint_night_backend` inceleme kopyasından ayrı `pomosprint_night_security` ve `pomosprint_night_start30` klonları oluşturuldu; yalnız yeni etiketli QA hesapları kullanıldı. SQL rollerine `authenticated`/`anon` hakları verilerek gerçek işlevler çalıştırıldı. Bu bir HTTP/native veya tam süreli kullanıcı testi değildir.

## Kabul kontrolleri

**41/41 güvenlik kabul kontrolü geçti.** Bunlar aşağıdaki açıkların giderildiği anlamına gelmez; açıkların yeniden üretimi ayrı tutuldu.

- Profil başka kullanıcının satırını/e-postasını göstermez veya adını değiştirmez. Kendi profilindeki puan, kum, dakika, seri, kademe, Premium ve avatar alanlarının doğrudan değiştirilmesi engellenir; doğrudan profil silme de reddedilir.
- Normal seans, avatar sahipliği, başlangıç, competition event ve deneme cüzdanı tablolarına doğrudan istemci yazımı reddedilir. Başka kullanıcının kategorisiyle tamamlama reddedilir ve ekonomi değişmez.
- Ücretli avatara sahip olmadan kuşanma, Premium olmayanın Premium satın alması, lig ödülünü satın alma ve yetersiz bakiye reddedilir. Ücretsiz varsayılan kuşanma geçer. Başkasının sahipliği okunamaz/kullanılamaz.
- Aynı avatarın iki eşzamanlı satın alınmasında bir ücret; farklı iki500kumluk avatarı500kumla alma yarışında yalnız bir satın alma. Satın alma ile normal tamamlamanın yarışında her iki bakiye değişimi korunur.
- Normal tamamlamada duplicate ve çakışma ikinci ödül üretmez. Başlangıç kaydı tek başına ödül üretmez; anon satın alma/başlangıç çağrısı reddedilir.

## Yeniden üretilen riskler

| Bulgu | Somut yerel kanıt | Durum |
|---|---|---|
| Normal çevrimdışı geçmiş tarihli ödül | Sunucu başlangıcı olmadan50dk isteği,51dk önceki `p_started_at` ile saniyenin altında12puan20kum verdi; `start_verified=false`, cap `null` | Mevcut politikadır; bu gece değiştirilmedi. Kullanıcı/ürün kararı gerekir. Deneme ayrı sunucu başlangıcıyla korunur. |
| Başlangıç kotası atomik değil |99 kayıt+iki paralel istek→101kayıt, iki `created:true` |30 numaralı aday düzeltmede giderildi; canlıya uygulanmadı. |
| Aynı UUID yarışında yanlış makbuz | İki paralel istek tek satır oluşturdu ama ikisi de `created:true` döndü |30 adayında tek `true`, diğeri `false`. Ekonomi çoğalması gözlenmedi. |
| UUID/süre uyuşmazlığı sessiz |25dk kayıt UUID'siyle50dk tekrar kabul edildi; kayıtta25 kaldı |30 adayında açık metadata hatası; önceki kayıt korunur. |
| Waitlist onaysız/kotasız giriş | Anon SQL rolü12 yeni yerel adresi `marketing_consent` olmadan kabul etti |§33 bilinen risk sürer. Bu yalnız SQL yetki kanıtıdır;12HTTP isteği veya mail teslimi deneyi değildir. |

`register_session_start` mevcut mobil normal sayacın başlangıç yolu değildir.101kayıt bulgusu normal seansın çöktüğü veya101kez puan üretildiği anlamına gelmez. Saatlik/günlük bütün API'ler için genel abuse/fatura limiti bulunduğu sonucuna varılmamalıdır.

Normal ödülün daha sıkı doğrulanması, mevcut offline ürün davranışıyla birlikte tasarlanmalıdır: istemcinin sunucu başlangıç makbuzunu kalıcı UUID ile edinmesi ve doğrulanmamış/offline kayıt için açık ödül politikası gerekir. Limiti sessizce0'a çekmek mevcut dürüst istemcilerin puanını da keser. Bu rapor böyle bir politika değişikliği yapmaz.

## 30 aday düzeltmesi

[30 rehberi](../supabase/proposed/30_session_start_atomic_README.md), ileri/down/DRYRUN ve `overnight_session_start_atomic.py` hazır. **31/31** izole kontrol geçti; DRYRUN içindeki10 madde bu toplamın parçasıdır. Geri alma orijinal işlevi tam geri getirir ve satırları korur. İlk deneme sırasında eksik SQL ayıracı test tarafından bulundu ve dosyalar düzeltilerek tam tur yeniden geçti. Ek bir eski/yeni davranış deneyi de kotanın100'de kaldığını, UUID makbuzunu ve metadata reddini doğruladı; sonuçlar31'e ayrıca eklenmedi.

Parite negatif kontrolleri **8/8**: eski referans korunur;30 için ayrı açık seçenek vardır. Aday yalnız bir işlev hash'i ve kendi migration kaydını değiştirir. `test/session_start_atomic_contract_test.dart` yeni hata metinlerinin mevcut Dart sınıflandırmasıyla uyumunu kontrol eder; Flutter komutları root tarafından çalıştırılır.

Kanıtlar git dışındaki `build/overnight_backend/security_audit_results.json`, `security_candidate_results.json`, `session_start_atomic_results.json`; tekrar aracı `tool/local_supabase/e2e/overnight_session_start_atomic.py`. İlk geniş güvenlik denetiminin yerel betikleri aynı build klasöründe saklanır. Bu rapor yazılırken30 anaQA veya canlıya uygulanmış sayılmaz; son yerel uygulama/parite sonucu kök ilerleme kaydına ayrıca yazılmalıdır.

## 28 Ekim 00:38 — yerel parola saklama doğrulaması

Salt okunur, yalnız loopback bağlantıyla son 12 saatteki `e2e-sim-*@pomosprint.local` hesapları incelendi: **47 QA hesabının 47'sinde bcrypt biçiminde parola özeti** bulundu. `public.profiles` içinde adında `password`, `secret` veya `token` geçen sütun sayısı **0**. Parola özeti, gerçek parola, token veya e-posta listesi çıktıya yazılmadı; yalnız toplu sayılar okundu. Bu kontrol canlı Auth ayarları veya tüm uygulama güvenliği için onay değildir; canlı servise bağlanılmadı.

## 28 Ekim 01:24 — yalnız yerel native test hostu

`e2e_host.py` için gerçek geçici HTTP sunucusunda fail-first kontrol yapıldı: yabancı Origin ve `Origin: null` ile `POST /psql` çağrısı önce 200 dönüyor ve mock SQL çalışıyordu. Bu, canlı API bulgusu değil, loopback QA aracına tarayıcı erişimi bulgusudur. Genel GET/POST kapısı eklendi: Origin veya herhangi bir Sec-Fetch başlığı reddedilir; tek Host başlığı yalnız loopback/Android alias ve gerçek dinleme portu olabilir. Böylece SQL, ekran görüntüsü, cihaz, yerel e-posta ve bağlantı kesme yolları aynı korumadan geçer.

Yeni 16 HTTP güvenlik testi + mevcut 12 ekran görüntüsü testi **28/28 geçti**. Testlerin SQL/cihaz/e-posta yan etkileri mock'tur. Tarayıcıdan engellenen isteklerin mock çağrı sayısı sıfır; native text/plain SQL ve cihaz yolları çalışır. `PGOPTIONS=default_transaction_read_only=on` trusted QA sorgularında hata önlemidir; keyfî SQL için tek başına güvenlik sınırı olarak sunulmaz.

Çalışan Android hostu, gerçek Maraton odak sayacı devam ederken aynı port ve cihazla yeniden yüklendi; uygulama/sayaç/veritabanı yeniden başlatılmadı. Yerel gerçek smoke: native `/health` 200, yabancı Origin ile aynı yol 403. iOS sonraki test hostu yeni korumayla açıldı. Kanıt: `/tmp/pomosprint_e2e_host_security_before.log`, `..._after.log`, `/tmp/pomosprint_android_v13_reloaded_host.log`.
