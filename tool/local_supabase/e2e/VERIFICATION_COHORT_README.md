# Kategori/Global doğrulama kohortu

`create_verification_cohort.py`, yalnız yerel A5/A7 testleri için dört **yeni** hesap hazırlar. Mevcut kullanıcıyı yeniden kullanmaz, sıfırlamaz veya başka odaya taşımaz. Ana uygulamanın ve katalogun davranışını değiştirmez. Doğal çalışma/sınav süresi kanıtı değildir.

Önce salt okunur plan:

```sh
python3 tool/local_supabase/e2e/create_verification_cohort.py --run verify-1028
```

Root diğer native işleri ve katalog geri yüklemesini koordine ettikten sonra açıkça uygulama:

```sh
python3 tool/local_supabase/e2e/create_verification_cohort.py \
  --run verify-1028 --apply --allow-historical-metadata
```

27–30 yerel paritesi ve yedi resmi sınavın tam süre/soru kataloğu zorunludur; 31 kurulmuşsa veya katalog kısa QA sürelerine çevriliyken işlem reddedilir. `.env` veya canlı servis kullanılmaz. Sabit yerel Auth → Mailpit onayı → giriş → onboarding API yolu çalışır. JWT yalnız bellektedir.

| Rol | Hedef | Normal25dakika kayıt adedi | Deneme |
|---|---|---:|---|
|lgs-a|LGS|4|LGS Sözel75dk,15Deneme puanı/3Deneme kumu|
|lgs-b|LGS|3|LGS Sözel75dk,15/3|
|tus-a|TUS|5|TUS Temel135dk,27/5|
|tus-b|TUS|2|TUS Temel135dk,27/5|

E-postalar `e2e-sim-cohort-<run>-<role>@pomosprint.local`; Auth metaverisi `qa_verification_cohort=<run>`, `qa_verification_role=<role>`. Native test bunlarla exact dört hesabı bulur. Beklenen normal puanlar20/15/25/10; normal kum80/60/100/40. Normal başlangıçlar sunucu anından9saat önce başlayıp30dakika aralıklıdır. Deneme başlangıcı5saat önceye kurulur; süre ve bitiş katalog snapshot'ına aynen uyar, odaklarla çakışmaz.

Puan, kum, ortak süre ve lig olayları **public tamamlama RPC'lerinden** gelir. Doğrudan ekonomik kolon ataması yoktur. Tek metadata istisnası, yeni başlatılan Denemenin kendi başlangıç/bitiş tarihleridir: exact yeni UID/e-posta/run/rol/attempt/client UUID, aktif durum, katalog süresi ve yakın oluşturulma zamanı SQL transaction'ında korunur. Bir ders neti public RPC ile kaydedilir; önce/sonra ekonomi eşitliği ve bağımsız `verify_reports_and_exams.py` sonucu kontrol edilir.

Her hedefin iki üyesinin hem normal hem Deneme liginde aynı odaya düştüğü doğrulanır. Boş kapasite nedeniyle ayrılırlarsa test bunu başarısız sayar; oda üyeleri zorla taşınmaz veya silinmez. Yeni bir explicit run kullanılabilir.

Manifest `build/verification_20261028/cohort_<run>.json`: plan, oluşturulan QA UID'leri, metadata aşaması, ödül toplamları, kategori odaları ve kontrollü geçmiş işaretleri. **Token/parola kaydedilmez.** Auth ve API çağrıları birden çok transaction olduğundan tüm kohort için rollback iddiası yoktur. Hata olursa `failed_partial_preserved` yazılır, kısmi hesaplar korunur; aynı e-posta/manifestle tekrar yürütme reddedilir. Varsayılan plan hiçbir hesap oluşturmaz.

Bu yardımcıyı yazan ajan yalnız mock testlerini çalıştırır; gerçek uygulama root'un koordinasyonuyla yapılır. Regresyon:

```sh
python3 -m unittest discover -s tool/local_supabase/e2e \
  -p test_create_verification_cohort.py -v
```
