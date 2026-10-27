# Yerel REST kesinti proxy'si

Bu araç sadece yerel QA içindir. Uygulamanın HTTP erişimini keser; fiziksel Wi-Fi, uçak modu veya gerçek internet kesintisi kanıtı değildir. Üretim yapılandırmasına eklenmez.

```sh
python3 tool/local_supabase/qa_http_proxy.py
```

- Veri: `127.0.0.1:54325` → sabit `127.0.0.1:54321`.
- Admin: `127.0.0.1:54326`, yalnız `/health` ve `/availability`.
- iOS simülatöründe QA `SUPABASE_URL=http://127.0.0.1:54325`.
- Android emülatöründe QA `SUPABASE_URL=http://10.0.2.2:54325`.
- Aynı yerel anahtar kullanılır; anahtar/token komut satırına veya proxy loguna yazılmaz. Anahtar bu araç tarafından okunmaz, saklanmaz, değiştirilmez.

```sh
curl -sS http://127.0.0.1:54326/health
curl -sS -X POST http://127.0.0.1:54326/availability -H 'Content-Type: application/json' --data '{"available":false}'
curl -sS -X POST http://127.0.0.1:54326/availability -H 'Content-Type: application/json' --data '{"available":true}'
```

Kapalı durumda yeni istekler genel `503 qa_transport_unavailable` yanıtı alır. Uçuşta olan upstream soketleri de kapatılır. İstek upstream'de zaten işlendiyse işlem geri alınmaz; istemcinin UUID/idempotency kuyruğunun aynı işlemi güvenle yeniden denemesi beklenir. Açınca yalnız sonraki istekler geçer.

Supabase, SQL, Mailpit veya diğer cihazların doğrudan `54321` bağlantıları durdurulmaz. Admin yalnız genel istek/reddetme/aktif bağlantı sayılarını gösterir; yazma için `application/json` gerekir, tarayıcı `Origin` başlığı reddedilir. Request path, header, body, token ve upstream hata metni loglanmaz. Upstream yönlendirmeleri takip edilmez; bu açık proxy değildir. TLS/CONNECT, WebSocket upgrade ve chunked **request** desteklenmez; native REST/auth/RPC istekleri hedeflenir. Chunked upstream yanıtı stdlib tarafından açılıp doğru Content-Length ile iletilir. Request sınırı 4 MiB, yanıt sınırı 32 MiB, upstream timeout 20 saniyedir. Loopback portlarını dış ağa tünelleme.

```sh
python3 -m unittest discover -s tool/local_supabase -p 'test_qa_http_proxy.py' -v
```

Testler geçici loopback portlarında echo upstream kullanır; Supabase hesabı, gerçek anahtar veya veritabanı gerektirmez. Durdurmak için Ctrl+C.

Native `integration_test/u_exam_http_recovery_test.dart` ayrıca açık `--dart-define=E2E_HTTP_PROXY=true` ister; admin portu `--dart-define=E2E_PROXY_ADMIN_PORT=54326` (varsayılan) olur. Test veri URL'sinin `127.0.0.1:54325` veya Android için `10.0.2.2:54325` olduğunu doğrular. Gerçek TYT başlangıcından sonra proxy'yi kapatır, vazgeçme isteğinin cihazda beklediğini ve ödül verilmediğini denetler; proxy'yi açınca tek terk edilmiş kayda dönüşmesini doğrular. Testin `finally` bloğu proxy'yi yeniden açar. Wrapper ve uygulama ortam ayarları bu araç tarafından değiştirilmez.
