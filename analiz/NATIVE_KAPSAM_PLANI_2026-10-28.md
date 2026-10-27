# Native kapsam ve kısa tamamlama planı — 28 Ekim 2026

Bu belge kaynak/kanıt eşleştirmesidir; devam eden koşuları başarılı saymaz.
`QA_NATIVE_GECE_2026-10-28.md` ve `DOGRULAMA_MATRISI_2026-10-28.md`
değiştirilmedi. Güncel `/tmp/pomosprint_ios*` ve `/tmp/pomosprint_android*`
loglarının sonuç satırları da okundu. Birden fazla koşunun başarıları tek
kusursuz tur gibi toplanmaz.

## Mevcut senaryolar ve gecenin kanıtı

| Dosya/harf | Ana kapsam | Bu gece okunan kanıt / kalan iş |
|---|---|---|
| a | Gerçek kayıt, Mailpit onayı, yedi hedef, TR/EN onboarding ve rehber | iOS27 yedi hedef native geçti; eski parity reddi sonradan ayrı güncel kontrolle çözüldü. Android ilk dört hedef a02, diğer üçü ayrı language03/university04/work05 koşularında geçti. iOS18 a01 iki test geçti, wrapper hatası ayrı kaldı. |
| b | Dikey timer, 25/50 satırı, kum saati, düğme sınırı | Android b03 geçti; önceki b01/b02 hata kayıtları korunur. iOS18 kısa tekrar isteğe bağlı. |
| c (+eski f) | Tamamlanmış normal kayıt, puan/kum/seri, rapor ve lig | Bu gece native sonuç bulunmadı. Başlangıcı26dk önce yazılan kalıcı timer **kontrollü fixture**; gerçek25dk değildir. w/r finalinden sonra yalnız farklı UI kapsamı gerekiyorsa çalıştır. |
| d | UI arkadaş kodu gönderimi, API kabul, canlı arkadaş ve arkadaş sıralaması | Bu gece native sonuç bulunmadı. q API ile kurulmuş arkadaşları gösterir; UI istek gönderimini ikame etmez. Kısa tamamlama adayı. |
| e | Gizlilik/yasal menü ve yalnız yeni QA hesabını silme | Bu gece sonuç yok. Kısa tamamlama adayı; bitmiş probe hesaplarını kullanma. |
| g1 | Şifremi unuttum→gönderildi UI, kontrollü25dk üzerinden hafta/ay, izin varsa bildirim | Bu gece native sonuç yok. g1 tek başına şifrenin değiştiğini kanıtlamaz. |
| g2 (yeni) | Gerçek Mailpit recovery→yerel Auth yeni parola→native eski parola reddi/yeni parola giriş | Kaynak ve helper hazır; native henüz koşmadı. Yerel API preflight ayrı geçti. Web formunun UI'si kapsam dışıdır. |
| i | Gerçek3000sn timer başlat, duraklat, widget yeniden kur, devam, ikinci hakkı reddet, iptal | Bu gece ayrı sonuç yok. Sürenin50dk olarak kurulması kanıtıdır;50dk tamamlanma değildir. Android t aynı kısa işlevlerin çoğunu kapsadı; iOS18 için uygun. |
| j | Android native bildirim izin/takvim/teslim/iptal ve Maraton mola uyarısı | Android j09 **1/1 + parity PASS**. iOS karşılığı k'dir. |
| k | iOS provisional bildirim, gerçek teslim, ActivityKit kanalı, Maraton uyarısı | Bu gece sonuç yok. ActivityKit false dönerse test bunu açık sınır olarak loglar; başarı gibi yazılmaz. Kısa aday. |
| l | IANA kanal, kontrollü saat dilimi, onay idempotency, istek iptali/silme/engelleme | Bu gece sonuç yok. Confirmation-required Auth uyumu düzeltildi. Saat dilimi değişimi sistem ayarını gerçekten çevirmek yerine method-channel kontrollü girdidir. |
| m | Kategori CRUD/limit/arşivli rapor, tema/dil, yetersiz avatar bakiyesi, tam çıkış | Bu gece sonuç yok. Bir25dk kayıt kontrollü eski-timer fixture'ıdır. Avatar satın alma başarısı/equip kalıcılığını kapsamaz. Kısa geniş kapsam adayı. |
| n | Kullanıcı bildirme formu, gerçek RPC, duplicate ve iptal | Bu gece sonuç yok. Yalnız yeni yerel hesaplarla kısa tamamlanabilir. |
| o1/o2 | Deneme başlat/vazgeç/kalıcılık/yön/dil ve kontrollü net düzenleme/rapor | iOS18 o2_04 geçti; Android o1_07 ve o2_08 ayrı ayrı **1/1 + parity PASS**. iOS27 eski o2 başarısızlıkları korunur. o2 gerçek165dk değildir. |
| p | İzole kum saati/debug kare ölçümü | iOS18 p01 geçti. Bütün uygulama, fiziksel pil veya release performansı değildir. |
| q | Tek native gözlemci,8 ayrı API arkadaşı, TR/EN, gerçek30sn yenileme | iOS18 q01 ve Android q10 geçti. Sekiz native cihaz veya UI arkadaş kabulü testi değildir. |
| r | Gerçek25/50 ve LGS75/TUS135, ayrı süreçte doğal bitiş/tek ödül | Geçerli25 ve135 başlangıcı var; final sonuçlar bu kapsam anında bekleniyor. İlk uninstall koşuları geçersiz kaldı. Normal50/LGS75 tamamlanması henüz kanıtlanmadı. |
| s | Gerçek2×25 veya2×50 Maraton,300sn mola/onay ve tam bonus/rapor/lig | Android sahibi gerçek25 varyantını başlattığını bildirdi; **sonuç bekleniyor**.50 varyantı da gerçek105dk gerektirir; kaynak varlığı başarı değildir. |
| t | Görünür timer seçicileri,50dk başlat/duraklat/devam/limit/iptal | Android t11 **1/1 + parity PASS**.50dk'nın gerçekten tamamlandığı iddiası yoktur. |
| u | Deneme vazgeçme niyetinin HTTP503 altında kalıcı kalması/tekrar işlenmesi | iOS18 u01 geçti. Fiziksel Wi-Fi/uçak modu veya tam süreli deneme tamamlanması değildir. |
| v | Gerçek25+300sn mola+60sn cevapsız onay→ikinci odağı başlatmama | Sonuç bekleniyor/planlı. Kontrollü kısa zamanla ikame edilmemeli. |
| w | Gerçek25 HTTP503→outbox→farklı PID→sync→ortak gün/hafta/ay | Karma geçmiş hazır; native test henüz sonuçlanmadı. Eski405dk fixture, eklenecek25dk gerçek duvar süresidir. |
| x | UI hedef değişimi, sonraki aya pending, iki ekonomi/Global, süreç yeniden açma | iOS18 change/resume ayrı ayrı geçti. Doğal ay değişimi ve gerçek terfi değildir. |
| y | Gerçek timer/Maraton tanıtım videosu sahneleri | Kaynak hazır; kayıt/encode/izleme sonucu bekleniyor. Ürün işlev testi yerine kullanılmaz. |

