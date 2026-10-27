# PomoSprint canlı servis kontrolü — 27 Ekim 2026

Proje: `/Users/almano/Desktop/Projects/Pomodoro`. Kontrol, Supabase/Resend/Cloudflare için güncel salt okuma istekleriyle yapıldı. Uygulama kodu, canlı veri, yapılandırma, DNS ve dağıtım değiştirilmedi. Kullanıcı hesabı açılmadı, oturum açma veya e-posta gönderme yapılmadı.

**Sonuç:** Temel servis erişiminde kesinti bulunmadı. Veritabanı, Auth, katalog/config API’leri, Resend API, SMTP bağlantısı ve site erişilebilir. Önceden bekleyen bazı yayın/operasyon işleri devam ediyor; bu kontrol tam uygulama veya yeni e-posta teslim testi değildir.

## 1. Supabase ve veritabanı

- SQL bağlantısı başarılı; kontrol transaction’ı `READ ONLY`.
- Auth health ve settings HTTP200. Gerçek katalog sorgusu HTTP206/count48, lig config HTTP200. REST kökündeki şema indeksi401; gerçek izinli endpoint’ler çalıştığı için bunu servis kesintisi saymadık.
- Veritabanı yaklaşık **15,71 MB**. **4 kullanıcı, 4 profil, 9 seans, 11 kategori, 42 avatar sahipliği** var; 9 Ekim sayımlarıyla aynı.
- Profil/seans toplamı 250 dakika, 51 puan; toplam kum150. Negatif puan/kum, 25/50 dakika dışı seans, yinelenen client UUID ve sahipsiz seans bulunmadı.
- 25 public tabloda RLS açık,17 politika var; kontrol edilen hassas tablolarda anon yetkisi yok. Bu şema kontrolü bütün yetki/istismar senaryolarının yeniden sınandığı anlamına gelmez.
- Üç zamanlanmış iş aktif. Son7günde **15 çalıştırmanın15’i başarılı**, başarısız kayıt0; her işin son çalıştırması başarılı.
- Lig kapasitesi25 ve durum `preparing`. Odadaki en yüksek kullanıcı sayısı3; kapasite aşımı yok. Resmî yarışın aktif kullanıcı eşiği25.
- Maraton açık. Mola300sn, devam onayı60sn;25dk için2/3/4seansta+2/+3/+5,50dk için+4/+6/+10 bonus yapılandırması doğru.
- Avatar kataloğu48toplam/47aktif/21özel/7aktifücretsiz. Özel avatarlar500kum; Ronin yok. Katalog checksum’u9Ekim ile aynı.
- İncelenen altı son migration mevcut; eski QA tamamlanma yardımcıları yok.

Ayrıntı: [Backend özeti](qa_evidence_20261027/service_check/backend/summary.md).

## 2. Resend, SMTP ve DNS

Resend’de beş salt okuma GET isteği HTTP200 döndü: domain, geçmiş mesajlar, kullanım, teslim metrikleri ve domain ayrıntısı.

- `mail.pomosprint.app` **verified**, gönderim özelliği açık, bölge eu-west-1.
- DKIM ve SPF kayıtları sağlayıcıda doğrulanmış, DNS’te mevcut. Ana domainin DMARC kaydı `p=none`. Bu ayar değişmedi; yeni DNS kaydı eklenmedi.
- Canlı kota: günlük **0/100**, mevcut aylık dönemde **2/3000** e-posta kullanılmış. Kota doluluğu görünmüyor; bu değerler doğrudan hesap API’sinden alındı.
- Görünen iki mesaj **5 ve7Ekim tarihli**, ikisi de `delivered`.1Ekim00:00–27Ekim00:00UTC metriğinde sent2/delivered2; bounce, complaint, failed ve delay0. Bu küçük geçmiş örneği bugünkü yeni teslim testi değildir.
- `smtp.resend.com:587` EHLO250/STARTTLS220 döndürdü; sertifika ve hostname doğrulamasıyla TLS1.3 kuruldu. Sertifika2Aralık2026’ya kadar geçerli. SMTP AUTH/DATA yapılmadı.
- Supabase’in güncel ayarları `config pull --dry-run` ile, mevcut yerel config bağlamında okundu; `wrote=false`. Host `smtp.resend.com`, port587, gönderen `noreply@mail.pomosprint.app`, görünen ad PomoSprint; e-posta aralığı1dakika, onay ve güvenli parola değişimi açık. `auth.rate_limit.email_sent=30` görüldü.
- SMTP username/password değerleri ve fark listesinde görünmeyen alanlar doğrulanmadı. Yeni reset veya test e-postası gönderilmedi; uçtan uca yeni teslim/inbox yerleşimi iddia edilmiyor.
- Ana domain gelen posta MX’i Cloudflare. Resend’de gönderim alt alanının receiving özelliği kapalı; gelen destek postası teslimi bu kontrolde denenmedi.

