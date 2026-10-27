# Şifre sıfırlama teşhisi ve düzeltmeleri — 7 Ekim 2026

## Kullanıcıda görülen sorun

Kullanıcı simülatörde Şifremi Unuttum'u denedi, kişisel kutusuna mail gelmediğini ve şifresinin değişmediğini bildirdi. Denemenin bir önceki turda açık bırakılan **yerel Supabase derlemesinde** yapıldığını kullanıcı doğruladı. Bu derleme `http://127.0.0.1:54321` kullanıyordu: posta dışarı gönderilmez, Mailpit'te tutulur; canlı hesaptan ayrı kullanıcılar vardır. Olmayan yerel e-posta için Auth hesap keşfine karşı yine başarılı dönebilir. Dolayısıyla başarı ekranı canlı hesaba mail gönderildiğinin veya şifre değiştiğinin kanıtı değildi.

## Yapılanlar

1. iPhone 16 Plus / iOS 18.6 simülatöründe **normal `lib/main.dart`**, yerel URL/anon ve QUICK_TIMER bayrakları olmadan açıldı. `.env` ve son derlemenin env asset'indeki URL, beklenen canlı Supabase projesi olarak doğrulandı. Son derleme 16,8 sn'de geçti; Flutter'dan ayrılınca Runner çalışmaya devam etti. Ajan kişisel hesapla giriş yapmadı veya parola değiştirmedi.
2. `BackendConfig.isLocalBackend` ve servisin bağlı yapılandırmasından gelen salt okunur getter eklendi. Bu yalnızca ortam açıklamasıdır; kısa seans veya API yetkisi vermez. Loopback ve Android emülatör hostları tanınır; `localhost.example.com` gibi adresler yerel sayılmaz.
3. Şifremi Unuttum ve gönderim sonucu ekranları yerel derlemede açıkça **gerçek gelen kutusuna gönderim yapılmadığını, Mailpit ve hesapların ayrı olduğunu** söyler. Gönderim başındaki ortam sonucu sonraki ekrana taşınır. Normal TR başlığı “E-postanı kontrol et” oldu; koşullu hesap-varlığı açıklaması korunur. Yeni metinler TR/EN, l10n üretildi.
4. Web reset sayfasında token doğrulamanın 5xx, bilinmeyen/kodsuz 429 ve bozuk başarılı yanıtları yanlışlıkla “bağlantı süresi doldu” sayıp formu kapatması düzeltildi. Geçici hatada form ve doğrulama bilgisi korunur; uygun hata ve yeniden deneme mümkündür. Bilinen kalıcı token hataları ile 401/403 formu kapatır. Başarılı yanıtın token'ı boş olmayan string olmalıdır. HTML script sürümü `20261007b` yapıldı.

## Canlı ayar kontrolü

Kullanıcının verdiği Safari/Supabase oturumunda **salt okuma** yapıldı:

| Alan | Görülen değer |
|---|---|
| Custom SMTP | Açık |
| Host / port | `smtp.resend.com` / `587` |
| Kullanıcı | `resend` |
| Gönderen adresi / adı | `noreply@mail.pomosprint.app` / `PomoSprint` |
| Aynı kullanıcı için minimum aralık | 60 sn |

SMTP parolası açılmadı, kopyalanmadı veya değiştirilmedi; ayar kaydedilmedi. Bu alanların doğru görünmesi yeni mailin teslim edildiği anlamına gelmez. **7 Ekim takip yanıtında kullanıcı “tamam düzeldi sorun yok düzgün çalışıyor” diyerek sorunun çözüldüğünü doğruladı.** Alıcı istemi artık bekleyen iş değildir; yeni test maili gerekmiyor. Ajan canlı mail istemedi veya kişisel parola değiştirmedi. Welcome/bülten gönderen hukuki kimliği ayrı, önceki açık iştir; bu teşhiste ona dokunulmadı.

## Testler ve kanıt

