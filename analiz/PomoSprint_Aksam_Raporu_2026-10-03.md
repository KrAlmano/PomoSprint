# PomoSprint: Akşam Turu Raporu (3 Ekim 2026)

Bu rapor, sabahki uçtan uca raporun ([PomoSprint_Analiz_Raporu_2026-10-03.md](PomoSprint_Analiz_Raporu_2026-10-03.md)) devamıdır. Akşam istenenler: kilit ekranında sayaç ve bildirimler, KVKK onaylı yeni kayıt ekranı, App Store / Google Play'den red yemeyecek uyum, analiz ekranlarının tek tek doğrulanması ve "aklımıza gelmeyen her şeyin" taranması.

**Sonuç:** `flutter analyze` 0 sorun, `flutter test` **914/914** geçiyor (sabah 478). iOS simülatör derlemesi başarılı. Site yayında. Canlı veritabanına yazılmadı; sunucu değişiklikleri SQL Editor'de sizin çalıştıracağınız öneri dosyaları olarak hazır.

---

## 1. Kilit ekranında sayaç ve bildirimler

| | Android | iPhone |
|---|---|---|
| Kilit ekranında süre | Kalıcı bildirimde saniye saniye geri sayım. Duraklatınca "Duraklatıldı · 12:34 kaldı" | Canlı Etkinlik (Live Activity): kilit ekranında geri sayım ve ilerleme çubuğu, Dynamic Island'da kum saati ve süre |
| Süre bitince | Bitiş bildirimi artık **tam zamanında** (USE_EXACT_ALARM; Play'de zamanlayıcı uygulamalarına izin veriliyor, beyan formu gerekiyor) | Bitiş bildirimi (Odak modlarını delen "zamana duyarlı" bildirim), Dynamic Island'da onay işareti |
| Uygulama kapatılırsa | Sayaç bildirimi bitişte kendiliğinden kalkar, bitiş bildirimi yine gelir | Etkinlik "Seans tamamlandı" görünümünde kalır, uygulama açılınca seans kaydedilir |
| Kullanıcı ayarı | İlk BAŞLAT'ta bildirim izni istenir. Profil'deki anahtar artık sistem iznini doğru gösteriyor ve Ayarlar'ı açabiliyor | Aynı. Canlı Etkinlik varsayılan açık |

- Ekran kapalıyken geçen süre puanı düşürmüyor (yalnızca kayıt amaçlı tutuluyor).
- Uygulama açıkken seans bitince titreşim ve bildirim sesi çalıyor.
- Doğrulama: iPhone 17 Pro simülatöründe Dynamic Island görüntülendi ([ekran](ekranlar/ios-dynamic-island-sayac.png)). Android tarafı bu Mac'te SDK olmadığı için derlenemedi; kod eklentinin kaynağına karşı satır satır doğrulandı. **Gerçek Android cihaz testi gerekli.**

## 2. KVKK, kayıt ekranı ve mağaza uyumu (uygulama)

- **Kayıt ekranı yeniden tasarlandı** ([telefon](ekranlar/kayit-telefon-acik.png), [koyu](ekranlar/kayit-telefon-koyu.png), [tablet](ekranlar/kayit-tablet.png)). Alan içi doğrulama ve yazdıkça işaretlenen şifre kuralları var. Ayrı bir "Onaylar" kartı var:
  - [Zorunlu] Kullanım Şartları'nı kabul.
  - [Zorunlu] KVKK Aydınlatma Metni ve Gizlilik Politikası'nı okudum (bilgilendirme teyidi, rıza değil).
  - [İsteğe bağlı, işaretsiz] e-posta bülteni (ticari elektronik ileti onayı).
  - Onay sürümü ve zamanı hesapla birlikte saklanıyor.
- Google/Apple ile girişte "devam ederek kabul edersin" metni KVKK bağlantısıyla.
- **Hesap:**
  - Çıkışta, gönderilmemiş seans ya da süren sayaç varsa uyarı çıkıyor.
  - Silmeden önce neyin silineceği listeleniyor; silme bitince onay mesajı gösteriliyor.
  - E-postayla kayıtlı hesaplarda uygulama içi şifre değiştirme var.
  - Uzaktan oturum düşerse (şifre değişti vb.) her şey temizleniyor ve kullanıcıya açıklanıyor.
  - Tüm giriş isteklerinde 25 sn zaman aşımı var.
  - Onay e-postasından dönen kullanıcının e-postası hazır dolu geliyor.
- **Apple ile girişte hesap silme:** Apple tarafındaki bağlantı da iptal ediliyor. Bunu yapan `delete-account` fonksiyonu hazır ama henüz yayında değil; o zamana kadar eski silme yolu çalışıyor ve kullanıcıya Ayarlar talimatı gösteriliyor.
- **App Store 1.2 (kullanıcı içeriği):**
  - Sıralama ve canlı akışta "Kullanıcıyı bildir" (destek@ e-postası) ve "Gizle" seçenekleri var.
  - Uygunsuz görünen ad filtresi var.
- **Profil:**
  - "Gizlilik ve yasal" bölümü: gizlenen kullanıcılar, şartlar, gizlilik, KVKK ve Hesabımı Sil. (4 Ekim: "Hesap silme hakkında" ve "Verilerimin kopyasını iste" kaldırıldı; silme web adresi Play Console'da isteniyor, veri kopyası Aydınlatma Metni'ndeki e-posta yoluyla isteniyor.)
  - Destek ve geri bildirim girişi, görünür sürüm numarası.
- **Mağaza riskleri giderildi:**
  - Satın alınamayan "Premium" avatarlar ve limit metinleri gizlendi.
  - Yaş sorusu artık önceden 17'ye ayarlı gelmiyor (tarafsız soru); 13 yaş altı devam edemiyor.
  - Sıralamada görünmek onboarding'de açıkça soruluyor.
  - Oyun kuralları ilk kullanımda anlatılıyor.
  - Dil cihazdan alınıyor; girişte TR/EN seçici var.
  - Resmi Google logosu kullanılıyor.
  - Ekran okuyucu etiketleri ve dokunma alanları düzeltildi.
  - Koyu tema kontrastı düzeltildi.
- **Platform:**
  - iOS gizlilik manifesti eklendi.
  - Android 13+ temalı ikon eklendi.
  - Koyu temada açılış flaşı giderildi.
  - Uygulama adı her yerde "PomoSprint".
  - Hata ayıklama sembolleri için `scripts/build_release.sh` eklendi.
  - 320 pt genişlik (eski iPhone SE, iPad kayan pencere) test matrisine eklendi; bu boyutta onboarding'deki "Devam" düğmesinin ekran dışında kalması düzeltildi.

## 3. Analiz ekranları (Raporlar, Haftalık, Aylık, Kategoriler)

4 bağımsız denetçi 47 bulgu çıkardı. Her biri önce başarısız bir testle kanıtlandı, sonra düzeltildi. **39 düzeltildi, 4 sunucu önerisi, 4 ertelendi** (ürün kararı: önceki ay/hafta gezinmesi, kullanıcıya özel saat dilimi). En önemlileri:

- Çevrimdışı tamamlanan seans Raporlar'da hiç görünmüyordu; artık bekleyen seanslar işaretli olarak sayılıyor.
- Yanıtı kaybolan seans iki kez sayılıyordu; artık tekilleştiriliyor.
- Sunucunun reddedeceği seans toplamlara giriyordu; artık girmiyor.
- **Kategori sorunları:**
  - Son kategori arşivlenince sunucuda kopyası oluşuyordu; artık engelleniyor ve nedeni söyleniyor.
  - Yalnızca büyük/küçük harfi değişen ad kaydedilmiyordu.
  - Kaydedilemeyen sıralama ekranda kalıyordu.
  - Ad ya da renk değişince Raporlar 30 sn eski kalıyordu.
- Yüzdelerin toplamı 100 etmiyordu; hedefe tam ulaşınca "aştın" diyordu; sıfır süre ekranlar arasında farklı yazılıyordu.
- Süren seansın kategorisi arşivlenince sayaçta seçili kategori kayboluyordu.
- İngilizcede seçim ilk kategoriye atlıyordu.
- Seans bitince çıkan "Tebrikler" penceresi sunucu sonucunu (puan, kum, seri ya da ret nedeni) göstermiyordu; artık gösteriyor. Reddedilen seanslar için ayrı bir liste ekranı var.
- Sabit veri setiyle her metriği kilitleyen `test/reports_correctness_test.dart` eklendi. Testler New York, Tokyo ve Berlin saat dilimlerinde de geçiyor.

## 4. Kör nokta taraması ("aklımıza gelmeyenler")

5 farklı denetçi 97 aday buldu. Baş denetçi bunları tekilleştirip **63 doğrulanmış maddeye** indirdi; asılsız çıkan olmadı. Durum: **26 düzeltildi, 9 kısmen, 17 sunucu önerisi, 14 sizin yapacağınız, 1 ertelendi** (google_sign_in 7: Android derlenemediği için). Kritik olanlar:

- **Supabase'de Apple ile giriş kapalı.** Uygulamada düğme var ama çalışmaz: **App Store reddi.** Sizin 30 dakikalık işiniz (aşağıda 1. madde).
- Apple ile girişte hesap silinince Apple bağlantısı iptal edilmiyordu (Apple şartı). Kod hazır, yayın için Apple anahtarı gerekiyor.
- Cihaz saati geri alınarak ya da doğrudan API çağrısıyla puan kazanılabiliyor. Sunucu önerisi hazır; çevrimdışı seanslar için bir **ürün kararı** gerekiyor (aşağıda).
- Sunucu tarafında engelleme ve arkadaşlıktan çıkarma yoktu. Bildirim kaydı ve onay kayıt defteri de yoktu. Hepsi öneri 14'te hazır.

## 5. Site (pomosprint.app, yayında)

- Yeni sayfalar: `/kvkk`, `/en/kvkk` (KVKK Aydınlatma Metni), `/hesap-silme`, `/en/delete-account` (Google Play hesap silme URL'si), `/destek`, `/en/support`.
- Şartlar ve gizlilik güncellendi: yaş, kullanıcı içeriği kuralları, kilit ekranı bildirimleri, onay kayıtları.
- Yazı tipleri ve animasyon kütüphanesi artık kendi sunucumuzda; ziyaretçi IP'si Google ve jsDelivr'e gitmiyor, güvenlik politikası (CSP) buna göre sıkılaştırıldı.
- Bekleme listesi formuna ayrı, işaretsiz ticari ileti onay kutusu eklendi.
- Abonelikten çıkma bağlantıları artık e-posta adresini taşımıyor.

---

## 6. Sizden gerekenler (öncelik sırasıyla)

Ayrıntılı adımlar: [magaza_uyum_kontrol_listesi_2026-10-03.md](magaza_uyum_kontrol_listesi_2026-10-03.md) §0–§1.

1. **Supabase → Authentication → Providers → Apple → Enable**, Client IDs: `com.pomosprint.app` (yaklaşık 30 dk). Yapılmazsa App Store reddeder.
2. **Veri sorumlusu bilgisi:** ad-soyad (ya da şirket unvanı) ve tebligat adresi. Bana yazın, dört yasal sayfaya ve e-posta altbilgisine ben işlerim. Şu an sitede geçici, nötr bir ifade var.
3. **Resend'de `mail.pomosprint.app` doğrulaması ve Supabase özel SMTP ayarı.** Bu yapılmadan kayıt onay ve şifre sıfırlama e-postaları ekip dışındaki kullanıcılara gitmeyebilir.
4. **SQL Editor'de çalıştırılacak öneriler, TEK SIRA:** `12 → 15 → 16 → 19 → 13 → 14`. Her adımda önce `_dryrun` dosyası (sonda `DRYRUN_RESULT` hatası ve tüm satırlar `true` olmalı), sonra asıl dosya. Adım adım tablo ve beklenen sonuçlar `supabase/proposed/README.md` → "Dosyalar ve uygulama sırası" bölümünde.
   - 13 ile 14 uyumlu hale getirildi. Sıra dışı uygulanırsa dosyalar hiçbir şey değiştirmeden durur, bu yüzden yanlış sıra veriyi bozmaz.
   - Yerel kopyada tüm kuru çalıştırmalar başarılı: 12 → 14/14, 15 → 6/6, 16 → 13/13, 19 → 12/12, 13 → 50/50, 14 → 67/67. Geri alma zinciri her adımda bir önceki hale birebir döndü.
   - 19'un B bölümü ayrı ve daha sonra uygulanır.
5. **Ürün kararı (öneri 13):** Sunucuda başlangıç kaydı olmayan (çevrimdışı) seanslara günlük üst sınır konsun mu? Varsayılan "sınır yok" ile bugünkü davranış aynen kalır; sınır koymak saat hilesini kapatır ama internetsiz çalışanı etkiler.
6. **Android:** SDK'lı bir makinede `flutter build appbundle` ve gerçek cihazda kilit ekranı testi. Ardından Play App Signing SHA-1 → Google OAuth ve Play Console'da exact alarm beyanı (gerekçe metni listede hazır).
7. **Mağaza formları:** App Privacy / Data safety yanıtları, demo hesap ve inceleme notu (şablonlar listede hazır), kişisel Play hesabıysa 14 günlük kapalı test.
8. **Apple geliştirici hesabı gelince:** Sign in with Apple yeteneği, widget hedefi imzası (otomatik), hesap silmede iptal için `.p8` anahtarı ve `delete-account` fonksiyonunun yayını.
9. **Hukuk:** Yurt dışı aktarım için KVKK standart sözleşmeleri ve Kurul'a bildirim, İYS kontrolü, metinlerin avukat incelemesi. Bu liste hukuki görüş değildir.

## 7. Yayınlanmayanlar (bilinçli)

- `delete-account` ve güncellenen `send-welcome-email` / `unsubscribe` fonksiyonları yayınlanmadı. Hoş geldin e-postası artık altbilgide gönderici kimliği istiyor (`MAIL_SENDER_NAME`, `MAIL_SENDER_ADDRESS` secret'ları). Bunlar tanımlanmadan yayınlanırsa e-posta gitmez.
- Sunucu önerilerinin hiçbiri canlıya uygulanmadı.

## 8. Başka bir yapay zekâ için

Önce [AGENTS.md](../AGENTS.md). Sunucu öneri sırası ve istemci sözleşmeleri `supabase/proposed/README.md`'de. Kör nokta bulgularının tamamı ve sonuçları bu raporun §4'ünde özetlendi; mağaza ve KVKK adımları kontrol listesinde.
