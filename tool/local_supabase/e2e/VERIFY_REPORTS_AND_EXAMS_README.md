# Yerel rapor ve Deneme doğrulayıcısı

`verify_reports_and_exams.py`, **yalnız sabit yerel Supabase** veritabanından bir QA hesabını okur. Ürün kodunu çağırmadan beklenen muhasebeyi ve günlük/haftalık/aylık rapor sayılarını hesaplar. `.env` okumaz; canlı servise, e-postaya veya sağlayıcı girişine gitmez. Hiçbir seans, puan, net, profil veya katalog satırını değiştirmez.

## Çalıştırma

Yerel veritabanı `127.0.0.1:54322/postgres` olmalıdır. 27–30 migration kayıtları ve 31 öncesi Maraton fonksiyon gövdesi kontrol edilir. 31 kuruluysa sonuç başarısızdır; araç şemayı düzeltmeye veya paketi uygulamaya çalışmaz.

```sh
python3 tool/local_supabase/e2e/verify_reports_and_exams.py \
  --owner "$TASK_QA_OWNER"
```

Hesap UUID'si kanonik küçük harfli olmalı; veritabanındaki hesabın e-postası `e2e-sim-…@pomosprint.local` veya `qa-…@pomosprint.local` biçiminde olmalıdır. Gerçek hesap ve farklı DSN verilmesi reddedilir. Ortamda `LOCAL_DB_URL` / `LOCAL_SUPABASE_URL` varsa yalnız belgelenen loopback değerleri kabul edilir.

Bir başka QA hesabının bu hesabın Deneme ve netlerini okuyamadığını doğrulamak için:

```sh
python3 tool/local_supabase/e2e/verify_reports_and_exams.py \
  --owner "$TASK_QA_OWNER" --peer-owner "$TASK_OTHER_QA_OWNER"
```

RLS kontrolünün boş veriyle yanlış güven vermemesi için kaynak hesabın en az bir Denemesi ve bir ders sonucu bulunmalıdır. İkinci hesapla `authenticated` rolüne geçilir; kaynak hesabın Deneme, net ve cüzdan satırları için görünür adetler sıfır olmalıdır. SQL yine `READ ONLY` işlemdir; parola, oturum anahtarı veya hizmet rolü anahtarı gerekmez.

`--as-of 2026-10-28T12:00:00+03:00` yalnız raporun takvim penceresini seçer. Cihaz/sunucu saati veya kayıt tarihi değişmez. Veri bütünlüğü için gelecekte kayıt kontrolü, geçmiş tarihli bu pencere yerine snapshot'ın gerçek yakalanma anına göre yapılır.

Çıkış kodları: **0** tüm denetlenen değişmezler geçti; **1** muhasebe/şema farkı var; **2** güvenlik/bağlantı/veri biçimi sorunu var. Stdout tek JSON'dur. Veritabanı stderr'i veya tokenlar rapora aktarılmaz.

## JSON sözleşmesi

- `schema_version: 1`, `status: PASS | FAIL | ERROR`, `owner_id`, `captured_at`, `as_of`, `profile_time_zone`, `study_day`.
- `expected.economy`: ortak dakika, normal puan/kum ve ayrı Deneme puan/kumu. Normal kumda avatar satın alma harcamaları düşülür; günlük ödül tavanında taban puanı sıfır olan odak kum kazanmış sayılmaz.
- `expected.reports.daily | weekly | monthly`: `start/end`, `total_minutes`, `focus_equivalents`, `counts`, kategori dakika/yüzde haritaları, kategori satırları, günler, aktif günler ve en yoğun gün. Normal seans, Maraton odağı, tamamlanmış Maraton planı ve tamamlanmış Deneme ayrı sayılır.
- `counts`: `normal_sessions`, `marathon_focus_sessions`, `completed_marathons`, `completed_exams`, `unknown_sessions`, `pending_sessions`.
- `category_minutes` / `category_percentages`: kategori UUID'si; kimlik yoksa `name:<ham ad>`. Deneme ayrı `pomosprint:exam` anahtarındadır, derslere bölüştürülmez. Yüzdeler en büyük kalan yöntemiyle toplam 100 olacak şekilde yuvarlanır.
- Günlük `efficiency` kırpılmamış hedef yüzdesidir; `goal_percentage` halka için 100'de kırpılır. Haftalık `efficiency` tam yedi günlük hedefe göredir; `elapsed_pace_percentage` etiket için geçen günlerin hedefini kullanır. Aylık hedef yüzdesi yalnız türetilmiş referanstır; uygulamada aylık verimlilik kartı bulunduğu iddia edilmez. Aylık aynı-dönem önceki ay kıyası ayrıca verilir.
- `actual`: seçili profil/cüzdan alanları ve satır adetleri. `checks` her değişmez için beklenen/görünen değer ve `passed` içerir; `passed_checks/total_checks` bunların sayısıdır.
- `warnings`: sessizce geçilmemesi gereken politika sınırları. Yeni kronolojik native fixture'larında boş olması beklenir.

