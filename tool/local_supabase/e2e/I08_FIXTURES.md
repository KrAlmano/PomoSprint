# I08: yerel çok hesaplı sosyal görünüm

Bu araç **bir native gözlemci ve sekiz API hesabı** içindir. Sekiz ayrı açık cihaz, tamamlanmış Maraton veya gerçek tam süreli deneme testi anlamına gelmez. Ana yerel Supabase kullanılır; mevcut kişisel/QA hesaplar değiştirilmez. Her yeni hesap gerçek signup → Mailpit onayı → parola girişiyle açılır.

```sh
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py setup --run-id night-1028
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py check --run-id night-1028
# Native testten hemen önce gerçek 5 dakikalık mola durumlarını yenile:
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py refresh --run-id night-1028
```

`build/overnight_backend/i08_multiuser_night-1028.json` yalnız UID, QA e-posta/etiketi, beklenen durum ve kanıt satırları içerir. Token/parola yazılmaz. Gözlemci e-postası `qa-i08-night-1028-observer@pomosprint.local`; yerel parola `integration_test/support/e2e.dart` içindeki `kE2ePassword` sabitidir.

Dört arkadaş normal odakta, ikisi 5 dakikalık mola durumunda, ikisi standart LGS/TUS denemesinde gösterilir. Durumlar gerçek RPC ile oluşur. Mola RPC'si, tamamlanmış bir Maraton planının kanıtı olarak sunulmaz. Kodla arkadaş isteği ve kabul iki yönde doğrulanır. `q_social_eight_accounts_test.dart` native arayüzde 8 satırı, TR/EN etiketlerini, durum noktalarını ve doğal 30 saniyelik yenilemeyi denetler; bu dosyanın çalıştırılması ana ajan tarafından yapılır.

Test tamamlandığında yalnız bu açıkça etiketli yeni hesapları temizlemek için:

```sh
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py cleanup --run-id night-1028
```

Silme her kaydın UID + e-posta + `qa_fixture_run` eşleşmesini doğrular; geniş bir “test kullanıcılarını sil” sorgusu yoktur. Yerel Auth hız sınırları korunur; 429 alınırsa beklenir, limit kapatılmaz.

## Ayrı, isteğe bağlı deneme geçmişi

UI net giriş/düzenleme testi için yeni native QA hesabına iki kontrollü geçmiş kaydı gerekirse, o hesap ayrıca izin listesine yazılır:

```json
{"owners":[{"id":"YENI-QA-UUID","email":"e2e-sim-exam-KOSU@pomosprint.local"}]}
```

```sh
python3 tool/local_supabase/e2e/create_exam_history_fixture.py \
  --owner-id YENI-QA-UUID --email e2e-sim-exam-KOSU@pomosprint.local \
  --allowlist /tmp/pomosprint-qa-owners.json
```

Araç yalnız son 24 saatte oluşturulmuş `e2e-sim-*` / `qa-i08-*` yerel hesabı, tam UID/e-posta eşleşmesi ve izin listesiyle kabul eder. Mevcut deneme geçmişi veya aktif normal seans varsa durur. İki yeni TYT kaydına 3 ve 1 gün önce 10:00 İstanbul başlangıcı, standart 165 dakikalık süre, Türkçe 20D/4Y/16B ve 28D/4Y/8B; diğer derslere tam boş sonuç yazar. Tamamlama ve net işlemleri gerçek sunucu fonksiyonlarıdır; yalnız bu iki başlangıç/bitiş zamanı kontrollü fixture'dır. Katalog ve uygulama süreleri kısaltılmaz.

Bu kayıtlar rapor ve net düzenleme arayüzünü sınar; **165 dakika gerçek cihazda beklenmiş sayılmaz**. Ayrı JSON kanıtı `controlled-historical-tyt-results` etiketi taşır. Hesaba 330 dakika ve ayrı deneme ekonomisi eklenmesi beklenen fixture etkisidir; kişisel hesaplarda kullanılmaz.

## Yeni Deneme geçmişi hesabını tek komutla hazırlama

`create_exam_qa_fixture_account.py` yalnız `e2e-sim-exam-fixture-…@pomosprint.local` veya `w` çevrimdışı rapor testi için `e2e-sim-http-normal-…@pomosprint.local` biçiminde **yeni** bir hesap kabul eder. Her iki ek en fazla40 küçük harf/rakam/tiredir. Gerçek yerel Auth kaydı/Mailpit onayı/login/onboarding sonrasında exact UID/e-posta allowlist'i oluşturur ve yukarıdaki iki tarihsel TYT fixture'ını ekler. Mevcut e-posta varsa hiçbir hesabı değiştirmeden durur. Token/parola dosyaya yazılmaz.

```sh
python3 tool/local_supabase/e2e/create_exam_qa_fixture_account.py \
  --email e2e-sim-exam-fixture-android-20261028@pomosprint.local
```

28 Ekim Android o2 hazırlığı: UID `e1388b6d-d321-4382-8c3c-3c716a92f6f6`, iki165dk TYT kaydı, Türkçe net19/27, toplam330dk, normalpuan/kum0/0, denemepuan/kum66/12. `build/overnight_backend/exam_qa_account_<uid>.json` tam açık fixture manifestidir. Bu165 veya330dakikanın cihazda gerçekten beklendiği iddia edilmez. Başka bir native tur için yeni bir e-posta eki kullanılır; bu komut mevcut fixture'ı sıfırlamaz.
