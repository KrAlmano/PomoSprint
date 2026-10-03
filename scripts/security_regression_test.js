// Güvenlik + iş kuralı regresyon testleri.
// Gerçek projeye karşı, tek kullanımlık test hesaplarıyla çalışır ve
// sonunda onları siler. Amaç: RLS/RPC sıkılaştırmalarının (profiles
// tek-satır erişimi, ensure_user_in_league/process_weekly_leagues'in
// dışarıdan çağrılamaması, günlük 16 seans ödül tavanı, vb.) ileride
// yapılacak bir değişiklikle sessizce bozulmadığını tek komutla
// doğrulamak.
//
// Bazı senaryolar supabase/proposed/11_audit_fixes_unapplied.sql (canlıda YOK) ve
// unsubscribe Edge Function'ının yeni sürümü canlıya alınmadan BAŞARISIZ
// olur; bu beklenen durumdur ve neyin eksik olduğunu gösterir.
//
// Çalıştırma: node scripts/security_regression_test.js
// Ayarlar yalnızca scripts/.env dosyasından okunur (bkz. scripts/.env.example).
// Service role anahtarını KÖK .env'e koymayın: kök .env uygulamaya asset
// olarak gömülür.

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !ANON_KEY || !SERVICE_KEY) {
  console.error('HATA: SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY eksik (scripts/.env kontrol et, örnek: scripts/.env.example).');
  process.exit(1);
}

const clientOptions = { auth: { autoRefreshToken: false, persistSession: false } };
const admin = createClient(SUPABASE_URL, SERVICE_KEY, clientOptions);
const anonClient = createClient(SUPABASE_URL, ANON_KEY, clientOptions);

let passed = 0;
let failed = 0;
const failures = [];

function check(name, cond, detail) {
  if (cond) {
    passed++;
    console.log(`  ✅ ${name}`);
  } else {
    failed++;
    failures.push(name);
    console.log(`  ❌ ${name}${detail ? ' — ' + detail : ''}`);
  }
}

const describe = (data, error) => (error ? error.message : JSON.stringify(data));
const minutesAgo = (m) => new Date(Date.now() - m * 60 * 1000).toISOString();
const ids = (rows) => (Array.isArray(rows) ? rows.map((r) => r.id) : []);
const countOf = (rows, id) => ids(rows).filter((x) => x === id).length;

async function createTestUser(label) {
  const email = `sectest_${label}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@pomosprinttest.com`;
  const password = 'TestSifre123!';
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw new Error(`createTestUser(${label}) failed: ${error.message}`);

  const client = createClient(SUPABASE_URL, ANON_KEY, clientOptions);
  const { error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError) throw new Error(`signIn(${label}) failed: ${signInError.message}`);

  return { id: data.user.id, email, client };
}

async function deleteTestUser(id) {
  if (!id) return;
  await admin.auth.admin.deleteUser(id).catch(() => {});
}

// complete_study_session'ı çağırır; RPC exception'ı (error) ve yumuşak
// reddi ({error: ...}) ayrı ayrı döndürür.
async function completeSession(user, { categoryId, minutes = 25, paused = false, startedAt, clientUuid }) {
  const uuid = clientUuid || crypto.randomUUID();
  const { data, error } = await user.client.rpc('complete_study_session', {
    p_client_uuid: uuid,
    p_category_id: categoryId,
    p_duration_minutes: minutes,
    p_was_paused: paused,
    p_is_verified: minutes * 60,
    p_started_at: startedAt,
  });
  const accepted = !error && !!data && !data.error;
  return { uuid, data, error, accepted };
}

async function storedSession(clientUuid) {
  const { data } = await admin
    .from('study_sessions')
    .select('started_at, completed_at, duration_minutes')
    .eq('client_uuid', clientUuid)
    .maybeSingle();
  return data;
}

