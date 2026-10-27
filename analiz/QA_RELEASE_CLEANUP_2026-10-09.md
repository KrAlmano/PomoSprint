# PomoSprint — Ronin, hizalama ve yayın öncesi temizlik

9 Ekim 2026. Proje kökü: `/Users/almano/Desktop/Projects/Pomodoro`.

Kullanıcının istediği Ronin kaldırma, avatar kartı hizalama ve gereksiz test verisi/kaynak temizliği yapıldı. Yeni ürün özelliği eklenmedi. Canlı Ronin SQL’ini kullanıcı SQL Editor’de uyguladı; ajan yalnız salt okuma ile sonucu doğruladı. Genel yayın, fiziksel cihaz veya mağaza onayı bu çalışmanın kapsamı değildir.

## Avatarlar ve görünüm

- Ronin PNG’si, manifest kaydı ve gömülü katalog kaydı kaldırıldı. Eski sunucu/cache Ronin satırı mağazada ve kayıt seçiminde gösterilmez; eski kuşanılmış ID güvenli temel görselle çözülür.
- **21 özel avatar** kaldı. Her biri **500 kum**, Türkçe/İngilizce adları mevcut; premium/default/lig ödülü işaretleri kapalıdır. Kayıt/onboarding yalnız mevcut **7 aktif ücretsiz** avatarı gösterir.
- Kaymanın nedeni kartın dış Stack’inin iç sütunu kısa ada göre daraltmasıydı. `StackFit.expand` ile kart, görsel ve ad aynı merkezi kullanır. Ad alanı ve avatar üzerindeki fiyat/kilit alanı ayrıdır. Kalan 21 PNG’nin kaynak hash’leri değişmedi; görseller kırpılmadı veya yeniden üretilmedi.
- Türkçe/İngilizce, dikey/yatay ve normal/büyük yazıda 21 × 8 = 168 kart için merkez ve fiyat/ad sınırları kontrol edildi. Hesap değişiminde eski katalog/equip cevabının uygulanmasını engelleyen owner+epoch koruması sürer.

## Canlı veritabanı ve hesap koruması

İleri paket: `20261009233000_remove_unowned_ronin`. Canlı kurulumdan sonra **20/20 salt okuma kontrolü geçti**.

| Kontrol | Sonuç |
|---|---|
| Katalog | 48 toplam, 47 aktif, 21 özel, 7 aktif ücretsiz; Ronin yok |
| Özel fiyat/işaretler | 21 satırın tamamı 500 kum ve güvenli edinme işaretleri |
| Migration geçmişi | `20261009233000` bir kez kayıtlı |
| Hesap/veri | 4 Auth, 4 profil, 9 seans, 11 kategori, 42 unlock korunur |
| Ekonomi | Özgün 250 dakika, 51 puan ve 150 kum aynı |
| Veri hash’leri | Profil ekonomisi ve seans SHA-256 değerleri 8 Ekim özgün kayıtla aynı |
| Yetkiler | 5 avatar RPC ve hesap silme gövde/ACL, tablo RLS, FK ve trigger’lar aynı |

Katalog MD5: `9ad12fc8edb016c69eb45a24f4ac1e11`.
Profil ekonomi SHA: `df52b7c56da670645381af4deee16695cd02fb0a0ccf72c08b15fe623555c18c`.
Seans SHA: `55e9d21bace630b44e48f98f6044cc4257fa77155056e9c998fc40489cbb78a2`.

Canlı envanterde silinebilecek kesin test hesabı bulunmadı: dört hesap eski tarihlidir, açık QA öneki/domain/metadata kanıtı yoktur. Bu hesapları sırf az kullanılmış oldukları için silmedik. Önceden belgelenmiş tek canlı QA hesabı 8 Ekim’de zaten silinmişti; bu kullanıcı için Auth 404 ve ilişkili satırların yokluğu bu tur kurulum öncesinde doğrulandı. Dört hesabın her birini bağımsız biçimde “kesin gerçek kullanıcı” olarak sınıflandırdığımız iddia edilmez.

SQL yalnız Ronin satırını ve migration kaydını değiştirir. Katalog kilidi ve sahiplik/kuşanma kontrolü, eşzamanlı satın alma halinde silmeyi reddeder. Mevcut profil/coin/seans/Auth silmesi yapılmaz. İzole yerel kontroller **24/24**, ayrı DRYRUN **12/12**; 24 toplamı DRYRUN doğrulama maddeleri içerir, 36 bağımsız senaryo diye toplanmaz. Bağımsız SQL incelemesi **17/17 statik/kanıt** kontrolüdür, yeni runtime testi değildir. İleri/geri/DRYRUN dosyaları ve [SQL rehberi](../supabase/tests/20261009_remove_unowned_ronin_README.md) korunur; ileri SQL yeniden uygulanmaz.

