# I-16–I-19 kanıt ve rapor kapsamı incelemesi

**28 Ekim 2026, 04:25 Europe/Istanbul — ARA DURUM; 07:00 nihai teslimi değildir.** Kaynak: `/Users/almano/Desktop/Projects/Pomodoro`, `codex/gece-2026-10-27`, HEAD `ffa5d5c`.

İlk kapsam incelemesi 01:24'te yapıldı; bu belge son doğrulanmış kanıtlarla güncellendi. Rapor düzenlemesi yeni native/SQL testi çalıştırmadı, canlı servis veya cihaz durumunu değiştirmedi. `DENETIM.md` yalnız okundu; son bağımsız tur 04:18/`8d2bf7a`, yeni bulgu yok. Bu denetim daha sonraki `ffa5d5c` veya bütün native sonuçları kapsıyor sayılmaz.

## Sonuçların doğru ayrılması

| Başlık | 04:25'te doğrulanan kanıt | Raporda korunacak sınır |
|---|---|---|
| Ortak kaynak kapısı | 42. tur: analiz temiz 8,2 sn; Flutter 1417 PASS / 5 isteğe bağlı PNG / 0 hata, 1:59; Node 164/164. `/tmp/pomosprint_checkpoint_42_*`. | Native sonuçlar veya SQL paketleri bu sayıya eklenmez. Ayrı parite aracı 14/14, ana QA'ya 31 kurulduğunu kanıtlamaz. |
| Gerçek normal ve Deneme süreleri | iOS18 normal 25/50 ve iOS27 TUS135 ayrı finaller+parite; tek kayıt/ödül bağımsız doğrulandı. | İlk uninstall hataları korunur; bütün sınav süreleri ya da her platformda bütün kombinasyonlar tamamlanmış değildir. |
| Ortak rapor ve offline | W gerçek 25 + HTTP503 + farklı OS sürecinde tek kabul; günlük/haftalık/aylık UI–SQL toplamı 430 dk. | 405 dk kontrollü geçmiş + yalnız 25 dk doğal bekleyiş. HTTP proxy kesintisi fiziksel Wi-Fi/uçak modu değildir. |
| Maraton | S25 gerçek 2×25 + 300 sn mola, pencere içinde onay ve +2 bonus; V13 gerçek 25 + 300 + 60 cevapsız, ikinci odak/bonus yok. | S25 onay penceresinin tamamını beklemez. V13 geç ilk kabul/paused yolunu sınamaz. |
| S50 ve AC | S50 iki gerçek 50 dk + 300 sn molayı bitirip 100 dk/28 puan/40 kum/+4 bonus kaydetti; son test isteği eski JWT ile 401 verdi. Ayrı AC 1/1+parite aynı korunmuş kayıtla taze token/duplicate/rapor/lig modelini doğruladı. | **S50 genel FAIL kalır.** AC 105 dakikalık yeniden koşu değildir; lig ekran görüntüsünde bilgi katmanı olduğu için görünür 28 puan kanıtı sayılmaz. |
| İlk kullanım H27/H18 | Ayrı yeni hesaplarda UI kayıt→Mailpit→giriş→rehber→gerçek 25→rapor→erken TUS vazgeçme; her biri 1/1+parite. H18 bağımsız finali 1503 sn, 03:44:57→04:09:57. | H18 başlangıç çalışma günü 27 Ekim: 28 Ekim günlük 0, haftalık/aylık 25. Gerçek **normal 25** için 04:00 geçişidir; Deneme/ay/DST/seyahat veya Resend kanıtı değildir. Android H bekler. |
| AB önceki şema | Geç ilk kabulde yeni 5+1 pencere oluştuğu özgün native/SQL kayıtta görüldü. İlk test ham sunucu/cihaz saati eşitliğinde yaklaşık 130 ms farkla FAIL. Kurtarma ürün kontrollerini ve tamamlanmış marker'ı kaydetti; ekran adındaki alt çizgi host 400 üretince o koşu da FAIL. | İki FAIL silinmez. [`verify`](/tmp/pomosprint_ios27_ab_before_verify.log) **1/1+parite PASS**: 04:22:42, PID15773→19986, tamamlanmış proof değişmedi; aynı owner, tek 25 dk/5 puan/20 kum, aynı gate ve boş timer/kuyruk/ret doğrulandı. 31 sonrası güvenli geç-kabul yolu ayrıca bekler. |
| Normal Android main derlemesi | `1cc6a05` ürün kaynağıyla release 54.167.363 bayt / debug 128.223.167 bayt derleme+statik PASS; mevcut debug imzası eşleşir, integration_test yok. | Henüz kurulmadı veya runtime denenmedi. R75/H kayıtları korunuyor. Yerel API'li QA ikilisi mağaza dağıtımı değildir. |
| Safari | 03:45–03:53 ve 04:16–04:18 yerel masaüstü TR/EN, SSS aç/kapa, mevcut video karesi ve imleç görüldü; düğme etiketi değişti. | Videonun ilerlemesi/autoplay, dar mobil ekran ve koordinat etkileşimi doğrulanmadı. Önceki `cgWindowNotFound`, sonraki `noWindowsAvailable` korunur; Chrome kullanılmadı. |

