# Supabase / Resend ücretsiz plan kapasite kontrolü — 8 Ekim 2026

## Sonuç

Mevcut kullanımda kota nedeniyle hemen plan yükseltme gerekmiyor. Küçük kapalı beta Free ile devam edebilir. Genel yayından önce Supabase Pro, hareketsizlikten durmama ve günlük yedek geri yükleme imkânı için önerilir. Resend Free şu an yeterli; büyüyen kayıt trafiği veya bülten için günlük 100 sınırı önceden bütçelenmeli.

Bu çalışma kaynak araştırması, Safari panel okumaları ve kimlik doğrulanmış **GET** istekleridir. Mail gönderilmedi, yeni hesap açılmadı, canlı SQL çalıştırılmadı, plan/ödeme/SMTP/rate limit değiştirilmedi. Kod ve uygulama testi yeniden koşulmadı; önceki gece QA kapsamı ayrı kalır. Mevcut sır çıktıya veya kanıt dosyasına yazılmadı.

## Hesaba özgü gözlemler

Supabase panel gözlemleri (ham çıktı §37 temizliğinde kaldırıldı), Resend API kullanım kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

| Ölçüm | Gözlenen | Sınır / kapsam |
|---|---:|---|
| PomoSprint gerçek DB boyutu | **28,91 MB** | 500 MB / proje; yaklaşık %6 |
| Uncached egress | **0,076 GB** | 5 GB / dönem; organizasyon toplamı |
| Cached egress | 0 GB | Ayrı 5 GB / dönem; organizasyon toplamı |
| Aylık aktif kullanıcı | **36** | 50.000; organizasyon toplamı |
| Edge Function çağrısı | 9 | 500.000; organizasyon toplamı |
| Storage | Panelde 0 GB | 1 GB; yuvarlanmış gösterim |
| Realtime peak / mesaj | 0 / 0 | 200 bağlantı / 2 milyon mesaj |
| Resend bugün | **0 mail** | 100 / UTC günü |
| Resend bu ay | **2 mail** | 3.000 / fatura dönemi |
| Resend doğrulanmış alan adı | `mail.pomosprint.app`, `verified` | 1 / 3 domain |
| Supabase Auth mail limiti | **30 mail/saat** | Proje genelinde kayıt/reset vb. toplamı |
| SMTP tekrar aralığı | **60 saniye** | Aynı kullanıcıya iki mail arasındaki süre |

Supabase: `Pomodoro App`, ref `eoosnyakvxmifmexpgxa`, `KrAlmano's Org`, **Free**. Panel fatura dönemi **27 Eylül–27 Ekim 2026**, filtre **All projects**; başka bir proje de bu organizasyonda bulunduğundan egress/MAU değerleri yalnız PomoSprint'e atfedilmedi. Panel “quota aşılmadı” diyor; kullanımın bir saate kadar gecikebildiğini belirtiyor.

İlk proje sayfasında `Unhealthy` görüldü; açıkça yenilenip yükleme tamamlanınca **Healthy**, son 60 dakikada 10 istek / %100 başarı görüldü. İlk durumun nedeni teşhis edilmedi; sürekli kesinti veya kota arızası olarak yorumlanmadı. Son backup etiketi **No backups**.

SMTP bugün yeniden okundu: custom açık, `smtp.resend.com:587`, kullanıcı `resend`, gönderen `noreply@mail.pomosprint.app` / PomoSprint. Parola gizli kaldı, Save çalıştırılmadı.

Safari'deki ilk Resend oturumu başka bir hesaba aitti (0 domain); o hesabın sıfır kullanımı PomoSprint kanıtı olarak kullanılmadı. Doğru hesabın mevcut proje bağlantısıyla `GET /usage` ve `GET /domains` **200** dönmesi ve PomoSprint domain eşleşmesi doğrulandı. [Resend Usage API](https://resend.com/docs/api-reference/usage/retrieve-usage).

Resend günlük sıfırlanma UTC gün sınırında, Türkiye'de yaklaşık **03:00**. API bu dönemin aylık bitişini `2026-10-28T22:29:59.495Z` gösteriyor; Supabase ve Resend fatura dönemleri aynı kabul edilmedi. Yeni teslim/inbox/spam testi veya yeni bounce/şikâyet metriği okunmadı; domain doğrulaması inbox teslim garantisi değildir.

## 8 Ekim'de resmi kaynaklardan doğrulanan sınırlar

