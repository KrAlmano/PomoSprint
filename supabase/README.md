# Supabase çalışma rehberi

> **28 Ekim 2026:** Yeni TUS/Deneme/aylık kategori ligleri [27→28→29 rehberi](proposed/NIGHT_20261028_README.md) altında proposed olarak hazırlanmıştır. Canlıya uygulama yok; aşağıdaki canlı14gün bilgisi sunucu değişikliği onaylanana kadar tarihsel mevcut davranıştır.

Bu klasör, PomoSprint'in Supabase SQL kaynaklarını, geri almalarını, dryrun'larını, Edge Functions'larını ve Auth e-posta şablonlarını içerir. **Git deposundaki migration sırası canlı Supabase migration geçmişinin aynısı değildir.** Yeni bir veritabanı kurmak veya canlıyı değiştirmek için bu klasörü körlemesine `db push` ile çalıştırma.

Canlı proje: `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, `eu-north-1`. Kaynak önceliği ve canlı salt okuma sorguları için kök [AGENTS.md §2](../AGENTS.md); proje geneli ve tarihli QA için [PROJE_DEVIR.md](../PROJE_DEVIR.md).

## Klasörler

| Yol | Ne içerir | Güvenli kullanım |
|---|---|---|
| `migrations/` | İleri migration dosyaları; aralarında legacy/tarihsel ve güncel paketler var | Her dosyanın canlıya uygulandığını varsayma; aşağıdaki durum tablosuna bak |
| `proposed/` | Ön koşul ve canlı gövde parmak izleriyle sıralanmış paketler | Çoğu 5 Ekim'de canlıya uygulandı; yeniden uygulamak için değil, tarihçe/DRYRUN için. `proposed/README.md` oku |
| `rollbacks/`, `proposed/*_down.sql` | Ters işlemler | Yıkıcı olabilir; sırayla ve veri kaybı notlarıyla incele |
| `tests/` | Yerel Postgres, geri alınan live dryrun, paket doğrulama | Live dryrun kullanıcı tarafından SQL Editor'de uygulanır; betiklerin bir kısmı bilerek hata ile rollback eder |
| `functions/` | Deno Edge Functions | Deploy/JWT ayarı fonksiyonun kendi README'sine göre |
| `auth-email-templates/` | Supabase panelindeki elle tutulan Auth şablon kopyaları | Paneldeki son durumla ayrıca karşılaştır |

## Canlı migration durumu

Aşağıdaki zincir geçmişi 5 Ekim kaydından gelir. **8 Ekim'de Maraton için canlı fonksiyon gövdeleri, parmak izleri, yetkiler, RLS, bağımlı trigger'lar ve migration geçmişi yeniden okundu; üç Maraton paketi uygulanıp doğrulandı. Rapor gönderimi eşzamanlılık düzeltmesi de ayrıca güncel canlı tanımla karşılaştırılıp uygulanarak doğrulandı.** Bu okuma diğer bekleyen paketlerin tümünü yeniden doğrulamış sayılmaz. Yeni canlı işlem öncesi güncel katalog ve sözleşmeyi tekrar salt okunur doğrula.

| Paket | Kayıtlı durum (Maraton/rapor:8 Ekim 2026; diğer zincir:5 Ekim) |
|---|---|
| `20261009233000_remove_unowned_ronin` | **9 Ekim canlıda; kullanıcı SQL Editor’de uyguladı.** Kurulum sonrası20/20saltokuma: Ronin0,48toplam/47aktif/21özel/7ücretsiz. DörtAuth/profil,dokuzseans,11kategori,42unlock ve ekonomi/seans hash’leri korundu. BeşavatarRPC+silmeRPC/RLS/ACL/FK/triggerler aynı; katalogMD5 `9ad12fc8edb016c69eb45a24f4ac1e11`. İzole24/24veDRYRUN12/12 ayrı kapsamdır. [Rehber](tests/20261009_remove_unowned_ronin_README.md), [QA](../analiz/QA_RELEASE_CLEANUP_2026-10-09.md). İleri paketi yeniden çalıştırma; sahiplik/kuşanma guard’ını gevşetme |
| `20261009190000_special_avatar_catalog` | **9 Ekim canlıda; kullanıcı SQL Editor'de uyguladı.** Kurulum sonrası tarihsel salt okuma16/16 ve public katalog25/25:49 toplam/48 aktif/22 özel/7 aktif ücretsiz, her özel500kum. Ronin kaldırıldıktan sonra güncel48/47/21/7 yukarıdaki pakettedir. Önceki27 avatar ve5RPC/ACL/RLS aynı; MD5 `5e80e532aa71a325edd1d76e96183fb5`. Önceki izole118/118 ve10/10 DRYRUN ayrı kanıttır; ileri/DRYRUN dosyalarını yeniden çalıştırma. Kullanılmış/kuşanılmış avatar varsa down reddeder. [SQL rehberi](tests/20261009_special_avatar_catalog_README.md), [QA](../analiz/QA_SPECIAL_AVATARS_2026-10-09.md), [devir §35](../PROJE_DEVIR.md) |
| `migrations/20260809*`, `20260928120000_security_hardening_up` | Canlı migration geçmişinin kopyası değil; bazı fonksiyon gövdeleri canlıda farklı. Bunları yeni canlı/staging ortamına sıradan güncel migration gibi uygulama |
| `migrations/20261003150000_live_audit_fixes.sql` | 3 Ekim'de canlıya uygulanmış, 28 dryrun kontrolü geçmiş |
| `12 → 15 → 16 → 19 A → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25 → 26` | 5 Ekim'de sıralı uygulanmış; ilgili dryrun/md5/katalog kontrolleri o işlemde geçmiş |
| `19 B` | Uygulanmadı. Site gerçek onay payload'ını gönderip doğrulayana kadar zorunlu kılma aşaması bekliyor |
| `proposed/01–11` | Bu sıranın yerine kullanılamaz; bazıları sonraki paketlerle geçersiz/tekrar işlenmiş. Tek tek `proposed/README.md` durumuna bak |
| `migrations/20261007110000_report_submission_lock.sql` | **8 Ekim'de canlıya uygulandı.** Bildirici başına transaction advisory kilidi eşzamanlı duplicate/10 sınırını korur; güncel hash `a7ee1b72778b92b59982e5bba8b86c7a`. Canlı DRYRUN 23/23, uygulama sonrası geri alınan 23/23 fonksiyon ve 9/9 salt okuma kontrolü; mevcut veriler, ACL ve normal seans/Maraton sözleşmeleri aynı. [Rehber ve tarihsel HTTP yarışı](tests/20261007_report_submission_lock_README.md), [canlı QA](../analiz/QA_REPORT_SUBMISSION_LIVE_2026-10-08.md). İleri dosyayı yeniden çalıştırma |
| `20261008190000_league_launch_policy` | **8 Ekim canlıda.** Oda25/hazırlık/global14gün/yeterlilik; exactSHA dac9176d…; önce55/55rollback, atomikuygulama, sonra55/55rollback ve18/18veri/ACL. Normal yalnızgeçilküyelik guard MD5 `72023f3f4d8636363cf0231f42d4c7e1`, Maraton gövdeleriaynı. [SQL rehberi](tests/20261008_league_launch_policy_README.md), [QA](../analiz/QA_LEAGUE_LAUNCH_2026-10-08.md). Yenidençalıştırma; down yalnızresmistartöncesi |
| `20261007150000_marathon_break_presence` → `20261007160000_marathon_rewards` → `20261007170000_marathon_presence_confirmation` | **8 Ekim'de canlıya uygulandı.** Kullanıcının açık canlıya alma talebiyle exact üç gövde tek atomik transaction; önce canlı23+59+73 DRYRUN, sonra96 geri alınan fonksiyon ve13 salt okuma sözleşme/güvenlik kontrolü geçti. Gerçek300+60 sn, bonus25dk:+2/+3/+5 ve50dk:+4/+6/+10, normal RPC aynı, QA helper0. [Sözleşme/geri alma](tests/20261007_marathon_README.md), canlı kanıt (ham çıktı §37 temizliğinde kaldırıldı). İleri paketleri yeniden çalıştırma |

5 Ekim'deki zincir DRYRUN sonuçları ve down testi `proposed/README.md`'de kayıtlıdır. Bu eski başarı kaydı yeni değişikliğin veya yeni canlı durumun doğrulaması yerine geçmez.

## Canlı SQL değişiklik akışı

1. `supabase/README.md` ve `proposed/README.md` ilgili bölümlerini, sonra canlı tanım ve yetkileri oku. `pg_get_functiondef`'i canlıdan al; eski migration gövdesini kaynak alma.
2. Önce çözülmesi gereken ürün/KVKK kararı varsa uygulamayı durdurup kaydet.
3. Yeni zaman damgalı ileri migration yaz. Canlı tanımın önceki hâlini içeren rollback ve `BEGIN`/kontroller/`ROLLBACK` yapan dryrun ekle.
4. Önce staging veya izole zincir DB'sinde doğrula. Canlı DRYRUN kullanıcı SQL Editor'de çalıştırılır; bütün ASSERT sonuçları beklenen olmalı ve transaction geri alınmalı.
5. Kullanıcı onayı ve bakım planı olmadan canlıya yazan SQL/CLI çalıştırma. Onaylı canlı değişiklikte dryrun, migration ve katalog/yetki doğrulamasını ayrı uygula.
6. `AGENTS.md` sözleşme tablosu ve ilgili QA/devir belgelerini güncelle.

8 Ekim Maraton talebinde kullanıcı uygulamayı canlıya açmamızı ve production hazırlığını açıkça yetkilendirdi; üç Maraton paketi için SQL Editor yerine mevcut Supabase CLI Management API yolu kullanıldı. Önce her geri alınan DRYRUN (önceki paket bağımlılıkları aynı transaction içinde), sonra tek atomik ileri transaction ve `NOTIFY pgrst, 'reload schema'`, sonra geri alınan fonksiyon testleri ve salt okuma doğrulaması yapıldı. Yayın hazırlığında bilinen `report_submission_lock` hatası ayrıca incelendi; canlı eski hash/rollback eşleşmesi ve 23/23 DRYRUN sonrası yalnız bu düzeltme ayrı transaction ile uygulandı, ardından geri alınan 23/23 senaryo ve 9/9 salt okuma geçti. Bu önceki istisna yalnız o dört paketi kapsar; `proposed/19` B veya başka bekleyen paket yetkilendirilmedi, `db push/reset` yasağı sürer.

8 Ekim daha sonraki “gerekli lig ayarlamalarını yap / mevcutlige aktar / başlangıç25” talebi yalnız yeni `20261008190000_league_launch_policy` için dar uygulama yetkisi olarak kaydedildi. Yeni güncelcanlıhashönkoşulları, izole89/89, canlırollback55/55, atomikCLIuygulaması ve son55/55rollback/verikoruma denetimleri [§29](../PROJE_DEVIR.md) ve ligQA'dedir. BaşkaSQL/Edge/ödeme/plan paketine yetki değildir.

**Kökte `supabase db push` / `db reset` kullanma.** Migration baseline işi tamamlanmadan CLI eski dosyaları yeniden uygulayabilir. `supabase link` ve `db push` yerel test talimatı değildir.

## İzole yerel test

Canlıya bağlanmayan Docker kopyası `tool/local_supabase/` altındadır:

```sh
open -a Docker
supabase start --workdir tool/local_supabase
python3 tool/local_supabase/smoke_test.py
```

URL/portun, mail kutusunun, reset sınırlarının ve normal süreli E2E komutlarının ayrıntısı [tool/local_supabase/README.md](../tool/local_supabase/README.md). **Yerel test kullanıcıları ve `db reset` yalnızca o workdir içindir.**9Ekim’de yerel proje veri hacimleri silindi; hazır hesap yoktur. Eski hızlı kayıt/helper yolu kaldırıldı; güncel snapshot yeni canlıyla eşit varsayılmaz.

`tests/run_local.sh` tek kullanımlık yerel PostgreSQL testi içindir; canlı şema tarihçesini otomatik kurduğu anlamına gelmez. `tests/*_dryrun.sql` dosyalarının bir bölümü canlı SQL Editor'e yapıştırılmak üzere kendini rollback eder; `run_local.sh` ile aynı amaca sahip değildir.

## Edge Functions

JWT ayarı endpoint sözleşmesinin parçasıdır:

- `unsubscribe`: kullanıcı tarayıcısından POST alır, **JWT doğrulaması kapalı** deploy gerekir; token'ı fonksiyon doğrular. Ayrıntı [`functions/unsubscribe/README.md`](functions/unsubscribe/README.md).
- `delete-account`: **JWT doğrulaması açık** olmalı. Repo kodu Apple token iptali ve e-posta ilişkili kayıt temizliği içerir; 5 Ekim proje kaydında henüz canlıya deploy edilmedi. İstemci 404/5xx'te canlı `delete_own_account` RPC yedeğine düşer. Canlı deploy/secrets durumu yeni işlem öncesi yeniden doğrulanmalı. Ayrıntı [`functions/delete-account/README.md`](functions/delete-account/README.md).
- `send-welcome-email`: Auth/waitlist tanıtım postasıdır; `functions/unsubscribe`'dan farklıdır. 5 Ekim kaydında repo sürüm v9 yayında, fakat `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` gönderici kimliği tanımlanmadığından tanıtım e-postası ve bülten bilinçli olarak kapalıdır. Auth kayıt/parola sıfırlama postası bundan ayrıdır. Kaynak [`auth-email-templates/README.md`](auth-email-templates/README.md).

Deno birim testleri ve Edge testleri için `cd scripts && npm test`. Canlı deploy komutları verilmiş README'lerdeki JWT uyarılarını değiştirmeden kullan; bir `--no-verify-jwt` bayrağını tüm fonksiyonlara genelleme.
