// Bülten e-postasının saf (ağsız, bağımlılıksız) parçaları.
// scripts/send_newsletter.js kullanır; scripts/test/newsletter_mail.test.js sınar.
//
// Şablon yer tutucuları (her geçtiği yer değiştirilir, değerler HTML kaçışlı):
//   {{unsubscribe_url}}  kişiye özel abonelikten çıkma sayfası (ZORUNLU)
//   {{sender_name}}      hizmet sağlayıcının adı-soyadı ya da unvanı (ZORUNLU)
//   {{sender_address}}   hizmet sağlayıcının iletişim adresi (ZORUNLU)
//   {{email}}            alıcının e-posta adresi (isteğe bağlı)
// Abonelikten çıkma bağlantıları yalnızca token taşır; e-posta adresi URL'ye
// konmaz (KVKK-11).

const UNSUBSCRIBE_PAGE = 'https://pomosprint.app/unsubscribe';
const REQUIRED_PLACEHOLDERS = ['unsubscribe_url', 'sender_name', 'sender_address'];
const SENDER_ENV = { name: 'MAIL_SENDER_NAME', address: 'MAIL_SENDER_ADDRESS' };

const placeholderRe = (name) => new RegExp(`\\{\\{\\s*${name}\\s*\\}\\}`, 'g');

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Sayfa bağlantısı ve RFC 8058 tek tık adresi; ikisi de yalnızca token taşır.
function unsubscribeLinks(token, supabaseUrl) {
  const query = `token=${encodeURIComponent(String(token))}`;
  return {
    pageUrl: `${UNSUBSCRIBE_PAGE}?${query}`,
    oneClickUrl: `${String(supabaseUrl).replace(/\/+$/, '')}/functions/v1/unsubscribe?${query}`,
  };
}

// Şablonda eksik zorunlu yer tutucular (boş dizi: şablon gönderime uygun).
function missingPlaceholders(template) {
  return REQUIRED_PLACEHOLDERS.filter((name) => !placeholderRe(name).test(template));
}

// scripts/.env'den gönderen kimliği. Bilgi uydurulmaz: eksikse `missing` dolu döner.
function readSenderIdentity(env) {
  const name = String(env[SENDER_ENV.name] || '').trim();
  const address = String(env[SENDER_ENV.address] || '').trim();
  const missing = [];
  if (!name) missing.push(SENDER_ENV.name);
  if (!address) missing.push(SENDER_ENV.address);
  return { name, address, missing };
}

function renderTemplate(template, { unsubscribeUrl, email, senderName, senderAddress }) {
  // Fonksiyonlu replace: değerdeki '$&' gibi diziler özel kalıp sayılmasın.
  return template
    .replace(placeholderRe('unsubscribe_url'), () => escapeHtml(unsubscribeUrl))
    .replace(placeholderRe('sender_name'), () => escapeHtml(senderName))
    .replace(placeholderRe('sender_address'), () => escapeHtml(senderAddress))
    .replace(placeholderRe('email'), () => escapeHtml(email));
}

function buildEmail(subscriber, { template, subject, from, supabaseUrl, sender }) {
  const { email, token } = subscriber;
  const { pageUrl, oneClickUrl } = unsubscribeLinks(token, supabaseUrl);
  return {
    from,
    to: [email],
    subject,
    html: renderTemplate(template, {
      unsubscribeUrl: pageUrl,
      email,
      senderName: sender.name,
      senderAddress: sender.address,
    }),
    headers: {
      'List-Unsubscribe': `<${oneClickUrl}>`,
      'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
    },
  };
}

module.exports = {
  REQUIRED_PLACEHOLDERS,
  SENDER_ENV,
  buildEmail,
  escapeHtml,
  missingPlaceholders,
  readSenderIdentity,
  renderTemplate,
  unsubscribeLinks,
};
