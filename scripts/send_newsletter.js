// Bülten gönderim script'i (marketing_subscribers -> Resend).
//
// Kullanım:
//   node scripts/send_newsletter.js --dry-run
//   node scripts/send_newsletter.js [--template <yol>] [--subject "<konu>"] [--from <n>]
//
//   --dry-run   Hiç e-posta göndermez; abone sayısını, parça planını ve ilk
//               abonenin kişisel abonelikten çıkma linkini yazar.
//   --template  HTML şablonu (varsayılan: scripts/templates/newsletter.html).
//   --subject   E-posta konusu.
//   --from <n>  Sıralı listede ilk n aboneyi atlar (yarıda kalan gönderimi
//               sürdürmek için; script başarısız parçaların başlangıcını yazar).
//
// Ayarlar yalnızca scripts/.env dosyasından okunur (bkz. scripts/.env.example).
// Kök .env uygulamaya asset olarak gömüldüğü için service role anahtarı oraya
// ASLA konmamalı.
//
// Şablon yer tutucuları (her geçtiği yer değiştirilir):
//   {{unsubscribe_url}}  kişiye özel abonelikten çıkma sayfası linki (ZORUNLU)
//   {{email}}            alıcının e-posta adresi (HTML kaçışlı)

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '.env') });
const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');
const fs = require('fs');

// --- ARGÜMANLAR ---
const args = process.argv.slice(2);
const argValue = (name) => {
  const i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : undefined;
};
const DRY_RUN = args.includes('--dry-run');
const TEMPLATE_PATH = path.resolve(argValue('--template') || path.join(__dirname, 'templates', 'newsletter.html'));
const EMAIL_SUBJECT = argValue('--subject') || 'PomoSprint: Yeni Harika Özellikler Geldi! 🚀';
const START_INDEX = Math.max(0, parseInt(argValue('--from') || '0', 10) || 0);

// --- SABİTLER ---
const FROM_ADDRESS = 'PomoSprint <noreply@mail.pomosprint.app>';
const UNSUBSCRIBE_PAGE = 'https://pomosprint.app/unsubscribe';
const BATCH_SIZE = 100; // Resend batch API çağrı başına en fazla 100 e-posta kabul eder.
const PAGE_SIZE = 1000; // PostgREST varsayılan satır sınırı.
const BATCH_DELAY_MS = 600; // Resend varsayılan hız sınırı: saniyede 2 istek.

// --- AYARLAR ---
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const RESEND_API_KEY = process.env.RESEND_API_KEY;
const missing = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY']
  .concat(DRY_RUN ? [] : ['RESEND_API_KEY'])
  .filter((k) => !process.env[k]);
if (missing.length > 0) {
  console.error(`HATA: scripts/.env dosyasında eksik: ${missing.join(', ')} (bkz. scripts/.env.example)`);
  process.exit(1);
}

const placeholderRe = (name) => new RegExp(`\\{\\{\\s*${name}\\s*\\}\\}`, 'g');

