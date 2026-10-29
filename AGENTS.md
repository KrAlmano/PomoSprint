> **29 Ekim cihaz/temizlik — en güncel durum:** Yalnız **HocamMacVar · iPhone 17 / iOS 27.0** (`2CFDB5C8-6CA6-457C-8A6E-864B1849C681`) ve **PomoSprint_QA_API36** Android AVD kalır. Kullanıcı PomoSprint’in de iPhone 17’ye taşınmasını açıkça istedi; iki uygulama aynı cihazda, mevcut verileri korunarak açıldı. Eski iPhone 16 ve iOS18.1/18.6 runtime’ları kaldırıldı. Yeni cihaz/runtime indirme veya mevcut uygulama verilerini sıfırlama. Native reset testlerinde ayrı QA bundle kullan. [Temizlik raporu](analiz/TEMIZLIK_2026-10-29.md). Aşağıdaki eski cihaz ID/runtime bilgileri tarihsel test kanıtıdır.

> **28 Ekim son devam noktası — KPSS / §11.10:** Yerel katalog 20 sınav/test, 5 ailedir (YKS/LGS/TUS/DUS/KPSS). KPSS uygulama/site/proposed paketi **canlıya uygulanmadı**. Son onaylı web kaynağı `6cfd9b5`, Worker sürümü `ad2fc988-4462-40ae-9333-ab0107e2138b` olup KPSS içermez. Kullanıcı bundan sonraki deploy öncesi yeniden açık onay ister; aşağıdaki eski genel yayın yetkisini yeni dağıtıma taşımayın. [KPSS raporu](analiz/QA_KPSS_2026-10-28.md) ve [sunucu kanıtı](analiz/QA_KPSS_SUNUCU_2026-10-28.md) güncel kaynaklardır. 29 Ekim son KPSS native iOS TR/EN turu geçti; 8 PNG ve değişmeyen tercih hash’i `ios/manifest.json` içindedir. Normal `lib/main.dart` paketi geri kuruldu; asıl uygulamadaki bekleyen taslak korundu. `ios_diagnostics` önceki başarısız girişimlerdir; güncel sonuç yerine kullanma.

> **28 Ekim site yayın yetkisi:** Kullanıcının son “site eski / Deneme ekranlarıyla tüm siteyi güncelle” isteği, mevcut PomoSprint web sitesinin güncel sürümünü yayımlama yetkisidir. Aşağıdaki eski “site deploy yok / uygulamadan sonra site” sınırı bu web tanıtımı için kaldırılmıştır. Supabase, 31, uygulama mağazaları, main/merge/force sınırları sürer. Site uygulamanın yayın hazırlığında olduğunu belirtir.

> **28 Ekim nihai devir:** Güncel dal `codex/gece-2026-10-27`. A kontrol noktası `4be1b9c`, DUS/ödül kodu `8cb3dc9`, sade Deneme arayüzü `641cc16` commit’indedir. Site/kanıt paketi `635a89d` olarak uzak dalda doğrulandı; kapanış notu bu dosyanın son commit’iyle izlenir; GitHub durumu için `git status -sb` ve dal geçmişini kullan. DUS, ortak ödül ve son arayüz doğrulaması tamamlandı: Flutter 1482 PASS/5 isteğe bağlı PNG atlaması, Node 172/172, analiz temiz; iOS/Android normal uygulama yerel backend ile açıldı. 27/28/29/32, aynı proposed paketleri içinde DUS'a göre güncellendi; 31 yok, canlı/main/deploy işlemi yok. Güncel veritabanları `pomosprint_review32_dus` (API 54351) ve `pomosprint_site32_dus` (API 54361) olarak ayrıdır. Eski main A ve ilk 32 veritabanları dondurulmuş tarihsel veridir. Önce [ilerleme kaydı](analiz/CODEX_ILERLEME.md), [DUS istemci raporu](analiz/QA_DUS_ISTEMCI_2026-10-28.md) ve [DUS sunucu kanıtı](analiz/kanit_dus_2026-10-28/INDEX.md) okunmalıdır. Eski “7 sınav”, TYT 150/AYT 175 ve ilk B 300 kum notları yeni politikayı anlatmaz.

# AGENTS.md — PomoSprint AI devir rehberi

> **28 Ekim yeni A/B devamı:** Güncel görev/kanıt [DOGRULAMA_RAPORU](analiz/DOGRULAMA_RAPORU_2026-10-28.md) ve [native rehber](tool/local_supabase/e2e/VERIFICATION_20261028_README.md). Kullanıcının D ek talimatı eski push yasağını yalnız `codex/gece-2026-10-27` için kaldırdı; başlangıç yedeği `fb70839` GitHub'a gönderildi. A sonrası/B sonrası/kapanış yedeği aynı dalda yapılır. **Main/merge/force push/deploy/canlı servis işlemi yok;31 uygulanmaz.** Yerel A doğrulaması tamam: iki platform/iki dil, yeni gerçek75dk,14/14tür OS/offline/reconnect, rapor/lig/sosyal/eski sunucu. İki net hatası `11ea62c` ve `8446eff` ile düzeltildi. B site medyası ve Safari doğrulaması tamamlandı; aşağıdaki geceye ait “push yok” notları tarihseldir.

> **Yayın sırası / D-06:** Yeni özellikleri anlatan site, önce 27 → 28 → 29 sunucu paketleri doğrulanıp uygulandıktan ve bunları kullanan yeni uygulama sürümü yayımlandıktan sonra deploy edilir. Bu geceki yerel site hazırlığı canlı özellik varlığı anlamına gelmez. Bağımsız 30 güvenlik eki ayrıca değerlendirilir.

