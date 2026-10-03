// Güvenlik + iş kuralı regresyon testleri.
// Gerçek projeye karşı, tek kullanımlık test hesaplarıyla çalışır ve
// sonunda onları siler. Amaç: RLS/RPC sıkılaştırmalarının (profiles
// tek-satır erişimi, ensure_user_in_league/process_weekly_leagues'in
// dışarıdan çağrılamaması, günlük 16 seans ödül tavanı, vb.) ileride
// yapılacak bir değişiklikle sessizce bozulmadığını tek komutla
// doğrulamak.
//
// Çalıştırma: cd scripts && node security_regression_test.js

require('dotenv').config({ path: '../.env' });
require('dotenv').config({ path: './.env' });
const { createClient } = require('@supabase/supabase-js');
const crypto = require('crypto');

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !ANON_KEY || !SERVICE_KEY) {
  console.error('HATA: SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY eksik (.env veya scripts/.env kontrol et).');
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

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

async function createTestUser(label) {
  const email = `sectest_${label}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@pomosprinttest.com`;
  const password = 'TestSifre123!';
  const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
  if (error) throw new Error(`createTestUser(${label}) failed: ${error.message}`);

  const client = createClient(SUPABASE_URL, ANON_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
  const { error: signInError } = await client.auth.signInWithPassword({ email, password });
  if (signInError) throw new Error(`signIn(${label}) failed: ${signInError.message}`);

  return { id: data.user.id, email, client };
}

async function deleteTestUser(id) {
  if (!id) return;
  await admin.auth.admin.deleteUser(id).catch(() => {});
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
      const anonClient = createClient(SUPABASE_URL, ANON_KEY, { auth: { autoRefreshToken: false, persistSession: false } });
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

    console.log('\n--- complete_study_session: puan hesabı + günlük tavan ---');
    const { data: catId, error: catErr } = await a.client.rpc('create_category', {
      p_name: 'SecTest', p_color_hex: '#FF0000', p_icon_name: 'star',
    });
    check('create_category çalışıyor', !catErr && !!catId, catErr && catErr.message);

    if (catId) {
      // Sunucu artık seansın gerçekten sürmüş olmasını şart koşuyor
      // (20260928120000_security_hardening: started_at + süre <= now()).
      // Bu yüzden geçerli seanslar geçmişe tarihlenerek gönderilir. Her
      // test kullanıcısı yalnızca BİR geçerli seans gönderebilir: canlı
      // RPC'nin çakışma kontrolü önceki seansın completed_at'ine (= çağrı
      // anı) bakar. Günlük 16 seans tavanı gerçek zamanda ~7 saat
      // sürdüğünden burada test edilmiyor.
      const minutesAgo = (m) => new Date(Date.now() - m * 60 * 1000).toISOString();

      const { data: hack, error: hackErr } = await a.client.rpc('complete_study_session', {
        p_client_uuid: crypto.randomUUID(),
        p_category_id: catId,
        p_duration_minutes: 50,
        p_was_paused: false,
        p_is_verified: 3000,
        p_started_at: new Date().toISOString(),
      });
      check(
        'Süresi dolmamış seans reddedilir (anında puan hilesi kapalı)',
        !!hackErr || (hack && hack.error),
        hackErr ? hackErr.message : JSON.stringify(hack)
      );

      const { data: s1, error: s1Err } = await a.client.rpc('complete_study_session', {
        p_client_uuid: crypto.randomUUID(),
        p_category_id: catId,
        p_duration_minutes: 25,
        p_was_paused: false,
        p_is_verified: 1500,
        p_started_at: minutesAgo(30),
      });
      check('25 dk seans: base_points = 5', !s1Err && s1 && s1.base_points === 5, s1Err ? s1Err.message : JSON.stringify(s1));
      check('25 dk seans: coins_earned = 20', !s1Err && s1 && s1.coins_earned === 20);

      const { data: bCat } = await b.client.rpc('create_category', {
        p_name: 'SecTestB', p_color_hex: '#00FF00', p_icon_name: 'star',
      });
      const { data: s2, error: s2Err } = await b.client.rpc('complete_study_session', {
        p_client_uuid: crypto.randomUUID(),
        p_category_id: bCat,
        p_duration_minutes: 25,
        p_was_paused: true,
        p_is_verified: 1500,
        p_started_at: minutesAgo(30),
      });
      check('Duraklatılmış seansta %20 puan kesintisi uygulanır (5 -> 4)', !s2Err && s2 && s2.base_points === 4, s2Err ? s2Err.message : JSON.stringify(s2));
    }

    console.log('\n--- profiles kolon yetkileri ---');
    {
      await a.client.from('profiles').update({ coins: 999999 }).eq('id', a.id);
      const { data } = await admin.from('profiles').select('coins').eq('id', a.id).single();
      check('Kullanıcı kendi coin bakiyesini değiştiremez', data && data.coins !== 999999, data && JSON.stringify(data));
    }
    {
      const { error } = await a.client.from('profiles').update({ name: 'SecTest A' }).eq('id', a.id);
      check('Kullanıcı kendi ismini değiştirebilir', !error, error && error.message);
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
  } finally {
    console.log('\nTest hesapları temizleniyor...');
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
