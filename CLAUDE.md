# CLAUDE.md

Bu projede çalışmadan önce **[AGENTS.md](AGENTS.md)** ve en yeni çalışma devri için **[PROJE_DEVIR.md](PROJE_DEVIR.md)** oku. Ürün özeti [README.md](README.md) ve [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) içindedir. Öncelik: canlı DB > AGENTS.md > repodaki migration'lar > diğer belgeler.
1. Puan, kum, seri ve lig yalnızca sunucuda hesaplanır; istemci RPC sonucunu gösterir. Seans hiçbir durumda sessizce silinmez.
2. Canlı DB'ye `supabase db push` / MCP ile yazma yok: canlı tanımdan migration + rollback + DRYRUN dosyası hazırla, kullanıcı SQL Editor'de çalıştırır.
3. Sırlar yalnızca uygun yerel secret dosyalarında ve Edge secrets'ta; `.env` dosyalarının içeriğini okuma. Kod değişikliklerinde uygun `flutter analyze` / `flutter test` kontrollerini çalıştır. Yalnızca dokümantasyon değişikliği için link ve `git diff --check` yeterlidir; raporlanmış QA sonuçlarını yeni test gibi sunma.
