# Öneri 33 — Deneme başlangıçlarında hesap başına sınır

**1 Kasım 2026: 33 canlıya uygulandı. Yeniden çalıştırmayın.** Kurulum öncesi canlı `start_exam_attempt(uuid,text)` gövdesinin MD5 değeri `8928a4a7c25c61fe1f92f874935d208d`. İstemci önce aynı UUID ile kaydı tekrar sorgulayabildiği için ağ kesintisi/tekrar denemesinde geçerli makbuzlar sınırda da döner. Başka sınavla aynı UUID kullanımı mevcut `exam_metadata_conflict` davranışını korur.

Yeni UUID ile bir hesabın son 24 saatteki deneme başlangıçları 100'e ulaşmışsa, yeni kayıt `exam_start_rate_limited` hatası ile reddedilir. Aktif deneme bitirme/terk etme, eski deneme okunması ve sonuçların değiştirilmesi etkilenmez. 100 sınırı aynı canlı sistemde normal seans başlangıçları için kullanılan günlük korumayla uyumlu bir üst sınırdır; kötüye kullanım için global/IP düzeyinde koruma veya hesap oluşturma limiti değildir. Hata kodunun istemcide bağlantı hatası gibi gösterilmemesi için kullanıcıya anlaşılır TR/EN mesajı ile istemci uyumu sağlanmalıdır. Zamana dayalı hesap server saatindedir ve mevcut `(user_id, started_at DESC)` indeksi kullanılır.

Gövde güncel canlı hash ile tek bir bilinen yere ek yapar; kaynak değişmiş veya yedek var ise kurulum durur. Aynı kullanıcı için mevcut `profiles FOR UPDATE` kilidi eşzamanlı 99→100 yarışını serileştirir. Öneri dosyaları `\\echo`/`\\quit` ile doğrudan CLI uygulamasına kapalıdır. İleri ve DRYRUN dosyaları kurulmuş canlıda yeniden çalıştırılmamalıdır. 1 Kasım kurulum öncesi salt-okuma canlıda fonksiyon hash'i, SECURITY DEFINER/search_path, tam ACL `{postgres=X/postgres,authenticated=X/postgres}`, attempts RLS ve `exam_attempt_owner_started` geçerli indeksini; yedek ve migration işareti yokluğunu doğruladı. Bu ön kontrol tarihsel kurulum öncesi durumu anlatır; canlıda 33 zaten kuruludur. Editör paketleri sunucu tablosu üzerinde kısa `ACCESS EXCLUSIVE ... NOWAIT` kilitleri alır: aktif sorgu veya işlem varsa derhal hata verip durur, boşken de COMMIT/ROLLBACK'a kadar profil ve deneme okumaları dahil diğer erişimler bekleyebilir. `lock_timeout=1s`, `statement_timeout=12s`; aktif trafiğin en az olduğu an seçilmeli ve kilit hatasında tekrar deneme daha sonra yapılmalıdır.

- `33_exam_start_rate_guard.sql`: ileri aday; tam eski fonksiyonu RLS etkin, API rollerine kapalı yedekte saklar.
- `33_exam_start_rate_guard_dryrun.sql`: yalnız yapısal 6 kontrol ve rollback; test hesabı oluşturmaz.
- `33_exam_start_rate_guard_down.sql`: yalnız kaynak/kurulu hash eşleşirse tam eski fonksiyonu geri yükler. Deneme kayıtları silinmez. Bilinmeyen yeni fonksiyon gövdesinde reddeder.

## Yerel kanıt