Kaynak kayıtlar tek `REPEATABLE READ READ ONLY` snapshot'ında alınır. Varsayılan bağlantı da salt okunurdur; sorgu ve dış süreç zaman aşımı ile satır/çıktı sınırları vardır. Kimlik bilgileri, `friend_code` veya ilgisiz hesap verileri projekte edilmez.

## Denetlenen sözleşmeler

- Denemenin saklı katalog süresi, başlangıç/bitiş, tamamlanma/vazgeçme durumu, elapsed ve ödüller. Süre bitmeden tamamlanan kayıt reddedilir; aktif/vazgeçilen Deneme ödül veya rapor dakikası üretmez.
- Dersin kendi soru kotası, negatif olmayan tam sayılar, doğru+yanlış+boş toplamı ve saklı bölenle net. PostgreSQL `numeric` ölçeği korunarak üçüncül netler de ondalık kaybı olmadan karşılaştırılır; sonuç zaman damgası kontrol edilir. Eksik ders sonucu sıfır net diye uydurulmaz.
- Hesap başına UUID ve olay tekliği, Maraton odağı/plan eşlemeleri; normal ve Deneme cüzdanlarının ayrımı, toplam çalışma dakikası.
- Çalışma günü başlangıca göre profil IANA diliminde **04:00**; lig ayı bitişe göre **İstanbul 00:00**. Tamamlanan Maraton planı son odağın bitiş çalışma gününe; odak dakikaları kendi başlangıç günlerine yazılır.
- Beklenen normal/Deneme lig olayı kaynakları, dakika, puan, çalışma günü ve dönem ayı. Vazgeçilen Deneme lig olayı üretmez.

## Sınırlar

Bu araç cihazın gönderilmemiş outbox'ını okuyamaz. Native test, kuyruk gönderilmeden önce bekleyen kaydı ayrıca doğrulamalı; gönderimden sonra bu aracın kabul edilmiş DB snapshot'ı ile ekrandaki sayıları karşılaştırmalıdır. Sonradan kabul edilen kayıt başlangıç tarihine göre geçmiş rapora gider; yeni kayıt zamanı onun çalışma gününe dönüştürülmez.

Normal RPC, geçmişten geç gelen seanslarda saklı seriyi geriye yürütmez ve aradaki eski boşluğu yeniden hesaplamaz. Saat dilimi seyahatinde rapor günü güncel dilimde değişirken lig olayı kabul gününü saklayabilir. Araç tüm tamamlanmış günlerden yeniden oluşturduğu seriyle saklı seri farkını `warnings` içinde açıklar; bu politika kararını sessizce değiştirip geçmişi yazmaz. Şema ve muhasebe `PASS` olması bu uyarının çözüldüğü anlamına gelmez. `last_study_date` ve olay-gün uyuşmazlıkları ayrıca kontrol olarak görünür.

Tamamlanmış geçmişin silinmesi veya elle bakiye atanması gibi kasıtlı fixture değişiklikleri araçta fark olarak çıkar; böyle bir fixture ürün hatası diye raporlanmamalıdır. Doğal süre, kontrollü geçmiş ve model regresyonu sonuçları birbirinin yerine sayılmaz.

## Native host

`e2e_host.py` içindeki `GET /verify-reports?owner=<UUID>` aynı sabit betiği çalıştırır. Yalnız owner UUID'si alınır; keyfi yol, SQL veya CLI argümanı alınmaz. Tarayıcı Origin/Fetch ve Host korumaları korunur. Çıktı `no-store`, zaman ve boyut sınırlıdır. Sonuçtaki `status: FAIL` HTTP200 içinde kalır; native test JSON sonucunu da kontrol etmelidir. Hata JSON'u güvenli kodla HTTP422/503 döner.

## Tekrar çalıştırılabilir testler

```sh
python3 -m unittest discover -s tool/local_supabase/e2e \
  -p test_verify_reports_and_exams.py -v
python3 -m unittest discover -s tool/local_supabase/e2e/sim \
  -p 'test_e2e_host*.py' -v
```

Model testleri karışık normal/Maraton/tamamlanmış-vazgeçilen Deneme, 04:00/ay/DST, negatif ve üçte bir net, avatar harcaması, mükerrer kimlik/olay, RLS farkı ve güvenli bağlantı hatalarını kapsar. Host testleri gerçek geçici HTTP sunucusunda çalışır; çocuk süreç, posta, SQL ve cihaz eylemleri mock'tur. Bu testler canlı servis veya gerçek doğal sınav süresi testi değildir.