İlk doğrudan Management credential denemesi erişim bulmadı. Kök config bulunmadığı için ilk CLI önizlemesi de çalışmadı; son doğru `--workdir tool/local_supabase --dry-run` okuması başarılı. Hiçbir config yazılmadı. Anahtar, parola, alıcı ve mesaj gövdesi kanıtlara kaydedilmedi.

Ayrıntı: [E-posta özeti](qa_evidence_20261027/service_check/email/REPORT.md).

## 3. Canlı site ve Cloudflare

- **94 GET/HEAD isteğinde219 kontrol geçti.**18HTML sayfası ve58 referans dosya okunabildi; gövdeler yerel kaynaklarla birebir eşleşiyor.
- DNS, HTTPS/sertifika, yönlendirmeler, hassas dosyalar için404, güvenlik başlıkları ve videoların Range yanıtları kontrol edildi.
- İlk rapordaki üç başarısız kontrol, test beklentisinden kaynaklandı: HTTP/2HEAD yanıtında Content-Length zorunlu değildir; doğrudan404belgesinin sunulması, bulunmayan rota davranışıyla aynı değildir. Beklentiler düzeltilerek aynı yakalanan yanıtlar tekrar değerlendirildi. Ürün kodu değiştirilmedi.
- Aktif Worker `840fd4f1-0779-493a-ad5b-e41fcd27a3c3`, trafik payı%100; son dağıtım8Ekim.
-26Ekim18:44–27Ekim18:44UTC penceresinde **878Worker isteği,0çalışma zamanı hatası**. Bu sayı tüm HTTP/ürün akışlarının hatasız olduğu anlamına gelmez.
- Worker `observability` alanı null; kalıcı log ve alarm kurulumu doğrulanmış değildir.
- Güncel **133/133Node testi** geçti; ortak HTML parça kontrolü exit0. Sayılar HTTPkontrol toplamıyla birleştirilmedi.
- Safari’de ana sayfa ve Özellikler açıldı; Maraton ve diğer özellik metinleri, görseller ve videoların oynatma durumları görüldü. Haberdar Ol bağlantısı e-posta alanı ve işaretlenmemiş açık onay kutusunu gösterdi. Form doldurulmadı/gönderilmedi. Chrome kullanılmadı.

Ayrıntı: [Site/Cloudflare raporu](qa_evidence_20261027/service_check/site/REPORT.md).

## 4. Devam eden işler ve kapsam sınırı

1. **Hoş geldin/tanıtım e-postası:** `send-welcome-email` aktif v9, `unsubscribe` aktif v10. `RESEND_API_KEY` secret adı mevcut; `MAIL_SENDER_NAME` ve `MAIL_SENDER_ADDRESS` hâlâ eksik. Gönderenin resmî bilgileri kullanıcıdan son aşamada beklendiği için yeni değer uydurulmadı. Bu eksik iş, Auth parola SMTP hattından ayrıdır.
2. **Apple girişi:** Auth ayarlarında kapalı. E-posta ve Google sağlayıcıları açık; bunların gerçek giriş akışı bu tur denenmedi.
3. **Hesap silme Edge Function:** `delete-account` dağıtım listesinde yok; önceki istemci/RPC yedeği bu tur gerçek hesap silerek sınanmadı.
4. **Operasyon ve güvenlik:** Önceki§33 Sentry/limiter/kill switch/staging bulguları bu bağlantı kontrolüyle kapanmış sayılmaz. Sentry ve genel Auth/REST/Edge hata logları okunmadı; mevcut çalışma hatası gözlemi cron geçmişi ve Cloudflare metriğiyle sınırlı.
5. **İçerik güncelliği:** Site kaynakları canlıyla aynı; Özellikler koleksiyon metninde21adet500kumluk özel avatar kategorisi henüz anlatılmıyor. Bu bir erişim arızası değil, sonraki içerik güncellemesi adayıdır.

Mobil uygulama derlenmedi veya simülatörde çalıştırılmadı;9Ekim’deki1291Flutter test sonucu bu turun sonucu değildir. Yeni mail, kayıt, satın alma, seans yazımı, şifre sıfırlama, stres testi ve fiziksel cihaz kontrolü yapılmadı. Geliştirmeye bağlantı sorunu gidermek zorunda kalmadan devam edilebilir; sıradaki ürün değişikliği için ilgili akış testleri ayrıca koşulmalıdır.

Bağımsız inceleme: [kanıt değerlendirmesi](qa_evidence_20261027/service_check/review.md). Yerel kanıtlar kimliksiz/özet içerir ve gitignore altındadır; bu rapor sonraki oturumun kalıcı başvurusudur.