## Temizlenenler

- Yalnız `pomosprint-local` Docker test projesi `stop --no-backup --project-id pomosprint-local` ile kaldırıldı. Bu projenin DB/storage/edge veri hacimleri ve hesap/seans fikstürleri artık yok. Diğer projelerin 15 container’ı ve veri hacimleri korundu; genel Docker prune yapılmadı.
- Özel `.runtime` login/define dosyaları, hazır hesap/parola envanteri, eski ham JSON/JSONL/log/fixture/JWT ve ekran görüntüsü klasörleri temizlendi. Tarihsel ham çıktı temizliğinde 1975 dosya / 145.562.083 byte kaldırıldı; insan tarafından okunabilir QA raporları/devir geçmişi tutuldu. Kimlik/e-posta envanteri veya gerçek seans satırları kompakt kanıtta tutulmaz.
- Eski `lib/dev` girişleri, hızlı demo/Maraton/gece/çoklu cihaz araçları, eski `complete_qa_*` tüketicileri ve snapshot’a bağlı tek seferlik avatar bridge’leri kaldırıldı. Kullanılmayan `TextUtil` yardımcı kaynağı silindi.
- `macos/`, `linux/`, `windows/`, `web/` şablonları kaldırıldı; ürün Android/iOS, site `landing/` olarak korunur.
- VS Code’da yalnız normal/profile/release `lib/main.dart` profilleri kaldı. Silinmiş cihaz UUID’si, otomatik QA login veya hızlı sayaç flag’i yok.
- Anlamlı **73 birim/widget test dosyası**, **13 native integration senaryosu**, Node testleri ve SQL izolasyon/zincir altyapısı korunur. Test kaynakları mobil asset değildir. Native `g/i/m` senaryoları eski kısa kayıt bağımlılıklarından ayrıldı; runtime sonuçları bu tur yeniden denenmedi.
- Orijinal Stitch klasörü ve kullanılmayan lig tasarım kaynakları, tek kopyaları kaybolmasın diye `/Users/almano/Desktop/PomoSprint-Tasarim-Arsivi` içine taşındı. Ürün görselleri ve aktif website medyası korunur.
- Derleme/cache envanteri 12,74 GB proje çıktısı; ayrıca eski bu projeye ait Xcode DerivedData 3,32 GB ve proje Gradle cache’i temizlendi. Bunlar mantıksal dosya boyutudur; APFS paylaşımı/diğer işlemler nedeniyle fiziksel boş alan artışıyla birebir aynı sayılmaz. Global SDK/pub cache ve başka projelerin Xcode/Docker verileri silinmedi.
- `.env` hash’i aynı: `d0559d473c9c6408de386fa99e40430822c35615bafa4f634a8c7ff42b7aa386`. İmzalama, `.git`, gerçek hesaplar ve canlı site korunur. Commit/push/deploy yapılmadı.

## Normal sayaç ve eski QA kayıtları

Normal debug/profile/release **25/50 dakika**, Maraton mola **300 saniye**, devam onayı **60 saniye** kullanır. QUICK/SAVE ve yerel kısa mola define’ları etkisizdir; `lib/` içinde QA tamamlanma RPC seçimi veya QA ortam flag okuması yoktur. Sosyal normal 30 saniye polling kullanır.

Açıkça verilen hızlı widget simülasyonu anlamlı regresyonlarda kalır ve yeni ürün modu değildir. Eski `recordAccelerated` kalıcı alanı uyumluluk için okunur: aktif QA sayacı geri yüklenirken temizlenir; outbox kimlik/kategori/ağ/RPC işlemlerinden önce kalıcı `invalid_data` ret listesine taşınır. Normal kayıtlar korunur. Eski QUICK/SAVE define’ları true verilerek **60/60 hedefli test** geçti; bu testler kısa kaydın tekrar açılmadığını kontrol eder.

## Gerçek doğrulamalar

