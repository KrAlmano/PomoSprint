# Canlı Maraton QA — 8 Ekim 2026

**Sonuç:** Maraton'un üç sunucu paketi canlı Supabase `eoosnyakvxmifmexpgxa` projesine uygulandı ve backend doğrulaması geçti. Gerçek 25/50 dakika, **300 sn mola +60 sn “Buradayım” onayı** etkin. Normal seans kaydı ve puan sistemi korunuyor; canlıda kısa kayıt/QA yardımcıları yok.

## Uygulama ve yetkilendirme

Kullanıcı açıkça “canlı sunucuda aç Maratonu” istedi. Bu oturumda yalnız üç incelenmiş paket için genel kullanıcı SQL Editor yöntemi yerine mevcut Supabase CLI Management API kullanıldı. Önce canlı gövdeler, yetkiler ve dört baseline parmak izi doğrulandı; üç DRYRUN ayrı geri alınan transaction'larda çalıştırıldı. Sonra **500 mola → 600 ödül → 700 zorunlu onay**, exact migration gövdeleriyle **tek atomik BEGIN/COMMIT** içinde uygulandı ve PostgREST şema yenilemesi bildirildi. `db push/reset`, diğer bekleyen migration'lar veya down betikleri çalıştırılmadı.

## Gerçekten koşulan kontroller

| Kontrol | Sonuç | Kanıt |
|---|---:|---|
| Kurulum öncesi üç canlı DRYRUN | **155/155** (23+59+73) | Özet (ham çıktı §37 temizliğinde kaldırıldı) |
| Kurulum sonrası sosyal + zorunlu onay fonksiyonları | **96/96** (23+73), fikstürler geri alındı | Özet (ham çıktı §37 temizliğinde kaldırıldı) |
| Yapılandırma, ACL, RLS, sahiplik, eski RPC ve QA kontrolü | **13/13** | Gerçek sonuç (ham çıktı §37 temizliğinde kaldırıldı) |
| Public HTTP şema/yetki kontrolü | **2/2**; Maraton anon 401/42501, app config 200 | HTTP gözlemleri (ham çıktı §37 temizliğinde kaldırıldı) |

Bu sayılar tur/alt küme olarak raporlanır; tekrar edilen kontroller birbirinden bağımsız 264 ürün senaryosu sayılmaz. DRYRUN'ların bilinçli `DRYRUN_RESULT`/CLI exit1 sonucu beklenen rollback'tir. Bir salt okuma kontrolünün beklenen JSON literalindeki taslak parantez hatası düzeltildi; ürün SQL'i değişmedi, ilk hata logu korundu.

Altı 25/50 ×2/3/4 planında tam onaylı setin bonusu bir kez verildi; seans/profil/lig/dakika/kum tutarlı kaldı. Duplicate, metadata/indeks çatışması, erken/geç/yanlış sahip veya UUID onayı, yanıt kaybı tekrarı, günlük tavan, duraklatma cezası ve hesap silme cascade sınandı. Bileti yeniden okumak pencereyi uzatmaz. Eksik/yanlış/geç devam onayı, geçerli normal seansı ve normal puanını korur; Maraton bonusunu kapatır. Molalar çalışma dakikası/puan/kum üretmez. Sosyal odak/mola ayrımı, arkadaş ve engelleme/gizlilik filtreleri, süre aşımı ve odak/iptalde mola temizliği yeşildir.

| Plan | Sabit ek puan | Yeni, serisiz ve duraklatılmamış hesapta toplam |
|---|---:|---:|
| 25 dk ×2/3/4 | +2/+3/+5 | 12/18/25 puan; 40/60/80 kum |
| 50 dk ×2/3/4 | +4/+6/+10 | 28/42/58 puan; 40/60/80 kum |

Dört özel Maraton tablosunda RLS açık, anon/authenticated doğrudan erişimi kapalıdır. Yeni altı RPC authenticated'a açık, anon'a kapalıdır. Özel onay öncesi ödül RPC'si anon/authenticated/service_role'a kapalıdır. SECURITY DEFINER sahipleri ve güvenli search path doğrulandı. Normal `complete_study_session` md5 **f0f2b9bcc09ae8440a66d889b5f22fcc**, eski arkadaş RPC'si değişmedi.

