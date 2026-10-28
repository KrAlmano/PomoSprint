# Maraton süreç kapanışı — native doğrulama planı

28 Ekim 2026. Kaynak: `integration_test/ab_marathon_process_probe_test.dart`.
**Henüz native çalıştırılmadı.** Bu belge hazır testin kapsamını ve gerçek uygulama sözleşmesini anlatır; çalışmış bir test raporu değildir.

## Kaynaktan doğrulanan davranış

- `TimerScreen._restoreSavedSession`, kayıtlı ilk odak süresi dolmuşsa aynı odak UUID'siyle tamamlamayı gönderir. Süre dolmamışsa başlangıç, bitiş ve plan korunur.
- `complete_marathon_study_session`, ilk kabul sırasında `clock_timestamp()` üzerinden 300 saniyelik mola ve ardından 60 saniyelik onay penceresi oluşturur (`20261007170000_marathon_presence_confirmation.sql`). İlk odak boyunca uygulama kapalıysa bu sunucu kabulü yeniden açılışta gerçekleşir.
- Bu nedenle **ilk odak başlangıcından 31 dakika sonra yapılan ilk açılışta planın hemen sona ermesini beklemek mevcut sözleşmeye aykırıdır**. İlk 25 dakika tek normal seans olarak kaydedilir; bu açılışta alınan sunucu makbuzundan itibaren mola/onay penceresi görünür. İkinci odak kendiliğinden başlamaz.
- Daha önce alınmış bir mola makbuzu varsa tekrar açılış onu değiştirmez. Kayıtlı son tarihten 300+60 saniye geçince kullanıcı onayı olmadan plan durur; ilk seans, 5 normal puan ve 20 kum korunur, Maraton bonusu verilmez.

**Açık risk:** İlk odak tamamlandığı halde kayıt gecikirse kabul anında yeni pencere açılması, kullanıcının istediği odak bitiminden itibaren en fazla 5+1 dakika kuralını uzatabilir. Bu sadece anlatım farkı değildir: kullanıcı uzun süre uygulamaya dönmeyip daha sonra yeni bir mola/onay penceresi alabilir. `AGENTS.md §5.7` mevcut kabul-anı sözleşmesini doğru anlatır; istenen AFK sınırını sağladığını kanıtlamaz. Bu risk normal çevrimdışı tamamlanmış seansların ödül politikasından ayrıdır. Öneri31, ayrı yerel klonda fail-first kanıt ve odak bitişine sabit pencereyle değerlendiriliyor; henüz ana yerel sunucuya veya canlıya uygulanmadı.

**Duraklatma sınırı:** Mevcut dokuz parametreli tamamlama RPC'si gerçek duraklatma süresini taşımaz. `ActiveTimerSession.resumeAt` cihazın `endsAt` değerini ileri alır, ancak sunucuya değişmeyen `startedAt` gider. Kabul edilmiş satırın `completed_at` değeri başlangıç+25/50 dakikadır. Ayrı, geri alınmış klon kontrolünde duraklatılmış25 için bu aralık1500s, normal tabanpuan4 ve satır bitişinin kabulden420s önce olması doğrulandı. Bu nedenle meşru7dk duraklatma ile7dk geç teslim yalnız mevcut RPC girdileriyle ayırt edilemez; kesin AFK politikası için bu ayrım ayrıca ele alınmalıdır. Bu kanıt fiziksel kullanıcı davranışını ölçen native test değildir.

`timer_screen.dart` içindeki “Geç açılış / yavaş bağlantı mola veya onay penceresini uzatmaz” yorumu, daha önce alınmış değişmez makbuzun korunmasını anlatır. İlk gecikmiş kabulün yeni pencere oluşturmadığı anlamına gelmez; öneri31 sonrasında da duraklatılmış kola genellenemez. Ürün kaynak yorumu bu işte değiştirilmedi. Ayrıca duraklatılmış kaydın sunucudaki bitişinin başlangıç+odak süresi olması, takvim ayı sınırındaki lig atfını gerçek cihaz bitişinden farklı yapabilir. Bu bir kaynak sözleşmesi sınırlamasıdır;31 normal seans politikasını veya lig tarihini değiştirmez ve bu gece doğal ay sınırı geçtiği iddia edilmez.

## Aşamalar

