# CLAUDE.md

Bu projede çalışmadan önce **[AGENTS.md](AGENTS.md)**'yi oku (öncelik: canlı DB > AGENTS.md > repodaki migration'lar > diğer).
1. Puan, kum, seri ve lig yalnızca sunucuda hesaplanır; istemci RPC sonucunu gösterir. Seans hiçbir durumda sessizce silinmez.
2. Canlı DB'ye `supabase db push` / MCP ile yazma yok: canlı tanımdan migration + rollback + DRYRUN dosyası hazırla, kullanıcı SQL Editor'de çalıştırır.
3. Sırlar yalnızca `scripts/.env` ve Edge secrets'ta; `.env` dosyalarının içeriğini okuma. Her değişiklikten sonra `flutter analyze` ve `flutter test`.
