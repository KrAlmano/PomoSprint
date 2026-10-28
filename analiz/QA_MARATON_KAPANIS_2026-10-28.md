# Maraton süreç kapanışı — ara doğrulama kaydı

**28 Ekim 04:01 İstanbul ara durumu; son doğrulama değildir.** Kaynak: [ab_marathon_process_probe_test.dart](../integration_test/ab_marathon_process_probe_test.dart). Eski 27–30 yerel şemada başlangıç ve erken odak açılışı geçti. İlk geç açılış, ham cihaz/sunucu tarihlerini birebir eşitleyen test assertion'ında başarısız oldu; tam kapanış/ödül doğrulaması henüz geçmedi. Öneri31 ana yerel QA'ya ve canlıya uygulanmadı.

## Gerçek native sonuçlar

Koşu `night-ab-before31`, iOS27 QA kurulumudur. Başlangıç **00:09:11.769439Z**, ilk odak bitişi **00:34:11.769439Z**; gerçek 1500 saniyedir. Aşağıdaki satırlar ayrı değerlendirilir; başlangıç/ara başarı final yerine geçmez.

| Aşama | Sonuç | Kanıt ve sınır |
|---|---|---|
| Gerçek UI ile 2×25 başlangıç | **1/1 + 27–30 parite PASS** | İlk odak/plan UUID'si ve tarihler diskte korundu; uygulama ve cihaz kapatıldı. [Günlük](/tmp/pomosprint_ios27_ab_before_start.log), [kapanış manifesti](../build/overnight_backend/ab_before_start_closed.json). |
| İlk odak bitmeden farklı süreçte açılış | **1/1 + 27–30 parite PASS** | Aynı ilk tarihler/UUID ve sıfır ekonomi; azalan kalan süre, `stage=same_focus_resumed`, `completion_verified=false`. Ardından tekrar kapatıldı. [Günlük](/tmp/pomosprint_ios27_ab_before_focus_resume.log), [manifest](../build/overnight_backend/ab_before_focus_resume_closed.json). |
| İlk odak bittikten sonra ilk açılış | **FAIL; parite PASS** | Sunucu ve cihaz mola sonlarının ham eşitliği beklendi. Sunucu **00:47:31.602725Z**, cihaz **00:47:31.472262Z**: fark **130463 mikrosaniye (0,130463 sn)**. İstemci makbuzu ölçülen saat farkıyla cihaz saatine çevirir; ham eşitlik test hatasıdır. [Özgün FAIL](/tmp/pomosprint_ios27_ab_before_break.log). |
| Aynı veride süre dolmuş makbuzu kurtarma | **Henüz çalıştırılmadı / PASS yok** | `recovered_expired` yalnız bu bilinen koşudaki korunmuş işareti ve gerçek gate'i kabul eder. Eski FAIL'i başarıya çevirmez; ayrı sonuç olacak. Kaynak için [hedefli analiz temiz](/tmp/pomosprint_ab_clock_recovery_analyze.log); native yürütme bekler. |

Bağımsız, salt okunur [hata sonrası dışa aktarım](../build/overnight_backend/ab_before_break_failed_clock_export.json), uygulamada **1 tamamlanan odak ve `breakTime`** bulunduğunu gösterir. Sunucu gate'i **00:42:31.602725Z**'de oluşturuldu: ilk gerçek odak sonundan **8 dakika 19,833286 saniye sonra**. Mola sonu **00:47:31.602725Z**, onay sonu **00:48:31.602725Z**; aralıklar tam300 ve60 saniye, `confirmed_at` ve `next_client_uuid` boş. Bu, eski sözleşmenin geç kabulde yeni pencere açtığına dair gerçek native/sunucu kanıtıdır.

Test, ham tarih assertion'ında durduğu için kalıcı proof hâlâ `same_focus_resumed` aşamasındadır; `gate` alanı yazılmamış ve `completion_verified=false` kalmıştır. Özgün FAIL korunur. Tam ekonomi, makbuzun değişmemesi, ikinci odağın başlamaması ve temiz sonlanma için ayrı kurtarma finali beklenir. Dışa aktarım auth tokenı/parola içermez; tercihler değiştirilmedi, QA cihazı kapalıdır.

