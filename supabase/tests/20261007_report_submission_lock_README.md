# Rapor gönderimi eşzamanlılık düzeltmesi — 8 Ekim 2026 canlıda

8 Ekim'de güncel canlı gövde, yetkiler ve rollback yeniden karşılaştırıldı.
Canlı DRYRUN **23/23** geçip tamamen geri alındı. Kullanıcının canlıya alma
ve production hazırlığı talebi kapsamında incelenen migration, Supabase CLI
Management API ile ayrı transaction içinde uygulandı. Sonrasında mevcut
gövdeyle geri alınan **23/23** fonksiyon senaryosu ve **9/9** salt okuma
kontrolü geçti. Güncel hash `a7ee1b72778b92b59982e5bba8b86c7a`, migration
`20261007110000` kayıtlı. [Güncel QA ve kanıtlar](../../analiz/QA_REPORT_SUBMISSION_LIVE_2026-10-08.md).

7 Ekim 2026 canlı `submit_user_report` tanımı salt okunarak alındı. Aynı
bildiriciden iki eşzamanlı istek duplicate/günlük sayımı INSERT'ten önce
ayrı ayrı geçebiliyor. İzole yerel PostgREST'te aynı hedefe 2 kayıt açıldı;
9 kaydı olan bildirici iki yeni hedefle 11 kayda çıktı.

Yeni gövde, duplicate/sayım/INSERT öncesinde bildirici UUID'sinden türetilen
transaction advisory kilidi alır. Profil satırları kilitlenmez; farklı
bildiricilerin anahtarları ayrıdır. Kilit transaction sonunda bırakılır.
Yer/neden kodları, JSON/imza, açık duplicate için 24 saat ve 10/24h sınırı,
RLS/yetkiler değişmez. Mevcut rapor verisi silinmez/düzenlenmez.

| Kaynak | Durum |
|---|---|
| [İleri migration](../migrations/20261007110000_report_submission_lock.sql) | 8 Ekim'de uygulandı; eski canlı hash ön koşulu içerir, yeniden çalıştırma |
| [DRYRUN](20261007_report_submission_lock_dryrun.sql) | 8 Ekim uygulama öncesi canlı 23/23 true; bilinçli `DRYRUN_RESULT` hatası tüm işlemi geri aldı. Güncel gövde eski hash olmadığından özgün ileri DRYRUN'u tekrar çalıştırma |
| [Rollback](../rollbacks/20261007110000_report_submission_lock_down.sql) | Eski gövdeyi birebir döndürür; eşzamanlılık hatasını da geri getirir |
| [Yerel HTTP yarış testi](20261007_report_submission_lock_local.py) | 7 Ekim tarihsel kanıtı: önce eski hatalar doğrulandı, sonra yeni davranış 7/7 geçti. Bu turda canlı paralel HTTP yarışı yapılmadı |
| Uygulama sonrası fonksiyon kontrolü (ham çıktı §37 temizliğinde kaldırıldı) | 8 Ekim mevcut canlı gövdeyle 23/23; yalnız transaction içinde sentetik hesap/rapor, bilinçli rollback |
| Uygulama sonrası salt okuma (ham çıktı §37 temizliğinde kaldırıldı) | 9/9 hash, migration, RPC/tablo erişimi, RLS, normal seans ve Maraton kontrolü |

8 Ekim kapsam istisnası [AGENTS.md §2.4](../../AGENTS.md) içinde kayıtlıdır;
başka bekleyen paketleri yetkilendirmez. Kökte `supabase db push/reset`
kullanılmaz. Testlerden önce/sonra aynı 4 Auth hesabı, 9 seans,
250 dakika/51 puan/150 kum ve 0 rapor korundu; test hesapları/raporları
kalıcı olmadı, e-posta gönderilmedi. İmza, ACL ve RLS aynı, normal seans RPC
gövdesi ve Maraton `available:true`, mola 300/onay 60 saniye yapılandırması
korundu. 23 senaryo uygulama öncesi ve sonrası tekrarlanmıştır;
46 farklı senaryo veya iki bağlantılı canlı yarış testi değildir.

Salt okuma doğrulaması:

```sql
select md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure));
-- 8 Ekim uygulamadan önce: 547b73d8a9163466b19dafb4b89e9fe3
-- Güncel canlı: a7ee1b72778b92b59982e5bba8b86c7a
select version, name from supabase_migrations.schema_migrations
where version = '20261007110000';
```

Yerel test, ana veritabanına dokunmayan `pomosprint_report_qa_20261007`
kopyasını ve `127.0.0.1:54351` PostgREST'i ister. Genel clone betiğine ek
olarak `ops` şema tanımları da kopyalanmalıdır (`handle_new_user`
`ops.neutral_display_name` kullanır). HTTP testi, iki INSERT'i geçici SHARE
tablo kilidiyle bekleterek yarışı belirginleştirir; ürün gövdesine gecikme
eklemez. Ana ortam/üretim üzerinde çalıştırılmaz. Kopya test sonunda kaldırılır.

7 Ekim izole yerel kanıtı: report_concurrency/summary.json (ham çıktı §37 temizliğinde kaldırıldı).
Yeni davranışta aynı hedef 1 satır/UUID, 9+2 istekte 10 satır,
farklı bildiricilerde bağımsız kabul doğrulandı. Önceki 21 ardışık sözleşme
kontrolü de geçti. DRYRUN öncesi/sonrası hash, ACL ve kayıt sayıları aynı;
down o izole kopyada eski canlı hash'ini ve migration geçmişini geri getirdi.
8 Ekim canlıya uygulanan düzeltme geri alınmadı; yalnız test fixture'ları
geri alındı.
