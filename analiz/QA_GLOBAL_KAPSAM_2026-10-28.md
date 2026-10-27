# Kategori ve Global lig: doğrudan kapsam doğrulaması

28 Ekim 2026 gece yerel denetiminde **46/46 assertion geçti**. Bu sayı 46 bağımsız kullanıcı yolculuğu değildir; kaynak/clone korumalarını, fixture doğrulamalarını, 32 görünüm/yan etki assertion'ını ve temizliği içerir. Yeni ürün veya sunucu davranışı eklenmedi.

Kaynak: [overnight_global_scope_check.py](../tool/local_supabase/e2e/overnight_global_scope_check.py).

## Neden ayrı kontrol eklendi?

Önceki `global_has_other_target_rows` testi Global satır sayısının tek oda satırından fazla olduğunu denetliyordu. 25+1 aynı-hedef oda da bu koşulu sağlayabilir. `global_does_not_award_again` yalnız uygunluk bayraklarını denetliyordu. Yeni kontrol, bu iki iddiayı doğrudan kullanıcı kimlikleri ve veri değişmezliğiyle sınar; önceki 21/21 süitin yerine geçmez.

## İzolasyon

- Kaynak, sabit `127.0.0.1:54322/pomosprint_night_backend` yerel inceleme veritabanıdır. Ana `postgres` uygulama verilerine ve devam eden native probe hesaplarına yazılmadı.
- Kaynaktan yalnız şema ve açıkça listelenmiş katalog/ayar tabloları okundu. **Auth veya kullanıcı verisi kopyalanmadı**; yeni clone'da başlangıç kullanıcı sayısı 0 doğrulandı.
- Sabit adlı `pomosprint_night_global_scope` clone yoksa oluşturulur; varsa araç üzerine yazmayı/silmeyi reddeder.
- Orijinal fonksiyon sahipleri, ACL ve SECURITY DEFINER rolleri korundu. İlgisiz newsletter trigger'ı yalnız clone'da kapatıldı; gerçek mail, REST veya canlı servis çağrısı yapılmadı.
- Araç, yalnız kendi oluşturduğu clone'u sonunda sildi; son assertion clone'un bulunmadığını doğruladı. Geçici SQL dosyaları `TemporaryDirectory` ile temizlendi.

## İşlevsel senaryo

Clone'da dört yeni yerel hesap oluşturuldu: iki LGS, iki TUS. Her hesaba standart public tamamlama RPC'siyle 25 dakikalık normal çalışma ve kendi hedefinde tamamlanmış bir Deneme kaydı hazırlandı. Deneme başlangıcı normal RPC ile, eski başlangıç/bitiş zamanı yalnız clone'da kontrollü fixture olarak yazıldı. Normal çalışma ile Deneme zamanları çakışmadı.

**Bu veriler doğal süre bekleyişi değildir.** LGS/TUS katalog süreleri ve genel saat değiştirilmedi; native uygulama çalıştırılmadı. Amaç hedef filtresi ve Global okuma yan etkisidir.

Hem `study` hem `exam` için dört hesabın her birinden:

1. `get_monthly_league_ranking(kind, 'segment')` sonucu tam kendi hedefindeki iki hesabı içerdi; diğer hedefteki iki hesap görünmedi.
2. `get_monthly_league_ranking(kind, 'global')` sonucu dört hesabın tamamını içerdi. Böylece her iki hedefin birlikte bulunduğu UID kümesi doğrudan doğrulandı.
3. Global satırlarında terfi, ödül ve düşme uygunluk bayraklarının üçü de kapalıydı.
4. Görünümler okunmadan önce ve her okuma çifti sonrasında 18 tablonun bütün satırları deterministik hash ile karşılaştırıldı. Profil/normal cüzdan, Deneme cüzdanı/kayıt/net, avatar kilit açma, competition puan olayı/oda/üyelik/sonuç/hedef/politika ve Maraton kayıtları değişmedi.

Bu sonuç Global görünümün ayrı ödül üretmediğini yalnız bayraklar üzerinden değil, ilgili veri durumunun değişmezliğiyle de kanıtlar.

## Çalıştırma ve sonuç

```sh
python3 -m py_compile tool/local_supabase/e2e/overnight_global_scope_check.py
python3 tool/local_supabase/e2e/overnight_global_scope_check.py
```

- Nihai günlük: `/tmp/pomosprint_global_scope_20261028_05.log`.
- Makine çıktısı: `build/overnight_backend/global_scope_results.json`.
- Sonuç: `completed=true`, `copied_user_data=false`, `passed=46`, `total=46`; süreç çıkış kodu 0.
- `git diff --check` ilgili kaynak için temiz. Tam Flutter/Node commit kapısı ana ajan tarafından ayrıca çalıştırılır.

İlk dört kurulum denemesi test gövdesine ulaşmadan durdu: host `pg_dump` 16 / sunucu 17 sürüm farkı; eski fonksiyon sahibini restore etme yetkisi; extension kurulumu; Auth trigger'ını kapatma yetkisi. Bunlar yerel clone kurucusuna aitti ve ürün hatası sayılmadı. Oluşturulan her clone bu denemelerde de temizlendi. Nihai araç sunucu container'ının eşleşen `pg_dump` sürümünü ve şema restorasyonu için yerel yönetici rolünü kullanır; uygulama RPC denemeleri `authenticated` rolü ve ayrı owner JWT claim'iyle yapıldı.

## Sınırlar

Doğrudan farklı-hedef Global kapsam boşluğu bu yerel SQL kontrolüyle kapandı. Gerçek ay dönümü, çok native cihazlı eşzamanlı ekran yenilemesi, Global ilk100 sınırı, gizli/engellenmiş kullanıcı politikalarının bütün kombinasyonları veya canlı veritabanı kurulumu bu küçük ek süitin iddiası değildir; mevcut diğer süitler ve yayın kontrolleri ayrıdır.