## Kaynaktan doğrulanan davranış

- `TimerScreen._restoreSavedSession`, kayıtlı ilk odak süresi dolmuşsa aynı odak UUID'siyle tamamlamayı gönderir. Süre dolmamışsa başlangıç, bitiş ve plan korunur.
- `complete_marathon_study_session`, ilk kabul sırasında `clock_timestamp()` üzerinden 300 saniyelik mola ve ardından 60 saniyelik onay penceresi oluşturur (`20261007170000_marathon_presence_confirmation.sql`). İlk odak boyunca uygulama kapalıysa bu sunucu kabulü yeniden açılışta gerçekleşir.
- Bu nedenle **ilk odak başlangıcından 31 dakika sonra yapılan ilk açılışta planın hemen sona ermesini beklemek mevcut sözleşmeye aykırıdır**. İlk 25 dakika tek normal seans olarak kaydedilir; bu açılışta alınan sunucu makbuzundan itibaren mola/onay penceresi görünür. İkinci odak kendiliğinden başlamaz.
- Daha önce alınmış bir mola makbuzu varsa tekrar açılış onu değiştirmez. Makbuzdaki onay sonu geçince kullanıcı onayı olmadan plan durur; ilk seans, 5 normal puan ve 20 kum korunur, Maraton bonusu verilmez.

**Açık risk:** İlk odak tamamlandığı halde kayıt gecikirse kabul anında yeni pencere açılması, kullanıcının istediği odak bitiminden itibaren en fazla 5+1 dakika kuralını uzatabilir. Bu sadece anlatım farkı değildir: kullanıcı uzun süre uygulamaya dönmeyip daha sonra yeni bir mola/onay penceresi alabilir. `AGENTS.md §5.7` mevcut kabul-anı sözleşmesini doğru anlatır; istenen AFK sınırını sağladığını kanıtlamaz. Bu risk normal çevrimdışı tamamlanmış seansların ödül politikasından ayrıdır. Öneri31, ayrı yerel klonda fail-first kanıt ve odak bitişine sabit pencereyle değerlendiriliyor; henüz ana yerel sunucuya veya canlıya uygulanmadı.

**Duraklatma sınırı:** Mevcut dokuz parametreli tamamlama RPC'si gerçek duraklatma süresini taşımaz. `ActiveTimerSession.resumeAt` cihazın `endsAt` değerini ileri alır, ancak sunucuya değişmeyen `startedAt` gider. Kabul edilmiş satırın `completed_at` değeri başlangıç+25/50 dakikadır. Ayrı, geri alınmış klon kontrolünde duraklatılmış25 için bu aralık1500s, normal tabanpuan4 ve satır bitişinin kabulden420s önce olması doğrulandı. Bu nedenle meşru7dk duraklatma ile7dk geç teslim yalnız mevcut RPC girdileriyle ayırt edilemez; kesin AFK politikası için bu ayrım ayrıca ele alınmalıdır. Bu kanıt fiziksel kullanıcı davranışını ölçen native test değildir.

`timer_screen.dart` içindeki “Geç açılış / yavaş bağlantı mola veya onay penceresini uzatmaz” yorumu, daha önce alınmış değişmez makbuzun korunmasını anlatır. İlk gecikmiş kabulün yeni pencere oluşturmadığı anlamına gelmez; öneri31 sonrasında da duraklatılmış kola genellenemez. Ürün kaynak yorumu bu işte değiştirilmedi. Ayrıca duraklatılmış kaydın sunucudaki bitişinin başlangıç+odak süresi olması, takvim ayı sınırındaki lig atfını gerçek cihaz bitişinden farklı yapabilir. Bu bir kaynak sözleşmesi sınırlamasıdır;31 normal seans politikasını veya lig tarihini değiştirmez ve bu gece doğal ay sınırı geçtiği iddia edilmez.

