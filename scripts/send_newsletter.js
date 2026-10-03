require('dotenv').config({ path: './.env' });
const { createClient } = require('@supabase/supabase-js');
const { Resend } = require('resend');
const fs = require('fs');
const crypto = require('crypto');
const path = require('path');

// --- AYARLAR ---
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const RESEND_API_KEY = process.env.RESEND_API_KEY;
// Abonelikten çıkma linklerini imzalamak için gizli anahtar. Aynı değer
// `unsubscribe` Edge Function'ında da tanımlı olmalı; fonksiyon token'ı
// doğrulamadan kimseyi listeden çıkarmamalı (aksi halde herkes, sadece
// e-posta adresini bilerek başkasını listeden çıkarabilir).
const UNSUBSCRIBE_SECRET = process.env.UNSUBSCRIBE_SECRET;

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !RESEND_API_KEY || !UNSUBSCRIBE_SECRET) {
  console.error("HATA: .env dosyasında SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY veya UNSUBSCRIBE_SECRET eksik!");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const resend = new Resend(RESEND_API_KEY);

// --- MAİL İÇERİĞİ ---
const emailSubject = 'PomoSprint: Yeni Harika Özellikler Geldi! 🚀';

// Ana dizindeki HTML dosyasını okuyoruz
const templatePath = path.join(__dirname, '..', 'newsletter_template.html');
let emailHtml = fs.readFileSync(templatePath, 'utf8');

// Resend'in zorunlu tagini bizim özel sistemimizle değiştiriyoruz
emailHtml = emailHtml.replace(
  '{{ unsubscribe_url }}', 
  'https://pomosprint.app/unsubscribe.html?email={{email}}&token={{token}}'
);

// E-posta adresine özel HMAC-SHA256 imzası. Edge Function aynı hesaplamayı
// yapıp sabit zamanlı karşılaştırmayla doğrulamalı.
function unsubscribeToken(email) {
  return crypto
    .createHmac('sha256', UNSUBSCRIBE_SECRET)
    .update(email.trim().toLowerCase())
    .digest('hex');
}

async function sendNewsletter() {
  console.log("1. Aboneler Supabase'den çekiliyor...");
  const { data: subscribers, error } = await supabase
    .from('marketing_subscribers')
    .select('email');

  if (error) {
    console.error('Veritabanı hatası:', error);
    return;
  }

  if (!subscribers || subscribers.length === 0) {
    console.log('Hiç abone bulunamadı!');
    return;
  }

  console.log(`Toplam ${subscribers.length} abone bulundu. Mailler gönderiliyor...`);

  const emailsToSend = subscribers.map(sub => {
    // Kişiye özel abonelikten çıkma linki oluşturuluyor
    const personalizedHtml = emailHtml
      .replace('{{email}}', encodeURIComponent(sub.email))
      .replace('{{token}}', unsubscribeToken(sub.email));
    
    return {
      from: 'PomoSprint <noreply@mail.pomosprint.app>',
      to: [sub.email],
      subject: emailSubject,
      html: personalizedHtml,
    };
  });

  try {
    const response = await resend.batch.send(emailsToSend);
    console.log('✅ İşlem Başarılı! Mailler gönderildi.');
    console.log(response);
  } catch (err) {
    console.error('Mail gönderim hatası:', err);
  }
}

sendNewsletter();