> **27/28 Ekim 2026 yerel geliştirme — önce bunu oku:** Yeni TUS/Deneme, TR/EN karşılama, birleşik rapor ve aylık hedef/global lig çalışması `codex/gece-2026-10-27` dalındadır. **Yeni SQL ve site canlıya uygulanmadı; push/deploy yok.** Yeni sözleşmenin kaynağı [§11](#11-2728-ekim-2026-yerel-deneme-ve-aylık-lig-sözleşmesi), [API](supabase/proposed/EXAM_API_CONTRACT.md) ve [27 → 28 → 29 kurulumu](supabase/proposed/NIGHT_20261028_README.md). Çalışma/test/cihaz durumları [istek listesi](analiz/ISTEKLER.md) ile [ilerleme kaydındadır](analiz/CODEX_ILERLEME.md). Aşağıdaki 8/9 Ekim canlı lig ve sıfır cihaz notları tarihseldir; yeni yerel durum yerine kullanılmaz. Yeni paketler kurulmadıkça eski canlı davranış değişmiş sayılmaz.

> **Canlı servis kontrolü — 27 Ekim 2026 / §38:** [Güncel rapor](analiz/SERVICE_HEALTH_2026-10-27.md) ve `PROJE_DEVIR.md` §38. Supabase/Resend/Cloudflare erişimi başarılı; site HTTP 219/219, Node 133/133, cron 15/15. Kontrol salt okumadır; yeni mail veya kullanıcı işlemi yapılmadı. SMTP AUTH/teslim ve mobil E2E denenmedi; Apple/welcome kimliği ve §33 operasyon işleri hâlâ bekler. Aşağıdaki 9 Ekim Flutter/derleme sonuçları tarihseldir.

> **Tarihsel durum — 9 Ekim 2026 / §37:** [Yayın öncesi temizlik QA](analiz/QA_RELEASE_CLEANUP_2026-10-09.md) ve [PROJE_DEVIR §37](PROJE_DEVIR.md) o tarihin devam noktasıdır. Ronin istemci görsellerinden ve katalogdan kaldırıldı; kullanıcının canlı SQL Editor işlemi ardından salt okuma **20/20** geçti. Katalogda toplam 48 avatar, 47 aktif, 21 özel ve 7 aktif ücretsiz avatar var; özel avatarlar 500 kum. Dört hesap, dokuz seans ve ekonomi hash’leri aynı. Kartın görsel ve ad merkezlemesi düzeltildi; TR/EN, yatay/dikey ve büyük yazı regresyonları geçti. Tam Flutter sonucu **1291 PASS ve isteğe bağlı 5 ekran görüntüsü testi atlaması**; analiz temiz. Eski QUICK başlatma/kayıt/yardımcı yolları kaldırıldı; her normal derleme gerçek 25/50 dk kullanır. Eski hızlandırılmış outbox güvenli ret listesine alınır, gerçek kayıtlar silinmez. Yerel `pomosprint-local` Docker test veri hacimleri, eski ham fixture/ekran görüntüsü/log ve tek seferlik demo/gece araçları temizlendi; anlamlı regresyon ve SQL test altyapısı korunur. Canlıda kesin QA hesabı saptanmadığından mevcut 4 hesap silinmedi. **Simülatör/runtime sayısı 0; açık uygulama yok, eski UUID’leri kullanma.** Yeni proje kökü `/Users/almano/Desktop/Projects/Pomodoro`.
>
> **Yayın sınırı:** §33 operasyonel işler ayrı değerlendirilir. Derin Sentry temizliği bu dalda yerel regresyonlarla eklendi (§11.6); canlıya yayımlandığı anlamına gelmez. Dart HTTP 500 otomatik yakalama hâlâ yok; waitlist anon POST onay/limiter zorunluluğu yok; `register_session_start` 99 + 2 yarışı 101 kayıt üretir. Maraton uyumluluk kapısı operasyonel kill switch değildir; hosted staging/canlı alarm/sembol çözümleme doğrulanmadı. Fiziksel cihaz, gerçek sağlayıcı girişleri, Apple imzalama ve yasal kimlik işleri ayrıdır. Temizlik bunları tamamlamaz. [Operasyonel QA](analiz/QA_OPERATIONAL_CONTROLS_2026-10-08.md).
>
> **Önceki turlar:** Tarihli sonuçlar `PROJE_DEVIR.md` ve `analiz/QA_*.md` içinde tutulur. §37'de eski ham kanıtlar bilerek kaldırıldı; rapor sonuçlarını bugünkü tekrar olarak sunma. Canlı DB > bu dosya > migration kaynakları > eski raporlar önceliği geçerlidir. RPC/kolon/hata sözleşmesi değişen işte bu rehberi güncelle.

## Kullanıcı çalışma tercihleri

- Tarayıcı kontrollerinde Safari kullan. Chrome kullanıcıya ayrılmıştır; açık Chrome sekmelerini değiştirme. Sistem varsayılanı zaten Safari.
- Geliştirici kimliği/şirket unvanı ve resmî başvuru adresi kullanıcı tarafından en son sağlanacak; bu bilgiler için tekrar soru sorma, yayın raporunda tamamlanmamış olarak işaretle.
- İş ve testler tamamlandığında `PROJE_DEVIR.md` ile ilgili QA raporunu güncelle; sözleşme değiştiyse bu dosyayı da güncelle. Yapılanları, gerçekten koşulan testleri, kanıt yollarını, kalan işleri ve sonraki oturumun devam noktasını yazıp kullanıcıya raporla. Yeni yapay zekâ sohbet geçmişine ihtiyaç duymadan devam edebilmeli.
- Kullanıcı kendi hesabını deneyecekse yerel QA uygulamasını normal canlı uygulama gibi açık bırakma; ortamı açıkça raporla. Yerel Mailpit kişisel inbox teslimi değildir. §36/37’deki sıfır cihaz ve silinen yerel DB durumu tarihseldir. Bu gece kullanıcı yeni iOS/Android QA cihazları ve yalnız yerel hesaplar için izin verdi; güncel envanter/çalışan süreçleri ilerleme kaydından ve cihaz listesinden kontrol et. Kök `.env` okunmaz/değiştirilmez; canlı kişisel hesap verileri korunur.

## Görev türüne göre nereye bak

| Görev | Önce bak | Sunucu tarafı | Bölüm |
|---|---|---|---|
| Seans kaydı, puan, kum, seri hatası | `lib/services/session_queue.dart`, `supabase_service.dart` (`submitCompletedSession`) | `complete_study_session` | §4.2, §5.2, §5.3 |
| Maraton popup, ilerleme animasyonu, mola/onay, ek puan | `widgets/marathon_plan_dialog.dart`, `widgets/marathon_break_indicator.dart`, `models/marathon_progress.dart`, `widgets/marathon_progress_card.dart`, `services/marathon_presence.dart`, `timer_screen.dart`, `timer_persistence.dart`, `main_shell.dart` | `get_marathon_config`, `complete_marathon_study_session`, `start_marathon_break`, `confirm_marathon_presence`, sosyal mola RPC’leri (8 Ekim canlıda) | §5.7 |
| Sayaç, duraklatma, uygulama kapanınca seans | `timer_screen.dart`, `services/timer_persistence.dart`, `app/main_shell.dart` | `start_/cancel_study_session` | §4.1, §6.1 |
| Bildirim gelmiyor, kilit ekranı sayacı | `services/notification_service.dart`, `services/lock_screen_timer.dart`, `AndroidManifest.xml`, `ios/Runner/LiveActivityChannel.swift`, `ios/PomoSprintTimerWidget/` | — | §4.1, §4.7 |
| Çevrimdışı kuyruk | `session_queue.dart`, `server_clock.dart`, `test/session_queue_test.dart` | `complete_study_session` | §6.2 |
| Raporlar, gün/hafta hesabı | `reports_screen.dart`, `utils/stats_calculator.dart`, `utils/study_day.dart`, `models/study_session.dart` | `get_my_study_sessions_v2`, deneme geçmişi | §4.3, §11 |
| Deneme, net, süre–net içgörüsü | `exam_screen.dart`, `exam_service.dart`, `exam_persistence.dart`, `models/exam_*.dart`, `exam_results_dialog.dart` | `get_exam_config`, `*_exam_attempt`, `save_exam_results` (yalnız yeni yerel paket) | §11 |
| Sıralama / lig | `ranking_screen.dart`, `widgets/social/ranking_models.dart`, `widgets/league_info_sheet.dart` | `get_my_league_ranking_v2`, `get_league_config`, `get_public_*_leaderboard`, `process_weekly_leagues` | §4.4, §6.4 |
| Arkadaşlar, canlı çalışanlar | `friends_sheet.dart`, `social_screen.dart` | `get_my_friends`, `get_incoming_friend_requests`, `add_friend_by_code`, `get_live_friends` | §4.4 |
| Avatar satın alma / kuşanma | `character_collection_screen.dart`, `models/avatar_model.dart` | `purchase_avatar`, `set_equipped_avatar`, `avatar_unlocks` | §4.4 |
| Giriş, kayıt, onboarding, yönlendirme | `app/app_gate.dart`, `login_/register_/post_auth_onboarding_screen.dart` | `handle_new_user` trigger | §4.5, §6.3 |
| Kategoriler | `categories_management_screen.dart`, `models/category_model.dart` | `create_category`, `enforce_category_limit` | §4.5 |
| Çeviri / metin | `lib/l10n/app_tr.arb` + `app_en.arb`, `services/language_service.dart` | — | §4.5 |
| Site (pomosprint.app) | `landing/`, `landing/README.md`, `wrangler.jsonc`, `_headers` | `waitlist`, `unsubscribe` | §8 |
| DB değişikliği | `supabase/README.md` akışı, `migrations/20261003150000_live_audit_fixes.sql` | canlı tanımlar | §2.3, §2.4, §4.6 |
| E-posta (hoş geldin, bülten, abonelikten çıkma) | `supabase/functions/`, `scripts/send_newsletter.js` | `marketing_subscribers` | §8 |
| Yatay telefon / tablet düzeni | `lib/utils/responsive.dart` (Responsive, ContentWidth), `widgets/shell_navigation.dart`, `test/responsive_*_test.dart` | — | Yeni ekranda `Responsive.of(context)` kullan; 6 boyutta taşma testi ekle |
| Derleme, imzalama, platform ayarı | `android/app/build.gradle.kts`, `ios/Runner/Info.plist`, `pubspec.yaml` | — | §4.7 |

## 1. Proje bir bakışta

- **Ne:** Oyunlaştırılmış Pomodoro uygulaması. 25 veya 50 dk tek seans veya 2/3/4 seanslık **Maraton** (aralarda 5 dk mola, ardından en fazla 1 dk içinde “Buradayım” onayı), kategoriler, raporlar, seri bonusu, 25 kişilik lig odaları, eski sunucuda hazırlık/14 günlük dönemler (§6.4); yeni yerel sözleşmede aylık hedef/global lig (§11), avatarlar, arkadaşlar. Maraton sunucu paketleri 8 Ekim'de canlıya uygulanıp doğrulandı (§5.7).
- **İstemci:** Flutter 3.44 / Dart ^3.12, yalnızca **Android ve iOS**. Kullanılmayan masaüstü/web şablonları §37’de kaldırıldı; site `landing/` altındadır.
- **Backend:** Supabase projesi `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, bölge `eu-north-1`. Postgres + RLS + SECURITY DEFINER RPC, Auth (e-posta, Google, Apple), pg_cron, Edge Functions.
- **Temel ilke:** Puan, kum (coins), seri ve lig **sunucuda** hesaplanır. İstemci seans meta verisini gönderir, RPC sonucunu gösterir.
- **Site:** `pomosprint.app`. `landing/` derleme adımı olmadan Cloudflare Workers static assets ile yayınlanır.
- **Varsayılanlar:** dil cihazdan (Türkçe ise `tr`, değilse `en`), tema sistem teması, varsayılan avatar `avatar_16_basic`.

## 2. Bir göreve başlamadan önce

### 2.1 Oku
1. Yukarıdaki tablodan işin bölümünü ve §5 sözleşmesini.
2. `git status` ve `git log -5`. Çalışma ağacında başka oturumların commit edilmemiş işleri olabilir; başkasının yarım işini geri alma.
3. Dokunacağın dosyanın tamamını (`supabase_service.dart` için ilgili bölge yeterli).
4. DB işi: `supabase/README.md`, `supabase/proposed/README.md`, `migrations/20261003150000_live_audit_fixes.sql` (canlı gövdelere en yakın kaynak).
5. Site işi: `landing/README.md`.

### 2.2 Çalıştır

| Komut | Ne zaman | Beklenen |
|---|---|---|
| `flutter pub get` | İlk kurulum | Hata yok |
| `flutter gen-l10n` | Her `.arb` değişikliğinden sonra | `lib/l10n/app_localizations*.dart` yeniden üretilir |
| `flutter analyze` | Her değişiklikten sonra | `No issues found!` |
| `flutter test` | Her değişiklikten sonra | Hepsi yeşil (birim + widget testleri; raporlar için `reports_correctness_test`, `reports_findings_test`, kategoriler için `categories_findings_test`). Gün hesabına dokunduysan `TZ=America/New_York flutter test` ile de çalıştır |
| `flutter run` (debug dahil) / `--profile` / `--release` | Gerçek seans ve puan doğrulaması | Her normal derlemede 25/50 dk; eski QUICK/SAVE define’ları etkisiz. VS Code yalnız normal/profile/release `lib/main.dart` açar |
| `supabase/tests/run_local.sh` | SQL değişikliği; **yalnızca yerel Postgres** | ASSERT'ler geçer. `live_audit_fixes` varsayılan olarak atlanır |
| `supabase start --workdir tool/local_supabase` | İzole yerel backend gerektiğinde | Test veri hacimleri §37’de silindi. Şema kaynakları tarihli snapshot; canlıyla eşit olduğunu varsayma, rehbere göre kur ve pariteyi yeniden kontrol et |
| `tool/local_supabase/proposed_chain_check.sh` | `supabase/proposed/` dosyası yazınca ya da değiştirince (yerel kopya açıkken) | Kopya veritabanında (ana kopyaya dokunmaz) zincir 12 → … → 14 ve 20–26: her DRYRUN maddesi `true`, DRYRUN'daki gövde = ana dosya, `_down`'lar şemayı birebir geri getirir; `SONUÇ: tüm adımlar beklendiği gibi` |
| `CHAIN_DB=pomosprint_chain_client NO_DOWN=1 KEEP_DB=1 REST_PORT=54331 tool/local_supabase/proposed_chain_check.sh` → `flutter test tool/local_supabase/e2e/client_compat/client_compat_e2e_test.dart` → `CHAIN_DB=pomosprint_chain_client DROP_ONLY=1 tool/local_supabase/proposed_chain_check.sh` | İstemcinin canlıda olmayan sunucu davranışına dokunan değişikliği | Aynı istemci kodu ESKİ (ana kopya = canlı) ve YENİ (zincir + 20–25; kopyaya bağlı PostgREST) sunucuda yeşil |
| `tool/local_supabase/e2e/sim/run_sim_e2e.sh [a b c d e]` | Kayıt/onboarding, sayaç, seans/kuyruk, sosyal, profil/silme akışına dokunan değişiklik (yerel kopya + iOS simülatörü açıkken) | Gerçek `main()` ile simülatörde (`integration_test/`) senaryolar yeşil; ekran görüntüleri `analiz/ekranlar/e2e-*.png`, psql doğrulamaları `build/e2e_sim/psql.log`. Ayrıntı ve elle koşulan bildirim / kesinti / kilit ekranı senaryoları: `tool/local_supabase/README.md` "Simülatörde uçtan uca test" |
| `python3 landing/tools/sync_partials.py --check` | Site değişikliğinden sonra | Çıkış kodu 0 |
| `cd scripts && npm test` | `landing/js`, `supabase/functions`, `scripts/send_newsletter.js` değişikliğinden sonra | Hepsi yeşil. Ağsız: Edge Function'lar sahte Supabase ile, site betikleri sahte DOM ile (`scripts/test/`); Node 22.18+ ya da 23.6+ (bayraksız TypeScript ayıklama ve `module.registerHooks`) |
| `cd scripts && node security_regression_test.js` | **Yalnızca kullanıcı onayıyla.** Gerçek hesap açar ve siler | Bazı senaryolar canlıda olmayan `proposed/11` yüzünden bilinçli kırmızı |

**Native testte veri koruma:** Cihazda `flutter test integration_test/... -d ...` varsayılan olarak test sonunda uygulamayı kaldırabilir; ilk r25/r135 denemelerinde container ve probe işareti bu yüzden silindi. Çok aşamalı `r`/`w`/`x` akışlarında iOS/Android çalıştırıcılarının `--no-uninstall --no-pub` seçeneklerini koru. Aşamalar arasında uygulamayı kaldırma, uygulama verisini/tercihlerini temizleme veya simülatörü sıfırlama; yalnız testin tanımladığı OS süreç sonlandırma/yeniden açma işlemini yap. Başlangıçtan sonra container ve kalıcı işaret doğrulanmadan sonraki aşamaya güvenme. `r` başlangıcının geçmesi doğal bitiş, tekrar açılma veya tek ödül kanıtı değildir. `w`, gerçek 25 dakika + HTTP 503 + OS süreç yeniden açılışını; `x`, kontrollü geçmişle hedef/Global ekranları ve ayrı OS sürecinde korunmayı sınar. Kontrollü geçmiş doğal çalışma/ay geçişi sayılmaz.

**Eski/yeni sunucu uyum aracının sınırı:** Yukarıdaki `client_compat` komutu yalnız PostgREST veritabanını klonlar; Auth kayıt/silme çağrıları ana yerel `54321` servisine gider. Tamamen izole bir Auth kopyası değildir. Devam eden native hesap/gerçek süre testi varken çalıştırma. 28 Ekim gecesi bu nedenle araç yeniden çalıştırılmadı; mevcut eski-RPC fallback ve kuyruk sözleşmeleri 105 hedefli birim/widget kontrolüyle sınandı. Bu sonuç gerçek HTTP eski sunucu E2E'si değildir; [uyum raporuna](analiz/QA_ESKI_SUNUCU_UYUMU_2026-10-28.md) bak.

Tam Flutter turundaki **5 atlama**, yalnız `SCREENSHOTS=true` ile açılan PNG üreticileridir: `onboarding_screenshots_test.dart` 1, `register_screenshots_test.dart` 3, `timer_screenshots_test.dart` 1. İşlevsel testlerin atlandığı anlamına gelmez; görüntü üretimini açıkça istemeden bu bayrağı genel turda etkinleştirme.

### 2.3 Canlı DB'yi kontrol et (salt okuma; Supabase MCP `execute_sql` ya da SQL Editor)

```sql
-- Fonksiyonun canlı gövdesi (tüm overload'lar)
select p.oid::regprocedure, pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'complete_study_session';
-- RLS, tablo / kolon / RPC yetkileri
select tablename, policyname, cmd, roles, qual, with_check from pg_policies where schemaname = 'public' order by 1, 2;
select table_name, grantee, privilege_type from information_schema.role_table_grants
where table_schema = 'public' and grantee in ('anon','authenticated') order by 1, 2, 3;
select column_name, privilege_type from information_schema.column_privileges
where table_schema = 'public' and table_name = 'profiles' and grantee = 'authenticated';
select routine_name, grantee from information_schema.routine_privileges
where routine_schema = 'public' and grantee in ('anon','authenticated','PUBLIC') order by 1, 2;
-- Trigger, cron, migration geçmişi
select tgname, tgrelid::regclass from pg_trigger where not tgisinternal and tgrelid::regclass::text like 'public.%';
select jobname, schedule, command from cron.job;
select version, name from supabase_migrations.schema_migrations order by version desc limit 15;
```
Canlı DB okumaları otomatik izin denetimine takılabilir. Takılırsa sorguyu kullanıcıya ver, SQL Editor'de çalıştırsın.

### 2.4 Canlıya SQL yazma akışı
MCP ile yıkıcı SQL çalıştırma. Canlıya yazan SQL'i **kullanıcı Supabase SQL Editor'de çalıştırır**.
1. §2.3 sorgularıyla canlı tanımları oku. Repodaki eski gövdeyi kullanma.
2. `supabase/migrations/<YYYYMMDDHHMMSS>_<ad>.sql` yaz; gövdeyi canlı tanımdan al. Sona `schema_migrations` kaydını ekle (kalıp: `live_audit_fixes`, bölüm 11).
3. `supabase/rollbacks/<sürüm>_<ad>_down.sql` yaz; içinde canlıdaki eski gövdeler olsun.
4. `supabase/tests/<tarih>_<ad>_dryrun.sql` yaz: `BEGIN` → migration → senaryolar → bilinçli `DRYRUN_RESULT` hatası → otomatik geri alma. Örnek: `20261003_live_audit_fixes_dryrun.sql`.
5. Kullanıcı önce DRYRUN'u çalıştırır (her satır `true`), sonra migration'ı.
6. §2.3 sorgularıyla sonucu doğrula; bu dosyada §5 ve §7'yi güncelle.

**8 Ekim dar istisna:** Kullanıcının “gerekli ayarlamaları yap / mevcut lige aktar / başlangıç25” talebi yalnız `20261008190000_league_launch_policy` için uygulama yetkisi olarak kaydedildi. Canlı tanım ön koşulları, uygulama öncesi yerel bağımsız86/86, canlı55/55 rollback, atomik CLI uygulaması, kurulum sonrası55/55 rollback ve veri/ACL kontrolleriyle tamamlandı. Yeni şemayla sonraki bağımsız tekrar89/89 geçti. Önceki dört Maraton/şikâyet paketi §26 ayrı yetkidir. Bu kayıt diğer SQL/Edge/ödeme/plan paketleri için izin değildir; kök db push/reset yasağı sürer.

**8 Ekim 2026 oturum istisnası:** Kullanıcı açıkça “canlı sunucuda aç Maratonu” ve “productiona hazır olsun” istedi. Üç incelenmiş Maraton paketi, Supabase CLI `db query --linked --project-ref eoosnyakvxmifmexpgxa --file …` Management API yolu ile uygulandı: canlı tanım/parmak izi → transaction içinde geri alınan üç DRYRUN → tek atomik ileri transaction → salt okuma ve geri alınan fonksiyon senaryoları. Ardından aynı yayın hazırlığı kapsamında bilinen rapor eşzamanlılık hatası için `20261007110000_report_submission_lock` ayrıca incelendi: güncel canlı gövde ve rollback birebir eşleşti, canlı DRYRUN 23/23 geçti, yalnız bildirici başına transaction kilidi ekleyen migration ayrı transaction ile uygulandı; uygulama sonrası geri alınan 23/23 senaryo ve 9/9 salt okuma kontrolü geçti. Mevcut veri ve yetkiler değişmedi. [Rapor düzeltmesi kanıtı](analiz/QA_REPORT_SUBMISSION_LIVE_2026-10-08.md). `db push/reset`, diğer bekleyen migration'lar ve veri silme çalıştırılmadı. Bu tarihli, dört paketle sınırlı istisna diğer SQL paketlerini kendiliğinden yetkilendirmez.

### 2.5 Görevi bitirirken
- `flutter analyze` temiz, `flutter test` yeşil.
- Yeni metin iki ARB dosyasına da eklendi, `flutter gen-l10n` çalıştırıldı.
- Sözleşme değiştiyse §5 güncellendi.
- `PROJE_DEVIR.md` ve ilgili QA raporunda son durum, test kanıtı ve bekleyen işler güncellendi; yerel doğrulama canlıya uygulanmış gibi yazılmadı. Kullanıcıya tamamlanan iş ve kalan adımlar raporlandı.

## 3. Klasör haritası

| Yol | Sorumluluk |
|---|---|
| `lib/main.dart` | Açılış: `.env` → Sentry → `LanguageService` → `ThemeController` → `NotificationService` (beklenmez) → `runApp`. `home: SplashScreen` → `AppGate` |
| `lib/app/app_gate.dart` | **Tek yönlendirme kapısı**: `currentUser` null → Login; onboarding eksik → hesaba bağlı `OnboardingWelcomeGate` dil seçimi + PostAuthOnboarding; aksi halde Shell |
| `lib/app/main_shell.dart` | `MainNavigationShell`: Pomo, Raporlar, Sıralama, Sosyal, Deneme; IndexedStack + TickerMode, bekleyen seans banner'ı, bağlantı dinleyicisi (`app/connection_watcher.dart`), bulutun yeniden denenmesi, `PopScope` |
| `lib/app/` (diğer) | `theme_controller` (`theme_mode`), `session_feedback` (seans sonucu diyalogları), `category_cache` (`saved_categories_uid_<uid>`; eski `saved_categories_<email>` ilk okumada taşınır), `error_reporting` (Sentry, e-posta maskeleme) |
| `lib/screens/timer_screen.dart` | Sayaç durum makinesi (25/50 dk, tek duraklatma, 3-2-1), Maraton mola/onay/timeout |
| `lib/models/marathon_progress.dart`, `lib/widgets/marathon_progress_card.dart` | Kalıcı Maraton aşamaları ve yalnız gösterim/animasyon yapan ilerleme kartı |
| `lib/services/marathon_presence.dart` | Güvenli sunucu sözleşmesi ve değişmez bilet/onay makbuzu doğrulaması |
| `lib/screens/splash_screen.dart` | Önce yerel önbellek, sonra `SupabaseService.ensureCloud` (5 sn bekler; başlatma süreçte bir kez başarır, başarısızsa kabuk/giriş yeniden dener), sonra profil ve kategori tazeleme |
| `lib/screens/login_ / register_ / post_auth_onboarding_screen.dart` | Giriş (e-posta, Google, iOS'ta Apple), kayıt, onboarding |
| `lib/screens/categories_management_screen.dart` | Kategori yönetimi (Profil'den açılır) |
| `lib/screens/reports_screen.dart` | Raporlar sekmesi; `history_screen` (**Haftalık**, dosya adı yanıltıcı) ve `monthly_tracking_screen`'e veri verir |
| `lib/screens/ranking_ / social_screen.dart`, `friends_sheet.dart` | Lig/Aylık/Arkadaşlar sıralaması, canlı çalışanlar, arkadaş kodu ve istekleri |
| `lib/screens/profile_ / character_collection_screen.dart` | Ayarlar, hesap silme, avatar satın alma ve kuşanma |
| `lib/services/supabase_service.dart` | Singleton veri katmanı (auth, profil, seans, kategori, lig, arkadaş, avatar). `service_errors` ve `session_queue` tiplerini export eder |
| `lib/services/session_queue.dart` | Kalıcı seans outbox'ı ve hata sınıflandırması (`classifySessionError`) |
| `lib/services/timer_persistence.dart` | Süren seansın cihazdaki kaydı (`active_session_uid_<key>`), `timerDurationSeconds` |
| `lib/services/server_clock.dart` | HTTP `date` başlığından sunucu-cihaz saat farkı |
| `lib/services/service_errors.dart` | `AuthErrorCode`, `ServiceErrorCode`, `ServiceException`. Servis metin üretmez |
| `lib/services/notification_service.dart` | Seans bitiş bildirimi (Android'de exact alarm), Android kalıcı sayaç bildirimi, izin akışı, açma/kapama tercihi |
| `lib/services/lock_screen_timer.dart` | Kilit ekranı sayacı cephesi: Android kalıcı bildirim / iOS Canlı Etkinlik (MethodChannel `com.pomosprint.app/live_activity`), testte no-op |
| `lib/services/language_service.dart` | Dil seçimi (`app_language_code`), eski `translate()` çağrılarını ARB'ye bağlayan köprü, `translateCatName`; ayrı metin sözlüğü yok |
| `lib/utils/` | `study_day` (04:00 kuralı), `stats_calculator`, `stats_format`, `async_lock`, `auth_error_text`, `color_hex` |
| `lib/models/` | `UserModel`, `CourseCategory`, `StudySession`, `AvatarCharacter` (gömülü yedek katalog dahil) |
| `lib/widgets/` | `stats/`, `social/`, `auth/` alt klasörleri; kum saati, avatar, lig bilgi sayfası, shell rozetleri |
| `lib/l10n/` | `app_tr.arb` (şablon), `app_en.arb` ve **üretilen** `app_localizations*.dart` (elle düzenlenmez) |
| `test/` | Birim ve widget testleri. Simülatörde uçtan uca testler `integration_test/` (yerel kopyaya bağlı; `tool/local_supabase/e2e/sim/`). `test/support/fake_supabase_service.dart`: Raporlar ve Kategorilerim'e `service:` ile verilen sahte servis |
| `supabase/migrations/` | İleri migration'lar. `20261003150000_live_audit_fixes`, 8 Ekim uygulanan `20261007110000_report_submission_lock` ve üç `20261007150000/160000/170000` Maraton paketi canlıda (§4.6); klasörün tamamı canlı geçmiş değildir |
| `supabase/rollbacks/` | Down betikleri; CLI uygulamaz |
| `supabase/proposed/` | Öneriler (`01`–`26`). 12, 15, 16, 19 (A), 13, 14, 20–26 canlıda (5 Ekim 2026); 01–11 ve 19 B uygulanmadı. Sıra `proposed/README.md`. Her dosya `\quit` ile başlar |
| `supabase/tests/` | `run_local.sh` (yerel), `*_dryrun.sql` (canlıda, geri alınan transaction) |
| `supabase/functions/` | `unsubscribe`, `send-welcome-email` (repodaki sürümler canlıdan yeni, §10), `delete-account` (canlıda yok; istemci 404/5xx'te `delete_own_account`'a düşer, §5.6) |
| `scripts/` | `security_regression_test.js` (canlı), `send_newsletter.js` (+ `lib/newsletter_mail.js`), `templates/`, `test/` (`npm test`, ağsız). Sırlar `scripts/.env` (şablon `.env.example`) |
| `landing/` | Site: `_partials/`, `tools/sync_partials.py`, `js/config.js`, `_headers`, `worker.js`, `wrangler.jsonc`, `en/` |
| `android/`, `ios/` | Platform yapılandırması (`com.pomosprint.app`). `ios/PomoSprintTimerWidget/` Canlı Etkinlik uzantısı, `ios/Shared/` iki hedefte derlenen ActivityAttributes |
| `tool/ios/add_live_activity_target.rb` | Widget uzantı hedefini `project.pbxproj`'a ekleyen idempotent betik (xcodeproj gem) |
| `analiz/` | 3 Ekim denetim raporu (`PomoSprint_Analiz_Raporu_2026-10-03.md`) ve 245 maddelik bulgu listesi |
| `specs/`, `.specify/`, `.claude/` | spec-kit, proje ajanı `qa-tester`, skill'ler |

## 4. Alan alan rehber

### 4.1 TIMER ve SHELL: sayaç, kabuk, bildirim
**Dosyalar:** `timer_screen.dart`, `timer_persistence.dart`, `app/main_shell.dart`, `notification_service.dart`, `AndroidManifest.xml`

**Kurallar**
- Kalan süre her tick'te ve `resumed`'da `ActiveTimerSession.remainingSecondsAt(now)` ile hesaplanır. Azaltarak sayan koda dönme.
- `clientUuid` ve `startedAt` seans başına **bir kez** üretilir, duraklat/devam boyunca korunur. `client_uuid` sunucudaki idempotency anahtarıdır.
- Yatay Pomo tüm sayaç durumlarında (boşta/duraklatılmış/mola/onay dahil) yalnız animasyon, sayaç ve seans kontrolleridir. MainShell üst çubuk/gezinme/banner görünümünü gizler; veri işleri ve IndexedStack state’i devam eder. Timer kategori/süre/Maraton satırını gizler. Odak/boşta/duraklatılmış görünümde duraklatma hakkı ve uygun Başlat/Duraklat/Devam/Sıfırla kontrolleri kalır; mola/onay aşamasında duraklatma hakkı gösterilmez. Duraklatma bilgilendirme SnackBar’ı küçük yatay/x2 yazıda Devam düğmesini örttüğünden yatayda gösterilmez; disk/hak/puan değişmez. Dikey eski düzen korunur.
- Kahve yalnız `MarathonPhase.breakTime` sırasında `MarathonBreakIndicator` ile gösterilir: sabit fincan, 4 sn küçük buhar hareketi, reduced-motion ve görünmeyen TickerMode’da durur. Onay beklerken normal duran kum saati vardır; waving-hand kullanılmaz. Yeni simge/özellik ekleme.
- Seans her durum değişiminde diske yazılır. Açılışta: süre dolduysa hemen tamamlanıp gönderilir. Duraklatılmış seans, devam ettirilse bile bitişi başlangıçtan 24 saat sonraya kalacaksa (`isAbandonedAt`; sunucu `too_old` ile reddeder) silinir ve `pausedSessionExpired` gösterilir: açılışta, BAŞLAT'ta (3-2-1'den önce ve sonra) ve ön plana dönüşte (`test/timer_paused_expiry_test.dart`).
- Sayaç tüm normal derlemelerde 25/50 dk kullanır. QUICK_TIMER/QUICK_TIMER_SAVE ve kısa mola override’ları kaldırıldı; `kQuickTimer=false`. Açıkça verilen `TimerScreen(quickTimer:true)` yalnız widget simülasyonu içindir; ürün başlatıcısı bunu açmaz. Eski `recordAccelerated` kalıcı alanı uyumluluk için okunur: aktif kayıt geri yüklenirken temizlenir, outbox servis/ağ/RPC işlemlerinden önce kalıcı `invalid_data` olarak ret geçmişine taşınır. Normal outbox korunur; QA tamamlama RPC’si seçilmez.
- Duraklatma hakkı 1. Seans varken 25/50 değiştirilirse seans sıfırlanır.
- Maratonda mola sonrasında yeni odak otomatik başlamaz: 60 sn içinde ön planda “Buradayım” dokunması ve kayıtlı planda sunucu onayı gerekir (§5.7). Süre aşımı, kapalı/askıda uygulama veya eski bilet yeni pencere üretmez; önceki tamamlanan seanslar korunur.
- Bildirim izni açılışta değil, ilk BAŞLAT'ta (`ensurePermission`) istenir. Profil'deki anahtar `notifications_enabled` (bitiş bildirimi + kilit ekranı sayacı); "tercih açık VE izin var"ı gösterir (`permissionStatus`: `granted` / `denied` / `notDetermined` / `unknown`, `resumed`'da yeniden okunur). iOS `checkPermissions` hiç sorulmamışla reddedilmişi ayırmaz (ikisi de `isEnabled: false`; `isProvisionalEnabled` izin sayılır); ayrım `notification_permission_asked` ile yapılır. Hiç sorulmamışsa anahtar kapalı, uyarısız; açınca sistem penceresi çıkar. Reddedilirse tercih AÇIK kalır: anahtar kapalı + "Ayarları aç" (Profil'de ve ilk BAŞLAT'ta; `openSystemSettings`: eklentinin `openAppNotificationSettings`'i, iOS'ta yedek `app-settings:`), ayarlardan izin verilip dönülünce anahtar kendiliğinden açılır. İzin platformu testte `debugPermissionPlatform` ile değiştirilir (`test/support/fake_notification_permissions.dart`).
- Kilit ekranı sayacı (`LockScreenTimer`) her durum geçişinde çağrılır: başlat/devam/geri yükleme `showRunning`, duraklat `showPaused`, sıfırla/tamamla/çıkış/ekran kapanışı `clear`, ön plana dönüş `force: true`. Bildirim tercihi kapalıysa gösterilmez; kapatınca `preferenceRevision` ile kaldırılır. iOS Canlı Etkinlik bildirim izni istemez: izin reddedilmiş ama tercih açıksa (anahtar kapalı + "Ayarları aç") sayaç yine görünür. Dart arka planda çalışmaz; geri sayımı sistem yürütür (Android kronometre + `timeoutAfter`, iOS `Text(timerInterval:)` + `staleDate`). Foreground service / background mode EKLEME.
- `start_study_session` / `cancel_study_session` çağrıları Shell'in `onTimerStateChanged` callback'inde yapılır.

**Tuzaklar**
- IndexedStack tüm sekmeleri açılışta kurar ve canlı tutar. Görünmeyen sekme `TickerMode(enabled: false)` alır; periyodik iş yapan ekran `TickerMode.valuesOf(context).enabled`'a bakmalı.
- `SnackBarWidthScope` dar ve geniş temalarda `floating` davranışını sabit tutmalı. Dar uçta null davranış + geniş uçta floating/width, açık dialog/aktif SnackBar dönüşünde `SnackBarThemeData.lerp` assertion’ı üretiyordu. Dar genişlik kısıtsız, geniş 480 dp; `snackbar_width_scope_test` ara geçiş karelerini denetler. Yalnız son `pumpAndSettle` sonucu kusuru kaçırabilir.
- `ShellNavigationScaffold` gövdesinin MediaQuery'si Scaffold'un gövdeye verdiğinden türetilir (`Builder`). Dış context'le `MediaQuery.removePadding` üst/alt güvenli alanı geri getiriyordu: sekmelerin `SafeArea`'sı iPhone'da üstte ve altta ikinci kez boşluk bırakıyor, sayaçta BAŞLAT alt gezinmenin altına kayıyordu. `responsive_shell_test` güvenli alanlı iPhone boyutlarıyla (402x874, 393x852, 390x844, 375x667) denetler.
- Sayaç düzeni (`_TimerLayout`): dikey telefonda kum saati 220–275 dp; kısa telefonda eski `(h*.34).clamp(120,220)` tabanı, yatayda eski iki sütun hesabı. `phoneControlsHeight` eski `5f99f90` bütçesini korur; 48 dp Maraton girişi kontrol aralıkları ve boşta ayrılan Sıfırla alanını kullanır. Popup/aşama/plan seçimine göre kum saatini yeniden küçültme. Üç kompakt/dense kontrol aralığı daraltılarak duraklatılmış normal seansta ana düğme iPhone16Pro/SE’de kaydırmadan görünür. Boyut formülü ve plan öncesi/sonrası konum `marathon_responsive_test` ile kilitlidir. Yeni büyük içerik popup’a gitmeli; yeni ana kontrol için gerçek yazı tipli fold testini çalıştır. 25/50 tek satırda eşit `Expanded`; `Wrap` içinde tüm genişliği alan `Container` kullanma.
- Çıkışta süren seans cihazda kalır (aynı hesapla girişte sürer); Shell bildirimi iptal edip `cancel_study_session` çağırır.
- `onAuthStateChange` son olayı yeni aboneye yeniden verir.
- connectivity_plus yalnızca ipucu (`ConnectionWatcher`): iOS'ta dinleme başında ve `checkConnectivity`'de yeni NWPathMonitor'ün ilk yolu sahte `none` olabilir, simülatörde geri geliş olayı gelmeyebilir. `none` hiçbir isteği engellemez ve çevrimdışı göstergesi üretmez; kuyruk zamanlayıcı, ön plana dönüş ve banner ile de denenir.
- Bulut başlatması (`SupabaseService.ensureCloud`) kalıcı olarak düşmez: açılışta hata ya da splash zaman aşımı olursa kabuk (kuyruk turu, ön plana dönüş, bağlantı olayı) ve her giriş denemesi yeniden dener; eşzamanlı çağrılar tek denemede birleşir. Bulut sonradan gelirse kabuk auth dinleyicisini bağlar, profil/kategori/kataloğu okur ve veri ekranlarını yeniler (`notifyConnectionRestored`). Test ortamında `debugCloudInitializer` verilmezse denenmez (gerçek `.env` ile canlıya bağlanılmasın).
- Android bildirim ikonu `@drawable/ic_stat_notification` (`res/raw/keep.xml` R8'den korur). 5 Ekim QA: bu makinede Android SDK kuruldu; ARM64 Android 16 emülatörde debug/UI ve release APK (29,5 MB) doğrulandı; iOS unsigned release derlemesi de geçti (30,3 MB). Fiziksel cihaz kapsam dışı.
- Android 14+ kullanıcı kalıcı bildirimi kaydırıp kapatabilir; uygulama ön plana dönünce yeniden gösterilir. Bildirim kimlikleri: 0 bitiş, 1 süren seans (`pomodoro_running_channel`).
- iOS Canlı Etkinlik bitişte "eskir" ("Seans tamamlandı" görünümü); uygulama açılınca seans tamamlanır ve etkinlik kaldırılır. Sistem etkinliği ~8 saatte bitirir.

### 4.2 DATA: veri katmanı ve modeller
**Dosyalar:** `supabase_service.dart`, `session_queue.dart`, `server_clock.dart`, `service_errors.dart`, `models/`

| Parça | Rol |
|---|---|
| `currentUser` (`ValueNotifier<UserModel?>`) | Kullanıcı için **tek kaynak**. Her güncelleme `saved_user` önbelleğini yazar; `signedOut`'ta null olur |
| `fetchCurrentUserModel()` | Profil + `avatar_unlocks` okur, profil yoksa oluşturur, `currentUser`'ı günceller |
| `setCurrentUser()` / `restoreCachedUser()` | Yerel değişikliği servise yazar / çevrimdışı açılışta önbellekten yükler |
| `submitCompletedSession()` | Önce kuyruğa yazar, sonra kuyruğun tamamını gönderir. Sonuç: `SessionSubmitSuccess / Queued / Rejected` (Dart 3 `switch`) |
| `syncPendingSessions()`, `pendingSessionCount` | Kuyruğu gönderir / bekleyen sayısı |
| `takeRejectedSessionNoticeCount()`, `getRejectedSessions()` | Arka planda reddedilen seansların tek seferlik bildirimi / son 50 kayıt |
| `categoriesRevision` (`ValueNotifier<int>`) | Her kategori mutasyonunda artar; Shell ve yönetim ekranı dinler |
| `addStatsChangedListener` | Yalnızca bu cihazdaki olay. Uzak `ranking_updates` yayını **kaldırıldı** |
| `fetchStudySessions({since})` | Yalnızca kendi seansları, 1000'lik sayfalama |

**Kurallar**
- Puan, kum ve seri yalnızca RPC sonucundan okunur. İstemcide formül yazılmaz.
- Kategori kimliği yalnızca UUID ise sunucuya gider (`isUuidCategoryId`). `'1'..'5'` yerel yer tutucudur; kuyruk isimle eşler.
- Seans **hiçbir durumda sessizce silinmez**. Kalıcı ret `rejected_sessions_uid_<uid>` listesine gider.
- `classifySessionError` testlerle kilitli (`session_sync_test`, `session_queue_test`). Değiştirirsen testleri de güncelle.
- Servis metodları hata yutmaz: `ServiceException` / `AuthFailure` fırlatır. UI `serviceErrorCodeOf(e)` ve `authErrorText(l10n, code)` ile metne çevirir.
- `ownProfileColumns` `email` içermez; e-posta oturumdan gelir. `profiles`'ı e-postayla filtreleme, `id` ile güncelle.

**Tuzaklar**
- PGRST202 yedekleri: `fetchFriends` / `fetchPendingFriendRequests` (RPC canlıda var, yedek ölü kod).
- `getPendingSessionCount` sahibini ve `_userEpoch` değerini okumadan önce yakalar; await sonrası ikisi de hâlâ eşitse global `pendingSessionCount` yazılır. UID aynı olsa bile çıkış/yeni oturum eski sonucu düşürmelidir. Çağırana kendi okuduğu sayı döner; başka hesabın göstergesi korunur. Beş regresyon `account_session_test` içinde; son QA §31.
- Uygulama kapalıyken biten seans açılışta tamamlanınca kabuğun açılış senkronu (`sync`) ile sayacın `submit`'i yarışır: seansı önceki tur gönderirse `submit`'in kendi turunda seans yoktur. Sonuç o turdan (`SessionQueue._settledOutcomes`, son 50 kabul/ret) okunur; eskiden diyalog, sunucu puanı yazmışken "bağlantı gelince gönderilecek" diyordu (simülatör e2e c, `test/session_queue_test.dart` "eşzamanlı başka tur").
- `updateCategoryOrders` aktif kategoriler için **paralel** `update(sort_order)` yapar; `reorder_categories` çağrılmaz (canlıda yok), upsert de yok. Kısmi başarısızlıkta sıra karışabilir: Kategorilerim hata olunca iyimser sırayı geri alır ve listeyi sessizce yeniden okur. `sort_order` canlıda çakışabilir (`create_category` aktif sayısını yazıyor); istemci `sort_order, created_at, id` ile sıralar. Kalıcı düzeltme `proposed/16`.
- Prefs anahtarları: `saved_user`, `saved_categories_<email>`, `pending_sessions_uid_<uid>` (eski `pending_sessions_<email>` ilk erişimde taşınır), `rejected_sessions_uid_<uid>`, `rejected_sessions_unseen_uid_<uid>`, `active_session_uid_<key>`, `avatar_catalog_v1`, `daily_pomo_goal` (eski, bir kez taşınır), `league_info_shown_<uid>`, `hidden_users_uid_<uid>` (gizlenen kullanıcılar), `onboarding_draft_uid_<uid>` (yarım onboarding), `apple_sign_in_identity` (bu cihazda Apple ile girilen oturumun Apple kimliği; her çıkışta silinir), `app_language_code` + `app_language_device_code` (seçim anındaki cihaz dili), `theme_mode`, `notifications_enabled`, `notification_permission_asked`.
- Hesap silme (`deleteUserAccount` → `clearDeletedAccountLocalData`) kullanıcıya bağlı tüm anahtarları siler ve `TimerPersistence.retireOwner(uid)` ile sayaç ekranının dispose'da seansı yeniden yazmasını engeller. Yeni kullanıcıya bağlı anahtar eklersen oraya da ekle (`test/user_safety_test.dart`).
- Avatar: `AvatarCharacter.byId` ve `allAvatars()` asla fırlatmaz / boş dönmez. Yine de listelerde korumasız `.first` kullanma.
- `supabase_service.dart` içinde "public leaderboard `is_me` DÖNMEZ" yorumu bayat; canlı RPC `is_me` döndürüyor.

### 4.3 STATS: Raporlar sekmesi
**Dosyalar:** `reports_screen.dart`, `history_screen.dart` (Haftalık), `monthly_tracking_screen.dart`, `utils/stats_calculator.dart`, `widgets/stats/`

**Kurallar**
- Veriyi yalnızca `ReportsScreen` çeker; Haftalık ve Aylık ekranlar parametre alır.
- Gün = çalışma günü, sınır yerel 04:00 (`studyDayOf`). Üçüncü bir gün kuralı icat etme.
- Hafta Pazartesi-Pazar (`mondayOf`). Takvim adımı `DateTime(y, m, d + n)` / `addDays`; `Duration(days:)` kullanma (DST).
- Sunucu ve kuyruk seansları yalnızca `mergeStatSessions(remote, pendingStatSessions(queue), categories)` ile birleşir:
  - `client_uuid`'si sunucu listesinde olan bekleyen seans atılır (yanıtı kaybolmuş seans iki kez sayılmaz). `_studySessionColumns` bu yüzden `client_uuid` içerir.
  - `lastError == 'overlap'` olan bekleyen seans sayılmaz (sunucu onu hiç kabul etmez); kuyrukta ve bantta kalır.
  - Bekleyen seansın günü kuyruğun gönderdiği düzeltilmiş saatle: `startedAt + clockOffsetMs` (yoksa o anki fark). Raporların "bugün"ü de sunucu saatiyle.
  - Bekleyen seansın kategorisi kimlikle (yer tutucuda dilden bağımsız adla, `categoryMatchKey`) çözülür; ad, renk, ikon sunucu birleşiminden (arşivlenmiş dahil), yoksa aktif listeden.
- Kategori toplamları **kimlikle** gruplanır (`statGroupKey`); yeniden adlandırma satırı bölmez. Kimliksiz kayıtlar adla.
- Kuyruk sunucu okumasından önce ve ondan bağımsız okunur: çevrimdışıyken de bekleyenler görünür. Uzak okuma başarısız olunca, kuyruktan çıkmış (reddedilmemiş) seanslar sunucu seansı olarak tutulur; toplam düşmez.
- `ReportsScreen` `categoriesRevision`'ı dinler (görünürse hemen, değilse dönüşte yenilenir).
- Günlük hedefin kaynağı `profiles.daily_goal_minutes` (`showDailyGoalSheet` → `updateDailyGoalMinutes`). Varsayılan 200 dk. Hedef sayfasındaki pomodoro sayısı yukarı yuvarlanır (hedefe ulaşmak için gereken).
- Yüzde gösterimi: dağılım lejantı `roundedPercents` (toplam 100); verimlilik kartı `goalProgressPercent` (kırpılmaz), halkalar `goalPercent` (en çok 100). Haftalık verimlilik etiketi geçen günlerin hedefine göre (`elapsedWeekGoalPercent`).
- Kategori adları DB'de çoğunlukla Türkçe, İngilizce onboarding'de İngilizce saklanır; gösterirken `translateCatName`, eşlemede `categoryMatchKey` (tablo: `utils/category_names.dart`). 50 dk = 2 pomodoro.

**Tuzaklar**
- Normal seans/outbox birleşimine yalnız sunucuda tamamlanmış denemeler eklenir (`combineStudyAndExamSessions`). Deneme ayrı kategori satırıdır; derslere bölüştürülmez. Eski hızlandırılmış QA outbox’ı puan/dakika üretmeden reddedilir. Detay §11.
- Gün kuralı istemcide de sunucuda da **profil diliminde** 04:00 (`studyDayOf`, `setStudyTimeZone`; `currentUser.timezone` değişince otomatik). `DeviceTimeZone` IANA adını native kanaldan okur; profil okumasında ve Shell ön plana döndüğünde kendi `profiles.timezone` kolonuna yazar. Bilinmeyen ad / ağ hatasında mevcut profil dilimi korunur; cihaz UTC farkından dilim uydurulmaz.
- **Eski canlı API:** Sıralama > Aylık (`get_public_monthly_leaderboard`) ve Raporlar > Aylık aynı çalışma ayı kuralını kullanır: `started_at`, profil dilimi, 04:00 (`proposed/15`, 5 Ekim 2026'dan beri canlıda). Geri sayım `nextMonthlyLeaderboardReset` (`ranking_models.dart`) `studyDayOf`/`studyDayStart` ile ayın 1'i 04:00. **Yeni paket 29 ligleri** ise İstanbul 00:00 takvim ayıdır; rapor/seri 04:00 değişmez. Eski RPC ile yeni aylık ligin zaman sınırını karıştırma.
- Yenileme ve gün dönümü zamanlayıcısı TickerMode'a bağlı; sekme görünmezken durur. Üst çubuktaki seri `StudyDayBuilder` ile 04:00'te kendiliğinden tazelenir.
- Testler: `test/reports_correctness_test.dart` (sabit veri setiyle tüm metrikler), `test/reports_findings_test.dart`, `test/support/fake_supabase_service.dart` (ekranlara `service:` ile verilir).

### 4.4 SOCIAL: lig, sıralama, avatar, profil, arkadaşlar
**Dosyalar:** `ranking_screen.dart`, `widgets/social/*`, `league_info_sheet.dart`, `social_screen.dart`, `friends_sheet.dart`, `profile_screen.dart`, `character_collection_screen.dart`, `avatar_model.dart`

**Kurallar**
- Sekmeler: **Lig | Aylık | Arkadaşlar**. "Tüm zamanlar" sekmesi kaldırıldı (`getAllTimeRanking` ve `getLeagueZones` servis metodları çağrılmıyor).
- Sosyal durum push/Realtime değildir: görünür/ön planda normal30 sn polling; sekmeye/ön plana dönüşte hemen okur. `_requestId` eski yanıtı düşürür; `test/social_break_presence_test.dart` ters sıralı yanıt regresyonunu içerir. Force-kill heartbeat yoktur; sunucudaki odak son tarihe/iptale kadar kalabilir. Beş gerçek eşzamanlı hesap/cihaz kanıtı devir §21'dedir.
- "Ben" satırı yalnızca `is_me` ile bulunur. İsimle eşleme yapma. Arkadaşlar sekmesinde kendi satırı yerel profilden eklenir.
- Lig verisi `get_my_league_ranking_v2()` JSON ile okunur; yalnız PGRST202 eski `get_my_league_ranking()` yedeğini açar (`services/league_backend.dart`). V2 satırında `has_league`, aktif üye sayısı, durum/başlangıç, kapasite, gömülü güvenli `league_config` ve `promotion_eligible/award_eligible/demotion_eligible` sunucudan gelir. Ağ/yetki hatasını eski sunucu gibi yorumlama; eligibility puandan tahmin edilmez.
- Ligsiz satır: `member_count` 0 (`proposed/20`, canlıda; öncesinde 1'di, tek kişilik gerçek odayla aynı). `LeagueSnapshot.fromRows` sırasıyla `has_league` → `member_count` 0 → birden çok üye/puan → kural sunucudan geldiyse (20) gerçek oda → canlıda `hasLeagueHistory` (ömür boyu puan > 0: puan kazandıran her seans odaya yerleştirir, üyelik silinmez). "Henüz bir lig odasında değilsin" yalnızca `awaitingPlacement`; odasında tek ve puansız kalan (terfi sonrası, t4-F6) "Odanda şimdilik yalnızsın" (`isAloneInRoom`).
- `LeagueRules` önce `get_league_config()` okur; yalnız eksik RPC (PGRST202) `get_app_config()` eski sözleşmesine düşer. Cache30sn, saat geri giderse yenilenir; v2 gömülü config ve satır durumu daha günceldir. Eksik v2 config güvenli25/10 yedeği ve kapalı eligibility kullanır. Eski sunucu1/1/1 davranışı yalnız eski sözleşme içindir. TR/EN rehber/onboarding ve madalyalar aynı kuralları kullanır.
- İlk başarılı okuma öncesinde ağ yoksa servisin başlangıç yedeği25kapasite/10aktif ödül/policy1/preparing'dir; rehber eski30 kişiyi göstermemelidir. Sunucu sonradan farklı config döndürürse onun yanıtı geçerlidir. TR/EN cold-offline regresyonu `test/league_offline_defaults_test.dart`; eski30 kuralı yalnız gerçekten legacy RPC sözleşmesinde kullanılabilir.
- Lig: 5 kademe (1 Bronz … 5 Elmas), oda en fazla 25 kişi; hazırlık sonrası global 14 gün. Ayrıntılı aktiflik, yeterlilik, ödül ve düşme §6.4'te. Kapasite sonradan yalnız sunucu config ile 30 yapılabilir; site statik açıklaması da güncellenmelidir.
- Avatar sahipliği = `avatar_unlocks` kaydı ya da ücretsiz (`isOwned`). Kaydı olmayan varsayılan avatar (kataloğa sonradan eklenen, t4-F9): canlı `set_equipped_avatar` 'Bu avatar kilitli.' der; `setEquippedAvatar` (`services/avatar_equip.dart`) yalnızca katalogda varsayılan ve bedelsizse kaydı `purchase_avatar` ile (0 kum) açıp bir kez yeniden dener (`proposed/22` sonrası ilk deneme başarılı). Lig ödülü avatarları satın alınamaz. Premium'a özel avatarlar (edinme yolu / IAP yok, App Store 2.3.1) yalnızca sahibine ya da Premium kullanıcıya listelenir (`isListedInShop`).
- Özel Avatarlar: `special_` önekiyle ayrı koleksiyon; 21 satırın tamamı 500 kum, default/premium-only/league-award=false. Kayıt yalnız 7 aktif ücretsiz varsayılanı listeler. `special_ronin` retired filtresi eski önbellek/sunucu satırını mağazadan dışlar; görseli temel avatarla güvenli gösterir. Manifest `assets/avatars/special_catalog.json`; sunucu/önbellek önceliği korunur. Koleksiyon mounted+ownerEpoch korumalıdır. Grid kartının dış `StackFit.expand` kuralını koru: görsel ve ad kartın ortak merkezindedir; fiyat ve kilit ayrı avatar alanındadır, TR/EN/x2/yatay Rect regresyonları bulunur. Canlı Ronin silme paketi `20261009233000`, MD5 `9ad12fc8edb016c69eb45a24f4ac1e11`; sahiplik/kuşanma varken SQL reddeder. RPC/kolon/ACL değişmedi.
- Profil ve Koleksiyon `currentUser`'ı dinler; kopya tutmaz.
- Başka kullanıcının verisi yalnızca RPC ile gelir.
- Kullanıcı içeriği (App Store 1.2): başkasının satırında uzun basma / "⋮" ile `showUserSafetySheet` (`widgets/social/user_safety.dart`). Sıralama ve canlı akışta "Bildir" + "Gizle" + kimlik varsa "Engelle"; arkadaş listesi ve isteklerde "Bildir" + "Engelle", kabul edilmiş arkadaşta ayrıca "Arkadaşlıktan çıkar"; kendi satırında menü yok. Bilinen kullanıcı kimliğinde `user_report_dialog.dart` neden seçimi ve isteğe bağlı 500 karakter açıklamayla `submitUserReport` → `submit_user_report` çağırır; kimliksiz eski satırda mailto yedeği kalır. Yer kodları `league`, `monthly`, `friends_ranking`, `live_feed`, `friends_list`, `friend_request`; neden kodları `offensive_name`, `offensive_content`, `harassment`, `spam`, `impersonation`, `other`. Sonuç `success`, `duplicate`, `code`; 24 saatte 10 bildirim, tekrar aynı hedef için açık kaydı çoğaltmaz. `user_reports` istemciden okunmaz; hesap silme kimlik referanslarını SET NULL yapar, snapshot/açıklama kalabilir. Operatör `ops.open_user_reports` / `resolve_user_report` kullanır.
- Gizleme cihazda, hesaba bağlı (`HiddenUsersStore`, `hidden_users_uid_<uid>`). Eski kimliksiz RPC satırlarında gizleme adla eşlenebilir; proposed/14 sonrası kimlik ve `is_blocked` içeren satırlar desteklenir; sıralamada satır silinmez, ad/avatar "Gizlenen kullanıcı" olur (sıra ve lig bölgeleri bozulmaz). Profil > Gizlilik ve yasal'dan sıfırlanır.
- Görünen ad denetimi `utils/name_filter.dart` (kayıt, profil ad düzenleme, Google/Apple ilk adı). Sunucuda proposed/13–14 ile ad/kategori içerik denetimi trigger'ları da var; istemci denetimi UX içindir.
- Profil adı e-postadan türetilmez: sağlayıcı ad vermezse (Apple adı yalnızca ilk yetkilendirmede verir) ya da ad kullanılamazsa (küfür, tek harf) ad `SupabaseService.neutralProfileName` olur: `'Pomo ' + kimliğin ilk 4 karakteri`. proposed/14 sonrası sunucu da uygun sağlayıcı adı yoksa nötr `Pomo 1234` üretir. İstemci (`providerFirstNameUpdate`) eski e-posta tohumu ve yeni nötr adı tanır; sağlayıcı adı gelirse uygun adla günceller.

**Tuzaklar**
- Arkadaşlar sheet'inde giden isteği iptal, arkadaş satırı menüsünde silme ve engelleme, engellenenler listesinde geri açma var. Canlı/sıralama menülerinde kimlik varsa engelleme var. İşlemler onaylı ve sunucu yanıtı beklenirken düğmeler kapalı; başarıda sosyal/sıralama tazelenir. Sunucu sözleşmesi (`proposed/14`, canlıda): `remove_friend`, `cancel_friend_request`, `get_outgoing_friend_requests`, `block_user`, `unblock_user`, `get_my_blocks`, `submit_user_report` (sözleşme `proposed/README.md` "Öneri 14"). Gizleme şimdilik cihazda.
- `add_friend_by_code` / `respond_friend_request` yanıtında makine-okunur `code` var (`proposed/13`–`14`, canlıda: `request_sent`, `accepted`, `rejected`, `rate_limited`, `cooldown`, `blocked`, …). İstemci `friendResponseCode` ile önce `code`'a, yoksa sunucunun sabit Türkçe mesajına bakar (`bulunamad` → `not_found`, `kendini`, `zaten arkadaş`, `zaten istek`); mesaj metni değişirse `test/friends_sheet_test.dart`'ı güncelle. Kod girişi `utils/friend_code.dart`: sunucudaki `normalize_friend_code` (13) ile aynı normalize (boşluk/tire/alt çizgi/nokta atılır, büyük harf, O→0, I/L→1; sunucu da aynısını yapar), 6–8 karakter Crockford alfabesi (eski 6 hex alt kümesi); biçimce geçersiz kod gönderilmez (13 her denemeyi saatlik sınıra sayar). Yanıtlanamayan istekte (sunucu cevap verdiyse) liste her zaman tazelenir, bayat kart kalmaz.
- V2 podyum madalyası yalnız `award_eligible=true`; hazırlık/scheduled veya10aktif/3gün/300dk şartları yoksa madalya yoktur. Eski RPC yedeğinin eski puan kuralı korunur. Sıra rozeti (#1–#3) her zaman.
- Sosyal ekran 30 sn'de bir poll yapar; görünmezken durur.
- Avatar görseli: uygulamada `assets/avatars/<asset_key>`, sitede `landing/avatars/<id>.webp`.

### 4.5 AUTH ve L10N: giriş, onboarding, kategoriler, yerelleştirme
**Dosyalar:** `app/app_gate.dart`, `login_screen.dart`, `register_screen.dart`, `post_auth_onboarding_screen.dart`, `categories_management_screen.dart`, `widgets/auth/*`, `language_service.dart`, `l10n/`

**Kurallar**
- Yönlendirme yalnızca `AppGate`'te. Ekranlar kendi aralarında Login/Onboarding/Shell'e geçiş yapmaz; `currentUser`'ı günceller.
- Onboarding `completeOnboarding()` ile biter (önce kategoriler, sonra profil). Profili `handle_new_user` trigger'ı oluşturur; istemci upsert'i yedektir ve avatar sunucuda varsayılana zorlanır. `showInSocialFeed` zorunlu ve her zaman yazılır (gönderilmezse sunucu varsayılanı TRUE kalır).
- Kategoriler `planOnboardingCategories` (`services/onboarding_categories.dart`) ile mevcut kategorilerle uzlaştırılır: ad eşlemesi dilden bağımsız (`categoryMatchKey`), zaten olan yeniden gönderilmez, önceki denemede arşivlenen geri açılır. Onboarding'i bitmemiş, sunucuda ve kuyrukta hiç seansı olmayan hesapta yeni seçimde olmayan aktif kategoriler arşivlenir (önceki deneme yarıda kaldıysa yeni seçim limite takılmaz, TR/EN çifti oluşmaz). Sıra `reconcileOnboardingCategories`; RPC yükü eksikler + aktif kalacaklar (`OnboardingCategoryPlan.rpcPayload`): `proposed/23` onboarding bitmemişken yükte olmayan seansız aktif kategoriyi arşivliyor, yalnız eksikler gönderilirse seçimdeki kategori arşive giderdi (canlıda birebir aynı ad atlandığı için zararsız). 23'ün jsonb sonucu `OnboardingCategoriesResult` (canlıda void → null); `skipped_limit` > 0 ise onboarding sonunda `onboardingCategoriesSkippedLimit`. Sunucu 13 yaş sınırı (`proposed/24`, `birth_year_under_minimum_age`) → `ServiceErrorCode.underMinimumAge`: yaş adımına dönülür, yıl kilitlenir. Öneri tablosu (`kRecommendedCategoriesBySegment`) ekranla ortak; hiç kategorisi olmayan hesabın varsayılanı (`ensureServerCategories`, kuyruk `createDefaultCategories`) segmentin ilk 5 önerisi, arayüz dilinde (`defaultCategorySeed`).
- Onboarding 7 adım: yaş (tekerlek önceden ayarlı değil, "Devam"da değerlendirilir; 13 altı yanıttan sonra yıl kilitlenir, çıkış / hesap silme kalır), segment (isteğe bağlı; sıra LGS, YKS, TUS, KPSS (`kpss`), Dil sınavı (`language`: YDS/YÖKDİL/IELTS/TOEFL), Üniversite, İş, Diğer; "Diğer" → `user_segment` null), kategoriler, sıralamalarda görünürlük (varsayılansız açık seçim → `show_in_social_feed`), oyun kuralları (`GameRulesList`, `get_points_config`), hedef, ekran rehberi. Hedefte Devam, son rehberde Bitir vardır; kayıt yalnız Bitir’de yapılır. Önünde hesaba bağlı TR/EN karşılama vardır. Rehber Pomo/Maraton/Deneme/netler/rapor/aylık hedef-global lig/kum-avatar/sosyal/profil’i TR/EN açıklar; `OnboardingDraft.step` 0–6, eski hedef taslağı 5 aynı hedef adımında korunur.
- Hedefe göre kategori ataması: segment seçilince o segmentin önerileri limite kadar (`categoryLimitFor`; YKS'de ücretsiz 8/9) **seçili gelir** (`autoSelectedCategoryNames`), başlık "Hedefine göre hazırladık" (`onboardingCategoryStepPrepared*`; "Diğer"de genel öneriler seçili, eski başlık). Ekran otomatik gelenleri ayrı tutar (`_autoCategoryNames`): segment değişince yalnızca onlar yeni segmentinkilerle değişir; elle seçilen öneriler (başka segmentinki olsa da çip olarak görünür kalır) ve özel kategoriler korunur. Tüm öneri adları `utils/category_names.dart`'ta TR/EN eşli olmalı (`test/onboarding_categories_test.dart` denetler).
- Segment sunucusu: `profiles_user_segment_check` eski canlıda `lgs, yks, kpss, language, university, work` (`proposed/26`). Yeni yerel `proposed/27` buna `tus` ekler; canlıya uygulanmadı. Eski sunucu için yedek yol kodda duruyor: İstemci (`validUserSegments`) yeni hedefleri gönderir; 23514 + `user_segment` gelirse `completeOnboarding` aynı PATCH'i `user_segment = null` ile bir kez daha yazar (`writeOnboardingProfileWithSegmentFallback`): onboarding tamamlanır, kategoriler önceden kurulmuştur, kullanıcı hata görmez. Birim: `test/onboarding_goal_categories_test.dart`; yerel kopyada uçtan uca (ekran dahil): `tool/local_supabase/e2e/t2_onboarding_categories/segment_fallback_e2e_test.dart`.
- Taslak (`OnboardingDraft`) görünürlük yanıtını (`show`) ve otomatik gelen kategorileri (`auto`) da tutar. Geri yüklemede "Diğer" ve segmentsiz seçimler korunur (izinli adlar: herhangi bir segmentin ya da genel öneriler + özel adlar); `auto` olmayan (eski sürüm) taslakta segment seçili ama kategori yoksa öneriler seçilir ve kategori adımı gösterilir; adım yaş, kategori ve görünürlük yanıtı eksikse o adıma çekilir. "Bitir" görünürlük yanıtı yoksa görünürlük adımına döner (`test/account_session_test.dart` "Onboarding taslağı").
- Kategori limiti ücretsiz 8, premium 15 (`categoryLimitFor`). Sunucu trigger'ı eklemede ve arşivden çıkarmada uygular; istemci kontrolü UX içindir. Kategori silinmez, arşivlenir.
- Yeni metin **yalnızca ARB'ye** (iki dosyaya da) eklenir, sonra `flutter gen-l10n`.
- Yasal sayfalar (`legal_links.dart`, `LegalPage`): TR `pomosprint.app/terms|privacy|kvkk`, diğer diller `/en/terms|/en/privacy|/en/kvkk`. Metin sürümü tek sabit: `kLegalDocumentsVersion`; yasal metin değişince artır.
- Profil > "Gizlilik ve yasal": Gizlenen kullanıcıları göster, Kullanım Şartları, Gizlilik Politikası, KVKK Aydınlatma Metni, Hesabımı Sil. Uygulama içi silme Apple 5.1.1(v) için yeterli; hesap silme web sayfası (`/hesap-silme`, `/en/delete-account`) Play Console'daki silme URL'sidir, uygulamada bağlanmaz. Veri kopyası (KVKK m.11 erişim hakkı) Aydınlatma Metni'ndeki e-posta yoluyla istenir; silme onayı bunu `destek@pomosprint.app` ile hatırlatır.
- Kayıt onayları: iki zorunlu (Kullanım Şartları kabulü; KVKK Aydınlatma Metni + Gizlilik Politikası okundu, rıza değil bilgilendirme teyidi), bir isteğe bağlı (ticari elektronik ileti, varsayılan kapalı). "Tümünü kabul et" yok. Zorunlular olmadan `registerUser` çağrılmaz; servis de `StateError` fırlatır. Metadata sözleşmesi §5.5.
- Google/Apple ile devam: giriş ekranındaki `SocialSignInNotice` (Kullanım Şartları + KVKK Aydınlatma Metni bağlantılı). Başarılı native sağlayıcı oturumundan sonra, profil/Shell yayınlanmadan `acceptLegalDocuments` mevcut `kLegalDocumentsVersion` ile `accept_legal_documents` çağırır. Kayıt `consents` ledger'ındadır (`terms`, `privacy_notice`, `source=app_legal_acceptance`); auth metadata'sı değiştirilmez. RPC kaydı başarısızsa tam çıkış yapılır ve hata gösterilir; yeniden giriş idempotenttir. Sessiz oturum geri yüklemesinde kullanıcı adına yeni onay verilmez.

**Tuzaklar**
- Metin kaynağı iki ARB'dir. `LanguageService.translate('key')` eski çağrılar için ARB getter köprüsüdür; ayrı 174 girdili sözlük ve kullanılmayan masa çevirmeni kaldırıldı. Yeni metin için doğrudan l10n getter kullan. `test/localization_completeness_test.dart`: anahtar/placeholder eşitliği, köprü ve doğrudan görünen metin taraması. Üç TR yasal dilbilgisi ön eki bilinçli boştur; bütün etiketler boş değildir. Marka/dil kodu/teknik indeks istisnaları dardır; geniş sessiz allowlist ekleme.
- Auth akışı **implicit** (`authFlowType: implicit`, `detectSessionInUri: false`). Sıfırlama/onay linkleri web sayfasında işlenir. Özel URL şeması (`io.supabase.pomosprint`) kaldırıldı.
- Şifremi Unuttum, `forgot_password_screen.dart` ekranında e-posta alır; `resetPassword` başarılı dönünce ayrı `PasswordResetSentScreen` açılır. E-posta bağlantısı mevcut web şifre yenileme sayfasına gider; uygulamada kod girişi yok. Başarı metni hesabın varlığını açıklamaz.
- `BackendConfig.isLocalBackend` → `SupabaseService.isLocalBackend` yalnız ortam açıklamasıdır, kayıt/yetki kapısı değildir. Yerel reset/sent ekranı Mailpit ve canlı hesaptan ayrı parola bilgisini gösterir; gönderim başladığı andaki bool Sent'e taşınır. Normal TR başlığı “E-postanı kontrol et”; API başarısı teslim garantisi değildir. Yerel token'ı üretim web config'iyle doğrulama; gerçek yerel tarayıcı reset helper'ı henüz kurulmadı.
- Auth istekleri (giriş, kayıt, sıfırlama, yeniden gönderme, sosyal giriş, şifre değiştirme) `runAuthRequest` ile 25 sn zaman aşımlı; kayıtta zaman aşımı ayrı metin (`signUpTimedOut`: "kayıt tamamlanmış olabilir").
- Oturum kapanışı tek kancadan: `signOutFully({notice})` (çıkış, silme, Apple izni) ve `handleAuthStateChange` (`signOutReason == sessionExpired`: şifre değişti / başka cihazdan kapatıldı). Kanca Google oturumunu, bitiş bildirimini ve kilit ekranı sayacını kapatır; `signOutNotice` giriş ekranında bir kez açıklanır (kullanıcının kendi çıkışında açıklama yok).
- Şifre kuralı (`widgets/auth/password_rules.dart`): en az 8 karakter + küçük/büyük harf + rakam (7 Ekim canlı Auth doğrulaması); Supabase panel ayarı, `authErrWeakPassword` ve `landing/js/reset-password.js` ile aynı tutulmalı. Kayıt ve Profil > Şifreyi değiştir (yalnızca `email` sağlayıcısı; mevcut şifreyle yeniden doğrulama + `updateUser`) canlı kural listesi gösterir.
- Kayıt ekranı `RegisterResult` döndürür (`RegisterSignedIn` / `RegisterAwaitingConfirmation`); onay bekleniyorsa giriş ekranı e-postayı doldurur ve "yeniden gönder"i doğrudan gösterir.
- Apple: iOS'ta Apple ile girilen oturum için açılışta ve ön plana dönüşte `getCredentialState` (revoked/notFound → tam çıkış). Android'de Apple girişi yok; giriş ekranındaki "Apple ile mi kaydoldun?" yardımı "Şifremi Unuttum" ile şifre belirlemeyi anlatır.
- Google iOS: Supabase'de "skip nonce" bilinçli açık. iOS client id üç yerde aynı olmalı: `GIDClientID`, `CFBundleURLSchemes` (ters çevrilmiş), `supabase_service.dart`.
- Apple girişi iOS login ekranında var; Apple Developer capability ve Supabase Apple provider ayarı kullanıcıda.
- `AppGate`, karşılama kapısına `signOutFully` verir; karşılama ekranında Çıkış vardır. Yaş adımı ve 13 altı engeli bu kapının ardından uygulanır.
- Dil: kayıtlı seçim yoksa cihaz dili (`PlatformDispatcher.locale`; iOS ve Android 13+ uygulama başına dil dahil, `locales_config.xml`). Giriş ekranında TR/EN seçici var. Seçim, o anki cihaz diliyle saklanır; cihaz dili sonradan değişirse cihaz izlenir (`test/language_service_test.dart`).
- `onboarding_screen.dart` ve `categories_screen.dart` silindi; geri getirme.

### 4.6 BACKEND: Supabase
**Dosyalar:** `supabase/README.md`, `supabase/proposed/README.md`, `migrations/20261003150000_live_audit_fixes.sql`, `tests/20261003_live_audit_fixes_dryrun.sql`

**Migration durumu**

| Dosya | Canlıda |
|---|---|
| `migrations/20260809*` … `20260809033000` | **Yok.** Canlı geçmişte farklı isimli ~36 migration var; içerik farklı. Tarihçe |
| `migrations/20260928120000_security_hardening_up` | **Hiç uygulanmadı.** `validate_study_session_timing` ve `session_not_elapsed` canlıda yok |
| `migrations/20261003150000_live_audit_fixes` | **Uygulandı** (3 Ekim, DRYRUN 28/28), geçmişe kayıtlı. Geri alma: `rollbacks/20261003150000_live_audit_fixes_down.sql` |
| `migrations/20261007110000_report_submission_lock` | **Uygulandı (8 Ekim 2026).** Bildirici başına transaction advisory kilidi duplicate ve 10/24h denetimini INSERT ile sıraya alır. Canlı DRYRUN 23/23, uygulama sonrası geri alınan 23/23 senaryo ve 9/9 salt okuma kontrolü; imza/JSON/ACL/veri aynı, hash `a7ee1b72778b92b59982e5bba8b86c7a`. [Rehber](supabase/tests/20261007_report_submission_lock_README.md), [QA](analiz/QA_REPORT_SUBMISSION_LIVE_2026-10-08.md) |
| `migrations/20261007150000_marathon_break_presence` → `20261007160000_marathon_rewards` → `20261007170000_marathon_presence_confirmation` | **Uygulandı (8 Ekim 2026).** Kullanıcının açık talebiyle üç paket tek atomik transaction; önce canlı 23+59+73 DRYRUN, sonra 96 geri alınan fonksiyon kontrolü ve 13 salt okuma sözleşme kontrolü yeşil. Gerçek300/60, altı bonus tutarlı, normal RPC aynı, QA helper yok. [SQL rehberi](supabase/tests/20261007_marathon_README.md), canlı kanıt (ham çıktı §37 temizliğinde kaldırıldı) |
| `migrations/20261008190000_league_launch_policy` | **Uygulandı (8 Ekim 2026).** Nihai SHA dac9176d…, canlı önce55/55 rollback, atomik uygulama, sonra55/55 rollback,18/18 veri/ACL; oda25 ve hazırlık. Normal RPC yalnız geçmiş ilk üyelik guard'ı: MD5 `72023f3f4d8636363cf0231f42d4c7e1`; Maraton gövdeleri birebir. [Lig SQL rehberi](supabase/tests/20261008_league_launch_policy_README.md), [QA](analiz/QA_LEAGUE_LAUNCH_2026-10-08.md) |
| `migrations/20261009190000_special_avatar_catalog` | **Kullanıcı SQL Editor'de uyguladı (9 Ekim 2026).** Salt okuma16/16 ve mobil public GET25/25:49 toplam/48 aktif/22 özel/7 aktif ücretsiz; özel500 kum, TR/EN/asset/flags manifestle aynı. Eski27 satır ve beş RPC/ACL/RLS yapısı korunur. MD5 `5e80e532aa71a325edd1d76e96183fb5`. İleri paketi yeniden çalıştırma; [rehber](supabase/tests/20261009_special_avatar_catalog_README.md), [QA](analiz/QA_SPECIAL_AVATARS_2026-10-09.md), devir§35. |
| `proposed/11_audit_fixes_unapplied.sql` (eski `20261003120000_audit_fixes`) | **Uygulanmadı**, `migrations/`'tan taşındı. Başındaki durum notu hangi parçanın gereksiz olduğunu söyler |
| `proposed/01`–`10` | Uygulanmadı. Sıra ve kapsam `proposed/README.md`'de |
| `proposed/12`, `15`, `16`, `19` (A), `13`, `14`, `20`–`26` (+ `_down`, `tests/proposed_*_dryrun.sql`) | **Uygulandı** (5 Ekim 2026, bu sırayla; kullanıcı onayıyla `supabase db query --linked --project-ref`, `postgres` rolü). Her adımda önce DRYRUN (hepsi `true`: 14/14, 6/6, 13/13, 12/12, 50/50, 67/67, 15/15, 10/10, 9/9, 13/13, 9/9, 9/9, 9/9), sonra dosya (`\echo`/`\quit` satırları çıkarılarak), sonra md5/katalog doğrulaması. Uygulama öncesi canlı parmak izi 4 Ekim kopyasıyla 13/13 aynıydı; sonrası yerel zincirle satır satır aynı (fark yalnızca bilinçli: 19 B yok, kopyaya özgü eklentiler, yerelde kapalı hoş geldin trigger'ı). Ürün düğmeleri varsayılanda: `unverified_session_daily_cap` null, lig ödül/terfi o tarihte1/1/1 (güncel §6.4), geç seans kendi gününün serisiyle. Geri alma ters sırayla `_down` dosyaları (`proposed/README.md`) |
| `proposed/19` B (yalnızca onaylı bekleme listesi kaydı) | **Uygulanmadı.** Önce site onay alanlarını göndermeli (§ landing); yoksa kayıt tamamen durur |
| `proposed/13` KVKK-20 2. aşama (`profiles.email` kolonunu kaldırma, dosya sonunda yorum) | **Uygulanmadı.** Ön koşul: istemci yedek profil upsert'ünden `email` çıkmış ve o sürüm `min_supported_version` |

**8 Ekim canlı Maraton RPC’leri:** `get_marathon_config`, `complete_marathon_study_session`, `start_study_break`, `get_live_friends_with_breaks`, `start_marathon_break`, `confirm_marathon_presence` (§5.7). Maraton kurulumunda normal tek seans RPC gövdesi korunmuştu; yeni lig paketinin yalnız ilk üyelik/geç dönem guard'ı §5.2'de. Güncel istemci gerekli onay sözleşmesini okuyunca yeni plan başlatmayı açar.

**Diğer canlıda olmayan RPC'ler:** `reorder_categories`, `set_my_timezone`, `get_my_category_limit` (ayrıca `get_my_streak`, `study_day_of`, `my_friend_ids`, `synced_at` kolonu). Gerekirse `proposed/11`'den canlı gövdelere göre ayrı migration yaz.

**Kurallar**
- Canlı tanım gerçeğin kaynağı. Repodaki eski gövdeden `CREATE OR REPLACE` yazma.
- Her SECURITY DEFINER fonksiyon: `SET search_path TO 'public','pg_temp'`; kullanıcı `auth.uid()`'den; `REVOKE ALL … FROM PUBLIC, anon` + `GRANT EXECUTE … TO authenticated`.
- `DROP` + `CREATE` yetkileri sıfırlar ve PUBLIC'e EXECUTE verir. Yetkileri her seferinde yeniden yaz.
- `RAISE EXCEPTION` P0001 üretir; istemci **mesaj metniyle** sınıflandırır. Mesaj değiştirirsen `classifySessionError`'ı ve testleri de değiştir.
- Puan sabitleri üç yerde: `complete_study_session`, `get_points_config`, `league_info_sheet` yedeği. Birlikte değiştir.
- İstemcinin yeni bir `profiles` kolonuna yazması gerekiyorsa önce `GRANT UPDATE (kolon)`.

**Tuzaklar**
- `supabase db push` / `db reset` **çalıştırma**: geçmiş uyuşmadığı için eski dosyaları canlıya uygulamaya çalışır. Önce baseline (`supabase/README.md`).
- `run_local.sh` stub'ı canlıyı birebir modellemez; `audit_fixes_test.sql` artık `migrations/`'ta olmayan nesneleri test ediyor.
- `security_regression_test.js` canlıda gerçek hesap açıp siler. Kullanıcıya sormadan çalıştırma.

### 4.7 PLATFORM: derleme, yapılandırma
**Dosyalar:** `pubspec.yaml`, `android/app/build.gradle.kts`, `AndroidManifest.xml`, `ios/Runner/Info.plist`, `Runner.entitlements`, `project.pbxproj`, `l10n.yaml`

**Kurallar**
- `applicationId`, `namespace` ve iOS bundle id: `com.pomosprint.app`. Google, Apple ve Supabase ayarları buna bağlı. Activity: `kotlin/com/pomosprint/app/MainActivity.kt`.
- Kök `.env` APK/IPA'ya düz metin gömülür. Yalnızca `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`.
- Release AAB için `android/key.properties` + upload keystore (ikisi de gitignore'da). Yoksa `bundleRelease` hata verir; `assembleRelease` uyarıyla debug imzası kullanır.
- Android release öncesinde normal `flutter build apk --release` / `flutter build appbundle --release` akışını kullan. Debug/native test için oluşmuş plugin kaydından sonra `--no-pub` kullanmak release için dev eklentilerinin yeniden ayıklanmasını atlayabilir; bu gece temiz kopyada `IntegrationTestPlugin` Java hatası böyle oluştu. SDK veya ürün bağımlılığı yaması gerekmedi. Native çok aşamalı test çalıştırıcılarındaki `--no-pub --no-uninstall` ayrı amaçlıdır ve korunur.
- 28 Ekim yerel guard düzeltmesi (`b752933`): yalnız uygulamanın tam `bundle...Release` görevi anahtar gerektirir; bağımlı `bundleReleaseLocalLintAar` APK'yi yanlış engellemez. Gerçek APK dry-run geçti, anahtarsız AAB dry-run beklenen şekilde reddedildi. İzole yerel QA release APK54.167.363bayt/debugimzalı; mağaza imzalı paket veya indirme boyutu değildir. Kanıt `build/overnight_release_android/manifest.json`.

- iOS: min 15.0, UIScene yaşam döngüsü, SPM (Podfile yok), team `AQGX8BJMYJ`. Entitlements: Sign in with Apple, time-sensitive bildirim.
- iOS Canlı Etkinlik: `PomoSprintTimerWidget` uzantısı (iOS 16.2, `com.pomosprint.app.TimerWidget`, App Group yok), Runner'da `NSSupportsLiveActivities`, ActivityKit zayıf bağlı. "Embed Foundation Extensions" aşaması "Thin Binary"den önce kalmalı (yoksa "Cycle inside Runner"). Hedefi elle değil `tool/ios/add_live_activity_target.rb` ile düzelt.
- `ios/Runner/PrivacyInfo.xcprivacy`: izleme yok; toplanan veri türleri App Store Connect gizlilik etiketleriyle aynı tutulmalı.
- Android: `allowBackup=false` + `data_extraction_rules.xml`; bildirim receiver'ları manifest'te. Exact alarm: `USE_EXACT_ALARM` (13+) ve `SCHEDULE_EXACT_ALARM` (`maxSdkVersion=32`); Play Console'da exact alarm beyanı gerekir.
- Sentry: `enablePrintBreadcrumbs=false`, `sendDefaultPii=false`; error/breadcrumb/transaction sınırında derin ve sınırlı temizleme (§11.6). Yine de `debugPrint`'e kişisel veri yazma.
- Mağaza derlemesi yalnızca `scripts/build_release.sh` ile (`--obfuscate --split-debug-info`; Dart sembolleri, obfuscation haritası, R8 mapping Sentry'ye; README > Mağaza derlemesi). Sentry kimlikleri `scripts/.env`'de (`SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`); `pubspec.yaml`'daki `sentry:` bloğuna org/proje/token yazma.
- R8: ek `proguard-rules.pro` gerekmiyor. `sentry_flutter` kendi consumer kurallarını getiriyor (`io.sentry.**`), `flutter_local_notifications` 22.x modellerinde `@Keep` var ve GSON 2.12 kendi kurallarını taşıyor; bildirim ikonu `res/raw/keep.xml` ile korunuyor. Gerekirse `android/app/proguard-rules.pro` açın; Flutter Gradle eklentisi onu kendisi ekler, `build.gradle.kts`'e bağlamak gerekmez.
- Uygulama adı her yerde `PomoSprint`: `kAppDisplayName` (MaterialApp.title, Android son uygulamalar), `android:label`, `CFBundleDisplayName`. `test/platform_config_test.dart` denetler.
- İkon ve açılış ekranı üretilir, elle düzenlenmez: `dart run flutter_launcher_icons`, `dart run flutter_native_splash:create` (ayar `pubspec.yaml`). Monochrome (Android 13+ temalı ikon) `assets/icon/monochrome.png`: `foreground.png`'nin alfa kanalı, beyaz. Android 12+ splash simgesi `assets/icon/splash_android12.png` (daire maskesine sığacak kadar küçültülmüş logo). Açılış renkleri `AppColors.surface` / `darkSurface` ile aynı; tema rengi değişirse `platform_config_test` kırılır.

**Tuzaklar**
- `google_sign_in` 6.x'te; 7.x'e geçiş (Credential Manager) yapılmadı. Yapılacaklar: `GoogleSignIn.instance.initialize(serverClientId, clientId)` tek sefer; `signInSilently() ?? signIn()` yerine `attemptLightweightAuthentication()` ve `authenticate()`; `idToken` `account.authentication`'dan, `accessToken` yalnızca `authorizationClient.authorizationForScopes` ile (Supabase `signInWithIdToken` için idToken yeterli); `signOut`/`disconnect` yeni API; iOS'ta nonce (idToken'da nonce varsa Supabase aynısını ister) ve `GIDClientID` yeniden doğrulanmalı; Android'de Credential Manager için gerçek cihazda test. 7.x göçü bu QA kapsamına alınmadı; mevcut 6.x Android debug derlemesi geçti, gerçek Google sağlayıcı girişi doğrulanmadı.
- iOS'ta Supabase oturumu (refresh token) ve `saved_user` önbelleği SharedPreferences'ta, yani NSUserDefaults'ta; cihaz yedeğine girer. `flutter_secure_storage` + özel `LocalStorage` ertelendi: yeni native eklenti ve veri göçü henüz uygulanıp denenmedi; Keychain kilitliyken (ilk kilit açmadan önce arka plan açılışı) okuma hatası oturumu sessizce kapatır; Keychain kaydı uygulama silinince kalır. Göç yazılırken eski anahtar ancak yeni depoya yazma doğrulanınca silinmeli.
- Kullanılmayan lig kaynak tasarımları ve orijinal Stitch klasörü repo dışında `/Users/almano/Desktop/PomoSprint-Tasarim-Arsivi` içinde korunur; ürün `assets/avatars/` dosyalarını kullanır.
- `.claude/settings.local.json` ve `landing/.claude/settings.local.json` gitignore'da ama git'te izleniyor olabilir (`git rm --cached` kullanıcıda).

### 4.8 LANDING: pomosprint.app
§8'e bak. Özet: uç sayfa adlarını değiştirme, inline `<script>`/`style=""` yazma, ortak parçaları `_partials/` içinde düzenleyip `sync_partials.py` çalıştır, Supabase URL ve anon key yalnızca `js/config.js`'te.

## 5. İstemci ↔ sunucu sözleşmesi

### 5.1 RPC'ler (canlı)

| RPC | Parametreler | Döndürdüğü | Çağıran | anon |
|---|---|---|---|---|
| `complete_study_session` | `p_client_uuid uuid, p_category_id uuid, p_duration_minutes int (25\|50), p_was_paused bool, p_is_verified int (ön planda geçen sn), p_started_at timestamptz` | jsonb `{base_points, bonus_points, total_points, coins_earned, streak, bonus_pct, duplicate, daily_limit_reached}` veya `{error:'overlap'}` | `SessionQueue` | Hayır |
| `start_study_session` | `p_duration_minutes int, p_category_name text` | void (`profiles.active_session_*`) | Shell (sosyal görünürlük açıksa) | Hayır |
| `cancel_study_session` | — | void | Shell (duraklat, bitiş, sıfırla, çıkış) | Hayır |
| `get_league_config` | — | jsonb güvenli policy_version1, kapasite25, başlangıç/phase ve aktif/gün/dakika/puan eşikleri; saltokuma | Ranking/rehber/onboarding | Evet |
| `get_my_league_ranking_v2` | — | JSONB dizi: eski alanlar + has_league, active_member_count, phase/start, room_capacity, league_config, promotion/award/demotion_eligible; owner auth gerekir | Ranking | Hayır |
| `get_my_league_ranking` | — | `name, avatar_id, weekly_points, tier, end_date, is_me, promotion_zone_end, demotion_zone_start, member_count` (ligsiz satır `member_count` 0; `proposed/20`) | Yalnız eksik v2 için eski yedek | Hayır |
| `get_league_ranking` | `p_user_id uuid` (yalnızca kendi id'si) | Yukarıdakiyle aynı | Kullanılmıyor | Hayır |
| `get_league_zones` | `p_member_count int` (yeni politikada aktif üye sayısı) | quota floor(aktif/3), min3 terfi/min10 düşme; gerçek satır yeterliliği ayrıca v2'dedir | Kullanılmıyor (servis metodu var) | Evet |
| `get_points_config` | — | jsonb (puan sabitleri) | Lig bilgi sayfası | Evet |
| `get_public_monthly_leaderboard` | `p_limit int` (vars. 10, en çok 100) | `name, avatar_id, total_points, total_minutes, is_me`. Ay: çalışma ayı (`started_at`, profil dilimi, 04:00; `proposed/15`). `proposed/14` sonrası ayrıca `id`, `is_blocked`; oturumsuz en çok 10 satır, maskeli ad | Ranking Aylık (50), landing (10, anon) | Evet |
| `get_public_alltime_leaderboard` | `p_limit int` (vars. 50, en çok 100) | `name, avatar_id, total_minutes, lifetime_points, is_premium, is_me` | Kullanılmıyor | Evet |
| `get_my_friends` | — | `id, name, avatar_id, lifetime_points, total_minutes` | FriendsSheet, Ranking | Hayır |
| `get_incoming_friend_requests` | — | yukarıdaki + `created_at` (`id` = gönderen) | FriendsSheet | Hayır |
| `add_friend_by_code` | `p_code text` | jsonb | FriendsSheet | Hayır |
| `respond_friend_request` | `p_from_user_id uuid, p_accept bool` | jsonb | FriendsSheet | Hayır |
| `get_live_friends` | — | jsonb dizi `[{id, name, avatar_id, category_name, ends_at}]` | SocialScreen | Hayır |
| `get_live_friends_with_breaks` | — | jsonb dizi; eski alanlar + `status:focus\|break`, molada kategori null; yalnız görünür, engellenmemiş arkadaş | SocialScreen (eski RPC yedeği korunur) | Hayır |
| `start_study_break` | `p_ends_at timestamptz` | void; sahibin geçici mola durumu, en fazla5dk10sn | Shell (yalnız Maraton molası) | Hayır |
| `get_marathon_config` | — | `{available:true,break_seconds:300,presence_required:true,presence_seconds:60,presence_start_grace_seconds:10,bonuses}`; altı bonus §5.7 | Shell | Hayır |
| `complete_marathon_study_session` | normal altı seans parametresi + `p_marathon_uuid uuid,p_target_sessions int,p_session_index int` | normal ekonomik sonuç + Maraton bonus/ilerleme/geçersizlik ve ara odakta değişmez mola/onay son tarihleri | SessionQueue | Hayır |
| `start_marathon_break` | `p_marathon_uuid uuid,p_completed_session_index int,p_previous_client_uuid uuid` | mevcut kendi biletinin değişmez tarih/UUID/onay alanları; pencereyi açmaz/uzatmaz | Presence servisi | Hayır |
| `confirm_marathon_presence` | `p_marathon_uuid uuid,p_next_session_index int,p_next_client_uuid uuid` | `{confirmed:true,confirmed_at,next_client_uuid,break_ends_at,confirmation_deadline}` | Açık ön plan “Buradayım” dokunması | Hayır |
| `create_category` | `p_name, p_color_hex, p_icon_name` | yeni id | Kategori yönetimi | Hayır |
| `setup_onboarding_categories` | `p_categories jsonb` | jsonb `{created, restored, skipped_existing, skipped_limit, skipped_invalid, archived}` (`proposed/23`; öncesinde void). İstemci ikisini de kabul eder (`OnboardingCategoriesResult`) | Onboarding (önce `planOnboardingCategories`), `ensureServerCategories`, kuyruk | Hayır |
| `get_app_config` | — | jsonb (`proposed/13`, canlıda; anon da çağırır). Lig kuralları yalnız get_league_config eksik olduğunda eski sunucu yedeğidir; güncel politika ayrı güvenli RPC'dedir | Ranking, lig bilgi sayfası, Koleksiyon | Evet (13) |
| `purchase_avatar` | `p_avatar_id text` | int (yeni bakiye) | Koleksiyon | Hayır |
| `set_equipped_avatar` | `p_avatar_id text` | void | Koleksiyon | Hayır |
| `delete_own_account` | — | void | Profil | Hayır |
| `cleanup_unconfirmed_duplicate_identity` | `p_email text` | void. Canlı gövde `p_email`'i JWT'deki e-postayla karşılaştırır, değilse `not authorized` (5 Ekim'de okundu; `proposed/04` gereksiz) | Google/Apple girişi sonrası (kendi e-postası) | Hayır |
| `get_friends_feed` | `int` | — | Kullanılmıyor | Hayır |
| `process_weekly_leagues`, `ensure_user_in_league` | — | — | Yalnızca cron ve sunucu içi | Hayır |

İstemci `reorder_categories`'i çağırmaz (canlıda yok); sıralama satır başına paralel `update(sort_order)` ile yazılır (§4.2).

### 5.2 `complete_study_session` kuralları
- İlk kontrol idempotency: aynı `(user_id, client_uuid)` → `duplicate:true`; yanıtta **ilk kaydın** `base_points`, `bonus_points`, `total_points`'i döner, `coins_earned` 0. `bonus_pct` her zaman 0 ve `daily_limit_reached` her zaman `false` gelir (ilk kaydın değeri değil); duplicate yanıtında bu ikisine güvenme. İstemci duplicate'te kullanıcıya delta eklemez (`_onSessionAccepted`), diyalog yalnızca "zaten kaydedilmişti" der.
- Doğrulama sırası: süre 25/50 → `started_at` gelecekte değil (null da reddedilir) → 24 saatten eski değil → `started_at + süre <= now() + 5 dk` → kategori kullanıcıya ait → gerçek aralıkla çakışma (`{error:'overlap'}`).
- Puan: 25 dk = 5, 50 dk = 12. Duraklatma cezası `ceil(%20)` (25 dk → 4, 50 dk → 9). Seri bonusu 3/7/14 günde %10/%20/%30 (`ceil`). Kum: seans başına 20.
- Günlük tavan: aynı çalışma gününde 16 seans dolunca puan, kum ve lig puanı 0. `total_minutes` artmaya devam eder.
- Gün: `((started_at AT TIME ZONE profiles.timezone) - 4 saat)::date`. Daha eski güne ait geç gelen seans seriyi ve `last_study_date`'i geri almaz.
- Yeni lig guard'ı: ilk üyeliği olmayanın önceki resmi dönemde bitmiş seansı lifetime/puan/kumu korur; güncel odaya0ligpuanıyla yerleşir, `league_points:0`, `league_period_closed:true`. Tam sınırda tamamlanan seans yeni döneme sayılır. Yeni normal MD5 `72023f3f4d8636363cf0231f42d4c7e1`; formüller/validation/idempotency birebir korunur.
- `completed_at = started_at + süre`. `activity_feed` yalnızca `show_in_social_feed` açıksa yazılır.

### 5.3 Seans hata sözleşmesi (`classifySessionError` / `classifySessionResponse`)

| Sunucu yanıtı | İstemci davranışı |
|---|---|
| `duplicate:true` | Başarı; yanıttaki puan ilk kaydınkidir, kum 0. Delta eklenmez, puan/kum gösterilmez |
| `daily_limit_reached:true` | Başarı, 0 puan / 0 kum |
| `{error:'overlap'}` | Kuyrukta kalır; sunucu yaşı 24 saati geçince `overlap` ile reddedilir |
| `session_not_finished` | Ölçülen düzeltilmemiş fark eşiği aşıyorsa geçici, neden `clock_skew` ("cihazının saati farklı/ileri" metni YALNIZCA bu nedende). Fark ölçülemediyse geçici, neden `not_elapsed` ("süre sunucuyla henüz doğrulanamadı"). Aksi halde kalıcı `not_elapsed` ("sunucuya göre seans süresi henüz dolmamıştı") |
| `started_at cannot be in the future` | `future_start`, aynı saat farkı kuralı (kalıcı retteki metin saat suçlamaz) |
| `started_at is older than 24 hours` | Kalıcı (`too_old`). İstemci 48 saati geçen seansı göndermeden reddeder |
| `invalid duration…` | Kalıcı (`invalid_duration`) |
| `category does not belong…`, 22P02 uuid, 23503 kategori | `category_invalid`: bir kez isimle yeniden eşlenir, sonra kalıcı |
| `not authenticated`, 42501, PGRST301, `AuthException` | Çevrimdışı (`auth`); tur durur, seans kalır |
| Ağ hatası, 15 sn zaman aşımı | Çevrimdışı (`network` / `timeout`); tur durur |
| Diğer P0001 | Kalıcı (`server_rejected`) |

`session_not_elapsed` metni yalnızca uyumluluk için tanınır; canlıda yok. Saat farkı eşiği `ServerClock.significantSkew` = 60 sn.

### 5.4 İstemcinin doğrudan tablo erişimi

| Tablo | İstemcinin yapabildiği |
|---|---|
| `profiles` | Kendi satırını SELECT. UPDATE yalnızca 7 kolon (§7). INSERT yalnızca yedek akışta `(id, email, name, avatar_id)` |
| `categories` | Kendi satırlarında SELECT, UPDATE yalnız 5 kolonda (ad/renk/ikon/arşiv/sıra). DELETE politikası/yetkisi yok (`proposed/16`). Ad/renk/ikon ve tekil ad trigger'la denetlenir (`proposed/13`, `23`). İstemci silmez |
| `study_sessions` | Kendi satırlarında SELECT. Yazma yalnızca RPC ile |
| `avatars`, `avatar_unlocks` | SELECT |
| `friendships` | Yalnızca PGRST202 yedek yolunda SELECT (ölü kod) |

### 5.5 Kayıt metadata'sı (`auth.signUp` `data` → `auth.users.raw_user_meta_data`)

| Anahtar | Okuyan | Not |
|---|---|---|
| `name`, `avatar_id` | `handle_new_user` (`full_name` de okunur) | Ad 1..50 (CHECK); avatar yalnızca `is_default` |
| `newsletter` (bool) | `handle_newsletter_subscription` (e-posta onaylanınca `= 'true'` ise `marketing_subscribers`) | Mevcut sözleşme, korunur; `marketing_consent` ile aynı değer |
| `marketing_consent` (bool), `terms_version`, `privacy_version` (`kLegalDocumentsVersion`), `terms_accepted_at` (UTC ISO-8601) | Yalnızca kayıt (KVKK ispat) | 3 Ekim'de canlı `handle_new_user` okundu; ek anahtarlar onu etkilemiyor |

Üretici: `SupabaseService.signUpMetadata` + `RegistrationConsent.toMetadata` (`test/registration_consent_test.dart`).

Sosyal sağlayıcı girişinde `accept_legal_documents(p_terms_version, p_privacy_version)` iki parametreye de `kLegalDocumentsVersion` alır. Yanıt `{success:true, code:recorded|unchanged}`; kaynak metadata değil `consents` ledger'ıdır. Başarısız kayıt Shell'e geçirmez. Arkadaş yönetimi RPC parametreleri §4.4 / `proposed/README.md` Öneri 14; profil saat dilimi doğrudan kendi `profiles.timezone` kolonuna yazılır, `set_my_timezone` kullanılmaz.

### 5.6 Hesap silme: `delete-account` Edge Function (canlıda yok) → `delete_own_account` (canlı, 3 Ekim)
İstemci (`deleteUserAccount`) önce `functions.invoke('delete-account', {apple_authorization_code?})` çağırır: Apple token iptali (`APPLE_*` secret'ları), doğrulanmış e-postaya bağlı `waitlist` / `user_id`'siz abonelik satırları, `admin.deleteUser`. Yanıt `{deleted, apple: {status: revoked|skipped|not_applicable}}`; fonksiyon 404 döndürmez; istemci 404'ü ("deploy edilmemiş") ve 5xx'i (çalışamadı; gövdedeki `apple` durumu korunur) görünce aşağıdaki RPC'ye düşer, 401/4xx'te düşmez (`shouldFallBackToDeleteRpc`). Yanıt kaybolursa `GET /user` `user_not_found`/404 ise silinmiş sayılır. Boş POST geçerli; bozuk JSON/yanlış gövde veya Apple kodu türü `400 invalid_payload` verir. Doğrulanmış e-posta temizliği case/literal imatch ile yapılır; okuma/silme hatasında Auth silinmeden `500 delete_failed` + mevcut apple durumu döner ve RPC yedeği denenebilir. Ayrıntı: `supabase/functions/delete-account/README.md`.

`delete_own_account`:
`auth.users` satırını siler; `profiles`, `study_sessions`, `friendships` (iki yön), `marketing_subscribers.user_id` auth.users'a, `categories`, `league_memberships`, `activity_feed`, `avatar_unlocks` profiles'a `ON DELETE CASCADE`. `waitlist` (e-posta, FK yok) ve `user_id`'si boş abonelik satırı da (yalnızca doğrulanmış e-postada) silinir, `search_path`'te `pg_temp` var (`proposed/12`, canlıda; geri alma `proposed/12_delete_own_account_down.sql`).

### 5.7 Maraton — 8 Ekim 2026 canlı: ilerleme UI ve zorunlu mola onayı

- Durum makinesi `lib/models/marathon_progress.dart`: `focus → completing → breakTime → awaitingPresence → focus … → finished`. 2/3/4 hedef, sabit `marathonUuid`, tamamlanan sayı, mola bitişi (bundan türeyen onay son tarihi), sunucudan kazanılan bonus, kalıcı `stopRequested` ve `presenceClientUuid` aktif kayıt JSON’unda saklanır. Eski tek-seans kaydıyla uyumlu kalır; eski Maraton kaydı restore edildiğinde de yeni odak kendiliğinden başlamaz.
- Ana ekranda 25/50 üstünde en çok 280 dp genişlikte, 40 dp görünen dolgulu/kenarlıklı `marathon-entry-surface` vardır. `marathon-open-planner` ve sağındaki 18 dp dairesel `marathon-info` (**?**) aynı kutunun içindedir; dokunma alanları 48 dp kalır. Normal `timer-start-pause` tek seans başlatır. `lib/widgets/marathon_plan_dialog.dart` TR/EN “Kaç seans yapmak istiyorsunuz?” sorusuyla tek satır eş aralıklı 56 dp 2/3/4 daireleri ve ortak 25/50 süresini taslak olarak seçtirir; yalnız `MarathonPlanChoice` dönüşü ve yeniden sahip/ön plan/auth/sunucu/disk denetiminden sonra plan başlar. İptal, 3-2-1 geri dönüşü veya geç dönüş normal sayacı Maraton modunda bırakmaz. Başarılı başlangıç `marathon-started-message` bildirimi gösterir. Modal çift çağrı guard’ı alttaki rotayı kapatmaz. Aktif satır `marathon-active-progress` canlı ilerleme popup’ını açar; saat popup’ta da işler, dispose/sahip değişimi rotayı temizler. TR/EN kullanım kılavuzu altı dinamik sunucu bonusunu gösterir.
- `lib/widgets/marathon_progress_card.dart` yalnızca popup’larda gösterimdir: numaralı duraklar, dolan bağlantılar, tamamlanan durakta onay ve kısa kutlama; preview/focus/saving/break/check-in/finished/timed-out/unavailable durumları. Yalnız aynı plan kimliğinde sayı artınca 650 ms animasyon oynar; restore, plan/hesap değişimi, mola tick’i ve gizli sekme kutlamayı yeniden başlatmaz. `MediaQuery.disableAnimations` hareketi azaltır; ağır animasyon paketi yoktur. Ara duraklar birikmiş **odak dakikalarıdır**, molaları içermez. Kartın yüksekliğini ana sayaç hesabına katma; yatayda popup gövdesi kaydırılır, Başlat sabit görünür.
- Her odak kendi UUID’si, başlangıcı, duraklatma hakkı ve outbox kaydıyla normal 25/50 dk seansıdır. Mola ve onay dakikası çalışma/dakika/puan/kum değildir. Gönderimden önce `completing` diske yazılır; hata/null sonuçta aynı UUID tekrar denenir. Güvenli kuyruk kaydı önceki odağı korur; kalıcı ret veya `marathonInvalid` planı durdurur. Biten önceki seanslar ve normal puanları silinmez.
- Normal mola 300 sn, ardından sabit 60 sn “Buradayım” penceresi. Onay yalnız ön plandaki kullanıcı dokunmasıyla çağrılır; tick, restore, bildirim, sekme dönüşü veya uygulama açılışı odak başlatmaz. Son tarihte/sonrasında plan durur ve aktif plan taşıyıcısı temizlenir; tamamlanan kayıt/outbox kalır. Askıda geçirilen mola/onay geçmişe doğru yeni odak üretmez.
- **Zaman çıpası:** Başarılı `SessionSubmitSuccess` içindeki değişmez `marathon_break_ends_at` ve `marathon_confirmation_deadline`, saat farkı çıkarılarak cihaz zamanına çevrilir; mola sunucunun kabulünden başlayan bu pencereyle gösterilir. Duplicate özgün pencereyi döndürür. Henüz kabul edilmeyip kuyruğa alınmış odakta `endsAt + breakSeconds + 60` yerel pencere korunur; sonraki kuyruk senkronu bu pencereyi uzatmaz veya yeni mola başlatmaz. Önceki kayıt gecikirse devam onayı başarısız olabilir; otomatik ilerleme ve hayalî seans yapılmaz.
- Onay adayı UUID, RPC’den **önce** `presenceClientUuid` olarak aynı compare-and-update kilidinde diske yazılır. Timeout/yanıt kaybı/soğuk açılışta aynı aday tekrar kullanılır; yeni UUID ile sunucudaki onay değiştirilmez. Callback sonrasında ve başlangıç diske yazılırken sahip, auth, ön plan, stop isteği ve son tarih yeniden denetlenir. Geç ACK yeni seans başlatamaz. Yeni odak başlangıcı yalnız başarılı ACK sonrasındaki gerçek şimdiki zamandır; sunucu sonraki odağın düzeltilmiş başlangıcını onaydan en fazla 10 sn sonrasıyla sınırlar (alt sınır hassasiyet payı −2 sn).
- `TimerScreen.isSessionActive` kabuğun sahip/çıkış denetimini okur; `SupabaseService.isDeviceSessionEnding` native temizliğe başlamadan true olur. Dispose/sahip değişimi odak0+mola2 alarmını iptal eder. `TimerPersistence.saveChecked` / `compareAndUpdateMarathon` `canCommit` ile disk yazısı sırasında koşul kaybında önceki JSON’u geri alır; hiç başlamayan odak restore edilip tamamlanamaz. Onay verisi kullanıcıya bağlı mevcut aktif kayıt içinde olduğundan yeni bağımsız prefs anahtarı yoktur.
- `get_marathon_config()` → `{available:true, break_seconds:300, presence_required:true, presence_seconds:60, presence_start_grace_seconds:10, bonuses:{'25':{'2':2,'3':3,'4':5},'50':{'2':4,'3':6,'4':10}}}`. `supportsMarathonPresence` bu sözleşmeyi eksiksiz doğrular; RPC yoksa veya eski iki paket kurulup onay paketi eksikse yeni Maraton seçimi kapalıdır. Normal tek seans devam eder. Seçimdeki bonus sayıları gösterim içindir; gerçek kazanç yalnız RPC yanıtından okunur.
- `complete_marathon_study_session` normal altı parametreye `p_marathon_uuid uuid`, `p_target_sessions integer`, `p_session_index integer` ekler; imza onay paketiyle değişmez. Korunan `marathon_runs`/`marathon_run_sessions`, `marathon_presence_gates` ve sahip ayar tablosuna istemci doğrudan erişemez. Maraton paketi normal gövdeyi değiştirmedi; sonraki lig guard'ı §5.2'dedir. Önceki onay doğru/süresinde olduğunda devam odağı bonus için uygun kalır; onaysız/yanlış UUID’li/geç başlangıçlı ama geçerli çalışma normal RPC ile kaydolur, `marathon_presence_invalid:true`, `marathon_invalid:true`, bonus 0 döner ve plan kalıcı geçersiz olur. Sırasız outbox gelecekteki indeks için onay veya bonus üretmez.
- Her kabul edilen ara odak aynı transaction’da sunucu saatinden 300+60 sn değişmez bilet açar; yanıta mola bitişi/son tarih eklenir. `start_marathon_break(p_marathon_uuid uuid,p_completed_session_index integer,p_previous_client_uuid uuid)` yalnız mevcut kendi bileti okur; pencereyi yeniden başlatmaz. `confirm_marathon_presence(p_marathon_uuid uuid,p_next_session_index integer,p_next_client_uuid uuid)` tüm önceki indeksleri denetler, `[break_ends_at,confirmation_deadline)` içinde onayı sonraki UUID’ye bir kez bağlar. Başarı `{confirmed:true,confirmed_at,next_client_uuid,break_ends_at,confirmation_deadline}`; aynı UUID tekrarı özgün makbuzu döndürür. Eski özel ödül gövdesi bütün istemci rollerine kapalıdır.
- Onay hataları (P0001): `marathon_presence_too_early`, `marathon_presence_expired`, `marathon_presence_conflict`, `marathon_presence_missing_previous`, `marathon_presence_invalid_metadata`. Onay kuyruğa konmaz; bağlantı/timeout başarısızlığında pencere içindeki açık kullanıcı tekrarını bekler. Eski metadata hataları `invalid_marathon_metadata`, `marathon_metadata_conflict`, `marathon_index_conflict`, `marathon_session_reused` kalıcı `server_rejected` olarak ret geçmişine gider. Zamanında sunucu isteği fiziksel insan dikkatinin cihaz tasdiki değildir; resmi istemci ön plan/dokunmayı ayrıca denetler.
- Bonus değişmedi: **25 dk 2/3/4 → +2/+3/+5; 50 dk → +4/+6/+10**. Bütün odaklar ve onaylar geçerli, farklı, kronolojik, puan kazanmış olduğunda bir kez verilir; seri yüzdesiyle çarpılmaz, ek kum üretmez, günlük tavanı aşmaz. Son dolduran odağın `study_sessions.bonus_points`, profil ve uygun lig dönemi birlikte güncellenir. Kapanmış dönem bugünkü lige yazılmaz; carry normal RPC ile aynı tek üyeliğe gider. `total_points` bonusu içerir; `marathon_bonus_points` ayrı alan. Duplicate ekonomik değişim yapmaz.
- Sosyal sözleşmesi: `start_study_break(p_ends_at)` kendi profilinde en çok 5 dk 10 sn mola yazar. Odak başlat/iptal molayı temizler. `get_live_friends_with_breaks()` arkadaş/engelleme/görünürlük filtresiyle `status:focus|break` döndürür; eski `get_live_friends()` focus-only kalır. Sosyal tek birleşik listedir, filtre sekmeleri yoktur: normal ve Maraton odağı yalnız “Odaklanıyor”, sadece Maraton molası “Molada” gösterilir; sağda hafif animasyonlu kırmızı/yeşil nokta vardır (`SocialPresenceDot`). “Maraton yapıyor” etiketi yoktur. “Buradayım” beklenirken odak görünmez ve bitmiş mola uzatılmaz. Normal yenileme 30 sn, yerel QA 2 sn; push realtime değildir.
- Bildirim kimlikleri değişmedi: odak0, Android ongoing1, mola bitişi2. Mola bildirimi artık kullanıcıya onay için uygulamayı açmasını söyler; alarmın çalışması odak başlatmaz. Mola/onay sırasında Canlı Etkinlik temizlenir. Tercih kapatma, çıkış ve auth kaybı odak/mola bitiş alarmlarını temizler.
- Kısa kayıt QA yolları §37’de kaldırıldı. Sunucu 25/50 dk ve 300/60 sn kuralları sürer; `complete_qa_*` RPC’leri istemcide seçilmez. Geçmiş QA komutları ve eski simülatör UUID’leri güncel çalışma yolu değildir.
- Canlı sıra ve geri alma: [Maraton SQL rehberi](supabase/tests/20261007_marathon_README.md). **150000 mola → 160000 ödül → 170000 onay**, 8 Ekim'de kullanıcı talebiyle tek atomik transaction içinde uygulandı. Canlı başlangıç gövdeleri dört beklenen parmak iziyle eşleşti; her DRYRUN'da önceki bağımlılıklar aynı geri alınan transaction'a eklenip tüm155 madde true bulundu. Uygulamadan sonra96 geri alınan fonksiyon senaryosu +13 salt okuma yapılandırma/ACL kontrolü geçti. Üç migration kaydı kalıcı; o Maraton turunda normal `complete_study_session` md5 `f0f2b9bcc09ae8440a66d889b5f22fcc` (güncel lig guard'ı sonrası720…, §5.2), eski `get_live_friends` aynı, kısa kayıt RPC yok. Testlerin hesap/seans/lig/ekonomik verileri geri alındı. Canlı kanıtlar (ham çıktı §37 temizliğinde kaldırıldı). Yeniden ileri dosyaları çalıştırma; güncel katalog oku. Ters sıra700→600→500 aktif plan/outbox geçişi gerektirir ve bu tur çalıştırılmadı.
- Son popup/sade yatay takip: **1158 Flutter testi**, temiz analiz; 155 SQL DRYRUN +25 ek kontrol. iOS ilk altı puan planı, son iki uç plan/gerçek 60 sn timeout, manuel OS süreç sonlandırma ve yatay onay; Android cihaz kapsamı/sonuçları [son popup QA](analiz/QA_MARATON_POPUP_2026-10-07.md), [devir §20](PROJE_DEVIR.md#20-maraton-popup-puan-ve-güvenlik-takibi--7-ekim-2026) içindedir. Aşağıdaki önceki 73/20 ve §18 sonuçları tarihsel aşamadır. Flutter araçlarını aynı çalışma ağacında paralel başlatma; üretilen Swift package klasöründe silme çakışması oluşabilir.
- Önceki eşzamanlı takip: **1159 Flutter testi**,0 atlama;17 bariyer/10 odak/350 dk/92 puan/200 kum. Tarihsel kapsam [önceki beş hesap QA](analiz/QA_CONCURRENT_SOCIAL_2026-10-07.md) içindedir. Son r03: **1174 Flutter**,103 Node, temiz analiz; beş native iOS hesabı21 aşama/56 görüntü ve günlük/haftalık/aylık15 raporu geçti. Gerçek roller Maraton, normal odak, Sosyal, Sıralama ve native yatay duraklat/devam/iptaldir; sonra beşi Maraton yapar. Final14 UUID/550 dk/144 puan/280 kum,6 plan/18 bonus, DB43/43/API5/5. İptal UUID’si kayıt üretmez. Ayrı32 Auth hesabı/ilk seans kapasite denetimi15/15: onboarding ligsiz, ilk puanlı seansta yerleşme, odalar en fazla30, hesaplar arası seans okuması boş. `integration_test/r_concurrent_social_test.dart` tek binary +`tool/local_supabase/e2e/sim/concurrent_social_host.py`21 aşamalı beş slot protokolüdür; tek cihaz `run_sim_e2e.sh r` ile çalıştırma. [Son tekrar çalışma, kanıt ve sınırlar](analiz/QA_REQUESTED_UI_2026-10-07.md), koordinatör kaynakları (ham çıktı §37 temizliğinde kaldırıldı). Normal30 sn/yerel QA2 sn polling ve pull-to-refresh sıralama korunur; push eklenmedi.
- Son backend onay doğrulaması **73/73 DRYRUN +20/20 ek kontrol**: gerçek sunucu saati onayı, iki bağlantıyla UUID/final yarışı, tek bonus, ACL/hesap izolasyonu, 3 sn mola/5 sn odak gerçek QA akışı ve birebir şema/ACL down. Backend kanıtı (ham çıktı §37 temizliğinde kaldırıldı). Güncel UI/tam Flutter/cihaz sonuçları ve kapsam [yeni Maraton UI/onay QA](analiz/QA_MARATON_PRESENCE_2026-10-07.md) ile `PROJE_DEVIR.md §18` içindedir; önceki 1129/altı plan kayıtları [ilk Maraton QA](analiz/QA_MARATON_2026-10-07.md) tarihsel kapsamıdır.

## 6. Veri akışları

### 6.1 Seans yaşam döngüsü
1. **Başlat:** bildirim izni (bir kez) → 3-2-1 → `ActiveTimerSession.start` (`clientUuid`, `startedAt`, `endsAt`) diske yazılır → bitiş bildirimi zamanlanır → Shell `start_study_session` çağırır.
2. **Tick:** `kalan = endsAt - now`; ön planda geçen saniye sayılır (`p_is_verified`).
3. **Duraklat:** bildirim iptal, `cancel_study_session`, seans `pausedRemainingSeconds` ile diske. `clientUuid`/`startedAt` korunur.
4. **Uygulama öldürülürse:** açılışta kayıt yüklenir; süre dolduysa doğrudan 5. adıma geçilir.
5. **Bitiş:** `cancel_study_session` → `submitCompletedSession()` → seans `pending_sessions_uid_<uid>`'e yazılır (cihaz saat farkı `clockOffsetMs` ile).
6. **Gönderim:** kuyruğun tamamı `started_at` sırasıyla, `AsyncLock` ile tek tur. `started_at`'e saat farkı düzeltmesi eklenir.
7. **Sonuç:** Başarı → `currentUser` güncellenir, seans kuyruktan silinir, `statsChanged`. Kalıcı ret → reddedilenler listesi + tek seferlik bildirim. Geçici → kuyrukta kalır, banner.

### 6.2 Çevrimdışı kuyruk
- **Tetikleyiciler:** Shell açılışı, bağlı görünen her bağlantı olayı, ön plana dönüş, artan aralıklı zamanlayıcı (30 sn → 15 dk; bulut başlatılamadıysa da kurulur), banner'a dokunma, yeni seans.
- **Yer tutucu kategori:** isimle buluttaki kategoriye eşlenir (yoksa ilk aktif kategoriye); bulutta hiç kategori yoksa kullanıcının segmentine ve diline göre varsayılanlar oluşturulur.
- **Kimliksiz önbellek:** uid bilinmiyorsa `pending_sessions_<email>`'e yazılır, uid öğrenilince taşınır.
- Çıkışta kuyruk uid'e bağlı kalır, başka hesaba gönderilmez. Hesap silinince temizlenir.

### 6.3 Giriş ve onboarding
1. **Splash:** `restoreCachedUser` + kategori önbelleği + avatar kataloğu (ağsız) → `SupabaseService.ensureCloud` (5 sn; bitmezse ya da hata verirse kabuk ve giriş yeniden dener) → oturum varsa `fetchCurrentUserModel` + kategoriler → `AppGate`.
2. **Login:** e-posta `signInWithPassword`; Google/Apple native idToken → `signInWithIdToken` → `cleanup_unconfirmed_duplicate_identity`.
3. **Profil:** `handle_new_user` trigger'ı (varsayılan avatar, `friend_code`).
4. **Onboarding:** `completeOnboarding` → mevcut kategorilerle uzlaştırma (arşivle / arşivden aç) → `setup_onboarding_categories` (yalnızca eksikler) → `profiles.update(birth_year, user_segment, daily_goal_minutes, show_in_social_feed, onboarding_completed_at)` → `currentUser` güncellenir → AppGate Shell'e geçer.
5. **Çıkış / oturum düşmesi:** `signOutFully` ya da `signedOut` olayı → `currentUser = null` → AppGate Login gösterir.

<a id="64-lig-döngüsü--güncel-8-ekim-paketi"></a>

### 6.4 Lig döngüsü — eski canlı 8 Ekim paketi

**Bu bölüm canlıda son doğrulanmış eski sözleşmedir. Yeni aylık geçişin §11/`proposed/29` kuralları bunun yerine yerelde hazırlanmıştır; canlı kurulum tamamlanmadan burada anlatılan sistemin değiştiğini iddia etme.**
1. İlk puan kazandıran tamamlanmış seans üyelik açar. Kullanıcı kendi kademesindeki, aynı döneme ait uygun mevcut odanın boşluğuna yerleşir: en dolu oda → en eski başlangıç → UUID. `app_config.league_room_capacity=25` (sunucu3–30 aralığına sınırlar); boşluk yoksa yeni oda açılır. Onboarding ve sıfır puanlı ilk seans üyelik açmaz.
2. Global `league_competition_state`: **preparing → scheduled → active**. Son336 saatte kabul edilmiş25/50 dk seansı olan25 farklı kullanıcı, sonraki tam14 günlük dönemi planlar. Günlük puan tavanındaki geçerli seans aktifliğe girer. Config salt okunur; başlangıcı INSERT trigger veya bakım planlar. Takvim çıpası12 Ekim2026 00:00 Europe/Istanbul, aralık sabit336 saat; SQL oturumunun saat dilimi ve DST bağımsızdır.
3. Hazırlıkta puan, rapor ve sıralama işler; terfi/düşme/lig avatarı verilmez. Mevcut kademe, lifetime puan, kum, dakika, seri, avatar ve geçmiş korunur. Hazırlıkta carry dahil görünür; hazırlık puanları resmi döneme taşınmaz. Yeni yarış puanı, kabul edilmiş seansın completed_at `[start,end)` aralığı ve base+bonus toplamıdır. Maraton ek puanı bir kez sayılır. Gecikmiş cron öncesinde de v2 bu gerçek toplamı gösterir.
4. Sıra: puan DESC, joined_at ASC, user_id. Aktif üye bu dönemde kabul edilmiş seansı olan kişidir; toplam oda mevcudu değildir. En az 3 aktif üyede terfi kontenjanı `floor(aktif/3)` (3→1,10→3,25→8,30→10). Ham sıra kontenjan içinde olmalı; ayrıca en az1 puan, profil IANA saat diliminde04:00 sınırıyla3 farklı çalışma günü ve300 dakika gerekir. Elmas üstüne çıkılmaz. Yetersiz üst sıranın yerine sıradaki kişi otomatik alınmaz.
5. Avatar için en az 10 aktif üye, ham ilk3 ve aynı gün/dakika/puan yeterliliği gerekir. `league_award_avatar_id` eski kademe üzerinden birincilik/podyum avatarını açar; otomatik kuşanılmaz. Legacy `_monthly/_weekly` varlık adları değişmez. Düşme için en az 10 aktif üye ve son `floor(aktif/3)` sıra değerlendirilir. Bitişe72 saatten kısa süre kala katılanlar korunur; Bronz düşmez.
6. Cron `weekly_leagues_job` `'1 21 * * 0'` (Pazartesi00:01 TR) değişmedi. Bakım global dönem geçişinde tek eski snapshot üzerinden karar verir; aynı kişiyi iki kez işleyemez. Aynı kademe odaları25 üst sınırıyla yeniden doldurulur; yeni dönemin puanları/carry korunur. Aktif dönem ortasında repack yapılmaz; tekrarlı cron ödül/puan üretmez. Kilit sırası: sıralı profiller → kademe advisory → state. Accepted INSERT trigger yalnız state günceller.
7. V2 eligibility bayrakları otoritatiftir; istemci sıradan/puandan terfi veya ödül tahmin etmez. Eski TABLE RPC imzaları yedek uyumluluk içindir. RLS/API erişimine kapalı state ve private `_league_*` helper §7'de. Down resmi başlangıç geçmeden eski config/oda eşlemesini geri getirir, arada kazanılmış seans/ekonomiyi korur; sonrasında bilinçli durur ve telafi gerekir.

Kanıt: [Lig QA](analiz/QA_LEAGUE_LAUNCH_2026-10-08.md), [SQL rehberi](supabase/tests/20261008_league_launch_policy_README.md). İzole denetim: `python3 tool/local_supabase/e2e/league_launch_independent.py --cron`; yalnız review DB içinde fixture/sentetik takvim kullanır. Eski/yeni kaynak parmak iziyle tanınır; eski baseline yalnız inceleme kopyasında kurulur, ana yerel/canlıya rollback veya fixture yazılmaz. Son89/89 tekrarın job/DB temizliği kayıtlıdır. `weekly_points` kolon adı korunur, dönem14 gündür; farklı bir gün/hafta kuralı yaratma.

## 7. Güvenlik modeli

### 7.1 Tablolar (canlı, `live_audit_fixes` sonrası)

| Tablo | anon | authenticated okuma | authenticated yazma | Not |
|---|---|---|---|---|
| `profiles` | Yok | RLS: kendi satırı (tablo düzeyinde SELECT) | INSERT `(id, email, name, avatar_id)` + `sanitize_profile_insert`. UPDATE yalnızca `name, show_in_social_feed, user_segment, daily_goal_minutes, birth_year, onboarding_completed_at, timezone`. DELETE yok | `coins, lifetime_points, is_premium, league_tier`, seri yalnızca RPC ile. CHECK: ad 1-50, hedef 5-1440, doğum yılı 1900-2100, `timezone` `pg_timezone_names`'te |
| `study_sessions` | Yok | SELECT (RLS) | Yok | Yalnızca `complete_study_session` yazar |
| `marathon_runs`, `marathon_run_sessions`, `marathon_presence_gates`, `marathon_presence_settings` | Yok | Yok | Yok | Dördünde RLS açık; plan/indeks/bilet/ayar yalnız güvenli RPC veya sahip tarafından. Gate/settings service_role'a da kapalı; özel onay öncesi RPC anon/authenticated/service_role'a kapalı |
| `league_competition_state` | Yok | Yok | Yok | RLS açık, API rollerine tablo yetkisi yok. `_league_*` helper PUBLIC/anon/authenticated/service_role EXECUTE kapalı; yalnız server içi |
| `categories` | Yok | Kendi satırları | RLS + limit trigger (ekleme ve arşivden çıkarma) | Silinmez, arşivlenir |
| `friendships`, `leagues`, `league_memberships`, `activity_feed`, `avatar_unlocks` | Yok | SELECT (RLS) | Yok | Yazma yalnızca RPC, trigger veya cron |
| `avatars` | SELECT | SELECT | Yok | Katalog |
| `marketing_subscribers` | Yok | Kendi satırı | INSERT/UPDATE yok | Satırı `handle_newsletter_subscription` trigger'ı ekler. `unsubscribe_token uuid`, `welcome_sent_at` |
| `waitlist` | INSERT (landing) | — | — | RLS migration'da yok; canlıda doğrula |

### 7.2 Anon'a açık olanlar
- RPC: `get_public_monthly_leaderboard`, `get_public_alltime_leaderboard`, `get_points_config`, `get_league_zones`, `league_award_avatar_id`, `get_league_config` (yalnız güvenli genel politika; owner ranking v2 anon kapalı).
- Tablo: `avatars` SELECT, `waitlist` INSERT.
- Edge Function: `unsubscribe` ve `send-welcome-email` JWT'siz çalışacak şekilde yazıldı; ikisi de isteği DB'den doğrular.
- Herkese açık sıralamalarda oturumsuz çağrı adı `Ad S.` biçiminde maskeler (`mask_public_name`). Oturum açıkken tam ad döner. `show_in_social_feed = false` olan kimse listelenmez.

### 7.3 Sırlar
- Kök `.env`: yalnızca public değerler (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SENTRY_DSN`).
- `scripts/.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (son ikisi sır değil, e-posta altbilgisindeki hizmet sağlayıcı kimliği; boşsa bülten gönderilmez); mağaza derlemesi için `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN`. İçeriğini okuma, hiçbir yere kopyalama.
- Edge secret: `RESEND_API_KEY`, `MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` (`send-welcome-email`; kimlik eksikse e-posta gönderilmez). Abonelikten çıkma token'ı UUID olduğu için ek secret yok. `delete-account` için `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`, `APPLE_PRIVATE_KEY` (.p8 PEM); yoksa Apple iptali atlanır.

## 8. Landing sitesi ve deploy

**Eski canlı site / §30 (8 Ekim):** Worker `840fd4f1-0779-493a-ad5b-e41fcd27a3c3`,83 public varlık. Beş mevcut `league_{bronze,silver,gold,sapphire,diamond}_monthly.webp` kupa avatarı eşit72° yörüngededir; dekoratif `.ot-d1/.ot-d2` kaldırıldı. `.ot-cycle/.orbit-dot` Pomodoro Nedir illüstrasyonunda kullanıldığı için korunur. Reduced-motion’da avatarlar sabit/dik kalır. SSS11 görünür/schema eşleşir, alt iletişim CTA'sı korunur; TR/EN Destek yasal listesinde dört link dışında açıklama yok. CSS cache `20261008e` tüm18 HTML'de (üç auth yardımcı dahil), ana JS/MP4 `20261008d`; telefon oranı ve video davranışı aynı. Son kontrol ve kanıt [site QA](analiz/QA_SITE_CLEANUP_2026-10-08.md) içindedir.

**Önceki lig açıklaması / §29:** Worker `6bdb8f56-a8c5-4973-8b18-74344edee7f4`; yalnız index/features/FAQ lig metinleri25/hazırlık/yeterlilikle güncellendi (3yükleme,80mevcut). Medya/CSS/JS/Worker davranışı §28'deki gibi korunur. Site statik metni kapasite30 olursa ayrıca güncelle. Yeni doğrulama ligQA'dedir; aşağıdaki52HTTP önceki medya turunun kanıtıdır.

**Yapı**
- Statik site, build yok. `_partials/` tek kaynak → `python3 landing/tools/sync_partials.py`. `en/` İngilizce ana sayfa/özellikler/SSS ile yasal ve destek sayfalarını içerir. Yeni yerel içerik ve testler için `landing/README.md`; canlı yayın kaydı yukarıda tarihlidir.
- Yazı tipleri (`fonts/`, `css/fonts.css`) ve GSAP (`vendor/gsap-3.13.0/`, jsDelivr'deki dosyayla birebir, SRI aynı) kendi alan adımızdan sunulur; dış CDN yok (KVKK-19).
- `js/config.js` Supabase URL ve anon key'in tek yeri. Site supabase-js yüklemez, düz `fetch` kullanır: `POST /rest/v1/waitlist`, `rpc/get_public_monthly_competition` (p_limit 10, yeni yerel sözleşme; eksikse hazırlık görünümü), `functions/v1/unsubscribe`.
- `worker.js` (`run_worker_first`): http → https ve `www` → apex 301 (yol ve sorgu korunur). GET tek byte Range yalnız dört MP 4 yolunda: `videos/{timer,marathon}-20261008.mp4` ve `videos/{timer,marathon}-demo-20261008d.mp4`. 206/416 yanıtında ASSETS güvenlik/cache/ETag başlıkları korunur. Okuma 256 KiB (262144 bayt) ile sınırlı; sınır aşılırsa iptal/normal streaming fallback. Normal GET/HEAD, 304/404 ve diğer varlıklar aynen geçer. Yeni video sürümünde allowlist + gerçek dosya Range regresyonlarını birlikte güncelle (`scripts/test/landing_worker_range.test.mjs`); bu görevde sınır büyütülmedi. Güncel Node 133/133 ve canlı 17 istekte 52/52 odaklı HTTP; önceki 21/21 yerel/59/59 canlı sonuçlar tarihsel kanıttır.
- `wrangler.jsonc`: `html_handling: auto-trailing-slash` (`.html` → uzantısız adrese 307), `not_found_handling: 404-page`, `pomosprint.app` ve `www` custom domain route'ları.
- `.assetsignore`'da olmayan **her dosya herkese açık yayınlanır** (`_partials`, `tools`, `*.md`, `worker.js`, `wrangler.jsonc` hariç tutulur; `_headers` Workers tarafından okunur).
- **Güncel site medyası / §28:** Ana sayfa ve Features düzeni korunur; Features yedi dönüşümlü ekran + altı destek kartıdır. Video dosyaları `videos/{timer,marathon}-demo-20261008d.mp4` + aynı adlı WebP poster (540×1170, 24 fps H.264/yuv420p/sessiz/faststart). 3 HTML video alanı (Features 2 + Home Maraton 1) `data-demo-video`, lazy `data-src`, `autoplay muted loop playsinline preload="none"`, native controls olmadan tanımlanır. JS URL'yi yalnız görünürken `src`e taşır, ekran/sekme dışında durdurur ve dönüşte sürdürür. Video `role="button" tabindex="0"`: tıklama/Space/Enter duraklat/devam; manuel duraklatma görünürlük dönüşünde ezilmez. Canlı reduced-motion değişikliği durdurur; CSS+JS reduced-motion, yükleme/autoplay reddi veya JS yokluğunda gerçek poster `<img>` kalır. Bekleyen play Promise yarışları son görünürlük/istek revizyonuyla korunur. Ekran oranını paddingli `.phone` üzerine koyma; `.phone-screen` 540/1170 ve doğal yükseklik kullanır. Native simctl kaydı OS imlecini içermez: gerçek dokunma zamanlarına hizalı editorial imleç/dokunma halkası compositing'dir; ürün UI'si üretilmedi. İmleç zamanlaması için CFR normalize/sabit kare sayısı kontrolünü koru. Kişisel canlı hesap verisi veya sırlar medyada/public varlıklarda bulunmaz. Güncel ayrıntı [QA_SITE_AUTOPLAY](analiz/QA_SITE_AUTOPLAY_2026-10-08.md).
- **Önceki 8 Ekim medya yayını / §26 (tarihsel):** Cloudflare sürümü `2e2d842b-2b03-4779-94d8-e9ff5a71c8c5`, apex + www, 79 varlık (19 yeni/değişmiş, 60 aynı). Önceki içerik `8e30ae76` ve Range `3aefb719` tarihsel dağıtımlardır. Bağımsız canlı HTTP **59/59**: aynı 57 baseline +2 yeni CSS/main hash kontrolü; home/features/FAQ/reset ve 11 medya SHA-256 eşleşmesi, 22 Range/If-Range/HEAD/304, helper no-store/CSP, sorgu koruyan yönlendirmeler, 14 özel/eski yol 404. Son HTTP (ham çıktı §37 temizliğinde kaldırıldı).
- **Önceki §26 statik preflight (tarihsel):** 18 HTML, 739 iç referans /65 hedef +16 CSS varlık referansı, 30 SRI, 44 geçerli ARIA ID bağlantısı, 58 img /3 video /79 public /private 0; FAQ 12/12. Son audit (ham çıktı §37 temizliğinde kaldırıldı), değişmeyen Worker yerel HTTP 21/21 (ham çıktı §37 temizliğinde kaldırıldı).
- **Önceki §26 Safari kapsamı (tarihsel):** `2e2d842b` canlı masaüstü Maraton sol metin/sağ video; canlı Özellikler 390×844 tek sütun Maraton metni ve kaydırılan poster/açıklama yatay taşmadan doğrulandı. Yeni ana sayfa Maraton kaydı 14/21 sn ilerleyip arka planda durakladı. Canlı HOME 390×844 Maraton başlık/metin/3 madde/CTA tek sütuna sığıyor, poster altında başlıyor. Yerel masaüstü Günlük/Aylık ters yön→Sosyal normal yön akışı düzgün. Önceki `3aefb719` canlı kanıtı ayrı: Maraton 21 sn /Pomo 23 sn tam oynatma, Maraton 21→10 sn timeline seek ve yeniden Play ile 11 sn ilerleme/Pause düğmesi; HOME 390×844 galeri ile 320×740 poster yerleşimi. Root kendi ayrı Safari penceresini kullandı. Üç Maraton SQL paketi ayrıca canlıda (§5.7); site yayını mağaza yayını değildir.

**Deploy**
```sh
python3 landing/tools/sync_partials.py --check
cd landing && wrangler deploy          # wrangler bu makinede oturum açık (yoksa npx wrangler)
curl -sI https://pomosprint.app/ | grep -i content-security-policy
curl -sI https://pomosprint.app/reset-password | grep -i cache-control   # no-store
```
- CSS/JS değişince `?v=` değerini `_partials/head.html`, `_partials/scripts.html` ve yardımcı sayfalarda artır (1 saat önbellek).

**`_headers`**
- CSP: inline `<script>`/`style=""` yok (JSON-LD hariç). `script-src` yalnızca `'self'` + Cloudflare Web Analytics; `style-src` ve `font-src` yalnızca `'self'`. `connect-src` Supabase + Cloudflare Insights. Yeni dış kaynak → önce CSP'ye ve gizlilik metinlerindeki sağlayıcı listesine ekle.
- Token taşıyan sayfalar (`/reset-password`, `/confirmed`, `/unsubscribe`): `no-store`, `noindex`, `no-referrer`.
- `screenshots/` bir saat, sürümlü `videos/` bir gün önbelleğe alınır; görseller/video kendi alan adında, `img-src` / `media-src 'self'`. Yeni kayıt için MP4 ve poster sürümünü birlikte değiştir.

**Dokunulmaz URL'ler:** `/privacy`, `/terms`, `/kvkk`, `/hesap-silme`, `/destek` ve `/en/` karşılıkları (`/en/delete-account`, `/en/support`), `/reset-password`, `/confirmed`, `/unsubscribe`. Uygulama sürümleri, mağaza kayıtları, Auth redirect allowlist'i ve gönderilmiş e-postalar bunlara bağlı.

**Yardımcı sayfa sözleşmeleri**
- `reset-password`: `#access_token=…&type=recovery` (implicit) ya da `?token_hash=…&type=recovery` (form gönderilince doğrulanır). `?code=` eski sürüm mesajı verir. 7 Ekim geçici verify hatasında yeniden deneme düzeltmesi 8 Ekim site yayınıyla canlıda; script `20261007b`, canlı SHA-256 `d3d3b2a7c8688cfd65c4b1ce486d5cb7358ca565264cfb969aa58e72d51af05a` yerelle aynı. Node 120/120; HTTP kanıtı (ham çıktı §37 temizliğinde kaldırıldı).
- `confirmed`: onay dönüşü; parametresiz açılınca "onaylandı" demez; uygulamayı açma deep link'i yok.
- `unsubscribe`: `?token=<uuid>` (yeni e-postalar; e-posta adresi URL'de yok). Eski `?email=…&token=<uuid>` bağlantıları da çalışır: sayfa adresi adres çubuğundan siler, istekte yalnızca gövdeye koyar. Sayfa açılınca bir şey silmez, butonla POST atar.
- Bekleme listesi formu: ayrı, önceden işaretsiz ticari ileti onay kutusu (`#notify-consent`); işaretlenmeden kayıt yok. Güncel kaynak `{email, marketing_consent: true, consent_text_version: "waitlist-2026-10-03"}` gönderir; `consented_at` sunucuda belirlenir. `waitlist` onay kolonları ve `unsubscribe_token` mevcut (`proposed/19` A, canlıda). İstemci gövdesi 8 Ekim site yayınıyla canlıda; `proposed/19` B (yalnızca onaylı kayıt) güncel canlı tanımlar üzerinden SQL Editor akışıyla ayrıca değerlendirilir; eski NULL onaylı kayıtlar izinli sayılmaz.

**E-posta**
- Email Routing: `destek@pomosprint.app` → kullanıcının Gmail'i. MX, SPF, DKIM var.
- `send-welcome-email`: `marketing_subscribers` INSERT trigger'ı `net.http_post` ile çağırır. Resend, gönderici `noreply@mail.pomosprint.app`. Satır son 1 saatte eklenmiş ve `welcome_sent_at` boş olmalı. Altbilgide hizmet sağlayıcı kimliği (`MAIL_SENDER_*` secret'ları), destek adresi, Gizlilik ve KVKK bağlantıları; abonelikten çıkma bağlantıları yalnızca `?token=`.
- `unsubscribe`: yalnızca POST siler (GET 405), token yok/biçimsiz 400, e-posta-token uyuşmazlığı 403, bilinmeyen token 200. Aboneyi `waitlist`'ten de çıkarır. Deploy: `supabase functions deploy unsubscribe --no-verify-jwt`.
- Bülten: `node scripts/send_newsletter.js --dry-run`, sonra gerçek gönderim. `List-Unsubscribe` + tek tık başlıkları üretir; bağlantılar yalnızca token taşır. Şablonda `{{unsubscribe_url}}`, `{{sender_name}}`, `{{sender_address}}` zorunlu.

**8 Ekim tarihsel içerik tutarlılığı (yeni metinler için §11):** tek odak 25/50 dk; yeni Maraton 2/3/4 odak, arada 5 dk mola ve 60 sn devam onayı (§5.7). Üç Maraton sunucu paketi canlıda doğrulandıktan sonra güncel site kaynağındaki önizleme/kapalı ibareleri kaldırıldı; özellik gerçek simülatör ekranlarıyla tanıtılır. Bu, uygulamanın mağazada yayınlandığı iddiası değildir. Sosyal tek listedir: Odaklanıyor; yalnız Maraton molasında Molada. Haftalık rapor Pazartesi–Pazar; lig en fazla 30 kişi / 5 kademe / 14 gün (yeni odanın ilk dönemi 7–14 gün), ilk puanlı seansta odaya yerleşme. Normal taban puan 5/12, seri %10/%20/%30, günde en fazla 16 puanlı seans; dil cihazdan (TR ise TR, diğerleri EN). Premium'un yakın tarihte satışa açılacağına dair vaat yok; yasal metinler ve ertelenen geliştirici kimliği bu görsel turda değiştirilmez. SSS JSON-LD cevapları görünür 12 cevabı birebir izler; sitemap home/features/faq 2026-10-08.

## 9. Yapma listesi

| Yapma | Yerine |
|---|---|
| İstemcide puan, kum, seri veya lig hesaplamak | RPC sonucunu göster; sabitleri `get_points_config`'ten oku |
| "Ben" satırını isimle bulmak | `is_me` |
| Repodaki eski migration'dan `CREATE OR REPLACE` | Canlı `pg_get_functiondef` (§2.4) |
| `supabase db push` / `db reset`; MCP ile yıkıcı SQL | DRYRUN → migration dosyası; kullanıcı SQL Editor'de çalıştırır |
| `proposed/` dosyasını olduğu gibi çalıştırmak | Canlı gövdeye uyarlayıp yeni migration yaz |
| Kök `.env`'e veya `landing/`'e service role / Resend anahtarı | Yalnızca `scripts/.env` ve Edge secrets |
| Sayacı debug/define ile kısaltmak, canlı süre doğrulamasını gevşetmek | Normal 25/50 dk; kısa widget simülasyonu kalıcı kayıt göndermez |
| Yer tutucu kategori id'sini (`'1'..'5'`) RPC'ye göndermek | `isUuidCategoryId` + isimle eşleme |
| Yeniden denemede yeni `client_uuid` | Kuyruktaki kimliği koru |
| Seansı sessizce silmek; hata sınıfını testsiz değiştirmek | Reddedilenler listesi + test güncellemesi |
| Ekrandan doğrudan `Supabase.instance.client.from(...)` | `SupabaseService`'e metod ekle |
| Ekranda `UserModel` kopyası tutmak | `currentUser`'ı dinle, değişikliği servise yaz |
| Başka kullanıcının `profiles` satırını okumak | SECURITY DEFINER RPC |
| `GRANT` eklemeden yeni `profiles` kolonuna yazmak | Kolon bazlı `GRANT UPDATE` |
| Global Realtime kanalı (`ranking_updates`) | `addStatsChangedListener` |
| `Duration(days:)` ile gün atlamak; yeni gün kuralı | `DateTime(y, m, d + n)`, `study_day.dart` |
| `app_localizations*.dart`'ı elle düzenlemek; yeni `translate` anahtarı | ARB → `flutter gen-l10n` |
| Yönlendirmeyi ekranda yapmak; `Supabase.initialize`'ı ikinci kez çağırmak | `AppGate`; Splash'teki tek çağrı |
| `debugPrint`'e e-posta veya kişisel veri | Kimliksiz log |
| Landing'de inline script/style, uç sayfa yeniden adlandırma | CSP'ye uy, URL'leri koru |
| Silinmiş ekranları (`onboarding_screen`, `categories_screen`) geri getirmek | `PostAuthOnboardingScreen`, `CategoriesManagementScreen` |

## 10. Bilinen açık konular (7 Ekim 2026; geçmiş ayrıntılar tarihli QA raporlarında)

| Öncelik | Konu | Not |
|---|---|---|
| P0 | Migration geçmişi canlıyla uyumsuz, baseline yok | `supabase/README.md` → Baseline (`db dump` + `migration repair`). O zamana kadar CLI push yasak |
| P1 | Hoş geldin / bülten gönderen kimliği bekliyor | 7 Ekim canlı welcome v9; MAIL_SENDER_NAME / MAIL_SENDER_ADDRESS yok, welcome 500 ile gönderimden önce durur. Kimlik kullanıcı tarafından en son verilecek. Repoda yanlış e-posta sahiplenmesi/ağ hatası/10 sn timeout/Resend idempotency düzeltildi (15/15); patched kaynak artık canlıdan farklı, kimlik tamamlanınca deploy gerekir. Bülten gönderilmedi. Auth kayıt/reset ayrı SMTP akışıdır |
| P1 | Veri sorumlusu kimliği sitede yer tutucu (KVKK-15) | `/privacy`, `/kvkk` (iki dil) §1'de `data-fill-in` işaretli; kullanıcı gerçek bilgiyle doldurur (`grep -rn 'data-fill-in' landing/`) |
| Bilgi | Resend ve yerel Auth akışı doğrulandı | Önceki 7 Ekim Safari: domain/SPF/DKIM Verified, 1 geçmiş Delivered, bounce/şikâyet 0. Son reset turunda SMTP paneli yeniden okundu: custom açık, smtp.resend.com:587, resend, noreply@mail.pomosprint.app/PomoSprint, aralık60sn; parola açılmadı/ayar değiştirilmedi. Yerel Mailpit9/9 tekrar geçti. Kullanıcı resetin düzeldiğini doğruladı; alıcı yanıtı/ek mail testi beklenmiyor, yeni teslim metrikleri bağımsız okunmadı. Son kapsam [reset QA](analiz/QA_PASSWORD_RESET_2026-10-07.md); geçmiş backend/email/summary.json güncel gönderim kanıtı değildir |
| Tamamlandı | Reset web düzeltmesi canlıda (8 Ekim) | İlk reset/Range yayını `3aefb719-f008-4c44-b6a7-31319c7e7963`, nihai site sürümü `2e2d842b-2b03-4779-94d8-e9ff5a71c8c5`; reset cache `20261007b`, canlı JS SHA-256 `d3d3b2a7c8688cfd65c4b1ce486d5cb7358ca565264cfb969aa58e72d51af05a` yerelle aynı. Verify 5xx / bilinmeyen 429 / bozuk yanıt formu korur; kalıcı token hataları kapanır, alt sınır 8. Node120/120; nihai HTTP59/59. Yeni inbox/parola değişikliği testi değildir. Eski7Ekimdeploy-bekliyor notları tarihseldir (§8) |
| P1 | `delete-account` Edge Function deploy edilmedi | Deploy (`verify_jwt` açık) + `APPLE_*` secret'ları; o zamana kadar silme `delete_own_account` ile yapılır ve Apple token'ı iptal edilmez (kullanıcıya Ayarlar talimatı gösterilir). Apple Developer'da `pomosprint.app` / `mail.pomosprint.app` gönderici alan adları "Sign in with Apple for Email Communication"a kaydedilmeli (gizli röle adreslerine sıfırlama e-postası) |
| P2 | E-posta değiştirme yok | Uygulama içi şifre değiştirme var; e-posta değişikliği eklenirse `handle_new_user` yalnızca INSERT'te çalıştığı için `profiles.email` ve `marketing_subscribers.email`'i güncelleyen bir trigger gerekir |
| P2 | Başka cihazda silinen hesabın kuyruğu | Silinen uid'in `pending_/rejected_sessions_uid_<uid>` anahtarları diğer cihazda kalır (gönderilemez). "Seans sessizce silinmez" kuralı yüzünden otomatik temizlik yok |
| Tamamlandı | Rapor RPC eşzamanlılık düzeltmesi canlıda (8 Ekim) | `20261007110000_report_submission_lock` uygulandı; bildirici başına advisory kilit, sabit JSON/yer/neden ve limit. Güncel hash `a7ee1b72778b92b59982e5bba8b86c7a`; canlı DRYRUN 23/23, uygulama sonrası geri alınan 23/23 senaryo + 9/9 salt okuma, mevcut veriler/ACL aynı. 7 Ekim izole HTTP yarışı ve düzeltilmiş 7/7 sonucu tarihseldir; bu turda yeni canlı paralel HTTP yarışı çalıştırılmadı. [Rehber](supabase/tests/20261007_report_submission_lock_README.md), [QA](analiz/QA_REPORT_SUBMISSION_LIVE_2026-10-08.md) |
| P2 | Google/Apple gerçek sağlayıcı doğrulaması | 5 Ekim: istemci başarılı sağlayıcı oturumu sonrası sürümü mevcut RPC ile kaydeder; eksik metadata ve idempotency yerelde doğrulandı. Gerçek sağlayıcı girişi fiziksel cihazda bekliyor |
| Tamamlandı | Uygulama içi bildirme formu | 7 Ekim form/RPC bağlı; 8 widget regresyonu, 21 sunucu sözleşmesi ve gerçek yerel UI doğrulaması. Kimliksiz satırda mailto yedeği. Yeni sunucu SQL gerekmiyor |
| P1 | iOS mağaza imzalama profili yok | 7 Ekim gerçek IPA pipeline kişisel takımın Sign In with Apple / Time Sensitive Notifications yeteneklerini desteklememesi nedeniyle başarısız. Ücretli Apple Developer takımı ve uygun provisioning gerekir. Obfuscation ile imzasız release derleme geçti; IPA üretildi sayılmaz |
| P1 | Apple Auth sağlayıcısı kapalı | 7 Ekim canlı: enabled=false, client_id boş; iOS Apple girişi yayından önce yapılandırılmalı ve imzalı cihazda doğrulanmalı. Google enabled=true. Canlı şifre 8 + küçük/büyük harf/rakam; UI/web hizalandı. Redirect site_url=pomosprint.app, confirmed.html ve https://pomosprint.app/*; confirmations/secure_password_change/refresh rotation açık. Kanıt `analiz/qa_evidence_20261007/backend/live_auth_config_status.json` |
| P2 | `reorder_categories` (`proposed/11`) canlıda yok | Toplu kategori sıralaması paralel `update(sort_order)` ile (§4) |
| P2 | `proposed/19` B uygulanmadı (A canlıda) | Form onayı gönderen site JS'si 8 Ekim Cloudflare yayınıyla canlıda (§8). Repodaki iki liste token'ını tanıyan unsubscribe Edge hata/retry düzeltmesinin ayrı deploy'u hâlâ bekliyor; site yayını Edge Function deploy etmez. 19 B güncel canlı tanımlar incelenerek ayrıca kullanıcı SQL akışıyla. Lansman e-postası yalnızca marketing_consent=true satırlara |
| Bilgi | Lig güncel kuralları | §6.4 / 8 Ekim league_launch_policy: 25 kişilik oda, hazırlık, global 14 gün, aktiflik/yeterlilik. Eski 1/1/1 eşikleri güncel politika yerine kullanılmaz |
| P2 | `proposed/01`–`10` kalan maddeler | 03 ve 07 `proposed/14`, 05 `proposed/22` ile geçersiz (UYGULAMAYIN, `proposed/README.md`). Kalan: puan sabitleri tek kaynak, `profiles` kolon bazlı SELECT (06), varsayılan yetkiler (08), veri temizliği (10); canlı gövdelere göre yeniden yazılmalı |
| P2 | Herkese açık sıralama oturum açıkken tam ad döndürüyor | Ürün kararı (`proposed/README.md`, 03 satırı) |
| P3 | Saat dilimi gerçek cihaz / seyahat doğrulaması | Native IANA kanalı ve kendi timezone kolonuna eşleme iOS/Android simülatörde geçti; New York DST ve geçersiz dilimde eski profil koruma sınandı. Fiziksel cihazda sistem saat dilimi değiştirme ayrıca bekliyor |
| P2 | Bayat referanslar | `proposed/README.md` ve `scripts/security_regression_test.js` hâlâ `migrations/20261003120000_audit_fixes.sql` diyor; `run_local.sh` `audit_fixes_test.sql`'i çalıştırıyor; `supabase_service.dart`'ta "`is_me` DÖNMEZ" yorumları |
| Tamamlandı (yerel) | Eski çeviri sözlüğü | 27/28 Ekim:68 çağrı ARB köprüsünde, ayrı sözlük kaldırıldı; parity/doğrudan metin regresyonları var. Genel akışta dolaylı üretilen metinler ayrıca gözden geçirilir |
| Bilgi | DMARC kaydı mevcut | 7 Ekim public DNS salt okuma sonuçları backend/email/dns_status.json; mevcut p=none, yeni DNS ayarı yapılmadı. Resend teslim durumu inbox/spam yerleşimini doğrulamaz |
| P3 | Android fiziksel cihaz doğrulaması bekliyor | 7 Ekim: Android 16 ARM64 emülatörde gerçek UI, beş hesap, native bildirim ve OS force-stop geçti; fiziksel cihaz kapsam dışı |
| P3 | Ertelenen teknik işler | `google_sign_in` 7.x; `SupabaseService`'in bölünmesi (Auth → Category → Social); onboarding'de Çıkış butonu (`AppGate` `onSignedOut` vermiyor) |
| P3 | Waitlist bot koruması | Sitede honeypot + süre kontrolü var; Turnstile/çift onay backend ister |
| Tamamlandı | Repo temizliği §37 | Masaüstü/web şablonları, ham QA fikstürleri ve demo/gece başlatma kaynakları kaldırıldı; tasarım kaynakları repo dışı arşivde, anlamlı testler korunur |
| P3 | Kalan test kapsamı | 7 Ekim: gerçek iOS/Android UI E2E ve OS süreç ölümü geçti. Fiziksel cihaz ve Google/Apple gerçek sağlayıcı girişleri doğrulanmadı; ayrıntı `analiz/QA_RELEASE_2026-10-07.md` |

### Tarihsel QA ve güncel ortam

Önceki 5–9 Ekim çalışma sonuçları `PROJE_DEVIR.md` §6, 15–36 ve tarihli QA raporlarında korunur. Yerel demo/gece/quick başlatıcıları kaldırıldı; eski ham kanıt linkleri kaldırılmış olabilir. Yeni çalışma için bu dosyanın üst notu/§11, gece ilerleme kaydı ve `tool/local_supabase/README.md` kullan. Kişisel geliştirici bilgilerini kullanıcı en son verecek; yeniden sorma.


## 11. 27/28 Ekim 2026 yerel Deneme ve aylık lig sözleşmesi

**Kapsam:** Bu bölüm geliştirme dalındaki yeni kodu anlatır; canlı kurulumu değildir. Tam alan/hata sözleşmesi [EXAM_API_CONTRACT](supabase/proposed/EXAM_API_CONTRACT.md), uygulama/geri alma sırası [NIGHT rehberi](supabase/proposed/NIGHT_20261028_README.md). Gerçek test sonuçları [CODEX_ILERLEME](analiz/CODEX_ILERLEME.md), madde durumu [ISTEKLER](analiz/ISTEKLER.md). Başka ajanın yürüyen işini geri alma; gece için `.env` okuma, canlı servis isteği, push, deploy ve main commit yasaktır.

### 11.1 Yerel dosya ve sahiplik haritası

- `models/exam_model.dart`: katı katalog/attempt/sonuç çözümleme. `exam_catalog_defaults.dart`: çevrimdışı güvenli katalog, başlatma yetkisi değildir. `exam_insights.dart`: gözlemsel süre–net karşılaştırması.
- `services/exam_service.dart`: owner/epoch, sunucu onayı, başlangıç/bitirme/vazgeçme/net yeniden denemesi. `exam_persistence.dart`: `exam_journal_uid_<uid>`, önce kalıcı yazı, sonra istek; bozuk kayıt sessiz atılmaz.
- `screens/exam_screen.dart`, `widgets/exam_results_dialog.dart`: katalog/sayaç, Denemelerim, doğru-yanlış-boş, içgörü. Shell normal/Maraton ile deneme çakışmasını engeller.
- `utils/stats_calculator.dart`, `models/study_session.dart`, `widgets/stats/session_type_summary.dart`: ortak süre, ayrı aktivite türü/plan sayısı.
- `widgets/auth/onboarding_welcome_gate.dart`: hesap başına TR/EN seçimi; `onboarding_welcome_uid_<uid>`. Mevcut yaş/13 altı ve 13–17 politikası değiştirilmedi.
- `supabase/proposed/27_*`, `28_*`, `29_*`: tek ilerleme zinciri. `tool/local_supabase/e2e/overnight_*.py`: yalnız izole review DB senaryoları. Bunları canlı komut gibi çalıştırma.

### 11.2 Deneme yaşam döngüsü

1. `get_exam_config()` schema 1, availability ve TR/EN katalog verir. `PGRST202` yalnız eksik özellik demektir; ağ/yetki/bozuk veri hatası başarıya veya ödüllü çevrimdışı kataloğa çevrilmez.
2. İstemci 3-2-1 sonrası kalıcı UUID ile `start_exam_attempt` çağırır. Sunucu sahibi, türü, çakışmayı ve katalog sürümünü sabitler; `started_at/ends_at` otoritatiftir. Yeniden deneme aynı UUID kullanır.
3. Duraklatma/mola yok. Arka plan/kapanma süreyi durdurmaz; açılış aynı günlüğü sunucuyla uzlaştırır. Başlangıç yanıtı belirsizse yeni ödüllü aktivite başlatılmaz.
4. `complete_exam_attempt` süreyi sunucuda denetler (`exam_not_elapsed`); duplicate aynı snapshot'tır, ikinci kazanç değildir. `abandon_exam_attempt` geçmişi saklar ve ödülsüzdür; zaten süresi dolmuş kayıt güvenli tamamlamaya döner.
5. `save_exam_results`: tamsayı, negatif olmayan doğru/yanlış/boş; toplam ders soru sayısına eşit. Gönderilmeyen ders korunur, bilinmeyen/tekrarlı ders reddedilir. Net negatif olabilir; eksik sonuç sıfır net diye üretilmez. Net ekonomi/ligden bağımsızdır.
6. Backend attempt/net satırları owner-only'dir. Normal/deneme başlangıcı profil kilidinde birleşir; sunucu tarafı overlap savunması istemci kontrolünün yerine geçer. Kayıtlı deneme varken rollback veri silerek zorlanmaz.

Resmî süreler TYT 165, AYT 180, YDT 120; LGS 75/80; TUS her biri 135 dk'dır. TUS Temel/Klinik ayrı 100 soruluk oturumdur. Katalog ayrıntısı ve yaklaşık TUS dağılımı [resmî kaynak raporunda](analiz/SINAV_KAYNAKLARI_2026-10-28.md); resmî sınav yerleştirme puanı hesaplanmaz.

### 11.3 Rapor ve ekonomi ayrımı

- Normal puan/kum yalnız Pomodoro/Maraton. Yeni deneme ödülü sunucu katalog snapshot'ındaki tam süreyle ayrı cüzdana yazılır; mevcut politika her tam 5 dk için 1 deneme puanı, her tam 25 dk için 1 deneme kumudur. İstemci bu formülden ödül üretmez.
- Ortak toplam = normal + Maraton odakları + yalnız tamamlanmış deneme. Vazgeçilen/aktif kayıt süre toplamına girmez. Deneme süresi tek `Deneme` kategorisidir; soru/nete göre derslere dağıtılmaz.
- `combineStudyAndExamSessions` tür + UUID ile mükerrerliği önler. `sessionTypeCounts` seans adedini25dk eşdeğerinden ayırır;50 dk bir normal seanstır. Tam Maraton planı distinct UUID ve tamamlanma metaverisiyle bir kez sayılır; belirsiz eski kayıt planı uydurmaz.
- Günlük hedef halkasındaki eski Pomodoro sayısı 25dk eşdeğeridir: tek50dk normal seans = Normal seans1 / eşdeğer2. `statsTodayPomodoros` ekran okuyucu metni TR/EN açıkça “25 dakikalık odak eşdeğeri” der; tamamlanmış gerçek seans adedi iddia etmez. Günlük/haftalık/aylık `SessionTypeSummary` normal seans, tamamlanmış Maraton, Maraton odağı ve denemeyi ayrı gösterir. `test/report_focus_equivalent_test.dart` iki dilde gerçek semantics ağacını ve1/2 ayrımını doğrular.
- Yeni `get_my_study_sessions_v2` normal/Maraton türü ve plan metaverisini sağlar. Eski sunucuda kesin bilinmeyen tür ayrı belirtilir. Çalışma günü/seri profil IANA04:00, hafta Pazartesi–Pazar kalır.
- Süre–net: son 21gün, aynı sınav+katalog+ders+soru sayısı, en az iki tamamlanmış sonuç ve arada en az 1 gün. Yalnız güvenli kategori eşlemesi. Artış ilişki olarak gösterilir; çalışma süresinin neti artırdığı kanıtı değildir.
- TUS Fizyoloji ile Histoloji/Embriyoloji, `Fizyoloji, Histoloji ve Embriyoloji` çalışma kategorisine; AYT edebiyatı `Edebiyat` ve `Türkçe` kategorilerine bağlanır. Birleşik kategorinin aynı dakika toplamı her ilgili net karşılaştırmasına bağlam olur; derslere paylaştırılmaz ve toplam çalışma süresini artırmaz. Arayüz bu yüzden “İlişkili çalışma kategorilerinde …” der. “Küçük Stajlar” için resmî ayrı soru kotası veya uydurma ders eşlemesi yoktur; yetersiz sonuç içgörü oluşturmaz. `test/exam_category_mapping_test.dart` TR/EN/trim/büyük-küçük harf, kategori aliaslarında tek sayım ve yetersiz veri davranışını kapsar.

### 11.4 Aylık lig ve site

- Paket 29 normal/deneme için **tek** aylık şemadır. `get_monthly_league_ranking(p_kind:study|exam,p_scope:segment|global)`; hedef `get/set_competition_target`. Segment sahibi sunucudan belirlenir. Global ilave görünüm, ikinci ödül/cüzdan değildir.
- Lig ayı İstanbul ayın 1'i 00:00; normal puan `completed_at`, deneme `ends_at`. Çalışma günü04:00 ayrı kalır. İlk puanlı aktivite en fazla25 kişilik odaya yerleşir. Hedef değişimi sonraki ay; mevcut ay puanı/oda korunur.
- En az 3 aktif üyede terfi kontenjanı `floor(aktif/3)`, ayrıca 3 çalışma günü/300 dk/pozitif puan; en az 10 aktifte düşme ve normal avatar ödülü. İlk 3 avatarı yeterlilik ister; son 72 saatte katılan korunur. Deneme avatar slotları görsel gelene kadar NULL, hayalî ödül yok.
- Kurulum ayı hesaplanır, resmî yeni dönem sonraki ay başlar. Eski son dönem bir kez değerlendirilir; geçmiş/kazanılmış avatar/lifetime ekonomi silinmez. İşlenmiş sonuç veya aktif dönem varken down reddedebilir; rehberdeki guard'ı kaldırarak veri kaybettirme.
- Site `get_public_monthly_competition(p_limit:10)` kullanır: yalnız maskeli ad/avatar/puan/dakika/dönem sonu. Ham kullanıcı UUID'si yoktur. Eksik RPC'de hazırlık, sıfır satırda boş durum; eski 04:00 RPC'ye sessiz fallback yok. Gerçek 1–2 kişi de gösterilir.
- Yeni TR/EN home/features/FAQ, hero ilk boyamada görünür, dekoratif hareket ≤300 ms; sayfa boyu sabit kum saati yok. 42 kullanılabilir avatar sayısı katalogla test edilir. Sahte kullanıcı/sayı/yorum/tarih eklenmez. Yeni medya gerçek native kayıttan gelmeden çizilmiş uygulama ekranı konmaz. Yayın yapılmadı.

Site değişiklikleri ve gerçek ekranlar `6d2b9f0` commit'inde; Node **155/155** geçti. Bu yerel commit'tir, push/deploy değildir. iOS 18.6 `o2_04` kontrollü iki TYT geçmişinde net/yatay/kayıt ve haftalık UI–SQL toplamını; `x_change`/`x_resume` kontrollü geçmişle hedef/Global durumunun ayrı OS sürecinde korunmasını geçti. Bunlar doğal 330 dakika veya ay geçişi değildir. Yeni r25/TUS135 başlangıçları geçti, final tamamlanma/ödül kanıtları henüz bekleniyor; son durum [native rapordan](analiz/QA_NATIVE_GECE_2026-10-28.md) okunur.

### 11.5 Kum saati ve test kanıtı sınırı

`assets/sand_timer.json` 18.772 bayt, 30 fps kompozisyon; Lottie 3.5.1 kendi RepaintBoundary'sini ve kompozisyon karesine yuvarlamayı zaten kullanır. Ölçülebilir yarar olmadan `FrameRate.max`/ek cache/katman eklenmedi. İki gerçek lifecycle regresyonu önce başarısız oldu: asset süresi yüklenmeden `repeat()`; hareket azaltma açılınca süren kategori sallanması. Yalnız duration guard ve shake reset eklendi; ölçü/renk/normal tempo değişmedi. `test/hourglass_lifecycle_test.dart` düzeltme sonrası 5/5 geçti; önce/sonra logları gece ilerleme kaydına bağlıdır.

Simülatör debug ölçümü üretim FPS/batarya iddiası değildir. Fiziksel cihaz profile/release ölçümü bekler. Tam paketin güncel sayısı ve native kapsamı tarihli gece raporundan okunur; bu küçük test sonucu bütün uygulamanın yayın onayı sayılmaz.


### 11.6 Derin yerelleştirme ve hata verisi gizliliği

- `test/exam_localization_audit_test.dart`: önce üç gerçek hata üretildi; net ondalık ayırıcı, dil değişiminde açık hata metni ve boşluklardan oluşan sunucu adı. Düzeltme: `utils/exam_format.dart` TR virgül/EN nokta; iki dilde trimlenmiş katalog adı; sonuç diyaloğunda hata durumunu tutup metni build sırasında üretme.
- Login, Register, ForgotPassword, profil adı, arkadaş ekleme/aksiyon, parola değiştirme, kategori adı ve bildirme formu kalıcı hata metinlerini eski dilde dondurmaz. `test/runtime_localization_test.dart` açık ekran/diyalogda dil değişimini ve avatar katalog yedeğini sınar. Bilinen avatarın eksik adı gömülü TR/EN adından alınır; bilinmeyen eksik çevirili katalog satırı reddedilir. Kaldırılmış Ronin satırı hâlâ güvenli filtrelenebilir.
- Deneme kuralları, denemeden vazgeçme ve onboarding hesap silme onayları açıkken cihaz dili değişirse başlık/gövde/düğmeler birlikte yenilenir; metin dialog builder bağlamında çözülür. Asenkron başlangıç/silme hatası da gösterildiği andaki dili kullanır. `test/exam_dialog_localization_test.dart` ve `test/onboarding_dialog_localization_test.dart` eski-dil hatalarını önce FAIL, düzeltme sonrası PASS ile doğruladı; hesap silme eylemi testte onaylanmaz. Onboarding ve Kategorilerim kategori pencereleri `CategoryNameDialog.showLocalized` ile başlık/ipucu/onay metnini güncellerken yazılan adı ve seçilen rengi korur; eski `show` özel metin API’si korunur. Beş hedefli regresyonun ardından mevcut kategori/onboarding testleriyle 26/26 geçti.
- Bildirim dili değiştiğinde mevcut odak/mola alarmı aynı mutlak zamanla yeniden yerelleştirilir. `NotificationService` yalnız RAM'de geçerli alarm parametrelerini tutar; göster/iptal/tercih kapat yolunda temizler. `test/notification_language_refresh_test.dart` eski deadline'ın aynen kaldığını ve iptal edilmiş alarmın yeniden oluşmadığını sınar. Sunucu mola/onay süresi değiştirilmedi.
- `app/error_reporting.dart`: Sentry9.26 error, breadcrumb ve transaction için ortak sınır. Anahtar adına göre kimlik bilgisi/kişisel veri atılır; iç içe map/list taranır. URL kimlik bilgisi, query ve fragment kaldırılır; request yalnız yöntem/güvenli URL olarak yeniden kurulur; body/cookies/headers/user/serverName gönderilmez. E-posta, Bearer/Basic, JWT, anahtar-değer tokenları ve PEM özel anahtar metni temizlenir. Derinlik8, koleksiyon64, metin2048 sınırı; dev/siklik payload sınırsız dolaşılmaz. Stack dosya/satırı, operation/status ve güvenli trace bilgileri korunur.
- `test/error_reporting_test.dart` sentetik nested/case/token/URL/user/depth/transaction/span senaryolarıdır. `tool/operational_qa/sentry_audit_test.dart` önceki sızıntı-bekleyen kontrolü artık temiz çıktı bekler; bellek transport'u kullanır, canlı event/alert göndermez. HTTP500 otomatik event ve canlı alarm/simge çözümleme hâlâ ayrı iştir.
- Kaynak sözleşmesi: [Sentry veri temizleme](https://docs.sentry.io/platforms/dart/guides/flutter/data-management/sensitive-data/), yerel kurulu SDK9.26 protokol sınıfları. Scanner yalnız doğrudan görünür literal alanlarını kanıtlar; bütün programın veri akışı ispatı değildir. Runtime çeviri ve payload regresyonları bu sınırı tamamlar.

### 11.7 A doğrulaması ve net düzenleme — 28 Ekim

Sonuç diyaloğu doğru/yanlış değişiminde boşları otomatik hesaplar; boş elle de düzenlenebilir. Yalnız değişen geçerli dersler gönderilir; diğer kabul edilmiş dersler korunur. `ExamService` ve `ExamPersistence` bekleyen offline ders alt kümelerini subject ID ile birleştirir. Negatif doğru/yanlış/boş veya kota aşımı kaydedilmez; matematiksel negatif net geçerlidir. Üç servis/journal ve beş widget regresyonu, her platformda7×TR/EN doğal60sn net UI turuyla doğrulandı. Normal uygulama25/50dk'dır; yalnız yerel katalog geçici60/0/0 kullanıldı ve sonunda birebir geri alındı.

Bağımsız `verify_reports_and_exams.py`, sabit loopback ve QA owner ile repeatable-read/read-only muhasebe/RLS/rapor beklenenleri üretir. Host `/verify-reports?owner=<UUID>` yalnız bu sabit aracı çağırır. `ad` resmî/kısa/rapor, `ae` ayrı Auth/REST/eskiDB, `af` kategori-global lig ve doğal sosyal polling senaryolarıdır. R `exam_catalog_start` yalnız açık kısa fixture'ı kabul eder; offline/final aşamaları aynı journal/UUID'yi korur. Bitmemiş lifecycle marker, normal sayaç, pending outbox veya aktif/pending exam journal varken yeni probe reset'i reddedilir. Yeni protokol ve kanıt sınırları [native rehberde](tool/local_supabase/e2e/VERIFICATION_20261028_README.md); tek seferlik AH recovery normal suite değildir.


### 11.8 DUS ve ortak Deneme kum politikası (28 Ekim yeni istek)

- Sekiz tür, dört sınav ailesine ayrılır: TYT/AYT/YDT (YKS), LGS Sözel/Sayısal, TUS Temel/Klinik ve DUS. Diğer eski onboarding hedefleri silinmez. DUS 150 dk/120 soru/16 ders içerir; 4 yanlış 1 doğruyu götürür. Resmî dağılım yaklaşık kapsamdır; [kaynağa](analiz/SINAV_KAYNAKLARI_2026-10-28.md) bak.
- Tam süre kum değerleri: lgs_verbal 60, lgs_quantitative 70, ydt 95, tus_basic 110, tus_clinical 110, dus 120, tyt 130, ayt 145. Puanlar aynı sırayla 15/16/24/27/27/30/33/36'dır. Dakika × 0,8 değeri en yakın 5'e yuvarlanır; quant 70 açık istisnadır. Erken AYT kumu floor(snapshot_fullcoins × actual/planned), puanı min(fullpoints, floor(actual/300)) ile hesaplanır; yeni 90 dk sonucu 72/18'dir. Eski 7/175 snapshot'ları korunur. Başka tür erken bitişi kabul etmez. reward_policy_version 2, bütün 8 yeni tanımda bulunur.
- İstemcide `exam_reward_policy.dart` tek fallback kaynağıdır; sunucunun açık 0 değerini veya eski makbuzunu yeni tablodan üretme/ezme. `dus_catalog.dart`, DUS'un 16 ders/kategori eşleşmesinin tek istemci kaynağıdır. UID'ye bağlı bekleyen hedef, TUS'ta olduğu gibi korunur ve sunucu kabul edince yeniden yazılır.
- Proposed 27'nin segment constraint'ine dus, 28'e DUS kataloğu, 29'un segment/target listelerine dus ve 32'ye bütün ödüller eklenir; 30 ayrı başlangıç kotasıdır. Yeni paket numarası yoktur. Temiz ve boş yerel kurulum, 27 → 28 → 29 → 30 → 32 zinciriyle sınanır; 31 kurulmaz. Veri içeren eski veritabanında forward işlemini tekrar deneme veya geniş kapsamlı reset yapma.
- 32'de title/note ve AYT kapsamı, yalnız sahibine ait özel veridir. 120/2000 Unicode-scalar sınırı UI/service katmanlarında ve yazılan verinin tekrar okunabilmesi koşuluyla korunur. Kişisel patch telemetriye taşınmaz. Metadata/revision Save ödül üretmez. Rapor ve overlap için gerçek finished_at/elapsed esastır; planlanan 180 korunur. Offline işlem ACK bekler; istemci zaman damgası ödül otoritesi değildir.
- Güncel izole review ortamı API 54351, iOS host 54359 ve Android host 54369'u; site ortamı API 54361 ve host 54379'u kullanır. Sabit profil adaptörü `exam32_host.py`'dır. Normal varsayılan A host'un SQL'i main A'ya aittir; 32 oracle'ında profil açıkça belirtilmelidir. `verify_reports_and_exams.py --profile review|site` salt okunur. Sırlar ve .env dosyaları okunmaz.
- Güncel kapanış/native/medya sonucunu ilerleme kaydından ve tarihli rapordan oku. Başlatılmış kısa test veya ilk B medyası, nihai sonuç sayılmaz. Kısa DUS testi yalnız yerel 60 sn/0 ödül kullanır; root'un finally adımında kataloğu birebir geri yüklemesi ve pariteyi doğrulaması gerekir. Bu, standart 150 dk/120 kum testi sayılmaz.


### 11.9 Kompakt Deneme ekranı (28 Ekim son arayüz isteği)

Deneme ekranında kısa Yeni/Geçmiş/Lig sekmeleri ve sabit `exam-tab-new/history/league` anahtarları kullanılır. Eski `examNew`, `examHistory`, `examLeague` çevirileri semantik ekran adları olarak korunur; sekme bulmak için bu uzun metinleri kullanma. Filtreler `exam-filter-all/yks/lgs/tus/dus`; kartlar `exam-card-<id>`. Katalogdaki uzun ders/formül paragrafları yerine tek net bilgisi kutusu, soru/süre etiketleri ve AYT'nin4test özeti vardır. YKS/TUS/DUS için4yanlış, LGS için3yanlış kuralı iki dilde açıklanır. Süre, ödül, RPC veya kayıt modeli bu görsel değişiklikte değiştirilmedi. Küçük ekran,2×yazı ve yatay düzen regresyonu `test/exam_compact_ui_test.dart` içindedir.


### 11.10 KPSS — 28 Ekim yeni yerel kapsam

Bu bölüm §11.8–11.9’daki tarihsel sekiz tür/dört aile bilgisini yeni katalog için günceller; eski kanıtlar ve eski kayıt snapshot’ları korunur. `exam_catalog_v1.json` ve `exam_catalog_32.json` artık 20 kayıt içerir. Beş aile YKS, LGS, TUS, DUS, KPSS’tir. KPSS, yeni tablo veya paket numarası açmadan 28 katalog ve 32 ödül sözleşmesine eklenir; 27/29 zaten `kpss` hedefini destekler. 31 kurulmaz.

| KPSS seçeneği | Soru | Dakika | Tam kum | Deneme puanı |
|---|---:|---:|---:|---:|
| Lisans / Ön Lisans / Ortaöğretim GY–GK (3 ayrı kayıt) |120 (60 + 60)|130|105|26|
| İstatistik dışındaki 8 Alan Bilgisi testi |40|50|40|10|
| İstatistik |40|60|50|12|

- Alanlar: İşletme, Muhasebe, Hukuk, Kamu Yönetimi, İktisat, Maliye, Uluslararası İlişkiler, Çalışma Ekonomisi ve Endüstri İlişkileri, İstatistik. Her alan ayrı denemedir. Yaklaşık konu dağılımı kesin alt ders soru kotası olarak uydurulmaz; GY–GK’nin resmî iki test toplamı kullanılır.
- Kullanıcı öğrenim düzeyini ve alanı açıkça seçer; mesleğe göre otomatik seçim yoktur. Yeni filtre `exam-filter-kpss`, düzey/alan seçimi `exam-kpss-track-*` anahtarlarıdır. AGS/ÖABT/DHBT yoktur. Eğitim Bilimleri’nin eski kategori/taslak verisi korunur, yeni KPSS öneri listesinde yer almaz. Yaş adımı/13 yaş altı engeli değişmedi.
- KPSS neti doğru − yanlış/4’tür; resmî standart KPSS puanı değildir. Yeni 12 türde erken tamamlama yoktur; yalnız AYT erken tamamlanabilir. Önceki 8 kataloğun değerleri ve başlamış/tamamlanmış kayıtların ödül snapshot’ları değişmez. Puan/kum/seri sunucu otoritesinde kalır, net/başlık/not düzenleme ödül üretmez.
- İstemci kaynağı `lib/models/kpss_catalog.dart`; ortak ödül fallback’i `exam_reward_policy.dart`. TR/EN adlar ve ders-kategori eşlemesi JSON/istemci paritesiyle denetlenir. Onboarding mevcut kullanıcı derslerini silmez.
- KPSS incelemesi DUS/main/site verisini değiştirmeyen `pomosprint_review32_kpss` DB’sindedir: API 54401, REST 54402, Auth 54403, iOS host 54409. `--profile kpss` sabit hedefini kullan; genel DB/URL override veya eski `review` profilini KPSS verisi sanma. Bu servislerin yeniden kurulması/silinmesi bu dokümanla yetkilendirilmez.
- Bu not yazılırken tamamlanan kapılar: analiz temiz, Flutter 1493 PASS + yalnız 5 isteğe bağlı PNG atlaması, Node 173/173, partial check; SQL 242/242, ağsız guard/oracle/host/parite 74/74 ve salt okuma şema paritesi 5/5. 29 Ekim doğrudan native test TR/EN geçti; 8 ekran ve orijinal tercihin korunduğu hash kaydı vardır. Normal uygulama yeniden kuruldu, 25:00 ana ekranı ve aynı bekleyen taslak doğrulandı. 130 dakikanın tamamı doğal sürede beklenmedi; yeni Android native KPSS turu yapılmadı. Sonraki sonuç için [KPSS raporu](analiz/QA_KPSS_2026-10-28.md) esas alınır.
- Site sadece yerel TR/EN metin hazırlığıdır: 3 gruplu ödül özeti, net ve 14 SSS/JSON-LD eşliği vardır. 30 PNG/4 video değişmedi ve KPSS ekranı çekilmiş gibi sunulmadı. Son canlı web sürümünde KPSS yoktur. Yeni site/uygulama/SQL yayını için ilgili açık kullanıcı onayı gerekir; main/merge/force yasağı sürer.