async function main() {
  console.log('Test hesapları oluşturuluyor...');
  const a = await createTestUser('a');
  const b = await createTestUser('b');
  console.log(`  A=${a.id.slice(0, 8)}  B=${b.id.slice(0, 8)}\n`);

  try {
    console.log('--- profiles RLS ---');
    {
      const { data } = await a.client.from('profiles').select('*').eq('id', b.id);
      check('A, B\'nin profilini okuyamaz (cross-user SELECT boş dönmeli)', Array.isArray(data) && data.length === 0);
    }
    {
      const { data, error } = await a.client.from('profiles').select('id,email,name').eq('id', a.id);
      check('A kendi profilini okuyabilir', !error && Array.isArray(data) && data.length === 1);
    }

    console.log('\n--- profil oluşturma varsayılanları (BACKEND-12 / SOCIAL-15) ---');
    {
      // Profil canlıdaki auth trigger'ı ile zaten oluşmuşsa bu upsert bir şey
      // yapmaz; oluşmamışsa sahte e-posta ve ücretli avatarla oluşturmayı dener.
      await a.client.from('profiles').upsert(
        { id: a.id, email: 'baskasi@example.com', name: 'SecTest A', avatar_id: 'avatar_1_gamer' },
        { onConflict: 'id', ignoreDuplicates: true },
      );
      const { data: prof } = await admin
        .from('profiles')
        .select('email, avatar_id, equipped_avatar_id')
        .eq('id', a.id)
        .maybeSingle();
      const { data: av } = prof && prof.avatar_id
        ? await admin.from('avatars').select('id, is_default').eq('id', prof.avatar_id).maybeSingle()
        : { data: null };
      // proposed/13 (KVKK-20) uygulanınca profiles.email hep NULL; öncesinde auth e-postası.
      check(
        'Profil e-postası istemciden yazılamaz (auth e-postası ya da proposed/13 sonrası NULL)',
        !!prof && (prof.email === a.email || prof.email === null),
        JSON.stringify(prof),
      );
      check('Yeni profilin avatarı varsayılan (is_default) bir avatar', !!av && av.is_default === true, JSON.stringify(av));
      check('equipped_avatar_id, avatar_id ile aynı', !!prof && prof.equipped_avatar_id === prof.avatar_id, JSON.stringify(prof));
    }

    console.log('\n--- avatar kataloğu (SOCIAL-V01) ---');
    {
      const { data, error } = await anonClient.from('avatars').select('id').limit(1);
      check('Oturumsuz (anon) avatar kataloğunu okuyabilir', !error && Array.isArray(data) && data.length === 1, describe(data, error));
    }

    console.log('\n--- ensure_user_in_league ---');
    {
      const { error } = await a.client.rpc('ensure_user_in_league', { p_user_id: b.id, p_points: 999999 });
      check('A, B adına lig puanı yazamaz (EXECUTE reddedilmeli)', !!error, error && error.message);
    }

    console.log('\n--- process_weekly_leagues ---');
    {
      const { error } = await a.client.rpc('process_weekly_leagues');
      check('Giriş yapmış kullanıcı process_weekly_leagues çağıramaz', !!error, error && error.message);
    }
    {
      const { error } = await anonClient.rpc('process_weekly_leagues');
      check('Anonim (girişsiz) process_weekly_leagues çağıramaz', !!error, error && error.message);
    }

    console.log('\n--- cleanup_unconfirmed_duplicate_identity ---');
    {
      const { error } = await a.client.rpc('cleanup_unconfirmed_duplicate_identity', { p_email: b.email });
      check('A, B\'nin e-postasıyla temizlik çağıramaz', !!error, error && error.message);
    }
    {
      const { error } = await a.client.rpc('cleanup_unconfirmed_duplicate_identity', { p_email: a.email });
      check('A kendi e-postasıyla temizlik çağırabilir', !error, error && error.message);
    }

    console.log('\n--- add_friend_by_code (points sütunu bug fix) ---');
    {
      const { data, error } = await a.client.rpc('add_friend_by_code', { p_code: 'ZZZZZZ' });
      check('add_friend_by_code temiz JSON döner (kolon hatası yok)', !error && data && data.success === false, error && error.message);
    }

    console.log('\n--- purchase_avatar / lig ödülü avatarları ---');
    {
      const { error } = await a.client.rpc('purchase_avatar', { p_avatar_id: 'league_gold_monthly' });
      check('Lig ödülü avatarı parayla satın alınamaz', !!error, error && error.message);
    }

    console.log('\n--- complete_study_session: doğrulama, çevrimdışı kuyruk, puan ---');
    const { data: catId, error: catErr } = await a.client.rpc('create_category', {
      p_name: 'SecTest', p_color_hex: '#FF0000', p_icon_name: 'star',
    });
    check('create_category çalışıyor', !catErr && !!catId, catErr && catErr.message);

    if (catId) {
      // Sunucu seansın gerçekten sürmüş olmasını şart koşuyor
      // (20260928120000_security_hardening: started_at + süre <= now()).
      // Seanslar started_at sırasıyla gönderilir (istemci kuyruğu da böyle
      // gönderir); daha yeni bir seanstan sonra gönderilen daha eski seans
      // proposed/01 uygulanana kadar 'overlap' alır.
      const hack = await completeSession(a, { categoryId: catId, minutes: 50, startedAt: new Date().toISOString() });
      check('Süresi dolmamış seans reddedilir (anında puan hilesi kapalı)', !hack.accepted, describe(hack.data, hack.error));

      // BACKEND-01: iki çevrimdışı seans arka arkaya senkronlanır.
      const off1 = await completeSession(a, { categoryId: catId, startedAt: minutesAgo(180) });
      check('Çevrimdışı 1. seans kabul edilir', off1.accepted, describe(off1.data, off1.error));
      const off2 = await completeSession(a, { categoryId: catId, startedAt: minutesAgo(155) });
      check('Çevrimdışı 2. seans (1.\'nin bitişinde başlayan) da kabul edilir', off2.accepted, describe(off2.data, off2.error));

      const row1 = await storedSession(off1.uuid);
      const realLength = row1 ? new Date(row1.completed_at) - new Date(row1.started_at) : NaN;
      check(
        'completed_at = started_at + süre (senkron anı değil)',
        Math.abs(realLength - 25 * 60 * 1000) < 1000,
        JSON.stringify(row1),
      );

      const retry = await completeSession(a, { categoryId: catId, startedAt: minutesAgo(180), clientUuid: off1.uuid });
      check('Aynı client_uuid tekrar gönderilince duplicate döner', !retry.error && retry.data && retry.data.duplicate === true, describe(retry.data, retry.error));

      const s1 = await completeSession(a, { categoryId: catId, startedAt: minutesAgo(30) });
      check('25 dk seans: base_points = 5', s1.accepted && s1.data.base_points === 5, describe(s1.data, s1.error));
      check('25 dk seans: coins_earned = 20', s1.accepted && s1.data.coins_earned === 20, describe(s1.data, s1.error));

      const { data: bCat } = await b.client.rpc('create_category', {
        p_name: 'SecTestB', p_color_hex: '#00FF00', p_icon_name: 'star',
      });
      const s2 = await completeSession(b, { categoryId: bCat, paused: true, startedAt: minutesAgo(90) });
      check('Duraklatılmış seansta %20 puan kesintisi uygulanır (5 -> 4)', s2.accepted && s2.data.base_points === 4, describe(s2.data, s2.error));

      // BACKEND-08: cihaz saati ~4 dk ileride (bitiş 4 dk sonra) -> kabul,
      // trigger bitişi now()+3 dk'ya çeker. (Trigger 15 dk'ya kadar kırpar;
      // 20261003150000'deki complete_study_session 5 dk üzerini RPC'de
      // reddettiği için canlıda etkin tolerans 5 dk.) Debug build'in 10
      // sn'lik seansı -> red.
      const skew = await completeSession(b, { categoryId: bCat, startedAt: minutesAgo(21) });
      check('Saati birkaç dakika ileri cihazın seansı kabul edilir', skew.accepted, describe(skew.data, skew.error));
      const skewRow = await storedSession(skew.uuid);
      check(
        'İleri saatli seansın bitişi en fazla now()+3 dk',
        !!skewRow && new Date(skewRow.completed_at).getTime() <= Date.now() + 3 * 60 * 1000 + 5000,
        JSON.stringify(skewRow),
      );
      const debugLike = await completeSession(b, { categoryId: bCat, startedAt: new Date(Date.now() - 10 * 1000).toISOString() });
      check('10 saniye önce başlamış 25 dk seans reddedilir', !debugLike.accepted, describe(debugLike.data, debugLike.error));
    }

    console.log('\n--- study_sessions RLS (STATS-14) ---');
    {
      const { data, error } = await b.client.from('study_sessions').select('id').eq('user_id', a.id);
      check('B, A\'nın seanslarını okuyamaz', !error && Array.isArray(data) && data.length === 0, describe(data, error));
    }

    console.log('\n--- profiles kolon yetkileri ---');
    {
      await a.client.from('profiles').update({ coins: 999999 }).eq('id', a.id);
      const { data } = await admin.from('profiles').select('coins').eq('id', a.id).single();
      check('Kullanıcı kendi coin bakiyesini değiştiremez', data && data.coins !== 999999, data && JSON.stringify(data));
    }
    {
      const { data, error } = await a.client.from('profiles').update({ name: 'SecTest A' }).eq('id', a.id).select('id');
      check('Kullanıcı kendi ismini id filtresiyle değiştirebilir (1 satır)', !error && Array.isArray(data) && data.length === 1, describe(data, error));
    }

    console.log('\n--- lig sıralaması e-posta sızdırmaz ---');
    {
      const { data, error } = await a.client.rpc('get_my_league_ranking');
      check(
        'get_my_league_ranking e-posta döndürmez',
        !error && Array.isArray(data) && data.every((row) => !('email' in row)),
        error ? error.message : JSON.stringify(data && data[0])
      );
    }
    {
      const { error } = await a.client.rpc('get_league_ranking', { p_user_id: b.id });
      check('Eski get_league_ranking istemciye kapalı', !!error, error && error.message);
    }

    console.log('\n--- arkadaşlık RPC\'leri (SOCIAL-05 / BACKEND-14) ---');
    {
      const { data: bProfile } = await b.client.from('profiles').select('friend_code').eq('id', b.id).maybeSingle();
      const code = bProfile && bProfile.friend_code;
      check('B\'nin arkadaş kodu var', !!code, JSON.stringify(bProfile));

      if (code) {
        const { data: add, error: addErr } = await a.client.rpc('add_friend_by_code', { p_code: code });
        check('A, B\'ye istek gönderir', !addErr && add && add.success === true, describe(add, addErr));

        const { data: incoming, error: inErr } = await b.client.rpc('get_incoming_friend_requests');
        check('B, A\'nın bekleyen isteğini görür (tam bir kez)', !inErr && countOf(incoming, a.id) === 1, describe(incoming, inErr));
        check(
          'İstek satırları e-posta içermez',
          Array.isArray(incoming) && incoming.every((r) => !('email' in r)),
          JSON.stringify(incoming && incoming[0]),
        );

        const { data: outgoing, error: outErr } = await a.client.rpc('get_outgoing_friend_requests');
        check('A gönderdiği isteği görür', !outErr && countOf(outgoing, b.id) === 1, describe(outgoing, outErr));

        const { data: resp, error: respErr } = await b.client.rpc('respond_friend_request', { p_from_user_id: a.id, p_accept: true });
        check('B isteği kabul eder', !respErr && resp && resp.success !== false, describe(resp, respErr));

        const { data: aFriends, error: aErr } = await a.client.rpc('get_my_friends');
        const { data: bFriends, error: bErr } = await b.client.rpc('get_my_friends');
        check('A\'nın listesinde B tam bir kez', !aErr && countOf(aFriends, b.id) === 1, describe(aFriends, aErr));
        check('B\'nin listesinde A tam bir kez (iki yönlü)', !bErr && countOf(bFriends, a.id) === 1, describe(bFriends, bErr));

        const { data: incomingAfter } = await b.client.rpc('get_incoming_friend_requests');
        check('Kabul edilen istek gelen istekler listesinden düşer', countOf(incomingAfter, a.id) === 0, JSON.stringify(incomingAfter));

        const { error: anonErr } = await anonClient.rpc('get_my_friends');
        check('Anonim get_my_friends çağıramaz', !!anonErr, anonErr && anonErr.message);

        const { data: rm, error: rmErr } = await a.client.rpc('remove_friend', { p_friend_id: b.id });
        const { data: bFriendsAfter } = await b.client.rpc('get_my_friends');
        check('A arkadaşlığı siler, iki taraftan da düşer', !rmErr && rm && rm.success === true && countOf(bFriendsAfter, a.id) === 0, describe(rm, rmErr));
      }
    }

    console.log('\n--- saat dilimi (BACKEND-09) ---');
    {
      const { error: badErr } = await a.client.rpc('set_my_timezone', { p_tz: 'Mars/Phobos' });
      check('Geçersiz saat dilimi reddedilir', !!badErr, badErr && badErr.message);
      const { data: tz1, error: tzErr } = await a.client.rpc('set_my_timezone', { p_tz: 'Europe/Berlin' });
      check('Geçerli saat dilimi kaydedilir', !tzErr && tz1 === 'Europe/Berlin', describe(tz1, tzErr));
      const { data: tz2 } = await a.client.rpc('set_my_timezone', { p_tz: 'Asia/Tokyo' });
      check('24 saat dolmadan ikinci değişiklik uygulanmaz', tz2 === 'Europe/Berlin', JSON.stringify(tz2));
    }

    console.log('\n--- kategori limiti (BACKEND-28) ---');
    {
      const { data: limit, error: limitErr } = await a.client.rpc('get_my_category_limit');
      check('get_my_category_limit ücretsiz kullanıcı için 8', !limitErr && limit === 8, describe(limit, limitErr));
      const { count } = await a.client.from('categories').select('id', { count: 'exact', head: true }).eq('is_archived', false);
      const toFill = Math.max(0, 8 - (count || 0));
      if (toFill > 0) {
        await a.client.from('categories').insert(
          Array.from({ length: toFill }, (_, i) => ({ user_id: a.id, name: `SecFill${i}`, color_hex: '#123456' })),
        );
      }
      const { error: overErr } = await a.client.from('categories').insert({ user_id: a.id, name: 'SecOver', color_hex: '#123456' });
      check('9. aktif kategori reddedilir', !!overErr, overErr ? JSON.stringify(overErr) : 'hata yok');
      const { data: archived } = await a.client.from('categories').select('id').eq('name', 'SecFill0').maybeSingle();
      if (archived) {
        await a.client.from('categories').update({ is_archived: true }).eq('id', archived.id);
        await a.client.from('categories').insert({ user_id: a.id, name: 'SecRefill', color_hex: '#123456' });
        const { error: unarchiveErr } = await a.client.from('categories').update({ is_archived: false }).eq('id', archived.id);
        check('Arşivden çıkarma da limite tabi', !!unarchiveErr, unarchiveErr ? unarchiveErr.message : 'hata yok');
      }
    }

    console.log('\n--- unsubscribe Edge Function (LANDING-01 / PLATFORM-V03) ---');
    {
      // Var olmayan bir adresle; silme yapmaz. Joker karakter içermez.
      const base = `${SUPABASE_URL.replace(/\/+$/, '')}/functions/v1/unsubscribe`;
      const probe = `sectest-nonexistent-${Date.now()}@example.invalid`;
      const noToken = await fetch(`${base}?email=${encodeURIComponent(probe)}`);
      check('Token\'sız istek 400 döner (eski sürüm 200 dönüyordu)', noToken.status === 400, `status=${noToken.status}`);
      const badToken = await fetch(`${base}?email=${encodeURIComponent(probe)}&token=${'0'.repeat(64)}`);
      check('Yanlış token 403 döner (401 ise --no-verify-jwt unutulmuş)', badToken.status === 403, `status=${badToken.status}`);
      const preflight = await fetch(base, { method: 'OPTIONS', headers: { Origin: 'https://www.pomosprint.app' } });
      check(
        'CORS www.pomosprint.app\'e izin verir',
        preflight.headers.get('access-control-allow-origin') === 'https://www.pomosprint.app',
        `ACAO=${preflight.headers.get('access-control-allow-origin')}`,
      );
    }
  } finally {
    console.log('\nTest hesapları temizleniyor...');
    await admin
      .from('friendships')
      .delete()
      .or(`user_id.in.(${a.id},${b.id}),friend_id.in.(${a.id},${b.id})`)
      .then(() => {}, () => {});
    await deleteTestUser(a.id);
    await deleteTestUser(b.id);
  }

  console.log(`\n${passed} geçti, ${failed} başarısız.`);
  if (failed > 0) {
    console.log('Başarısız olanlar:', failures.join(', '));
    process.exit(1);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('Beklenmeyen hata:', e);
  process.exit(1);
});