| Aşama | Parametre | Beklenen kanıt |
|---|---|---|
| Yeni başlangıç | `E2E_MARATHON_PROBE_MODE=start` | Yeni yerel hesap, gerçek UI ile 2×25 plan; 1500 saniye, ilk UUID/plan UUID'si/tarihler diskte; sıfır ekonomi ve henüz mola makbuzu yok. |
| İsteğe bağlı erken açılış | `MODE=resume`, `EXPECT=focus` | İlk odak bitmeden farklı OS sürecinde aynı hesap/UUID/tarihler; kalan süre azalır; ödül yok. Yaklaşık iki dakika sonra uygulanabilir. |
| İlk geç açılış | `MODE=resume`, `EXPECT=break` | İlk odak son tarihinden sonra açılır. Tek 25 dakika/5 puan/20 kum/1 seri; birinci odak eşlemesi; 2 hedefli geçerli plan ve bonus0. Yeni sunucu makbuzu tam 300+60 saniye; onay ve sonraki UUID boş. |
| Makbuz süresi sonrası açılış | `MODE=resume`, `EXPECT=expired` | Önceki `break` aşamasının makbuzu diskte gerekir. Makbuzun `confirmation_deadline` zamanı geçtikten sonra farklı süreçte açılış; zamanlayıcı temizlenir ve devam onayı gelmediği mesajı görünür. Aynı tek seans/ekonomi korunur; makbuz tarihleri/onayı değişmez. |
| Öneri31 sonrası ilk geç açılış | `MODE=resume`, `EXPECT=late_rejected` | Yalnız duraklatılmamış yeni plan ve31 kurulmuş yerel sunucu. İlk odak bitişinden en az370sn sonra ilk açılış; tek25dk/5puan/20kum korunur, run `is_invalid=true`, aktif zamanlayıcı temizlenir, yeni gate/ACK/ikinci odak yoktur. |

Tam parametre adları: `E2E_MARATHON_PROBE_MODE`, `E2E_MARATHON_PROBE_EXPECT`, `E2E_RUN_ID`.
`MODE` boşsa test güvenli biçimde atlanır; geçersiz değerler başarısız olur. `late_rejected` eski sunucuya karşı çalıştırılmaz; `break` ilk geç kabul beklentisi ise31 sonrası duraklatılmamış yeni plan için doğru değildir.

**Kök ajanın planı, sonuç değil:** eski sözleşme için02:35 başlangıç →02:37 erken `focus` →03:07 ilk `break` →03:14 `expired`; öneri31 sonrasında ayrı yeni hesapla03:30 başlangıç →04:10 `late_rejected`. Derleme/çalışma saatleri kayabilir; gerçek sonuçlar ancak log, makbuz ve korunan işaretle doğrulanır.

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

Sonraki komutlarda aynı cihaz, kurulum ve `E2E_RUN_ID` korunur; `MODE=resume` ve uygun `EXPECT=focus|break|expired|late_rejected` eklenir. Her native komut sonrasında OS uygulama kapatma/cihaz kapatma işini kök ajan yapar. Test kendi sürecini öldürmez. `--no-uninstall` zorunludur; kurulum verisi kaybolursa test başarısız olur, yeniden hesap açarak devam etmez.

Başlangıç hedefi: `e2e-sim-marathon-process-<E2E_RUN_ID>@pomosprint.local`. Hesap Mailpit doğrulaması ve standart onboarding API yardımcısıyla hazırlanır; bu test kayıt/onboarding UI testi değildir. Maraton planlaması gerçek UI üzerinden yapılır. Bildirimler bu senaryoda kapalıdır; bildirim teslimi kapsam dışıdır.

## Kanıt ve güvenlik sınırı

- Başlangıç işareti: `e2e_marathon_process_probe_<run>`. Sahip, plan/odak UUID'leri, ham başlangıç/bitiş, farklı süreç PID'leri ve sunucu mola makbuzu kaydedilir. `completion_verified=true` yalnız `expired` veya31 sonrası `late_rejected` aşamasında yazılır. Başlangıç ve ara açılışlar tamamlanmış test sayılmaz.
- Testte tarih, katalog, süre, puan veya mola satırı yazılmaz. SQL yalnız salt okunur kanıt toplar. Ekonomi yalnız uygulamanın gerçek tamamlamasıyla oluşur.
- r/w/h ve diğer ab işaretleri, mevcut zamanlayıcı, bekleyen seanslar ve aktif/bekleyen Deneme kayıtları başlangıç sıfırlamasından önce korunur. Aynı e-posta mevcutsa yeni başlangıç reddedilir.
- Başarılı veya başarısız koşudan sonra hesap, seans, makbuz, auth ve işaret silinmez. Gerçek kapalı kalma kanıtı için kök ajan OS kapatma/başlatma zamanlarını ve süreç durumunu ayrıca saklamalıdır.
- Sunucunun kabul zamanında mola başlatması yukarıdaki mevcut davranıştır; odak bitişinden sayılması şeklinde bir ürün değişikliği bu test kapsamında yapılmadı.