| Özellik | Supabase Free | Supabase Pro başlangıç |
|---|---:|---:|
| Veritabanı alanı | 500 MB gerçek DB / proje | 8 GB disk / proje |
| MAU / ay | 50.000 | 100.000 |
| Uncached / cached egress / ay | Ayrı ayrı 5 GB | Ayrı ayrı 250 GB |
| Storage | 1 GB | 100 GB |
| Realtime eşzamanlı peak | 200 | 500 |
| Realtime mesaj / ay | 2 milyon | 5 milyon |
| Edge invocation / ay | 500.000 | 2 milyon |
| Günlük otomatik DB yedeği | Dahil değil | 7 gün saklama |
| Hareketsizlikte pause | 7 günlük düşük aktivitede olabilir | Uygulanmaz |
| Fiyat | $0 | $25 / ay başlangıç |

[Supabase resmi fiyatlandırma](https://supabase.com/pricing). Free gerçek DB boyutu ile Pro ayrılan disk alanı farklı ölçülerdir. API istek adedi sınırsız olması CPU, RAM ve veri çıkışının sınırsız olduğu anlamına gelmez.

Free DB 500 MB'ı aşarsa yazılar engellenebilir/read-only olur; seans ve profil güncellemeleri bundan etkilenir. Devamlı diğer kota aşımlarında uyarı/grace sonrasında kısıt, pause veya API 402 görülebilir. Free aşımı otomatik ücretlenmez; ücretsiz kalmak hizmetin her koşulda devam edeceği anlamına gelmez. [DB boyutu](https://supabase.com/docs/guides/platform/database-size), [Fair Use / billing FAQ](https://supabase.com/docs/guides/platform/billing-faq#fair-use-policy).

Free için düzenli ayrı DB dump yedeği gerekir; mevcut yerel QA kopyası otomatik üretim yedeği değildir. Pro DB yedeği Storage dosyalarını içermez. [Backups](https://supabase.com/docs/guides/platform/backups). Yerel Docker QA üretimde kullanıcı aktivitesi yaratmaz; Free pause dashboard'dan restore gerektirebilir. [Free project pausing](https://supabase.com/docs/guides/platform/free-project-pausing).

| Özellik | Resend transactional Free | Transactional Pro |
|---|---:|---:|
| Mail / ay | 3.000 | 50.000 |
| Mail / gün | **100** | Günlük kota yok |
| Domain | 3 | 10 |
| Fiyat | $0 | $20 / ay |

[Resend fiyatlandırma](https://resend.com/pricing). Hesabın mevcut API hız limiti 10 istek/saniye. Alıcı başına mail sayılır; tek batch içindeki 100 alıcı 100 maildir. Gönderilen ve alınan mailler kotaya dahildir; günlük sınır UTC takvim günüdür. Marketing Free ayrı ürün olarak 1.000 contact'a sınırsız mail sağlar; mevcut uygulama bülten yolu bunu kullanmıyor. [Account quotas and limits](https://resend.com/docs/knowledge-base/account-quotas-and-limits).

Resend API'de günlük/aylık kota aşımı `429 daily_quota_exceeded` / `monthly_quota_exceeded` olur; saniyelik hız aşımı `rate_limit_exceeded` ayrı nedendir. Dolmuş günlük kotada saniyeler arası tekrar çözüm değildir. Auth SMTP teslimleri de sağlayıcı kapasitesine bağlıdır. [Resend hata sözleşmesi](https://resend.com/docs/api-reference/errors).

Supabase Auth'un bugünkü **30 mail/saat** kuralı Resend'in **100/gün** kuralından ayrıdır. Resend Pro'ya geçiş Auth sınırını otomatik artırmaz. Built-in SMTP'nin yalnız ekip adreslerine ve saatte 2 maile izin veren sınırı burada uygulanmıyor; mevcut custom SMTP doğrulandı. [Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits).

## Uygulamanın kapasiteyi tüketmesi

- Sayaç her saniye DB'ye yazmıyor; start/cancel/tamamla durumları RPC çağırıyor. Biten seans kalıcı outbox ve sabit UUID ile tekrar denenir: [servis](../lib/services/supabase_service.dart:1739), [kuyruk retry](../lib/app/main_shell.dart:61).
- Sosyal yalnız görünür ve ön plandayken **30 saniyede bir HTTP** sorguluyor: yaklaşık 120 tur/saat/kullanıcı. Yerel QA 2 saniyesi üretim hesabına katılmadı. [Polling](../lib/screens/social_screen.dart:67). Canlıda mola RPC'si bulunmadığı son doğrulamada biliniyor; fallback bu eksikliği her tur yeniden deneyip ikinci istek yapabilir: [fallback](../lib/services/supabase_service.dart:2092). Bu turda canlı RPC katalog denetimi tekrarlanmadı.
- Uygulama Supabase Realtime kanalı açmıyor; HTTP sosyal sorguları Realtime mesaj kotası değildir. Rapor/sıralama 30 saniyelik sürekli polling yapmıyor; bu süre bayatlık eşiği. Rapor kendi önceki ay–bugün kayıtlarını 1000'lik sayfalarla okuyor: [rapor](../lib/screens/reports_screen.dart:265), [sayfalama](../lib/services/supabase_service.dart:1915).
- Avatar görselleri `Image.asset` ile uygulama paketinde; Supabase'den katalog JSON metaverisi geliyor ve yerelde cache'leniyor: [avatar](../lib/widgets/avatar_widget.dart:23), [katalog](../lib/services/supabase_service.dart:2375). Site sıralaması ziyaret başına en fazla 10 satır public RPC okur; statik site Cloudflare'dadır: [site](../landing/js/main.js:325).
- Auth kayıt/reset **Supabase Auth → Resend SMTP**, welcome **Edge → Resend `/emails`**, bülten **`resend.batch.send`** kullanır. Bunlar aynı transactional kotayı birlikte tüketir: [bülten](../scripts/send_newsletter.js:164).
- **100 alıcılı bülten günlük 100 kapasiteyi doldurup kayıt/reset mailine yer bırakmayabilir.** Mevcut script'te quota ön kontrolü veya Auth için rezerv yok; bu turda kod değiştirilmedi. Başarısız batch'lerden sonra script'in elle yeniden gönderim uyarısı da korunur.
- Welcome 7 Ekim canlı v9 denetiminde gönderen kimliği eksik olduğu için gönderimden önce 500 ile kapalıydı. Repo idempotency/claim/timeout düzeltmeleri kaynak sürümdür, canlıya deploy edildi sayılmadı. Kimlik kullanıcı tarafından en son verilecek; yeniden istenmedi. Bu tur welcome yeniden çağrılmadı. Auth resetin çalışması welcome'ın açık olduğunu kanıtlamaz.

Yalnız hesaplama örneği: sosyal cevabı **5 KB varsayılırsa**, 100 kişi × günde 10 dakika × 20 tur × 30 gün ≈ **300 MB/ay**; 1.000 kişi ≈ **3 GB/ay**. Rapor, Auth, katalog, site ve fallback hata yanıtları eklenmemiştir; ölçülmüş üretim trafik tahmini değildir. Günde dört seans yapan 1.000 kullanıcı ayda yaklaşık 120.000 satır oluşturur; gerçek satır+indeks boyutu ölçülmeden DB dolma tarihi verilemez. “50.000 MAU” tek başına 50.000 kişilik uygulama kapasitesi garantisi değildir.

## Yükseltme kararı ve devam noktası

1. Şimdiki küçük beta: Free'de kalmak makul; mevcut kullanımda acil yükseltme yok.
2. Genel yayın: Supabase Pro'yu pause ve yedek nedeniyle bütçele. Tek Micro projenin compute'u $10 krediyle karşılanır; temel başlangıç $25/ay. Organizasyondaki başka proje de aktif Micro olarak tutulursa yaklaşık $10/ay ek compute doğabilir; bu tur ikinci projenin aktif/paused durumu incelenmedi. [Compute billing](https://supabase.com/docs/guides/platform/manage-your-usage/compute).
3. Resend: düzenli günlük **70–80** mail, aylık **2.100–2.400** mail veya tek günde büyük bülten/kayıt duyurusu öncesinde Pro ya da ayrı Marketing gönderim akışı değerlendirilir. Bunlar erken hareket önerisidir, sağlayıcının resmi limiti değildir. Welcome açılıp izinli 50 kayıt için birer onay+welcome gönderilirse 100 mail eder; reset/resend için yer kalmaz.
4. DB **350–400 MB**, egress **3,5–4 GB/dönem** yaklaşımını erken inceleme eşiği olarak kullan. Şu an bu eşiklerde değiliz. Otomatik alarm veya quota koruması bu çalışmada kurulmadı.
5. Supabase Pro **Spend Cap** varsayılan açık olsa da compute, PITR ve kimi eklentiler kapsam dışıdır; toplam faturaya mutlak $25 tavanı koymaz. Resend ücretli overage seçenekleri de ayrıca incelenmeli. [Supabase maliyet kontrolü](https://supabase.com/docs/guides/platform/cost-control), [Resend fiyatlandırma](https://resend.com/pricing). Bir Micro Supabase Pro + Resend Pro başlangıç bütçesi **$45/ay**; ek compute/kullanım/vergiler hariç. Plan satın alınmadı.

Sonraki görüşme bu rapor ve iki sanitize kanıt dosyasını okuyabilir. Anlık sayılar sonraki tarihte yeniden sorgulanmalı; mevcut kimlik doğrulanmış GET yolu yeterli olduğundan kullanıcının Safari Resend hesabını değiştirmesi gerekmiyor. Yayın hazırlığındaki ayrı Maraton migration, imzalama ve gönderen kimliği işleri önceki devirde kalır; bu kapasite kontrolü onların uygulanması anlamına gelmez.