| Kontrol | Sonuç ve sınır |
|---|---|
| Tam Flutter | **1291 PASS**, 0 fail; 5 isteğe bağlı screenshot testi atlandı. 73 loader olayı test toplamına eklenmedi |
| Son analiz | **No issues found**, bütün temizlik/korunan native test değişimleri sonrasında |
| Avatar/legacy alt küme | **114 PASS**, 0 skip; tam Flutter toplamının alt kümesi |
| Node | **133/133 PASS**, ağsız site/Edge regresyonu |
| HTML parça uyumu | `sync_partials.py --check` çıkış kodu 0 |
| Runner | **50/50 CLI/statik kontrol**, shell syntax temiz; DB/cihaz/container başlatmadan yardım/geçersiz senaryo/cihaz seçimi ve kaynak kontrolleri |
| Android release APK | Başarılı, 97.195.322 byte; pakette 21 özel PNG, Ronin 0, QA fixture eşleşmesi 0. Normal main, QUICK define yok |
| iOS release | **İmzasız** normal Runner.app başarılı, 53.931.923 byte; 21 özel PNG, Ronin 0. İmzalı IPA/mağaza/fiziksel cihaz testi değildir |
| Canlı Ronin | **20/20** salt okuma; ajan canlıya yazmadı |
| Git/bağlantı | `git diff --check` temiz; kaldırılan ham artifact linkleri tarihsel düz metne çevrildi |

İlk iOS denemeleri derlemeden önce SwiftPM remote güncelleme çözümlemesinde başarısız oldu. Üretilmiş SourcePackages state’inde eski taşınmış proje yolu saptandı. Workspace çözümlemesi çalıştı; eski build/cache temizliği ve normal pub get sonrası aynı kaynak/sabit paket sürümleriyle temiz iOS derlemesi geçti (Xcode 55,8 sn). Bu durum gizlenmedi; kalıcı ürün veya bağımlılık sürümü değişikliği yapılmadı. APK/Runner.app ve ham derleme/test logları doğrulama sonrası depoda tutulmadı.

## Devam ve yayın sınırı

Şu anda **0 simülatör / 0 runtime / açık uygulama yok**. Bu tur yeni simülatör/emülatör kurulmadı; canlı UI/native görsel veya OS süreç kapatma testleri yeniden çalıştırılmadı. Sonraki cihaz testinde kullanıcı istediğinde tek yeni cihaz kurulmalı, normal main güncel ID ile derlenmelidir. Yerel backend gerektiğinde [güncel yerel rehber](../tool/local_supabase/README.md) izlenmeli; snapshot’ın yeni canlıyla eşit olduğu varsayılmamalıdır.

§33 Sentry derin maskelemesi ve HTTP 500 hata yakalama, waitlist onay/limiter, start API yarış kotası, operasyonel kill switch ve hosted staging açıkları değişmedi. Apple Auth/imzalama, gerçek sağlayıcı/fiziksel cihaz, mağaza beyanları ve kullanıcı tarafından en son verilecek yasal/gönderen kimliği ayrı işlerdir. “Proje temizlendi/derlendi” ile “tam yayın onayı var” aynı sonuç değildir.

Kompakt, kimliksiz kontrol özetleri yerelde `analiz/qa_evidence_20261009/release_cleanup/` altında tutulur ve gitignore’dadır. Kalıcı devir kaydı bu rapor, `PROJE_DEVIR.md` §37, `AGENTS.md`, README ve kısa bağlamdır; eski ham kanıtlara ihtiyaç duymadan okunabilir.

## 10 Ekim ek klasör kontrolü

Kullanıcının kalan gereksiz dosyalar ve indirme boyutu sorusu üzerine salt okuma tekrar yapıldı. Önceki temizlikte gitignore altındaki `release_artifacts/` klasöründe kalan 7 Ekim tarihli iki QA APK, imzasız iOS tar ve özet (toplam 68.513.838 byte) önceki açık temizlik yetkisi kapsamında kaldırıldı. Boş `bin/` kaldırıldı. Hata kayıtları için gerekli eski sürüm sembolleri `release_symbols/` içinde korundu; bunlar güncel uygulama/indirme boyutuna dahil değildir. IDE ve ajan araç ayarları korunur. Ürün kaynağı, avatar görselleri, veritabanı ve paket sürümleri değişmedi; yeni derleme/test iddiası yok. Son ölçümler hâlâ Android evrensel release APK 97.195.322 byte ve iOS imzasız `.app` 53.931.923 byte; gerçek mağaza sıkıştırılmış indirme boyutu bu iki sayıdan doğrudan çıkarılamaz.
