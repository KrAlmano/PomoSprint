# Rapor gönderimi eşzamanlılık düzeltmesi — hazırlanmış, canlıda değil

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
| [İleri migration](../migrations/20261007110000_report_submission_lock.sql) | Hazır; eski canlı gövdenin hash'ini ön koşul olarak ister |
| [DRYRUN](20261007_report_submission_lock_dryrun.sql) | 23/23 true; bilinçli `DRYRUN_RESULT` hatası tüm işlemi geri alır |
| [Rollback](../rollbacks/20261007110000_report_submission_lock_down.sql) | Eski gövdeyi birebir döndürür; eşzamanlılık hatasını da geri getirir |
| [Yerel HTTP yarış testi](20261007_report_submission_lock_local.py) | Önce eski hatalar doğrulandı, sonra yeni davranış 7/7 geçti |

Canlıda kullanıcı önce DRYRUN'u SQL Editor'de çalıştırmalı; her madde
`true` olmalı. Sonra ileri migration'ı çalıştırabilir. Ajan bu dosyaları
canlıya uygulamadı; kökte `supabase db push/reset` kullanılmaz.

Salt okuma doğrulaması:

```sql
select md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure));
-- Eski canlı: 547b73d8a9163466b19dafb4b89e9fe3
-- Yeni gövde: a7ee1b72778b92b59982e5bba8b86c7a
select version, name from supabase_migrations.schema_migrations
where version = '20261007110000';
```

Yerel test, ana veritabanına dokunmayan `pomosprint_report_qa_20261007`
kopyasını ve `127.0.0.1:54351` PostgREST'i ister. Genel clone betiğine ek
olarak `ops` şema tanımları da kopyalanmalıdır (`handle_new_user`
`ops.neutral_display_name` kullanır). HTTP testi, iki INSERT'i geçici SHARE
tablo kilidiyle bekleterek yarışı belirginleştirir; ürün gövdesine gecikme
eklemez. Ana ortam/üretim üzerinde çalıştırılmaz. Kopya test sonunda kaldırılır.

Kanıt: [report_concurrency/summary.json](../../analiz/qa_evidence_20261007/backend/report_concurrency/summary.json).
Yeni davranışta aynı hedef 1 satır/UUID, 9+2 istekte 10 satır,
farklı bildiricilerde bağımsız kabul doğrulandı. Önceki 21 ardışık sözleşme
kontrolü de geçti. DRYRUN öncesi/sonrası hash, ACL ve kayıt sayıları aynı;
down eski canlı hash'ini ve migration geçmişini geri getirdi.