## Aşamalar

| Aşama | Parametre | Beklenen kanıt |
|---|---|---|
| Yeni başlangıç | `E2E_MARATHON_PROBE_MODE=start` | Yeni yerel hesap, gerçek UI ile 2×25 plan; 1500 saniye, ilk UUID/plan UUID'si/tarihler diskte; sıfır ekonomi ve henüz mola makbuzu yok. |
| İsteğe bağlı erken açılış | `MODE=resume`, `EXPECT=focus` | İlk odak bitmeden farklı OS sürecinde aynı hesap/UUID/tarihler; kalan süre azalır; ödül yok. Yaklaşık iki dakika sonra uygulanabilir. |
| İlk geç açılış | `MODE=resume`, `EXPECT=break` | İlk odak son tarihinden sonra açılır. Tek 25 dakika/5 puan/20 kum/1 seri; birinci odak eşlemesi; 2 hedefli geçerli plan ve bonus0. Yeni sunucu makbuzu tam 300+60 saniye; onay ve sonraki UUID boş. |
| Makbuz süresi sonrası açılış | `MODE=resume`, `EXPECT=expired` | Başarılı önceki `break` aşamasının makbuzu diskte gerekir. Makbuzun `confirmation_deadline` zamanı geçtikten sonra farklı süreçte açılış; zamanlayıcı temizlenir ve devam onayı gelmediği mesajı görünür. Aynı tek seans/ekonomi korunur; makbuz tarihleri/onayı değişmez. |
| Bilinen FAIL sonrası ayrı kurtarma | `MODE=resume`, `EXPECT=recovered_expired` | Yalnız `night-ab-before31`: proof `same_focus_resumed`, kayıtlı gate yok, fakat aynı ilk UUID için gerçek sunucu gate'i ve diskte1/break bulunmalı. Gerçek gate sonu+saat toleransı geçince açılır; mevcut kayıt/ödül korunması ve ikinci odağın başlamaması ayrı doğrulanır. |
| Öneri31 sonrası ilk geç açılış | `MODE=resume`, `EXPECT=late_rejected` | Yalnız duraklatılmamış yeni plan ve31 kurulmuş yerel sunucu. İlk odak bitişinden en az370sn sonra ilk açılış; tek25dk/5puan/20kum korunur, run `is_invalid=true`, aktif zamanlayıcı temizlenir, yeni gate/ACK/ikinci odak yoktur. |

Tam parametre adları: `E2E_MARATHON_PROBE_MODE`, `E2E_MARATHON_PROBE_EXPECT`, `E2E_RUN_ID`.
`MODE` boşsa test güvenli biçimde atlanır; geçersiz değerler başarısız olur. `late_rejected` eski sunucuya karşı çalıştırılmaz; `break` ilk geç kabul beklentisi ise31 sonrası duraklatılmamış yeni plan için doğru değildir. `recovered_expired` rastgele kayıp işareti veya yeni bir hesabı başarılı sayan genel bir yedek yol değildir; yalnız bilinen başarısız eski koşu içindir.

**Güncel plan, sonuç değil:** H18 yaklaşık04:12'de bittikten sonra eski27–30/parite2 üzerinde `recovered_expired` çalıştırılacak. Ana QA bütün eski sözleşmeli doğal koşular, LGS75 yaklaşık04:45 ve Android H yaklaşık05:15 dahil, bitene kadar değiştirilmez. Sonra31 DRYRUN/ileri/parite3; yeni ayrı AB başlangıcı yaklaşık05:18 ve `late_rejected` finali yaklaşık05:50 planlanır. Saatler kayabilir; hiçbiri henüz final başarı değildir.

## Çalıştırma

Kök ajan wrapper desteğini ayrıca ekleyebilir; bu işte wrapper değiştirilmedi. Çalışan yerel E2E hostuyla doğrudan komut:

