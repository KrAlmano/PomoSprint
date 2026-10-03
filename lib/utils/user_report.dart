/// Kullanıcı bildirimi e-postası (App Store 1.2: kullanıcı içeriğini
/// bildirme yolu). Bildirim destek adresine kullanıcının kendi e-posta
/// uygulamasından gider; bildirenin e-postası ya da kimliği URL'ye
/// KONMAZ (gönderen adresini e-posta uygulaması ekler).
const String kSupportEmail = 'destek@pomosprint.app';

/// `mailto:` adresi. Konu ve gövde yüzde kodlamasıyla (boşluk %20) yazılır;
/// `Uri.queryParameters` boşluğu '+' yaptığı için bazı e-posta
/// uygulamalarında metin bozuk görünüyordu.
Uri buildUserReportUri({required String subject, required String body}) {
  final query = 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}';
  return Uri(scheme: 'mailto', path: kSupportEmail, query: query);
}
