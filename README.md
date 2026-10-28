# PomoSprint

PomoSprint, iOS ve Android için odaklanma ve sınava hazırlık uygulamasıdır. Gerçek 25/50 dakikalık Pomodoro, 2/3/4 seanslık Maraton, Deneme, günlük/haftalık/aylık raporlar, hedefe göre ligler, avatarlar ve arkadaş durumlarını bir araya getirir. Puan, kum ve lig sonuçları sunucuda hesaplanır; istemcinin girdiği netler ödül üretmez.

## Dal ve güncel durum

Geliştirme dalı [`codex/gece-2026-10-27`](https://github.com/KrAlmano/PomoSprint/tree/codex/gece-2026-10-27); repo özeldir. Kullanıcının son yetkisi yalnız bu dalı normal push ile yedeklemektir. `main` push/merge, force push ve canlıya deploy yapılmaz. Yeni 27–30 ve 32 SQL paketleri yerel inceleme içindir; canlıya uygulanmış sayılmaz. **31 Maraton paketi kullanıcı kararı bekliyor ve bu doğrulama ortamına kurulmaz.**

Tek güncel sonuç kaynağı [doğrulama raporu](analiz/DOGRULAMA_RAPORU_2026-10-28.md) ile [ilerleme kaydıdır](analiz/CODEX_ILERLEME.md). Her yeni çalışmada [AGENTS.md](AGENTS.md), [PROJE_DEVIR.md](PROJE_DEVIR.md) ve bu kayıtlar okunur. Eski raporların sayıları, başlatılmış bir uzun koşu veya kontrollü geçmiş, yeni doğal süre/native başarı olarak sunulmaz. README son kapı sayılarını tekrar ederek ikinci bir çelişkili durum tablosu tutmaz.

A2 düzeltmeleri: kısmi ders sonuçları ve çevrimdışı kalıcı kuyruk `11ea62c`; otomatik/düzenlenebilir boş sayısı ve yalnız düzenlenen derslerin kaydı `8446eff`. Bunlar kayıtlı kod düzeltmeleridir; bütün platform/dil matrisi ve B site tarayıcı kontrolünün final sonucu ayrıca rapordan okunur. Bu dal genel mağaza yayın onayı değildir.

## Ürün sözleşmesi

| Alan | Davranış |
|---|---|
| Pomodoro | 25 veya 50 dakika; bir duraklatma hakkı. Ödüllendirilen 25 dk odak 5, 50 dk odak 12 temel puan ve seans başına 20 kum. Normal derlemede hızlandırılmış sayaç veya test etiketi yok. |
| Maraton | 2/3/4 odak; aralarda 5 dk mola ve ardından 1 dk içinde ön planda “Buradayım” ile sunucu onayı. Erken ayrılınca bitmiş odaklar normal puanlarıyla korunur. Tam plan bonusu 25 dk için +2/+3/+5, 50 dk için +4/+6/+10; sunucu yalnız bir kez verir. |
| Deneme | TYT, AYT, YDT, LGS Sözel/Sayısal, TUS Temel/Klinik, DUS; 3-2-1 sonrası duraklatma/mola yok. Sunucu başlangıç/bitişi kapanma ve arka plandan etkilenmez. Çakışan Pomodoro/Maraton/Deneme başlatılamaz. |
| AYT erken bitiş / ayrıntılar | Yeni32 sözleşmesinde yalnız AYT erken tamamlanabilir. Gerçek süre raporlanır; kum sunucuda `floor(snapshot_kumu × gerçek_saniye / planlanan_saniye)` ile hesaplanır. Yeni tam ödüller LGS Sözel60, LGS Sayısal70, YDT95, TUS Temel/Klinik110, DUS120, TYT130, AYT145; bütün yeni denemeler bu tabloyu kullanır; eski active/completed kayıtların ödülleri korunur. Dört40 soruluk AYT testinden çözülen1–4 seçilir. Tüm tamamlanmış denemelere120 karakter başlık ve2000 karakter özel not eklenebilir. Eski kayıtların ödülü değişmez; net/başlık düzenleme ödül üretmez. |
| Net girişi | Doğru/yanlış değişince boş otomatik hesaplanır, yine de elle düzenlenir. Kısmi ders sonucu kaydedilir; dokunulmayan ders için sıfır sonuç uydurulmaz. Doğru/yanlış/boş için negatif, tam sayı olmayan veya soru kotasını aşan giriş engellenir; hesaplanan net negatif olabilir. YKS/TUS/DUS doğru−yanlış/4, LGS doğru−yanlış/3; TR virgül, EN nokta. Netler puan/kum/lig değiştirmez. |
| Raporlar | Pomodoro+Maraton+tamamlanan Deneme süreleri ortak toplamdır. Deneme ayrı satırdır, derslere paylaştırılmaz. Vazgeçilen deneme geçmişte kalır fakat süre/seri/ödül/tamamlama sayısına katkı vermez. Gün sınırı profil IANA saat diliminde 04:00. |
| İçgörüler | Son 3 haftadaki yeterli karşılaştırılabilir denemede ders netindeki değişim ve ilişkili kategori çalışma süresi birlikte gösterilir; neden–sonuç iddiası yapılmaz. Netler kişiseldir. |
| Ligler | Normal ve Deneme ekonomisi ayrı. Hedef kategorisi odaları en fazla 25 kişi; ilk puanlı aktiviteyle yerleşme ve ek global görünüm. Ay sınırı Europe/Istanbul ayın 1'i 00:00; ay içi hedef değişimi sonraki ay geçerli, puan korunur. Terfi/ödül için aktivite şartları vardır. |
| Sosyal | Odaklanıyor, yalnız Maraton molasında Molada ve yeni Deneme sunucusunda Denemede. Görünür ekranda 30 saniyelik sorgu; anlık push iddiası yok. Görünürlük/engelleme kuralları korunur. |
| Koleksiyon/dil | 7 ücretsiz başlangıç avatarı, 200 kumla açılan 4 karakter, her biri 500 kum olan 21 özel avatar, kazanılan 10 normal lig ödülü: toplam 42 kullanılabilir karakter. Türkçe/İngilizce; yaş adımı ve 13 yaş altı engeli korunur. |

[Resmî sınav kaynakları](analiz/SINAV_KAYNAKLARI_2026-10-28.md), [Deneme API](supabase/proposed/EXAM_API_CONTRACT.md), [lig/geçiş kuralları](supabase/proposed/NIGHT_20261028_README.md). Eski sunucuda Deneme RPC'leri yoksa güvenli kullanılamaz/hazırlık durumu gösterilir; eski normal seans ve rapor yolları kullanılabilir. Ağ veya yetki hatası başarı diye gösterilmez.

## Özel repoyu kur

GitHub hesabının özel repoya erişimi gerekir. Parolayı/kişisel tokenı komut satırına veya repoya yazma; kendi Git kimlik yöneticini kullan.

```sh
git clone --branch codex/gece-2026-10-27 https://github.com/KrAlmano/PomoSprint.git
cd PomoSprint
# Yalnız eksikse boş mobil asset oluştur; mevcut dosyayı okuma/ezme.
python3 -c 'from pathlib import Path; p=Path(".env"); p.touch() if not p.exists() else None'
flutter doctor -v
flutter pub get
flutter gen-l10n
npm --prefix scripts ci
```

Bu çalışmada kullanılan sürümler: Flutter 3.44.8 stable, Dart 3.12.2, Node 26.8.2, Python 3.13.3, Supabase CLI 2.119.0, Docker 29.8.2, Xcode 27.0. Bunlar her makinede güncel sürüm veya hepsi için minimum sürüm iddiası değildir. Kaynak `pubspec.yaml` Dart `^3.12.2` ister. Android JVM/source/target 17, Gradle 8.14 / AGP 8.11.1 / Kotlin 2.2.20, SDK 36 / min 24 ve NDK 28.2.13676358 kullanır. Node minimumu paket tarafından sabitlenmemiştir. [Kurulum ayrıntıları](tool/local_supabase/README.md).

- macOS/iOS: Xcode seçili olmalı; **iOS 18.6 Simulator runtime** ayrıca kurulur. Xcode SDK sürümü ile runtime aynı şey değildir. Runner minimum iOS 16.2'dir. Native eklentiler Swift Package Manager ile bağlanır; projede Podfile olmadığı için kör `pod install` adımı yoktur.
- Android: JDK 17 ve Android SDK 36 gerekir. Flutter'ın Java seçimini `flutter doctor -v` ile kontrol et; gerekirse `flutter config --jdk-dir <kendi-jdk17-yolun>` kullan. Makineye özgü JDK veya eski cihaz UUID'si kopyalama.
- QA cihazları açıkça `flutter devices`, `xcrun simctl list devices available` ve `adb devices` ile seçilir. Bu işin sınırı bir QA iPhone 18.6 ve bir QA Android API 36'dır; başka kişisel cihazlar silinmez/değiştirilmez.

### Ortam ve sırlar

Kök `.env`, Flutter asset'i olduğu için uygulamaya düz metin gömülür: yalnız istemciye açık Supabase URL/anon ve isteğe bağlı Sentry DSN buraya konabilir. Service-role, Resend API key, Sentry AUTH token, yönetim anahtarı, sertifika ve keystore mobil asset veya dart-define'a girmez. `scripts/.env` ve `scripts/.env.example` ayrı, ayrıcalıklı Node/sunucu/operasyon araçları içindir; mobil kök dosyanın yerine kopyalanmaz ve mobil asset yapılmaz.

**Bu checkout'ta kök `.env.example` yoktur.** `pubspec.yaml` kök `.env` dosyasını build asset'i olarak bildirir. Bu yüzden doğru yerel dart-define'lar verilse bile dosya hiç yoksa asset paketleme aşaması başarısız olabilir. `main.dart` içindeki dotenv yükleme hatasını yakalama yalnız çalışma zamanındadır; eksik build asset'ini çözmez. Klonlama adımındaki gibi yalnız dosya eksikse boş asset oluştur; mevcut `.env` içeriğini okuma veya üzerine yazma:

```sh
python3 -c 'from pathlib import Path; p=Path(".env"); p.touch() if not p.exists() else None'
```

İki Supabase dart-define birlikte verilince `BackendConfig` kök `.env` bağlantısını geçersiz kılar; Sentry de yalnız define'dan gelir. Yalnız bir define verilirse yanlış anahtar/adres karışmasını önlemek için bulut kapalı kalır. Definesız normal `flutter run` mevcut `.env` ile **canlıya bağlanabilir**. Boş `.env` yalnız paketleme gereğini karşılar; backend seçimi değildir. Yerel QA için aşağıdaki iki Supabase define ve boş `SENTRY_DSN` açıkça verilir.

`.env`, `scripts/.env`, `.claude/settings.local.json`, anahtar/sertifika/keystore dosyaları commit/push'a alınmaz. `git diff --cached --name-only` ve gönderilecek commitlerin dosya listesi kontrol edilir; 50 MB üstü dosya gönderilmez.

## Yerel Supabase: 27–30, 31 hariç

Bu bölüm yeni bir yerel kurulum içindir. Mevcut QA ortamını yeniden kurma, verisini silme veya yürüyen uzun native koşunun kataloğunu değiştirme. Hosted Supabase'e `link`, kök dizinden `db push/reset` veya canlı yönetim isteği bu adımların parçası değildir.

```sh
supabase start --workdir tool/local_supabase
```

Servisler: API `127.0.0.1:54321`, Postgres `54322`, Studio `54323`, Mailpit `54324`. Yerel e-posta onayı açıktır; kayıt/şifre sıfırlama maili Mailpit'te kalır, kişisel posta kutusuna gitmez. Yerel OAuth/gerçek teslim bu kurulumla doğrulanmış sayılmaz.

Yalnız **yeni, sıfır Auth kullanıcılı** snapshot üzerinde ve QA hesabı açmadan önce:

```sh
python3 tool/local_supabase/prepare_overnight_backend.py
```

Bu script sabit yerel Docker adı/label'ı ve boş kullanıcı guard'larını doğrular; mevcut veriyi sıfırlamaz. Eski 12–26 paketi ile Maraton/gizlilik/lig/avatar öncüllerini kaynakta belirtilen sırayla kurar. El ile tarih sırasına yeniden dizme, guard'ı kaldırma veya eski `proposed_chain_check.sh` aracını fresh installer yerine kullanma.

Ardından her yeni paket ayrı incelenir:27 TUS →28 Deneme →29 aylık lig; bağımsız 30 başlangıç kotası. Her biri önce kendi DRYRUN'ı, ardından ileri SQL. [Ayrıntılı paket rehberi](supabase/proposed/NIGHT_20261028_README.md) ve aynı klasördeki `*_down.sql` dosyaları temel alınır.

| Paket | Önce kontrol | Sonra ileri |
|---|---|---|
| 27| `27_tus_segment_dryrun.sql`| `27_tus_segment.sql`|
| 28| `28_exam_core_dryrun.sql`| `28_exam_core.sql`|
| 29| `29_monthly_competitions_dryrun.sql`| `29_monthly_competitions.sql`|
| 30| `30_session_start_atomic_dryrun.sql`| `30_session_start_atomic.sql`|

Yalnız local container'a 27 örneği:

```sh
docker exec -i supabase_db_pomosprint-local psql -U postgres -d postgres -X -v ON_ERROR_STOP=1 < supabase/proposed/27_tus_segment_dryrun.sql
```

DRYRUN sonunda kasıtlı`DRYRUN_RESULT`exception/rollback vardır; yalnız hata çıkması başarı değildir: içerideki **bütün Txx sonuçları true** olmalıdır. Farklı hata veya false varsa ileri uygulanmaz. İleri dosyadaki yalnız ilk `\echo`/`\quit` güvenlik satırları bilinçli çıkarılır; hash/fonksiyon/diğer guard değiştirilmez. Studio'nun **yerel** SQL Editor'ü veya aşağıdaki bir-adımlık örnek kullanılabilir:

```sh
python3 -c 'from pathlib import Path; import sys; s=Path(sys.argv[1]).read_text(); print("\n".join(x for x in s.splitlines() if not x.startswith(("\\echo", "\\quit"))))' supabase/proposed/27_tus_segment.sql | docker exec -i supabase_db_pomosprint-local psql -U postgres -d postgres -X -v ON_ERROR_STOP=1
```

Aynı inceleme 28/29/30 için öncülü kurulduktan sonra tekrarlanır. Repo 27–30 için tek komut otomatik fresh bootstrap sunmaz. Kurulum tamamlanınca:

```sh
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic
```

31 bu zincirin parçası değildir; `E2E_REVIEWED_NIGHT=3` veya `--with-marathon-anchor` bu çalışma için kullanılmaz. **29 tarih uyarısı:** resmî aylık rekabet kurulum ayından sonraki ayın 1'inde 00:00 İstanbul'da etkinleşir.31 Ekim 23:59'dan önce kurulursa 1 Kasım;1 Kasım'da veya sonrasında kurulursa 1 Aralık. Bu,04:00 çalışma günü sınırı değildir. Canlıya kurulum ayrıca kullanıcı incelemesi/kararı gerektirir.

### Uygulamayı açıkça yerel backend ile çalıştır

Aşağıdaki anon, üretimde geçmeyen kaynak kontrollü public local development sabitinden alınır; `.env` okunmaz:

```sh
TASK_LOCAL_ANON="$(python3 -c 'import sys; sys.path.insert(0,"tool/local_supabase/e2e"); from local_fixture_api import ANON; print(ANON)')"
flutter devices
flutter run -d <qa-ios-simulator-id> \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY="$TASK_LOCAL_ANON" \
  --dart-define=SENTRY_DSN=
```

Android emülatöründe aynı define'larla URL`http://10.0.2.2:54321` olur. Alternatif `adb reverse tcp:54321 tcp:54321` ile loopback kullanılabilir; native runner reverse/cleanup'ı yönetir. HTTP cleartext izni debug kaynağına özeldir; local HTTP debug örneğini release bağlantısı diye kullanma. Normal süreler 25/50 dk; Maraton 300+60 sn'dir.

### DUS ve güncel32 için ayrı inceleme ve site ortamı

[32 rehberi](supabase/proposed/32_exam_details_early_finish_README.md) ileri/down/DRYRUN ve gerçek süre/ödül sözleşmesini açıklar.32,31'e bağlı değildir. Yeni32 kaydı veya kişisel not oluştuktan sonra veri kaybettirecek tam rollback reddedilir; kazanılmış ödül geri alınmaz.

Bu oturumun ayrı, sabit yerel hedefleri:

| Profil | API / REST / Auth | DB (Postgres54322) | Amaç |
|---|---|---|---|
| Normal A |54321|postgres|Önceki7sınavlı27–30 snapshot doğrulaması; güncelDUS kaynaklarıyla karıştırma|
| review |54351 /54352 /54353|pomosprint_review32_dus|32 SQL/native testleri|
| site |54361 /54362 /54363|pomosprint_site32_dus|Başlangıçta sıfır kullanıcıdan oluşturulan yedi kurgu kişi|

İzole servisler yalnız loopback'te ve auto-confirm ile çalışır; shared Mailpit veya gerçek mail teslimi kullanılmaz. `isolated32_stack.py --profile review|site` ve `parity_check_exam32.py --profile review|site` yalnız bu sabit profilleri kabul eder. Site kurucusu `tool/local_supabase/e2e/site_demo_fixture.py` varsayılan olarak çevrimdışı plan üretir; açık `setup --apply --allow-historical` yalnız yeni, işaretli yerel hesaplar oluşturur. Bu kontrollü geçmiş,455 dakika doğal bekleme kanıtı değildir. Hazır bir ortamı yeniden kurma/silme; yeni klon hazırlığı için32 rehberinin guard'larını izle.

İzoleAPI için Android'de `adb reverse tcp:54351 tcp:54351` ve `http://127.0.0.1:54351` kullanılır; gateway'in Host koruması gevşetilmez. Normal canlı bağlantılı derleme ile yerel QA bağlantılı derlemeyi karıştırma. Yeni32 sunucu henüz canlıya uygulanmadı.

### Deneme ödül tablosu

| Deneme | Dakika | Kum | Deneme puanı |
|---|---:|---:|---:|
| LGS Sözel |75|60|15|
| LGS Sayısal |80|70|16|
| YDT |120|95|24|
| TUS Temel |135|110|27|
| TUS Klinik |135|110|27|
| DUS |150|120|30|
| TYT |165|130|33|
| AYT |180|145|36|

Kural dakika başına0,8 kumun en yakın5katına yuvarlanmasıdır; LGS Sayısal70 kullanıcı tarafından belirlenen istisnadır. AYT90dk erken bitiş72kum/18puan,1–59sn0; diğer sınavlar erken bitirilemez. Eski başlamış/bitmiş snapshot ödülleri değişmez. İstemcide `ExamRewardPolicy` tek çevrimdışı referanstır; gerçek makbuzda sunucunun snapshot/earned alanları üstün gelir. Bütün yeni katalog tanımları reward_policy_version2 kullanır. Deneme cüzdanı/ligi normal cüzdan/ligden ayrıdır.

DUS'un16alanı resmi yaklaşık kapsam tablosuna bağlıdır. Onboarding hedefi,UID'ye bağlı sunucuya henüz yazılamamış seçim,ders-kategori içgörü eşlemesi veDUS kategori/global ligi TUS ile aynı iş akışındadır. Normal hedeflerdeki diğer seçenekler silinmez; dört sınav ailesi YKS/LGS/TUS/DUS'tur.

## Doğrulama

Repo kökünden her düzeltme/commit öncesi:

```sh
flutter analyze
flutter test
npm --prefix scripts test
python3 landing/tools/sync_partials.py --check
```

Birim/widget, ARB anahtar/placeholder/source taraması, çevrimdışı kuyruk, normal/Deneme ekonomi ayrımı, saat dilimi ve rapor hesapları otomatik testlerde kapsanır. İsteğe bağlı PNG üretim atlaması, işlevsel test başarısızlığı veya native cihaz başarısı değildir. Gerçek sonuç sayıları ve kanıt dosyaları son raporda tutulur.

Native için önceden hazır yerel DB ve açık QA cihazı seçilir. Aşağıdaki varsayılan kısa dizi, bütün gerçek uzun koşuları başlatmaz:

```sh
SIM_UDID=<qa-ios-simulator-id> E2E_REVIEWED_NIGHT=2 tool/local_supabase/e2e/sim/run_sim_e2e.sh a b c d e
ANDROID_SERIAL=<qa-android-emulator-id> E2E_REVIEWED_NIGHT=2 tool/local_supabase/e2e/sim/run_android_e2e.sh a b c d e
```

Bu checkout'ta Flutter build/test/pub/analyze işlemlerini sırayla çalıştır; platformlar ortak üretilen eklenti kayıtlarını paylaşır. Native testten sonraki normal release için `flutter build apk --release` gibi normal üretimi çalıştır; eski debug kayıtları dururken `--no-pub` ile release başlatma. Çok aşamalı native koşularda `--no-uninstall --no-pub` korunur; start/resume/final arasında uygulama verisi temizlenmez veya yeniden kurulmaz. OS sürecini kapatıp açmak veri sıfırlamak değildir. Başlangıç PASS'i uzun koşunun tamamlama/ödül PASS'i yerine geçmez.

- [Yerel hesap muhasebe doğrulayıcısı](tool/local_supabase/e2e/VERIFY_REPORTS_AND_EXAMS_README.md): `verify_reports_and_exams.py --owner <qa-uuid>` yalnız sabit local QA owner okur, beklenen normal/Deneme ekonomi ve rapor toplamlarını bağımsız hesaplar. `--peer-owner` RLS'yi salt okunur işlemde kontrol eder.
- [Dört hesaplı hedef/global kohortu](tool/local_supabase/e2e/VERIFICATION_COHORT_README.md): varsayılan plan, açık apply ile yalnız yeni yerel hesap ve kontrollü geçmiş üretir. Doğrudan bakiye/puan atanmaz; doğal süre kanıtı değildir.
- [İzole eski sunucu](tool/local_supabase/e2e/isolated_old_stack_README.md): ayrı boş DB / Auth / REST / gateway `54341`; A8 eski sunucu uyumu ana QA verisini değiştirmeden çalışır. Kurulum/temizlik yalnız kendi isimli kaynakları hedefler.

Gerçek doğal süreli deneme, kısa yerel katalog deneyi, kontrollü tarihli fixture, saf model/unit ve native UI kanıtı ayrı raporlanır. Kontrollü geçmiş gerçek 330 dk veya ay geçişi beklenmiş sayılmaz. Simülatör debug ölçümü fiziksel cihaz release performansı veya gerçek Apple/Google giriş/bildirim teslim kanıtı değildir.

## Site, derleme ve yayın sınırı

TR/EN site `landing/`; [site rehberi](landing/README.md), [güncel medya listesi](landing/screenshots/README.md). Site yalnız yeni backend ve uygulama hazırlandıktan sonra yayınlanabilir. Bu çalışma yerel hazırlık/QA ve yetkili geliştirme dalı push'udur; deploy değildir. Safari kullanıcı tercihi olarak korunur; kişisel Chrome sekmeleri kontrol edilmez/değiştirilmez.

- `flutter build ios --release --no-codesign`: imzasız fiziksel cihaz release paketi; Simulator kurulumu veya TestFlight dağıtımı değildir.
- Simulator: `flutter build ios --simulator` / açık local define'lı `flutter run` ayrı adımlardır.
- `scripts/build_release.sh android| ios| all`: mağaza için obfuscation/sembol çıktıları; Android upload keystore, iOS signing/provisioning ve isteğe bağlı Sentry symbol upload yapılandırması gerektirir. Anahtarlar/sertifikalar repoya girmez. İmzalama yokken debug imzalı release ürününü mağazaya dağıtma.
- Apple/Google giriş, fiziksel cihaz/gerçek bildirim, yasal veri-sorumlusu ve e-posta gönderen kimliği, mağaza beyanları ve ücretli ürünler ayrıca ele alınır. Kullanıcı gerçek kimlik bilgilerini sonradan sağlayacaktır; bilgi uydurulmaz.

## Kaynak haritası

| Yol | İşlev |
|---|---|
| `lib/`, `assets/`| Mobil ürün, yerelleştirme, aktif görseller|
| `test/`, `integration_test/`| Birim/widget/native regresyonlar|
| `supabase/`| SQL/Edge kaynakları, proposed/rollback/DRYRUN ve API|
| `tool/local_supabase/`| İzole yerel Docker/Supabase ve QA yardımcıları|
| `landing/`| TR/EN statik site, Worker, gerçek native medya|
| `scripts/`| Derleme, Node ve operasyon araçları; canlı güvenlik araçları normal kapı değildir|
| `analiz/`| İstekler, ilerleme, tarihli QA raporları ve korunan kanıtlar|
| `AGENTS.md`, `PROJE_DEVIR.md`, `PROJECT_CONTEXT.md`| Kurallar, mimari ve oturum devri|

Geçici derlemeler, tokenlar, sırlar ve imzalama çıktıları commitlenmez. Test temizliği gerçek hesap silmek veya ortak Docker prune çalıştırmak değildir. Yerel servisi durdurmak için yalnız ilgili projede `supabase stop --workdir tool/local_supabase` kullanılır; veri silen `--no-backup` ancak test bitip kapsamı açıkça onaylandıktan sonra seçilir.