İlgili belgeler: [native kayıt](QA_NATIVE_GECE_2026-10-28.md), [ilk kullanım](QA_ILK_KULLANIM_2026-10-28.md), [Safari](QA_SAFARI_2026-10-28.md), [normal release](../build/overnight_final_main/android_release_verification.json), [normal debug](../build/overnight_final_main/android_debug_verification.json).

## İlk kapsam bulgusu: Global assertion artık ek kanıtla tamamlandı

İlk incelemede `overnight_competition_backend.py` içindeki `global_has_other_target_rows` yalnız liste uzunluklarını karşılaştırıyordu. İkinci TUS odası da bu koşulu sağlayabilirdi; farklı hedeflerin aynı Global listede bulunduğunu tek başına kanıtlamaz. `global_does_not_award_again` de yalnız eligibility bayraklarını kontrol eder; cüzdan öncesi/sonrası karşılaştırması değildir. Bu eski test adlarının anlamı büyütülmemeli.

Ardından bağımsız [Global kapsam kontrolü](QA_GLOBAL_KAPSAM_2026-10-28.md) **46/46 PASS** verdi: iki LGS + iki TUS, normal ve Deneme için segmentte tam doğru sahip kümesi, Global'de dört sahip, 18 ekonomi/rekabet tablosunda okuma öncesi/sonrası aynı hash. Hesaplar ve tarihler izole kontrollü fixture'dır; ana kullanıcılar kopyalanmadı. Native X ayrıca hedef/puan/oda durumunun Global okumalarında ve ayrı OS sürecinde korunduğunu doğrular. Bu ekler ilk testin tek başına eksik olan kanıtını tamamlar; eski test geriye dönük daha geniş anlam kazanmaz.

## I-16–I-19 için mevcut kapsam ve açık uçlar

| Madde | Güçlü kanıt | Açık kapsam |
|---|---|---|
| I-16 kategori/Global | 25+1 oda yarışı, owner/kind/segment ayrımı, kontrollü ay kapanışı/terfi/düşme/ödül; Global 46/46; iOS X gerçek hedef seçimi ve farklı süreçte kalıcılık. | Android X, doğal ay dönümü/canlı cron/nüfus, fiziksel çok cihaz güncelliği. Seyahat sonrası terfi günlerinin politikası ayrı. |
| I-17 onboarding | iOS27 yedi hedef; Android dört hedef + üç ayrı başarılı tekrar; çok boyut/2× yazı rehber; H27/H18 aynı yeni hesapta gerçek ilk kullanım. | Android tek turda 7/7 değil. Native yetişkin yıl kullanır; 13 altı birim/widget/server regresyonları ayrı. VoiceOver/TalkBack ve Android H henüz tam değil. |
| I-18 iki dil | ARB/placeholder eşitliği, sınırlı display-literal taraması, açık hata/diyalog/bildirim; iOS ve Android AA Profil TR/EN + pozitif içgörü. | Tarama genel veri akışı veya çeviri dilbilgisi kanıtı değildir. Bütün native ekran/hata/bildirim/erişilebilirlik kombinasyonları tüketilmedi. |
| I-19 rapor | 340 dk karma model; gerçek normal 25/50, TUS135; W430 dk; S25, V13, S50 kayıt+AC; H18 gerçek 04:00 başlangıç günü; ayrı Deneme/normal ekonomi ve çift sayım koruması. | Android LGS75 finali, Android H, doğal Deneme 04:00 ve aylık geçiş, 31 sonrası AB; geçmiş varken profil TZ değişimi. Kontrollü geçmiş doğal bekleyişe eklenerek sunulmaz. |