## Veri etkisi ve kapsam

SQL fikstürleri yalnız rollback transaction'ında oluşturuldu; kalıcı test hesabı/seans/arkadaşlık veya e-posta yok. Başlangıç ve son canlı sayım aynı: **4 kullanıcı/profil, 9 seans, 250 dakika/51 puan/150 kum**; kategori/lig/üyelik/abone sayımları da eşit. Fikstürlerde tarihsel makbuzlar kullanılması, yeni canlı native 25/50 dakikalık duvar saati testi değildir. Önceki gerçek süreli yerel gece kanıtı [ayrı rapordadır](QA_OVERNIGHT_REAL_2026-10-08.md).

## Üretime bağlı native uygulama kontrolü

Normal `lib/main.dart`, değişmemiş canlı `.env` ve gerçek sürelerle iPhone16Plus/iOS18.6 üzerinde açıldı. Yalnız bu iş için yeni, e-posta göndermeyen bir QA hesabı oluşturuldu. Altı 25/50 ×2/3/4 planının bonusu, çalışma/mola toplamı, 300/60 kılavuzu ve Türkçe/İngilizce popup native UI'da doğru görüldü. 25×2 Maraton gerçek25 dakikalık sayaçla başladı; duraklatma1/1→0/1, yatay kontrol, devam ve **process terminate→launch** sonrasında23:34/0/1 ve plan korundu. Tamamlanmadan iptal edildi. Normal50 de gerçek50:00'dan başladı ve sıfırlandı. Günlük/Haftalık/Aylık raporda kayıt yok; ilk seans bitmeden lig üyeliği yok; boş sosyal ekran doğru.

Bağımsız backend GET'lerinde Maraton odağı yaklaşık1498sn, normal50 odağı2980sn ve mola boştu. Native iptaller sonrası0seans/0puan/0kum/0dk, aktif odak/mola null doğrulandı. QA hesabı sıkı UID/metadata/host guard ile silindi; profil/kategori cascade ve Auth404 geçti. **Orijinal4profil/9seans/250dk/51puan/150kum ve satır SHA256'ları önce/sonra aynı**, `.env` dosyaları değişmedi. Uygulama canlı giriş ekranında/TR açık; kullanıcı kendi hesabıyla girebilir. Geçici9:41 durum çubuğu temizlendi.

`flutter analyze` temiz; ilgili sekiz Maraton/sosyal test dosyası **53/53**,0atlama geçti. Bu tur yeni native25/50 dakikalık tamamlanma veya300+60sn mola beklemesi yapılmadı; sunucu rollback senaryoları ve önceki gerçek süreli yerel gece kanıtı ayrı kapsamdır. Native UI gözlemleri ve PNG yolları (ham çıktı §37 temizliğinde kaldırıldı), sanitize backend/temizlik kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

Fiziksel iOS/Android, gerçek Google/Apple sağlayıcı girişi, Apple imzalama/TestFlight/mağaza, mağaza gizlilik beyanları ve kullanıcının en son vereceği yasal geliştirici bilgileri açık işlerdir. Canlı Maraton'un etkinleşmesi bütün mağaza koşullarını tamamlamaz. Ayrı yayın incelemesindeki kullanıcı bildirme eşzamanlılık düzeltmesi [kendi raporunda](QA_REPORT_SUBMISSION_LIVE_2026-10-08.md); diğer bekleyen SQL/Edge paketleri bu kapsamda uygulanmadı.

Ayrıntılı backend incelemesi ve tüm kanıtlar (ham çıktı §37 temizliğinde kaldırıldı), [sunucu kurulum/geri alma rehberi](../supabase/tests/20261007_marathon_README.md). Geri alma 700→600→500 sırası aktif plan/outbox geçiş planı gerektirir; bu tur geri alma yapılmadı.