## Hazırlık doğrulaması

- `dart format integration_test/ab_marathon_process_probe_test.dart`: tamamlandı.
- `dart analyze integration_test/ab_marathon_process_probe_test.dart`: **No issues found**.
- Yerel `54322` üzerinde `BEGIN READ ONLY` + `WHERE false` ile profil/cüzdan, `marathon_presence_gates`, seans/eşleme, `marathon_runs`, `competition_events` ve Deneme sütunları derlendi: **6 sorgu başarılı**, hiçbir profil/seans satırı okunmadı veya değiştirilmedi.
- Native başlangıç/açılış henüz çalıştırılmadı; canlı servise erişilmedi.

## Öneri31 izole doğrulama sonucu

Ana yerel QA ve canlı sunucu değiştirilmeden, kullanıcı verisi kopyalanmayan `pomosprint_night_marathon31` klonunda çalışıldı. Her tur sonunda yalnız bu araç tarafından oluşturulan klon kaldırıldı.

| Kontrol | Sonuç ve kapsam |
|---|---|
| Eski davranış | 6 kontrol geçti; olması istenen `gate başlangıcı = kabul edilmiş odak bitişi` beklentisi **1 kez bilinçli FAIL** verdi. 7 dakika önce bitmiş odak için yeni pencere oluştu. |
| Eski pencerenin kullanılabilirliği | Yapay saati değiştirmeden gerçek300 saniye beklendi; ardından kimliği doğrulanmış onay RPC'si `confirmed=true` döndü. Bu SQL/API kanıtıdır, native uygulama koşusu değildir. |
| Öneri31 | **73/73 kontrol geçti.** Ayrı DRYRUN'daki13 koşulun tamamı doğru; kasıtlı hata ileri değişikliği geri aldı. |
| Süre sınırları | 10,299,300,350 saniye geç kabulde gerçek kalan pencere;360 ve420 saniyede normal ödül korunarak plan geçersiz, yeni gate yok. |
| Diğer kontroller | Tekrar/eşzamanlı kabul, geç ara2/3 odağı, normal25/50, NULL/gelecek tarih/yabancı kategori reddi, altı bonus kombinasyonu, duraklatılmış son odak, tüm veri korumalı geri alma. |
| Bilinen açık kalan politika | `p_was_paused=true` kabul zamanı penceresi korunur; meşru duraklatma bozulmaz, fakat bu yol için AFK sorunu kapatılmış sayılmaz. |

Kanıtlar: `/tmp/pomosprint_marathon_anchor_before.log`, `/tmp/pomosprint_marathon_anchor_after.log`; kalıcı yerel yapılandırılmış çıktılar `build/overnight_backend/marathon_anchor_before.json`, `marathon_anchor_after.json`, `marathon_pause_semantics.json`.

Paketler: [ileri](../supabase/proposed/31_marathon_completion_anchor.sql), [DRYRUN](../supabase/proposed/31_marathon_completion_anchor_dryrun.sql), [geri alma](../supabase/proposed/31_marathon_completion_anchor_down.sql), [kapsam ve kullanım](../supabase/proposed/31_marathon_completion_anchor_README.md). Geçmiş SQL tarihleri kontrollü fixture'dır;25/50 dakika doğal çalışma beklenmiş gibi sunulmaz. Native AB aşamaları ayrıca çalıştırılacaktır.

## Genişletilmiş bağımsız inceleme sonrası SQL kapsamı
Son AFTER turu **96/96 PASS**;13/13 DRYRUN bu toplamın içindedir.25dk gecikme300/350 ve50dk araodak(index2/3) gecikme300/350 için yeni fonksiyonun gerçek ürettiği gate üzerinden publicACKbaşarısı ve aynıcandidateUUIDtekrarı doğrulandı.50dk araodak420sngecikmede ilgiliodağın12puan20kumu korunur, planinvalidolur ve yenigateyoktur. Full-plan bonusmatrisindeki öncekiACKgeçmişleri kontrollüfixture'dır; bu ayrı yeni testler gerçekpublicACKçağrılarıdır. KaynakSQL/down/DRYRUNhashleri değişmedi. Kanıt `/tmp/pomosprint_marathon_anchor_after_extended.log`, `build/overnight_backend/marathon_anchor_after.json`.

03:09TR'de eski sunucu sözleşmesiyle ilk gerçekABstart aşaması **1/1+paritePASS** oldu; gerçek25dakikaMaratonbaşlatıldı, nativePID86072/appverisi korunarak OSvecihaz kapatıldı. Bu yalnız başlangıçkanıtıdır, final değildir. `build/overnight_backend/ab_before_start_closed.json`.
