# PomoSprint: Kapsamlı Test ve Düzeltme Raporu (5 Ekim 2026)

**Kısaca:** İstediğiniz her madde yapıldı ve gerçek simülatörde, test hesaplarıyla uçtan uca doğrulandı.
- Seansların kaydedilmemesinin sebebi bulundu ve düzeltildi.
- Uygulama tarafında yapılan her şey ana koda işlendi.
- Sunucu tarafındaki düzeltmeler SQL dosyası olarak hazır; döndüğünüzde SQL Editor'de siz çalıştıracaksınız. Sıra aşağıda.

| | Sonuç |
|---|---|
| Otomatik testler | **1038** (başta 478); `flutter analyze` 0 sorun |
| Sunucu senaryoları (yerel kopyada, test hesaplarıyla) | **590** senaryo, 36 bulgu |
| Simülatörde gerçek uygulama turu (iPhone 16 Pro, iOS 18.6) | **9/9** senaryo geçti |
| Canlı veritabanı | Hiç dokunulmadı |

---

## 1. İstedikleriniz

| İstek | Sonuç | Kanıt |
|---|---|---|
| BAŞLAT aşağı kaymış; 25/50 yan yana; her şey tek ekranda | ✅ İki ayrı sebep vardı: 25/50 düğmeleri bir erişilebilirlik düzeltmesi yüzünden alt alta düşüyordu, alt gezinme de güvenli alanı iki kez düşüyordu. İkisi de düzeltildi. | `ekranlar/e2e-sayac.png` |
| Kum saati 1,25 kat büyük | ✅ Ekrana sığacak şekilde sınırlı (iPhone 16 Pro'da 183 → 268 nokta). | `ekranlar/e2e-sayac.png` |
| Seanslar kaydedilmiyor, puan gelmiyor | ✅ **Sebep:** VS Code'dan F5 ile açılan geliştirme sürümünde sayaç 25 dakika yerine 5 saniye sürüyordu. Sunucu "25 dakikalık seans 5 saniyede bitemez" diyerek reddediyordu, uygulama da bunu yanlışlıkla "cihaz saatin ileri" diye gösteriyordu. **Mağazadaki sürümde bu hata yoktu.** Artık sayaç her sürümde gerçek süreyle çalışıyor; gerçek seans 5 puan, 20 kum ve seriyi doğru veriyor. | `ekranlar/e2e-seans-sonucu.png` |
| Yeni kayıtta hedefe göre kategoriler gelsin | ✅ Sistem vardı ama kategorileri yalnızca öneriyordu. Artık hedef seçilince dersler **seçili** geliyor, kullanıcı isterse değiştiriyor. **KPSS** ve **Dil sınavı** (YDS/YÖKDİL/IELTS/TOEFL) hedefleri eklendi. | `ekranlar/e2e-onboarding-kategoriler.png` |
| İnternet bağlantısı sorunu | ✅ Üç sebep vardı: (1) Uygulama açılışta sunucuya bir kez bağlanamazsa kapatılıp açılana kadar kalıcı çevrimdışı kalıyordu. (2) Açılış ekranındaki 5 saniyelik zaman aşımı oturum dinleyicisini kaçırıyordu. (3) iOS, bağlantıyı yanlışlıkla "yok" bildirebiliyordu. Artık uygulama kendini toparlıyor: sunucu 44 saniye kapatılıp açıldığında kuyruktaki seans kendiliğinden gönderildi. | `ekranlar/e2e-kesinti-*.png` |
| Ayarlarda "Hesap silme hakkında" ve "Verilerimin kopyasını iste" gereksiz | ✅ İkisi de kaldırıldı. Mağaza ve KVKK uyumu bozulmuyor: Apple'ın istediği "Hesabımı Sil" yerinde, Google'ın istediği silme sayfası Play Console'a girilen bir web adresi, KVKK veri talebi de aydınlatma metnindeki e-posta yoluyla yapılıyor. | `ekranlar/e2e-profil-ayarlar.png` |
| Bildirim anahtarı düzgün çalışmıyor | ✅ Dört sebep vardı. En önemlisi: iOS'ta hiç sorulmamış izin "reddedildi" sayılıyordu, kullanıcı da Ayarlar'da PomoSprint satırı olmadığı için çıkmaza giriyordu. Artık anahtar açılınca iOS izin penceresi çıkıyor. İzin reddedilirse anahtar kapalı kalıyor ve "Ayarları aç" çıkıyor; Ayarlar'dan izin verip uygulamaya dönünce anahtar kendiliğinden açılıyor. | `ekranlar/e2e-bildirim-*.png` |
| Hesaplar birbirini görebiliyor mu? | ✅ Evet, olması gerektiği kadar. Arkadaşlık isteği, kabul, arkadaş listesi, canlı çalışanlar ve sıralamalar iki hesapla denendi. **Güvenlik:** bir hesap diğerinin e-postasını, kumunu, seanslarını ya da kategorilerini okuyamıyor. Tek açık: aynı lig odasındakilerin kimlik numarası ve puan satırları doğrudan okunabiliyor. Düzeltme 25 numaralı dosyada. | `ekranlar/e2e-arkadaslar.png`, `e2e-canli-akis.png` |
| Lig sistemi ve madalya/avatar ödülleri doğru mu? | ✅ **Çekirdek doğru:** odalara yerleştirme, puan birikimi, sıralama, haftalık terfi ve düşme, 0 puanlıya ödül verilmemesi, ödül avatarının doğru kişiye bir kez verilmesi. Kenar durumlarda 11 sorun bulundu (örnek: tek kişilik odada 5 puanla şampiyonluk, terfi edenin yarılanmış döneme girmesi, aynı anda iki avatar satın alımı). Uygulama tarafı düzeltildi; örneğin 0 puanlıya artık madalya gösterilmiyor. Sunucu tarafı 20 ve 22 numaralı dosyalarda. | `ekranlar/e2e-lig.png` |
| Test hesapları aç/sil, kapsamlı test | ✅ Canlının birebir kopyası Docker'da kuruldu (33/33 fonksiyon aynı). Onlarca test hesabı **yalnızca bu kopyada** açıldı ve silindi; hesap silme de uçtan uca denendi. | `tool/local_supabase/` |

Ek olarak bulunup düzeltilenler:
- Uygulama kapalıyken biten seans sunucuya yazıldığı hâlde ekranda "gönderilmedi" yazıyordu.
- Duraklatılmış seans 24 saati geçince uyarısız reddediliyordu.
- Onboarding yarıda bırakılıp dönülünce seçimler kayboluyordu.
- Apple ile girişte ad gelmezse e-postanın baş kısmı görünen ad oluyordu.
- Arkadaş isteği yanıtı yanlış okunuyordu.

## 2. Sizden gerekenler

### 2.1 Sunucu düzeltmeleri: Supabase SQL Editor, bu sırayla

Her adım iki çalıştırmadır:
1. `supabase/tests/` altındaki `_dryrun` dosyasını olduğu gibi yapıştırıp çalıştırın. Sonunda `DRYRUN_RESULT` hatası çıkması normal; maddelerin hepsi `true` olmalı.
2. `supabase/proposed/` altındaki asıl dosyayı, `\echo` ve `\quit` satırlarını silerek çalıştırın.

Bir adım beklendiği gibi sonuçlanmazsa **durun ve bana yazın.**

**Sıra:** `12 → 15 → 16 → 19 → 13 → 14 → 20 → 21 → 22 → 23 → 24 → 25` (26 bağımsız, istediğiniz zaman).

Her adımın beklenen sonucu `supabase/proposed/README.md` → "Dosyalar ve uygulama sırası" tablosunda. Hepsi canlının birebir kopyasında baştan sona ve geri alma yönünde denendi. Yanlış sırada çalıştırılırsa dosyalar hiçbir şey değiştirmeden durur.

Uygulama hepsine hazır: dosyalar uygulanmadan önce de, uygulandıktan sonra da doğru çalışıyor. Bu iki durum ayrı ayrı test edildi. Yani acele etmenize gerek yok.

### 2.2 Ürün kararları (ilgili dosyadan önce)

| Karar | Benim önerim | Ne zaman |
|---|---|---|
| Lig ödülü ve terfi için en az kaç üye / kaç puan gerekli? | 3 üye, 25 puan. Şimdilik bugünkü kural kalıyor (1/1/1); değiştirmek için uygulamadaki ilgili metinler de güncellenmeli, haber verin. | 20'den önce |
| Bir önceki güne ait geç gönderilen seans hangi seri bonusunu alsın? | O günün serisi (dosyada böyle) | 21'den önce |
| İnternetsiz yapılan seanslara günlük üst sınır (saat hilesine karşı) | Şimdilik sınır yok; hile görülürse açılır | 13'ten sonra herhangi bir zaman |
| Yeni lig odasının ilk dönemi 7–14 gün arasında değişiyor | Sabit 14 gün (ayrı bir iş) | sonra |
| 24 saatten uzun internetsiz kalınca seanslar reddediliyor | Kural kalsın; gerekirse 72 saate çıkarılır | sonra |
| Yurt dışındaki kullanıcının gün sınırı | Şimdilik herkes İstanbul saatiyle; ileride cihaz saat dilimi kullanılır | sonra |

### 2.3 Daha önceki listeden hâlâ bekleyenler
- Supabase'de Apple ile girişi açmak.
- Veri sorumlusu bilgisi.
- Resend/SMTP ayarı.

Bunların ayrıntısı `analiz/magaza_uyum_kontrol_listesi_2026-10-03.md` dosyasında.

## 3. Geliştirme ortamınızda değişenler

- **VS Code'da F5 artık Xcode 27 ile derliyor** (`.vscode/settings.json`). Siz sistemde Xcode 26.6'yı varsayılan yaptınız, ama 26.6'nın iOS derleme bileşeni kurulu değil; bu yüzden F5 hata veriyordu. Eski "Simulator" uygulaması (`open -a Simulator`) aynen çalışıyor.
- **Terminalden derlerken** aynısı için komutun başına şunu ekleyin: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
- **VS Code çalıştırma seçenekleri:**
  - **"PomoSprint":** Gerçek sunucu, gerçek 25 dakikalık sayaç.
  - **"PomoSprint (yerel Supabase)":** Bilgisayarınızdaki test kopyasına bağlanır; deneme yaparken gerçek hesabınız etkilenmez. Önce şu komutla kopyayı başlatın: `supabase start --workdir tool/local_supabase`
  - **"PomoSprint (hızlı test sayacı, kaydedilmez)":** 5 saniyelik sayaç ve ekranda TEST rozeti. Bu seanslar sunucuya **gitmez**, puan da vermez; sadece ekranları hızlı denemek için.
- **Yerel test kopyası:** Docker'da çalışıyor. Kullanmadığınızda şu komutla kapatabilirsiniz (veriler kalır): `supabase stop --workdir tool/local_supabase`. Ayrıntılar `tool/local_supabase/README.md` dosyasında.
- **Simülatörde otomatik uçtan uca test (yaklaşık 5 dk):** `tool/local_supabase/e2e/sim/run_sim_e2e.sh`

## 4. Doğrulanamayanlar

- **Android:** Bu Mac'te Android SDK yok, hiçbir şey Android'de denenmedi.
- **Gerçek iPhone:** Ses, titreşim ve gerçek kilit ekranı yalnızca simülatörde denendi. Kilit ekranındaki Canlı Etkinlik çalışıyor (`ekranlar/e2e-kilit-ekrani.png`).
- **Canlıda sunucu dosyaları:** Hiçbiri canlıda çalıştırılmadı. Hepsi canlının birebir kopyasında doğrulandı, ama canlıda da önce DRYRUN dosyası şart.

## 5. Başka bir yapay zekâ için

Önce `AGENTS.md`. Sunucu sırası `supabase/proposed/README.md`'de, yerel test ortamı `tool/local_supabase/README.md`'de. Test betikleri `tool/local_supabase/e2e/` altında.