## Uzun koşulardan sonra iOS18 için kısa sıra

1. **g / özellikle g2:** yalnız yeni `e2e-sim-recovery-<run>@pomosprint.local`
   hesabı. Uygulamadan sıfırlama isteği, gönderildi ekranı, gerçek Mailpit
   mesajı/yerel Auth güncellemesi, eski şifrenin UI'da reddi ve yeni şifreyle
   aynı owner'ın açılması. 25dk bekleme yok; g1 geçmişi kontrollüdür. Yeni
   host `/recover-password` endpoint'i için wrapper'ın başlattığı güncel host
   kullanılmalı. Token/URL/parola/yanıt gövdesi loglanmaz.
2. **m:** kategori ekle/düzenle/limit/arşiv, arşivli geçmişin raporda kalması,
   Ayarlar'dan TR/EN+koyu tema, yetersiz-bakiye avatar diyaloğu ve açık route
   üzerinden güvenli çıkış. Timer fixture'ı açıkça etiketlenir. Yeni Deneme
   sekmesini de dil/tema gezintisine eklemek ayrı kısa kapsam tamamlamasıdır.
3. **d ve l:** d UI kod gönderimi + arkadaş sıralamasını kapatır; l iptal,
   kaldır, engelle/aç ve onay ledger'ını kapatır. q'nun8 gerçek hesaplı
   görünürlük kanıtı bunlardan farklıdır. Gelen isteği **UI'dan kabul/reddetme**
   ayrıca kısa senaryo ister; d/l karşı tarafı API ile kabul ettiriyor.
4. **i ve k:** iOS pause/restore/limit/ödülsüz iptal ve provisional bildirim
   teslimi. i widget yeniden kurulmasıdır; OS kapanışı r/w kanıtında kalır.
   k'da ActivityKit uygun değilse sınır açıkça kalır. Deneme sırasında
   portrait↔landscape, geri dönüş ve erişilebilir pause görünürlüğü ayrıca
   kısa gözle kontrol edilebilir; o2'nin net rotasyonunu tekrarlamak şart değil.
