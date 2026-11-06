# Canlı bağlantı ve güvenlik kontrolü — 6 Kasım 2026

## Canlı salt okunur inceleme

- `pomosprint.app` için yönlendirmeler izlenerek 20/20 sayfa HTTP 200 döndü. Ana, Özellikler ve SSS TR/EN, CSS/JS ve önceki dört rapor PNG'si 1 Kasım kaynaklarıyla SHA-256 eşleşti; şifre sıfırlama yardımcı sayfasının `.html` yönlendirmesi deneme sorgu parametresini korudu. Bu tarihli yerel yeni görseller ve aylık lig açıklamaları henüz dağıtılmadı.
- Supabase Auth health, anonim sınav kataloğu ve avatar kataloğu HTTP 200. Kontrol edilen özel tablolar (profil, seans, kategori, arkadaşlık, deneme kayıt/sonuç/cüzdan, lig oda/üyelik ve Maraton verileri) anonim okumada HTTP 401. Kritik 13 tabloda RLS açık; 13'ünde anon tablo SELECT kapalı; beş deneme/lig tablosunda authenticated doğrudan INSERT/UPDATE/DELETE kapalı. Bu, gerçek farklı iki hesap arasında tüm RLS yollarının canlıda test edildiği anlamına gelmez.
- İncelenen seans, Deneme ve Maraton RPC overload'larında anonim EXECUTE kapalı. Seçilen profil/seans/kategori/Deneme/arkadaşlık SELECT politikalarında sahip veya arkadaş kontrolü görüldü. Parola değerleri alınmadan `auth.users.encrypted_password` alanındaki dolu hash'lerin bcrypt biçimi ve anon/authenticated okuma izni bulunmadığı kontrol edildi; gerçek parolaların gücü veya kullanıcı cihazları incelenmedi.
- 33 başlatma kotası kurulu ve işlev hash'i eşleşiyor; bekleme listesinde anon onay ve sunucu-token yetki düzeltmesi uygulanmış. Üç cron'un son kayıtlı denemesi başarılı: lig 6 Kasım 00:01, activity feed 06:00 ve privacy retention 06:17 İstanbul. Bu, cron sonuçlarının bütün iş mantığıyla doğru olduğunu kanıtlamaz.
- Aylık normal/Deneme lig geçişi 1 Aralık 2026 00:00 Europe/Istanbul için yapılandırılmış; `monthly_active=false`, `legacy_finalized=false`. Sitedeki tarih açıklaması yerelde düzeltildi. Geçişin doğal cron ile işlenmesi henüz yaşanmadı.

## Doğrulanmış açıklar ve kapsam

1. **Normal seans ödül güvencesi canlıda eksik:** 34 kurulu değil, `unverified_session_daily_cap=null`; sunucu başlangıcı doğrulanmamış sahte seansa hâlen ödül riski var. Kullanıcının seçimi (offline çalışma kaydedilsin, puan/kum verilmesin) canlıda etkin değil. Güncellenen 34 adayı, eski lig aktiflik geçişi riski dahil yalnız yerelde test edildi; eski mobil sürümler ve kuyruklar için uyumlu rollout gerekir. 24 saatten eski offline kayıt reddi sürer. [Lig/34](lig_guvenlik_2026-11-06/README.md).
2. **Yaş kapısı kısmi:** Mevcut trigger null doğum yılında onboarding tamamlamasını engellemiyor; lokal sentetik tekrar ve kısmi 35 adayı hazır. 35, onboarding tamamlanmadan bazı RPC çağrılarını veya yanlış yaş beyanını engellemez; bu kapsam açığı ayrı yerel klonda gösterildi. Canlı 35 kurulmadı. [35 kapsamı](../supabase/proposed/35_onboarding_birth_year_guard_README.md).
3. **Rapor sınırında sayfalama:** Aynı `started_at` sınırındaki Deneme kayıtları eski RPC'de atlanabilir. İstemci uyarısı ve v2 RPC yalnız yerelde, canlıya uygulanmadı. [Rapor kanıtı](RAPOR_VERI_BUTUNLUGU_2026-11-06.md).
4. Bekleme listesinde genel bot/IP hızı sınırı ve yinelenen adres yanıtından varlık tahmini riskleri sürer. Bazı API'lerde hesap bazlı kota bulunması genel abuse veya fatura koruması kanıtı değildir.
5. Resend Safari oturumu kullanıcı girişinden sonra kontrol edildi: `mail.pomosprint.app` Verified ve gönderime hazır gösteriliyor; SPF/DKIM başlıkları mevcut. Free plan görünüyor. E-posta geçmişi yüklenmediği için gerçek teslim, kullanılan kota ve SMTP doğrulanamadı; e-posta gönderilmedi. Gerçek sağlayıcı girişi, fiziksel cihaz bildirimleri, hosted staging, Sentry canlı alarm teslimi ve imzalı mağaza dağıtımı bu turda doğrulanmış sayılmaz.

## Bağımlılık ve testler

`npm audit --json` scripts bağımlılıklarında 0 bilinen açık; OSV toplu sorgusunda `pubspec.lock` içindeki 132 hosted Dart paketi için 0 eşleşen bildirim verdi. Bu sonuç, söz konusu veritabanlarının kapsamadığı açıkları veya Swift/Gradle/native bağımlılıkların tamamını kapsamaz. Flutter genel ve hedefli testlerin nihai sayıları ana raporda ayrı kaydedilir.