| Kontrol | Sonuç |
|---|---|
| `flutter analyze --no-pub` | Temiz, 5,4 sn |
| Tam Flutter, SCREENSHOTS=true, concurrency=2 | **1131/1131**, 0 atlama/hata, yaklaşık 54 sn |
| Forgot password + backend config alt kümesi | **23/23**; tam toplamın alt kümesi |
| Recovery/sent düzeni | 6 boyut × TR/EN × yerel/normal × 2 ekran = **48 durum**; klavye ve büyük yazı |
| Tüm Node/site/Edge testleri | **103/103**, 0 atlama/hata |
| Web auth sayfaları hedef alt kümesi | 16/16; tam Node paketinin alt kümesi |
| Gerçek yerel Auth → Mailpit → REST doğrulama → parola güncelleme | **9/9**: eski şifre reddi, yeni şifre girişi, tek kullanımlık bağlantı, olmayan hesap gizliliği ve temizleme |
| Yerel test hesabı temizliği | `qa-auth-mail-*` önce 0, sonra 0 |
| Cloudflare yayın dry-run | Geçti; 201 varlık okundu, gerçek deploy yapılmadı |
| Son normal iOS debug açılışı | 16,8 sn; beklenen canlı backend asset'i ve çalışan Runner doğrulandı |

Kanıtlar password_reset/ (ham çıktı §37 temizliğinde kaldırıldı) altında: `flutter_full.txt`, `targeted_flutter.txt`, `node_tests.txt`, `analyze.txt`, `local_auth.txt`, `local_auth_summary.json`, `worker_dryrun.txt`, `final_live_app_launch.txt`, `live_page_status.json`. Tarihsel sayaç ekran dosyaları test öncesi içerikleriyle korundu. E-posta kurtarma token'ı, kişisel alıcı ve parola kanıta yazılmadı.

## Kalan sınırlar ve devam

- **Yeni web JS/HTML henüz yayınlanmadı.** Canlı sayfa HTTP200/no-store ile okunabildi; Python varsayılan istemcisinin HTTP403'ü Safari kullanıcı ajanıyla tekrar kontrol edilerek aşıldı, TLS güvenliği kapatılmadı. Canlı JS hâlâ 6 karakter eşiği ve geçici-hata→expired eski davranışını içerir; kaynak 8 karakter sunucu kuralına hizalıdır. Canlı/kaynak hashleri `live_page_status.json` içindedir. Cloudflare/Wrangler rehberleriyle dry-run yapıldı; gerçek yayın ayrı adımdır.
- Kullanıcı reset sorununun çözüldüğünü doğruladı. Yeni gönderimin Resend Delivered/bounce ve inbox/spam ayrıntıları ajan tarafından bağımsız okunmadı; kullanıcı kabulünü bu teslim metrikleriyle eş tutma. Kullanıcı yeniden istemedikçe ek mail gönderme veya alıcı sorma.
- Yerel 9/9 senaryosu gerçek web tarayıcısını açmaz; token'ı REST ile doğrular. Yerel mobil reset redirect'i üretim URL'sine sabittir, yerel allowlist/site_url ve üretim web config'iyle gerçek yerel Safari zinciri kurulmuş sayılmaz. Yerelde bu zincir için loopback web helper + yerel config/redirect eşlemesi sonraki altyapı işidir; üretim reset testine yerel token taşıma.
- Üretim SQL, auth ayarı/SMTP anahtarı, Edge deploy, hesap açma/silme, mağaza yayını veya Git commit/push yapılmadı. Son açık uygulama normal canlı hesabın giriş ekranıdır; yerel test oturumu değildir. Android çalıştırılmadı; ortak Dart ekranları aynı kodu kullanır, bu tur gerçek Android reset UI koşusu yapılmadı.

Yeni oturum önce [PROJE_DEVIR.md](../PROJE_DEVIR.md) §17 ve [AGENTS.md](../AGENTS.md) Auth/site bölümlerini okumalı. Kişisel reset şikâyeti kullanıcı tarafından çözülmüş olarak kabul edildi; web kaynağının yayını ayrı açık iştir. Docker yalnızca yerel Supabase test hizmetlerini çalıştırır; normal canlı backend'e bağlı uygulama Docker'a ihtiyaç duymaz, iOS simülatörünü Xcode çalıştırır.