`q`, tek native gözlemci + sekiz yerel API hesabıdır; sekiz native cihaz değildir. `l` ilk gerçek IANA okumasından sonra New York/DST'yi mock kanalla sınar; gerçek seyahat değildir. `u/w` HTTP kesintisi fiziksel ağ anahtarı değildir.

## I-15/I-19: saat dilimi ve yanlış sınır yorumu

[`overnight_transition_metadata.py`](../tool/local_supabase/e2e/overnight_transition_metadata.py) Deneme fixture'ı **02:30→03:50**, yani tümüyle 04:00 öncesidir. `exam_workday_before04_is_yesterday` bu günü; sonraki 05:00 normal odak ise iki çalışma gününün ortak serisini sınar. “80 minute spanning 04” yorumu düzeltildi; tarih/süre/test davranışı değiştirilmedi ve 20/20 sonuç yeniden koşulmuş gibi yazılmadı.

[Saat dilimi incelemesi](QA_SAAT_DILIMI_SINIRI_2026-10-28.md): normal v2/Deneme geçmiş API'leri kabulün çalışma günü veya dilimini döndürmüyor. Raporlar başlangıcı güncel profil TZ'de yeniden sınıflandırırken `competition_events.study_day` kabulde sabit kalır; `last_study_date` yalnız TZ değişince yeniden yazılmaz. Örneğin `2026-10-28T01:30Z` İstanbul'da 28 Ekim 04:30, New York'ta 27 Ekim 21:30'dur. Bu kaynak çıkarımıdır; kabul edilmiş karma geçmişin gerçek seyahat E2E sonucu değildir.

Geçmişin sabit kabul gününü mü yoksa güncel dilimi mi izleyeceği kararı kullanıcıya bırakıldı. Karardan önce testle bir politikayı sessizce zorlamak veya geçmiş/ödülleri yeniden yazmak yapılmadı. Sabit TZ/DST testlerinin tüm seyahat tutarlılığını kanıtladığı yazılmamalı.

## Nihai rapora geçmeden bekleyenler

- Android R75 ve Android H doğal finalleri ve 31 sonrası AB. Ayrı AB verify sonucu 1/1+parite PASS olarak okundu. Her biri kendi run-id ve eski/yeni şemasıyla yazılmalı. Başlangıç veya tamamlanmış marker tek başına tüm test PASS değildir.
- 31 ana QA'ya **henüz uygulanmadı**; Android R75/H bitmeden uygulanmayacak. İzole 96/96 + 13 DRYRUN ve 14 parite aracı kanıtı canlı/ana şema kurulumu değildir. Duraklatılmış AFK açığı ve D-07 katı 5+1/offline kararı açık.
- Normal main ikilisinin veriyi koruyarak kurulması/runtime doğrulaması; 06:30 cihaz/geçici dosya temizliği ve son kapı. Mevcut derleme PASS bunların yerine geçmez.
- D-06 yayın sırası, fiziksel cihaz/gerçek provider/Resend/Sentry/hosted staging ve yasal bilgiler açık kalır. Safari'deki etiket değişimi video autoplay diye tamamlanmaz.

Önceki 01:24 belgesinin bekleyen normal 50/TUS135/V13/Android AA/Global satırları yeni kanıtlarla güncellendi. İlk koşu hataları ve ilk assertion'ın dar kapsamı yukarıda korunur; hiçbir tekrar, başarısız özgün koşuyu geriye dönük PASS yapmaz.