```sh
flutter test --no-pub --no-uninstall \
  integration_test/ab_marathon_process_probe_test.dart -d "$SIM_UDID" \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY="$LOCAL_QA_ANON_KEY" \
  --dart-define=E2E_HOST_PORT="$E2E_HOST_PORT" \
  --dart-define=E2E_RUN_ID=marathon-process-ios27-01 \
  --dart-define=E2E_MARATHON_PROBE_MODE=start
```

Sonraki komutlarda aynı cihaz, kurulum ve `E2E_RUN_ID` korunur; `MODE=resume` ve uygun `EXPECT=focus|break|expired|late_rejected` eklenir. Bu gecenin bilinen FAIL kurtarması için koşu kimliği `night-ab-before31` ve `EXPECT=recovered_expired` zorunludur. Her native komut sonrasında OS uygulama kapatma/cihaz kapatma işini kök ajan yapar. Test kendi sürecini öldürmez. `--no-uninstall` zorunludur; kurulum verisi kaybolursa test başarısız olur, yeniden hesap açarak devam etmez.

Başlangıç hedefi: `e2e-sim-marathon-process-<E2E_RUN_ID>@pomosprint.local`. Hesap Mailpit doğrulaması ve standart onboarding API yardımcısıyla hazırlanır; bu test kayıt/onboarding UI testi değildir. Maraton planlaması gerçek UI üzerinden yapılır. Bildirimler bu senaryoda kapalıdır; bildirim teslimi kapsam dışıdır.

## Kanıt ve güvenlik sınırı

- Başlangıç işareti: `e2e_marathon_process_probe_<run>`. Sahip, plan/odak UUID'leri, ham başlangıç/bitiş, farklı süreç PID'leri ve sunucu mola makbuzu kaydedilir. `completion_verified=true` yalnız `expired`, bilinen koşunun ayrı `recovered_expired` finali veya31 sonrası `late_rejected` aşamasında yazılır. Başlangıç ve ara açılışlar tamamlanmış test sayılmaz.
- Testte tarih, katalog, süre, puan veya mola satırı yazılmaz. SQL yalnız salt okunur kanıt toplar. Ekonomi yalnız uygulamanın gerçek tamamlamasıyla oluşur.
- r/w/h ve diğer ab işaretleri, mevcut zamanlayıcı, bekleyen seanslar ve aktif/bekleyen Deneme kayıtları başlangıç sıfırlamasından önce korunur. Aynı e-posta mevcutsa yeni başlangıç reddedilir.
- Başarılı veya başarısız koşudan sonra hesap, seans, makbuz, auth ve işaret silinmez. Gerçek kapalı kalma kanıtı için kök ajan OS kapatma/başlatma zamanlarını ve süreç durumunu ayrıca saklamalıdır.
- Sunucunun kabul zamanında mola başlatması yukarıdaki mevcut davranıştır; odak bitişinden sayılması şeklinde bir ürün değişikliği bu test kapsamında yapılmadı.

## Hazırlık doğrulaması

- `dart format integration_test/ab_marathon_process_probe_test.dart`: tamamlandı.
- `dart analyze integration_test/ab_marathon_process_probe_test.dart`: **No issues found**.
- Yerel `54322` üzerinde `BEGIN READ ONLY` + `WHERE false` ile profil/cüzdan, `marathon_presence_gates`, seans/eşleme, `marathon_runs`, `competition_events` ve Deneme sütunları derlendi: **6 sorgu başarılı**, hiçbir profil/seans satırı okunmadı veya değiştirilmedi.
- İlk hazırlıkta native başlangıç/açılış henüz çalışmamıştı. Güncel gerçek sonuçlar üstteki tabloda ayrı verilmiştir; canlı servise erişilmedi.
- Saat karşılaştırması düzeltmesi cihazın iki bitişine aynı saat dönüşümünün uygulandığını ve sunucudaki300/60 aralıklarını doğrular; ham tarih eşitliğini istemez. Bu kaynak değişikliği henüz commitlenmedi; statik analiz temizliği, kurtarma native PASS'i değildir.

## Öneri31 izole doğrulama sonucu

