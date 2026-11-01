# Çevrimdışı seanslar ve ödül güvenliği — 1 Kasım 2026

Bu inceleme canlı fonksiyon ve yapılandırma üzerinde `BEGIN READ ONLY` ile yapıldı; canlı seans/ödül işlemi veya istismar denenmedi. Mevcut [28 Ekim yerel güvenlik raporu](QA_GUVENLIK_GECE_2026-10-28.md) daha önce kontrollü yerel istismar kanıtı kaydetmiştir.

## Canlı davranış ve risk

- `complete_study_session`, eşleşen sunucu başlangıcı varsa onu doğrulayıp kullanabiliyor; yoksa istemcinin bildirdiği başlangıca geri düşüyor. Kabul için geçmişteki aralığın en fazla 24 saat önce başlamış ve mevcut başka seansla çakışmamış olması gibi koşullar aranıyor; bitişte beş dakikalık tolerans bulunuyor.
- Canlı `unverified_session_daily_cap` değeri `null`: doğrulanmamış seanslara özel ödül tavanı kapalı. Bunun dışında günlük 16 seanslık genel puan/kum sınırı bulunuyor. Doğrulanmış bir başlangıç olmadan geçmiş zaman bildiren değiştirilmiş istemciden ödül alınması riski bu nedenle devam ediyor. Fonksiyon kaynak okuması istismarın bugün canlıda yürütüldüğü anlamına gelmez.
- Normal 25 ve 50 dakikalık seansın varsayılan ödülü 20'şer kumdur. Temel puan sırasıyla 5 ve 12'dir; duraklatma kesintisi, seri bonusu ve günlük sınırlara göre sonuç değişebilir. Canlıda ödül yazılmadı.
- İstemcide bekleyen kayıtlar kullanıcı UUID'sine bağlıdır ve bağlantı hatalarında korunup yeniden denenir. Ancak **başlangıcı 24 saatten eski kayıt canlıda reddedilir**. İstemci 48 saatten eski kuyruk kaydını sunucuya göndermeden kalıcı ret olarak ayırır; çakışma gibi bazı kalıcı sorunlar da otomatik ödül anlamına gelmez. Çevrimdışı çalışma sınırsız süre sonra eşitlenebilir diye sunulmamalıdır.

## Mevcut paketler ve uyumluluk

- [Öneri 30](../supabase/proposed/30_session_start_atomic_README.md), `register_session_start` çağrısının sayma/ekleme yarışını ve tekrar makbuzunu düzeltir; **istemciyi veya tamamlamanın doğrulanmamış başlangıca düşmesini değiştirmez**. Dolayısıyla yukarıdaki geçmiş seans/ödül riskini tek başına çözmez. 1 Kasım salt okunur gövde karşılaştırmasında canlı işlev 30'un eski ön koşuluyla eşleşti ve yeni adayla eşleşmedi. Tarihsel 99+2 yarış sonucu yerel/önceki inceleme kanıtıdır; bu turda canlıya eşzamanlı istek yapılmadı. Ayrı test edilmiş olması canlıya uygulandığı anlamına gelmez.
- Mevcut `lib/` içinde `register_session_start` çağrısı bulunmadı; sosyal görünürlükteki `start_study_session` aynı kayıt sözleşmesi değildir. Bu nedenle `unverified_session_daily_cap` değerini hemen 0'a veya düşük bir sayıya çekmek, şu anki uygulamada dürüst kullanıcıların normal seans ödüllerini de kısıtlar. Eski sürümler ve ağ yokken başlayan seanslar ayrıca etkilenir.
- [Öneri 13](../supabase/proposed/13_sunucu_butunluk.sql) mevcut cap mekanizması için olası ürün tercihlerini, çevrimdışı kullanıcı ve eski sürüm etkisini açıklar. Bu değer bir güvenlik düğmesi olsa da mevcut istemcinin başlangıç kayıt uyumsuzluğunu tek başına gidermez.

## Önerilen sonraki çalışma

1. Önce mevcut sunucu sözleşmesi ve uygulama sürümleri doğrulanarak çevrimiçiyken her normal seansın kullanıcıya ait sabit UUID ve süreyle sunucu başlangıcı alınır; tekrar, zaman aşımı, hesap değişimi, uygulama kapanması, eşzamanlı çağrı ve eski sunucu hataları sınanır. Ağ yokken başlangıcın açık bir durumu olur; başarılı sunucu başlangıcı varmış gibi gösterilmez.
2. Çevrimdışı başlatılmış veya eski sürümden gelen seansların dakika/seri ve puan/kum/lig davranışı için ürün kararı belirlenir. Sınırlı ödül seçilecekse limit ve kullanıcıya gösterilecek açıklama önceden tanımlanır. Gerçek çevrimdışı seanslara doğrudan sıfır ödül uygulanması otomatik güvenli düzeltme değildir.
3. İstemci/sunucu değişiklikleri ayrı yerel veritabanında migration, DRYRUN, geri alma, eski sürüm ve ağ kesintisi senaryolarıyla doğrulanır. Gerçek ve sahte zaman bildirimleri, idempotency, ödülün tek kez yazılması ve günlük sınırlar ayrı test edilir. Ardından istemci dağıtım ve minimum sürüm planı tamamlanmadan canlı ayar değiştirilmez.

Doğrulanmış başlangıç tek başına uygulamanın ön planda gerçek dikkatle kullanıldığını kanıtlamaz. Yalnız süreye ilişkin sunucu kanıtını güçlendirir; cihaz bütünlüğü ve kötüye kullanım izleme farklı koruma katmanlarıdır.
