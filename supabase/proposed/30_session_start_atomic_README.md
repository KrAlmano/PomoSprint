# 30 — Normal başlangıç kotasının atomikliği

**Yalnız yerelde hazırlanmıştır; canlıya uygulanmadı.** Bu paket Deneme/aylık lig paketlerinden bağımsızdır. `13_sunucu_butunluk.sql` ile gelen `register_session_start(uuid,integer)` gerekir; 27–29'un tablolarını veya işlevlerini değiştirmez.

## Sorun ve düzeltme

Eski gövdede son 24 saatteki satırlar sayılıp sonra INSERT yapılıyordu. 99 kayıt varken iki eşzamanlı istek 101'e çıkabiliyor. Aynı UUID'nin eşzamanlı tekrarında tek satır kalmasına rağmen iki yanıt da `created:true` diyordu. Aynı UUID önce25, sonra50 dakika istenince ilk kayıt sessizce kullanılıyordu.

Yeni gövde kullanıcının profilini `FOR UPDATE` ile kilitler; var olan UUID, kota ve INSERT aynı kullanıcı için sırayla değerlendirilir. Sonuçlar:

- 99+2 istekte tek yeni kayıt; diğeri mevcut `too_many_session_starts` hatasını alır.
- Aynı UUID/süre tekrarı aynı `server_started_at` ve `created:false` döndürür. Kota doluyken de önceki UUID tekrar okunabilir.
- Aynı UUID/farklı süre `P0001: invalid duration: session_start_metadata_conflict` ile reddedilir. Kayıt değiştirilmez.
- İlk istek `created:true`; `ON CONFLICT` korumasından dönen istek de artık doğru `created:false` değerini alır.
- 24 saatlik kota ve48 saatlik temizleme sınırı,25/50dk koşulu, RLS/ACL ve fonksiyon imzası aynıdır. Yeni tablo, yeni kullanıcı verisi veya yeni istemci alanı yoktur.

Normal tamamlama ve avatar satın alma da profil satırını önce kilitler. Bu paket o kilit sırasını korur. İşlev PostgREST'in varsayılan `READ COMMITTED` transaction ortamında test edilmiştir.

## İstemci sözleşmesi ve saat düzeltmesi

Girdi yalnız `p_client_uuid` ve `p_duration_minutes`; **başlangıç timestamp'i bu RPC'nin parametresi değildir**. Paket `complete_study_session` / `complete_marathon_study_session` veya SessionQueue kodunu değiştirmez. Cihaz/sunucu saat farkı nedeniyle `p_started_at` yeniden hesaplanması yeni bir metadata uyuşmazlığı sayılmaz. Mevcut mobil istemci bu kayıt RPC'sini zaten çağırmıyor; normal başlangıcın sosyal rezervasyonu `start_study_session` üzerinden gider.

Yeni metadata hata metnindeki `invalid duration` mevcut `classifySessionError` ile `permanent / invalidDuration`; eksik profil `not authenticated` üzerinden `offline / auth` olarak sınıflanır. Bunlar için iki Dart regresyon testi bulunur. `created:false`, normal tamamlama RPC'sinin `duplicate` alanından farklıdır; başlangıç makbuzudur ve hiçbir ödeme yapmaz. Mevcut kota hata metni değişmemiştir. İleride RPC istemciye bağlanırsa başlangıç kotası hatası tamamlanmış seans outbox'ını silmek için kullanılmamalıdır.

**Normal çevrimdışı ödül politikası bu paketle değiştirilmez.** `unverified_session_daily_cap=null` nedeniyle sunucuya kaydedilmiş başlangıcı olmayan geçmiş tarihli normal seans hâlâ ödül alabilir. Bu, raporlanan mevcut ürün/güvenlik kararıdır. Mevcut istemciye sunucu başlangıcı eklenmeden limiti0'a çevirmek dürüst normal seansların da ödülünü keser; bu gece yapılmadı. Deneme zaten ayrı sunucu başlangıcıyla doğrulanır.

## Uygulama ve geri alma

1. Canlı uygulama ancak sabah kullanıcı incelemesinden sonra; önce güncel işlev tanımı/hakları salt okunur doğrulanır. Beklenen eski MD5 `9500c7c45503a3e5031e52c879b1dba2`.
2. `30_session_start_atomic_dryrun.sql` olduğu gibi çalıştırılır. Son `DRYRUN_RESULT` hatası bilinçli rollback'tir;10 maddenin tamamı `true` olmalı.
3. İleri dosyadaki `\echo` / `\quit` satırları yalnız bilinçli uygulama için çıkarılır. Tek transaction yeni gövdeyi ve `20261028040000 / session_start_atomic` migration kaydını yazar.
4. Yeni MD5 `1582a6da3c5e9ff496a8f2c16455b13e` olmalı. Tekrarlanan kurulum reddedilir; guard kaldırılmaz.
5. Down yeni MD5'yi doğrular, eski gövdeyi geri getirir ve yalnız kendi migration kaydını kaldırır. Seans, başlangıç, profil, puan/kum/lig/ödül satırı silmez. **Eski kota yarışını geri getirir**; bunu bilerek kullanın. Sonradan değiştirilmiş gövdeyi ezmeyi reddeder.

## Yerel kanıt

`tool/local_supabase/e2e/overnight_session_start_atomic.py`:31/31. Aynı içerikteki DRYRUN10/10 bu31'in içindedir; ayrı ek test toplamı değildir. Atomik kota yarışı, aynı UUID yarışında doğru makbuz, süre uyuşmazlığı, dolu kotada tekrar,24/48saat penceresi, kullanıcı ayrımı, normal tamamlama uyumluluğu, down bütünlüğü ve hash guard sınanır. Test yalnız `pomosprint_night_start30` klonuna bağlanır ve sonunda eski gövdeyi geri yükler. Yeni QA hesapları yalnız bu klondadır; bu gerçek süreli mobil test değildir.

```sh
python3 tool/local_supabase/e2e/overnight_session_start_atomic.py
python3 -m unittest tool/local_supabase/parity/test_reviewed_parity.py -v
# Yalnız30 yerel anaQA'ya kurulduktan sonra:
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic
```

Eski `--reviewed-night-20261028` referansı değişmemiştir. Yeni açık seçenek ayrı bir referansta yalnız bu işlevin hash farkını ve tek migration kaydını kabul eder. Otomatik şema kabulü/gevşetme veya canlı referans güncellemesi yoktur.