if (!fs.existsSync(TEMPLATE_PATH)) {
  console.error(`HATA: Şablon bulunamadı: ${TEMPLATE_PATH}`);
  console.error('Örnek şablon: scripts/templates/newsletter.html (ya da --template <yol>).');
  process.exit(1);
}
const TEMPLATE = fs.readFileSync(TEMPLATE_PATH, 'utf8');
if (!placeholderRe('unsubscribe_url').test(TEMPLATE)) {
  console.error('HATA: Şablonda {{unsubscribe_url}} yer tutucusu yok. Abonelikten çıkma linki olmadan gönderim yapılmaz.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Her abonenin veritabanında tahmin edilemez bir unsubscribe_token'ı
// (UUID) var; unsubscribe Edge Function'ı satırı bu token'la bulup siler.
function unsubscribeQuery({ email, token }) {
  return `email=${encodeURIComponent(email)}&token=${encodeURIComponent(token)}`;
}

function buildEmail(subscriber) {
  const { email } = subscriber;
  const pageUrl = `${UNSUBSCRIBE_PAGE}?${unsubscribeQuery(subscriber)}`;
  // RFC 8058 tek tık: e-posta istemcisi bu adrese doğrudan POST atar.
  const oneClickUrl = `${SUPABASE_URL.replace(/\/+$/, '')}/functions/v1/unsubscribe?${unsubscribeQuery(subscriber)}`;
  // Fonksiyonlu replace: değerdeki '$&' gibi diziler özel kalıp sayılmasın.
  const html = TEMPLATE
    .replace(placeholderRe('unsubscribe_url'), () => escapeHtml(pageUrl))
    .replace(placeholderRe('email'), () => escapeHtml(email));
  return {
    from: FROM_ADDRESS,
    to: [email],
    subject: EMAIL_SUBJECT,
    html,
    headers: {
      'List-Unsubscribe': `<${oneClickUrl}>`,
      'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    },
  };
}

// Tüm aboneleri sayfalayarak çeker; büyük/küçük harf farkıyla yinelenen
// adresler tek gönderime indirilir.
async function fetchAllSubscribers() {
  const byLower = new Map();
  for (let from = 0; ; from += PAGE_SIZE) {
    const { data, error } = await supabase
      .from('marketing_subscribers')
      .select('email, unsubscribe_token')
      .order('email', { ascending: true })
      .range(from, from + PAGE_SIZE - 1);
    if (error) throw new Error(`Veritabanı hatası: ${error.message}`);
    for (const row of data || []) {
      const email = String(row.email || '').trim();
      const token = String(row.unsubscribe_token || '');
      if (email && token && !byLower.has(email.toLowerCase())) byLower.set(email.toLowerCase(), { email, token });
    }
    if (!data || data.length < PAGE_SIZE) break;
  }
  return Array.from(byLower.values());
}

async function sendNewsletter() {
  console.log("1. Aboneler Supabase'den çekiliyor...");
  const subscribers = await fetchAllSubscribers();
  if (subscribers.length === 0) {
    console.log('Hiç abone bulunamadı.');
    return;
  }

  const queue = subscribers.slice(START_INDEX);
  const batchCount = Math.ceil(queue.length / BATCH_SIZE);
  console.log(`Toplam ${subscribers.length} abone; ${START_INDEX > 0 ? `ilk ${START_INDEX} atlanıyor, ` : ''}${queue.length} alıcı, ${batchCount} parça.`);

  if (DRY_RUN) {
    if (queue.length > 0) {
      const sample = buildEmail(queue[0]);
      console.log('[dry-run] Örnek alıcı:', queue[0].email);
      console.log('[dry-run] List-Unsubscribe:', sample.headers['List-Unsubscribe']);
    }
    console.log('[dry-run] Hiç e-posta gönderilmedi.');
    return;
  }

  const resend = new Resend(RESEND_API_KEY);
  let sent = 0;
  const failedBatches = [];

  for (let i = 0; i < queue.length; i += BATCH_SIZE) {
    const chunk = queue.slice(i, i + BATCH_SIZE);
    const batchNo = i / BATCH_SIZE + 1;
    const absoluteStart = START_INDEX + i;
    try {
      // Resend SDK hata fırlatmaz, { data, error } döndürür.
      const { data, error } = await resend.batch.send(chunk.map(buildEmail));
      if (error) {
        failedBatches.push({ batchNo, absoluteStart, reason: error.message || JSON.stringify(error) });
      } else {
        sent += (data && Array.isArray(data.data)) ? data.data.length : chunk.length;
      }
    } catch (err) {
      failedBatches.push({ batchNo, absoluteStart, reason: err && err.message ? err.message : String(err) });
    }
    console.log(`  Parça ${batchNo}/${batchCount}: ${failedBatches.some((f) => f.batchNo === batchNo) ? 'HATA' : 'gönderildi'}`);
    if (i + BATCH_SIZE < queue.length) await sleep(BATCH_DELAY_MS);
  }

  if (failedBatches.length === 0) {
    console.log(`İşlem başarılı: ${sent} e-posta gönderildi.`);
    return;
  }

  process.exitCode = 1;
  console.error(`\n${failedBatches.length} parça gönderilemedi (${sent} e-posta gönderildi):`);
  for (const f of failedBatches) {
    console.error(`  Parça ${f.batchNo} (sıra ${f.absoluteStart}-${f.absoluteStart + BATCH_SIZE - 1}): ${f.reason}`);
  }
  console.error(`Yeniden denemek için: node scripts/send_newsletter.js --from ${failedBatches[0].absoluteStart} ...`);
  console.error('Not: --from sonraki tüm parçaları da yeniden gönderir; başarılı parçalara tekrar gitmemesi için aralığı kontrol edin.');
}

sendNewsletter().catch((err) => {
  console.error('Beklenmeyen hata:', err && err.message ? err.message : err);
  process.exitCode = 1;
});