Kişisel veri kullanılmayan yerel QA şeması `pomosprint_review32_kpss`'ten oluşturulmuş geçici ve ayrı `pomosprint_security_audit_20261101` klonunda denendi; mevcut canlıya yazılmadı. DRYRUN **6/6**, izole gerçek DB/RPC ile `tool/local_supabase/e2e/exam_start_rate_guard_test.py` **12/12** geçti: hızlı başlat/vazgeç, 100/24s sınırı, yeni UUID reddi, eski UUID ve metadata çakışması, 24 saat iki yanı, ayrı hesap ve eşzamanlı 99→100 yarışı dahil. Down sonrası canlı eski gövde MD5'i geri geldi, authenticated/anon yetkisi korundu ve yedek/migration işareti kaldırıldı; yeniden DRYRUN da 6/6 geçti. Bu testler kullanıcı gerçek cihazı, küresel yük veya gerçek production API trafiği testi değildir.

## SQL Editor hazırlığı ve canlı kurulum

- `supabase/tests/20261101_exam_rate_33_DRYRUN_SQL_EDITOR.sql`: tek transaction, ileri kodunun aynısı ve 6 kontrol, sonunda ROLLBACK. SQL Editor için psql `\quit` içermez; bu dosya geçici de olsa yukarıdaki kilitleri alır.
- `supabase/tests/20261101_exam_rate_33_APPLY_SQL_EDITOR.sql`: ayrı tek transaction içinde aynı hash/ACL/RLS/indeks ön koşulları ve NOWAIT kilitleriyle uygular; **çalıştırıldığında canlıyı değiştirir**. Öncesinde başarılı güncel DRYRUN ve uygulama sahibinin dağıtım kararı gereklidir.
- `supabase/tests/20261101_exam_rate_33_POSTFLIGHT_SQL_EDITOR.sql`: yalnız okuma; altı alanın tamamı true olmalıdır.
- `supabase/tests/20261101_exam_rate_33_DOWN_SQL_EDITOR.sql`: yalnız önceki ve yeni hash ile fonksiyon ACL tam eşleşirse geri alır. Kayıtlar etkilenmez; aynı NOWAIT/timeout sınırlaması geçerlidir.

Yerel clone üzerinde SQL Editor dosyalarıyla DRYRUN 6/6, yeni APPLY sonrası 12/12 RPC, DOWN sonrası önceki fonksiyon ve tam ACL paritesi doğrulandı. Paralel işlem profil tablosunu tuttuğunda DRYRUN NOWAIT anında durdu; değiştirilmiş authenticated ACL ile `exam_rate_acl_changed` beklenen biçimde engelledi. Normal canlı uygulama trafiği veya gerçek cihazla test yapılmadı. Mevcut eski istemciler sınır aşılırsa genel hata gösterebilir; yeni TR/EN mesajı yalnız güncel istemci dağıtılınca herkese ulaşır.

## Canlı sonuç — 1 Kasım 2026

Ana ajan, kullanıcının Safari SQL Editor yetkisiyle güncel DRYRUN'u çalıştırdı: **6/6**, ardından eski hash ve migration işaretinin yokluğu doğrulandı. Sonra yalnız 33 kurulumu yapıldı ve SQL Editor postflight altı kontrolü true döndü. Bu kayıt hazırlanırken bağımsız **salt okunur** sorguda da 33 kurulu hash'i `ce55b651dbb65b94909f1ed09b587a0c` olarak korumalı yedekteki kurulu hash ile eşleşti; eski gövde hash'i `8928a4a7c25c61fe1f92f874935d208d`, ACL, RLS, özel yedek ve migration işareti doğrulandı. Canlıda sentetik hesap veya davranış testi yapılmadı; gerçek trafik/istemci testi için bu sonuç garanti değildir.

Aynı salt okunur sorguda 31 migration işareti yok ve dış Maraton fonksiyonunun 31 öncesi hash'i değişmemiş; 34 migration/backup yok, `unverified_session_daily_cap` JSON null kalmıştır. Dolayısıyla 33 yalnız deneme başlangıç kotasını korur; normal seanslarda doğrulanmamış ödül riski 34 etkinleştirilmedikçe devam eder. Eski istemciler nadir kota hatasını genel hata gibi gösterebilir; yeni TR/EN mesajları ancak yeni sürüm dağıtıldığında kullanıcılara ulaşır.
