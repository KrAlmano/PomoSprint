// scripts/lib/newsletter_mail.js testi (KVKK-11): bülten bağlantıları yalnızca
// token taşır, altbilgide gönderen kimliği zorunludur.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');

const {
  buildEmail,
  missingPlaceholders,
  readSenderIdentity,
  renderTemplate,
  unsubscribeLinks,
} = require('../lib/newsletter_mail');

const TOKEN = '9a8b7c6d-3333-4444-8555-b66677788899';
const EMAIL = 'ayse.yilmaz@example.com';
const SENDER = { name: 'Test Gönderen', address: 'Örnek Mah. No:1, İstanbul', missing: [] };
const TEMPLATE = fs.readFileSync(path.join(__dirname, '..', 'templates', 'newsletter.html'), 'utf8');

test('abonelikten çıkma bağlantıları yalnızca token taşır', () => {
  const { pageUrl, oneClickUrl } = unsubscribeLinks(TOKEN, 'https://proj.supabase.co///');
  assert.equal(pageUrl, `https://pomosprint.app/unsubscribe?token=${TOKEN}`);
  assert.equal(oneClickUrl, `https://proj.supabase.co/functions/v1/unsubscribe?token=${TOKEN}`);
});

test('buildEmail: e-posta adresi hiçbir bağlantıda yok, tek tık başlıkları var', () => {
  const mail = buildEmail({ email: EMAIL, token: TOKEN }, {
    template: TEMPLATE,
    subject: 'Konu',
    from: 'PomoSprint <noreply@mail.pomosprint.app>',
    supabaseUrl: 'https://proj.supabase.co',
    sender: SENDER,
  });
  assert.deepEqual(mail.to, [EMAIL]);
  assert.equal(mail.headers['List-Unsubscribe'], `<https://proj.supabase.co/functions/v1/unsubscribe?token=${TOKEN}>`);
  assert.equal(mail.headers['List-Unsubscribe-Post'], 'List-Unsubscribe=One-Click');
  assert.ok(mail.html.includes(`href="https://pomosprint.app/unsubscribe?token=${TOKEN}"`));
  const hrefs = mail.html.match(/href="[^"]*"/g) || [];
  assert.ok(hrefs.length > 0);
  for (const href of hrefs) {
    assert.ok(!href.includes('email='), href);
    assert.ok(!href.includes(EMAIL) && !href.includes(encodeURIComponent(EMAIL)), href);
  }
});

test('örnek şablon altbilgisi gönderen kimliği, iletişim ve gizlilik/KVKK bağlantılarını içerir', () => {
  assert.deepEqual(missingPlaceholders(TEMPLATE), []);
  const html = renderTemplate(TEMPLATE, {
    unsubscribeUrl: unsubscribeLinks(TOKEN, 'https://proj.supabase.co').pageUrl,
    email: EMAIL,
    senderName: SENDER.name,
    senderAddress: SENDER.address,
  });
  assert.ok(html.includes('Test Gönderen'));
  assert.ok(html.includes('Örnek Mah. No:1, İstanbul'));
  assert.ok(html.includes('destek@pomosprint.app'));
  assert.ok(html.includes('https://pomosprint.app/privacy'));
  assert.ok(html.includes('https://pomosprint.app/kvkk'));
  assert.ok(!/\{\{\s*\w+\s*\}\}/.test(html), 'doldurulmamış yer tutucu kalmamalı');
});

test('zorunlu yer tutucusu eksik şablon reddedilir', () => {
  assert.deepEqual(missingPlaceholders('<p>{{ unsubscribe_url }}</p>'), ['sender_name', 'sender_address']);
  assert.deepEqual(missingPlaceholders('<p>{{sender_name}} {{sender_address}}</p>'), ['unsubscribe_url']);
});

test('gönderen kimliği .env\'den okunur, eksikse bildirilir (uydurulmaz)', () => {
  assert.deepEqual(readSenderIdentity({}), { name: '', address: '', missing: ['MAIL_SENDER_NAME', 'MAIL_SENDER_ADDRESS'] });
  assert.deepEqual(
    readSenderIdentity({ MAIL_SENDER_NAME: '  Ad Soyad ', MAIL_SENDER_ADDRESS: ' ' }),
    { name: 'Ad Soyad', address: '', missing: ['MAIL_SENDER_ADDRESS'] },
  );
});

test('değerler HTML kaçışlanır ve $& gibi diziler kalıp sayılmaz', () => {
  const html = renderTemplate('{{sender_name}}|{{sender_address}}|{{email}}|{{unsubscribe_url}}', {
    unsubscribeUrl: 'https://pomosprint.app/unsubscribe?token=a&b',
    email: 'x$&y@example.com',
    senderName: 'A & B <Ltd>',
    senderAddress: '"Adres" $1',
  });
  assert.equal(html, 'A &amp; B &lt;Ltd&gt;|&quot;Adres&quot; $1|x$&amp;y@example.com|https://pomosprint.app/unsubscribe?token=a&amp;b');
});