Ana yerel QA ve canlı sunucu değiştirilmeden, kullanıcı verisi kopyalanmayan `pomosprint_night_marathon31` klonunda çalışıldı. Her tur sonunda yalnız bu araç tarafından oluşturulan klon kaldırıldı.

| Kontrol | Sonuç ve kapsam |
|---|---|
| Eski davranış | 6 kontrol geçti; olması istenen `gate başlangıcı = kabul edilmiş odak bitişi` beklentisi **1 kez bilinçli FAIL** verdi. 7 dakika önce bitmiş odak için yeni pencere oluştu. |
| Eski pencerenin kullanılabilirliği | Yapay saati değiştirmeden gerçek300 saniye beklendi; ardından kimliği doğrulanmış onay RPC'si `confirmed=true` döndü. Bu SQL/API kanıtıdır, native uygulama koşusu değildir. |
| Öneri31 | İlk tur **73/73**, gerçek ACK kapsamı eklenen son tur **96/96**. İçerilen DRYRUN'daki13 koşulun tamamı doğru; kasıtlı hata ileri değişikliği geri aldı. Bu sonuçlar toplanmaz. |
| Süre sınırları | 10,299,300,350 saniye geç kabulde gerçek kalan pencere;360 ve420 saniyede normal ödül korunarak plan geçersiz, yeni gate yok. |
| Diğer kontroller | Tekrar/eşzamanlı kabul, geç ara2/3 odağı, normal25/50, NULL/gelecek tarih/yabancı kategori reddi, altı bonus kombinasyonu, duraklatılmış son odak, tüm veri korumalı geri alma. |
| Bilinen açık kalan politika | `p_was_paused=true` kabul zamanı penceresi korunur; meşru duraklatma bozulmaz, fakat bu yol için AFK sorunu kapatılmış sayılmaz. |

Kanıtlar: [eski davranış](/tmp/pomosprint_marathon_anchor_before.log), [ilk AFTER](/tmp/pomosprint_marathon_anchor_after.log), [son96/96](/tmp/pomosprint_marathon_anchor_after_extended.log); yerel yapılandırılmış çıktılar [önce](../build/overnight_backend/marathon_anchor_before.json), [sonra](../build/overnight_backend/marathon_anchor_after.json) ve [duraklatma sözleşmesi](../build/overnight_backend/marathon_pause_semantics.json).

Paketler: [ileri](../supabase/proposed/31_marathon_completion_anchor.sql), [DRYRUN](../supabase/proposed/31_marathon_completion_anchor_dryrun.sql), [geri alma](../supabase/proposed/31_marathon_completion_anchor_down.sql), [kapsam ve kullanım](../supabase/proposed/31_marathon_completion_anchor_README.md). Geçmiş SQL tarihleri kontrollü fixture'dır;25/50 dakika doğal çalışma beklenmiş gibi sunulmaz. Native AB kurtarma ve31 sonrası aşamaları ayrıca çalıştırılacaktır. Ana QA ve canlı31 uygulanmamış durumdadır; duraklatılmış AFK sınırlaması çözülmüş sayılmaz.

## Genişletilmiş bağımsız inceleme sonrası SQL kapsamı
Son AFTER turu **96/96 PASS**;13/13 DRYRUN bu toplamın içindedir.25dk gecikme300/350 ve50dk araodak(index2/3) gecikme300/350 için yeni fonksiyonun gerçek ürettiği gate üzerinden publicACKbaşarısı ve aynıcandidateUUIDtekrarı doğrulandı.50dk araodak420sngecikmede ilgiliodağın12puan20kumu korunur, planinvalidolur ve yenigateyoktur. Full-plan bonusmatrisindeki öncekiACKgeçmişleri kontrollüfixture'dır; bu ayrı yeni testler gerçekpublicACKçağrılarıdır. KaynakSQL/down/DRYRUNhashleri değişmedi. Kanıt `/tmp/pomosprint_marathon_anchor_after_extended.log`, `build/overnight_backend/marathon_anchor_after.json`.
