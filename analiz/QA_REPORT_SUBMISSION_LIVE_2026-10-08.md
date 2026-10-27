# Kullanıcı bildirimi eşzamanlılığı — canlı QA, 8 Ekim 2026

`submit_user_report(uuid,text,text,text)` düzeltmesi canlı Supabase
`eoosnyakvxmifmexpgxa` projesine uygulandı. Migration `20261007110000`
kalıcı; güncel gövde MD5'i **a7ee1b72778b92b59982e5bba8b86c7a**.
Kullanıcının “canlı sunucuda aç” ve “productiona hazır olsun” talebiyle,
Maraton paketlerinden ayrıca incelenen bu mevcut güvenilirlik düzeltmesi
Supabase CLI Management API üzerinden tek transaction ile uygulandı.
İleri/geri gövde ve canlı baseline eşleşmesi önce doğrulandı;
`db push/reset`, veri silme ve diğer bekleyen paketler çalıştırılmadı.
Kapsam istisnası [AGENTS.md §2.4](../AGENTS.md) içinde kayıtlıdır.

## Değişiklik ve sonuç

Duplicate denetimi, 24 saatlik sayım ve INSERT öncesinde bildirici UUID'sine
özgü `pg_advisory_xact_lock` alınır. Aynı bildiricinin paralel gönderimleri
sıraya girer; farklı bildiriciler farklı anahtarlar kullanır. Profil satırı
kilitlenmez. İmza/JSON, yer/neden kodları, açıklama sınırı 500 karakter,
açık duplicate için 24 saat ve 10/24h sınırı korunur. Tablo, RLS ve ACL aynı.
Eski MD5 `547b73d8a9163466b19dafb4b89e9fe3`, yalnız bu kilitle
yeni MD5'e geçti. Kaynak eşleşmesi (ham çıktı §37 temizliğinde kaldırıldı),
uygulama çıktısı (ham çıktı §37 temizliğinde kaldırıldı).

| Bu turda gerçekten çalıştırılan kontrol | Sonuç |
|---|---|
| Uygulama öncesi canlı DRYRUN | **23/23**; bilinçli `DRYRUN_RESULT`/CLI exit1 ile bütün transaction geri alındı |
| Kalıcı migration | Başarılı; CLI exit0, yeni gövde ve migration kaydı sonraki katalog okumasında mevcut |
| Uygulama sonrası mevcut RPC ile fonksiyon senaryoları | **23/23**; geçerli/duplicate rapor, self/null/eksik hedef, bozuk yer/neden, normalize 500 karakter, 10 kabul/11. ret, erişim/ACL/migration. Fixture'lar bilinçli rollback ile geri alındı |
| Uygulama sonrası salt okuma | **9/9**; hash, migration, sahip/güvenli search_path/ACL, authenticated açık/anon kapalı RPC, özel rapor tablosu RLS/erişim, normal seans ve Maraton sözleşmesi |
| Önce/sonra tam snapshot | Eşit; kalıcı test hesabı veya rapor yok, e-posta gönderilmedi |

23 senaryo iki aşamada tekrarlanmıştır; 46 farklı senaryo olarak sayılmaz.
DRYRUN özeti (ham çıktı §37 temizliğinde kaldırıldı),
son fonksiyon özeti (ham çıktı §37 temizliğinde kaldırıldı),
9 kontrol (ham çıktı §37 temizliğinde kaldırıldı),
tam kanıt özeti (ham çıktı §37 temizliğinde kaldırıldı).

Mevcut **4 Auth hesabı/4 profil, 9 seans, 11 kategori, 3 bülten kaydı;
250 dakika/51 puan/150 kum ve 0 rapor** korundu. Test kullanıcıları yalnız
transaction içinde `example.invalid` adresleriyle oluşturuldu; Auth/SMTP
gönderim çağrısı yapılmadı. Normal seans RPC MD5'i
`f0f2b9bcc09ae8440a66d889b5f22fcc` aynı. Maraton hâlâ `available:true`,
mola 300/onay 60 saniye; 25 dk bonusları 2/3/5, 50 dk bonusları 4/6/10.
Testten önce (ham çıktı §37 temizliğinde kaldırıldı),
testten sonra (ham çıktı §37 temizliğinde kaldırıldı).

## Yarış testi kanıtının sınırı

**7 Ekim izole yerel gerçek iki bağlantılı HTTP testi** eski gövdede aynı
hedefe 2 kayıt ve günlük 9→11 aşımını üretti. Aynı yeni gövdeyle 7/7 kontrolde
aynı hedef 1 kayıt/aynı UUID, günlük 10 sınırı ve farklı bildiricilerin bağımsız
kabulü doğrulandı; önceki 21 sözleşme kontrolü de geçti.
Tarihsel yarış kanıtı (ham çıktı §37 temizliğinde kaldırıldı).
Bu turda canlıda yeni paralel HTTP yarışı çalıştırılmadı. Güncel canlı kanıtı
o doğrulanmış gövdenin birebir kurulması, geri alınan ardışık 23 senaryo ve
salt okuma 9 kontroldür.

İleri migration'ın yalnız başlık yorumu canlı durumla güncellendi;
SQL transaction gövdesi değişmedi. Rollback eski gövdeyi ve yarışı geri
getirir, bu turda üretimde çalıştırılmadı.
[Paket rehberi](../supabase/tests/20261007_report_submission_lock_README.md).
Bu backend düzeltmesi fiziksel cihaz, Apple sağlayıcısı, mağaza imzası veya
eksik resmî geliştirici/KVKK bilgilerinin tamamlandığı anlamına gelmez.
