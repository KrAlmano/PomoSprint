# Etkinlik planlayıcı ve bölüm denemeleri — tasarım önerisi

Bu belge öneridir; planlayıcı veya bölüm denemesi uygulamaya ve sunucuya eklenmiş değildir. Mevcut tam sınavların süre, puan, kum ve net kuralları değişmez.

## Planlayıcı

İlk sürümde kullanıcı tarih/saat, başlık ve isteğe bağlı ders seçerek bir çalışma veya deneme planlayabilir; planı düzenleyebilir, silebilir ve isterse hatırlatıcı kurabilir. Plan, otomatik olarak başlatılmış ya da tamamlanmış bir seans değildir. Gerçek sayaç veya deneme kullanıcı tarafından başlatılır; yalnızca sunucunun kabul ettiği tamamlanmış kayıtlar süre, seri ve ödül üretir. Planlanan süre raporlara gerçekleşen çalışma olarak eklenmez.

Takvimde seçilen tarih ve saat, kullanıcının saat dilimiyle gösterilmeli; gün değişimi, saat dilimi değişikliği ve 04.00 çalışma günü sınırı birbirinden ayrı ele alınmalıdır. Cihaz hatırlatıcıları izin verilirse kurulur, kapalıysa açıkça belirtilir. Çevrimdışı değişikliklerde kullanıcıya bekleyen eşitleme gösterilmeli, hesaplar arasında veri taşınmamalı ve tekrar gönderim aynı planı iki kez oluşturmamalıdır. Silinen bir plan mevcut seansları veya kazanılmış ödülleri silmemelidir.

## Bölüm denemeleri

Öneri: Kullanıcı önce bağlı olduğu sınavı, ardından Türkçe veya Matematik gibi bir dersi/bölümü seçer; soru sayısını ve süreyi kendisi belirler. Bitince doğru ve yanlış girer; boşlar soru sayısından hesaplanır ve seçilen sınav ailesinin net kuralı uygulanır. Kullanıcıya özel sınav, resmî tam sınav gibi adlandırılmaz veya resmî puan iddiasında bulunmaz. AYT'deki mevcut alan seçimi ile ayrı bir bölüm denemesi birbirine karıştırılmaz.

Mevcut veritabanı tam sınav tanımını, soru kotalarını ve ödül snapshot'ını sunucuda doğrular. Bu yüzden istemcide sahte bir tam sınav başlatmak ya da yalnızca ekranda süre kısaltmak güvenli değildir. Bölüm denemesi için ayrı, sürümlü ve sunucu tarafından doğrulanan tanım/attempt sözleşmesi, sonuç doğrulaması, tekrar gönderime dayanıklı kayıt ve mevcut raporlarla uyumlu ayrı gösterim gerekir. Çalışma süresi bir kez sayılır; tam sınav sayısı ve mevcut sınav ligi yanlışlıkla artmaz.

## Uygulama öncesi kararlar

- Bölüm denemesi ödülü: hiç ödül olmaması veya süreye bağlı, üst sınırlı ayrı bir kural. Karar verilmeden puan/kum verilmemeli.
- Tamamlanmış bölüm denemesinin seri ve ortak çalışma süresine katkısı, vazgeçme ve erken bitirme davranışı.
- Kullanıcının belirleyeceği süre ve soru sayısının alt/üst sınırları; net katsayısının sınav ailesinden mi seçileceği.
- Planlayıcının yalnız kişisel olup olmayacağı, tekrarlama ve hatırlatma kapsamı.

## Doğrulama planı

Sahiplik/RLS, cihazlar arası eşitleme, silme ve eşzamanlı düzenleme; offline kuyruk ve hesap değiştirme; 04.00/gün/ay/DST sınırları; doğru-yanlış-boş ve geçersiz giriş; vazgeçme, tekrar gönderim, ödülün tek kez yazılması ve rapor toplamlarında çift sayım ayrı yerel testlerle doğrulanmalı. Sunucu değişiklikleri öncelikle ayrı yerel veritabanında migration/geri alma ve DRYRUN ile sınanmalı; canlıya kendiliğinden uygulanmamalıdır.
