# Supabase çalışma rehberi

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

Aşağıdaki durum `AGENTS.md` ve 5 Ekim tarihli doğrulama kaydından aktarılmıştır. **Bu README güncellenirken canlı DB'ye sorgu atılmadı.** Canlıda işlem yapmadan önce güncel fonksiyon, tablo, yetki, RLS, trigger, cron ve migration geçmişini salt okunur doğrula.

| Paket | Kayıtlı durum (5 Ekim 2026) |
|---|---|
| `migrations/20260809*`, `20260928120000_security_hardening_up` | Canlı migration geçmişinin kopyası değil; bazı fonksiyon gövdeleri canlıda farklı. Bunları yeni canlı/staging ortamına sıradan güncel migration gibi uygulama |
| `migrations/20261003150000_live_audit_fixes.sql` | 3 Ekim'de canlıya uygulanmış, 28 dryrun kontrolü geçmiş |
| `12 → 15 → 16 → 19 A → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25 → 26` | 5 Ekim'de sıralı uygulanmış; ilgili dryrun/md5/katalog kontrolleri o işlemde geçmiş |
| `19 B` | Uygulanmadı. Site gerçek onay payload'ını gönderip doğrulayana kadar zorunlu kılma aşaması bekliyor |
| `proposed/01–11` | Bu sıranın yerine kullanılamaz; bazıları sonraki paketlerle geçersiz/tekrar işlenmiş. Tek tek `proposed/README.md` durumuna bak |

5 Ekim'deki zincir DRYRUN sonuçları ve down testi `proposed/README.md`'de kayıtlıdır. Bu eski başarı kaydı yeni değişikliğin veya yeni canlı durumun doğrulaması yerine geçmez.

## Canlı SQL değişiklik akışı

1. `supabase/README.md` ve `proposed/README.md` ilgili bölümlerini, sonra canlı tanım ve yetkileri oku. `pg_get_functiondef`'i canlıdan al; eski migration gövdesini kaynak alma.
2. Önce çözülmesi gereken ürün/KVKK kararı varsa uygulamayı durdurup kaydet.
3. Yeni zaman damgalı ileri migration yaz. Canlı tanımın önceki hâlini içeren rollback ve `BEGIN`/kontroller/`ROLLBACK` yapan dryrun ekle.
4. Önce staging veya izole zincir DB'sinde doğrula. Canlı DRYRUN kullanıcı SQL Editor'de çalıştırılır; bütün ASSERT sonuçları beklenen olmalı ve transaction geri alınmalı.
5. Kullanıcı onayı ve bakım planı olmadan canlıya yazan SQL/CLI çalıştırma. Onaylı canlı değişiklikte dryrun, migration ve katalog/yetki doğrulamasını ayrı uygula.
6. `AGENTS.md` sözleşme tablosu ve ilgili QA/devir belgelerini güncelle.

**Kökte `supabase db push` / `db reset` kullanma.** Migration baseline işi tamamlanmadan CLI eski dosyaları yeniden uygulayabilir. `supabase link` ve `db push` yerel test talimatı değildir.

## İzole yerel test

Canlıya bağlanmayan Docker kopyası `tool/local_supabase/` altındadır:

```sh
open -a Docker
supabase start --workdir tool/local_supabase
python3 tool/local_supabase/smoke_test.py
```

URL/portun, hesapların, mail kutusunun, reset sınırlarının, kısa kayıt QA modunun ve E2E komutlarının ayrıntısı [tool/local_supabase/README.md](../tool/local_supabase/README.md). **Yerel test kullanıcıları ve `db reset` yalnızca o workdir içindir.** Kısa seans kaydı, ana Postgres'e QA-only RPC ekler; bitince README'deki `quick_recording.py --remove` ile kaldır.

`tests/run_local.sh` tek kullanımlık yerel PostgreSQL testi içindir; canlı şema tarihçesini otomatik kurduğu anlamına gelmez. `tests/*_dryrun.sql` dosyalarının bir bölümü canlı SQL Editor'e yapıştırılmak üzere kendini rollback eder; `run_local.sh` ile aynı amaca sahip değildir.

## Edge Functions

JWT ayarı endpoint sözleşmesinin parçasıdır:

- `unsubscribe`: kullanıcı tarayıcısından POST alır, **JWT doğrulaması kapalı** deploy gerekir; token'ı fonksiyon doğrular. Ayrıntı [`functions/unsubscribe/README.md`](functions/unsubscribe/README.md).
- `delete-account`: **JWT doğrulaması açık** olmalı. Repo kodu Apple token iptali ve e-posta ilişkili kayıt temizliği içerir; 5 Ekim proje kaydında henüz canlıya deploy edilmedi. İstemci 404/5xx'te canlı `delete_own_account` RPC yedeğine düşer. Canlı deploy/secrets durumu yeni işlem öncesi yeniden doğrulanmalı. Ayrıntı [`functions/delete-account/README.md`](functions/delete-account/README.md).
- `send-welcome-email`: Auth/waitlist tanıtım postasıdır; `functions/unsubscribe`'dan farklıdır. 5 Ekim kaydında repo sürüm v9 yayında, fakat `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` gönderici kimliği tanımlanmadığından tanıtım e-postası ve bülten bilinçli olarak kapalıdır. Auth kayıt/parola sıfırlama postası bundan ayrıdır. Kaynak [`auth-email-templates/README.md`](auth-email-templates/README.md).

Deno birim testleri ve Edge testleri için `cd scripts && npm test`. Canlı deploy komutları verilmiş README'lerdeki JWT uyarılarını değiştirmeden kullan; bir `--no-verify-jwt` bayrağını tüm fonksiyonlara genelleme.