5. **n ve e:** bildirme/duplicate/iptal, sonra farklı yeni QA hesabıyla hesap
   silme. Silme auth/profile/categories SQL ile doğrulanır; uzun koşu sahibi
   veya kişisel hesap hiçbir zaman bu testte kullanılmaz.

Öncelik, aynı şeyi tekrar eden c/g rapor fixture'larından önce g2, m, d/l,
k ve e ile yeni temel UI boşluklarını kapatmaktır. Her kısa testin kurulum,
derleme ve ekran alma süresi cihaza bağlıdır; toplam süre garantisi verilmez.

## Ayrı kalan kısa senaryolar

- **Avatar satın alma/equip:** m yalnız yetersiz bakiye kontrolüdür. Yeni
  exact-owner QA hesabında açıkça kontrollü geçmişten gerçek normal puan/kum
  RPC'leriyle yeterli bakiye hazırlanıp500kumluk bir özel avatar UI'dan
  alınmalı; tek kesinti, ownership, equip, tekrar açılış ve tekrar satın
  almanın ikinci kez kesmemesi kontrol edilmelidir. Bakiye doğrudan üretim
  sütununa yazılarak başarı uydurulmaz. Bu gece bu native kanıt henüz yoktur;
  backend sahiplik/RLS testleri ayrı kanıttır.
- **Yanlış giriş/şifre değiştirme:** g2 eski parola reddi + yeni giriş ekler.
  Profil içi mevcut parola ile değiştirme, zayıf/aynı/yanlış mevcut parola ve
  oturum yenilemesi için ayrı kısa test gerekebilir.
- **Tam reset web formu:** uygulama yalnız e-posta yollar; yeni parola formu
  `landing/reset-password.html` + `landing/js/reset-password.js` içindedir.
  Uygulamada bunun için ayrı yeni-parola deeplink ekranı yoktur. Gerçek web
  formu testinde yerel config override ve çalışan Safari gerekir. Güncel
  Safari otomasyonu `cgWindowNotFound` verdiği için bu gece g2'den web UI
  başarı iddiası çıkarılmaz; Chrome'a geçilmez.
- **Lig terfi/ödül ve ay sınırı:** x hedef/pending/economy kapsamını kapatır.
  Gerçek ay dönümü bu gece beklenmez; kontrollü SQL dönem testleri ve
  istemci regression'ları ayrı sunulur. Normal/deneme ligleri ve Global'in
  her iki platformda aynı UI turu istenirse x Android'de de ayrıca çalışır.

## Eski varsayımlar ve çalıştırmadan önce dikkat

- Yeni menüde sıra **Pomo0, Raporlar1, Sıralama2, Sosyal3, Deneme4**. Eski
  indeks0–3 kodları yanlış sayfaya kaymadı; kaynakta kesin bir indeks kırığı
  bulunmadı. m'nin `[0,1,2,3]` gezintisi kırılmak yerine yeni Deneme'yi eksik
  test ediyor. `openTab` yalnız `NavigationBar` kullanır; landscape/tablet
  `NavigationRail` için r/w/o/x gibi iki yerleşimli helper kullanılmalı.
- b dikey ekran, sekiz YKS kategorisi ve `NavigationBar` varsayar; landscape
  senaryosu diye çalıştırılmaz. g1 de dikey NavigationBar varsayar.
- l'nin ham signup dalındaki token ve kullanıcı şekli varsayımları
  düzeltildi: `(raw['user'] ?? raw)`, gerekirse Mailpit onayı + password
  grant; karşılık gelen owner eşitliği kontrol edilir. Bu düzeltmenin analyze
  sonucu temizdir; yeni native l sonucu henüz yoktur.
- `c`/`g1`/`m` geçmişi ve k'nın45sn ActivityKit içeriği canlı tam Pomodoro
  bekleyişi değildir. Bu kaynaklar gerçek süre bayrağı altında sunulmaz.
- a/g/l/m/e gibi hazırlığı `resetAppState` yapan testler, r/w/s/v'nin aktif
  verisi bulunan kurulumda başlatılmaz. Root'un uzun işler bittikten sonra
  kısa turu başlatma sırası korunur; `--no-uninstall` süreç testlerinde şarttır.

Bu plan uygulama, cihaz veya veriyi değiştiren bir çalıştırma içermedi.
Sonradan eklenecek native sonuçlar yalnız gerçek log/ekran kanıtıyla ana
rapora taşınmalıdır.
