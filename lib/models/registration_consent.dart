import 'package:flutter/foundation.dart';

/// Kayıt ekranındaki onaylar.
///
/// - [termsAccepted] (zorunlu): Kullanım Şartları kabul edildi.
/// - [privacyAcknowledged] (zorunlu): KVKK Aydınlatma Metni ve Gizlilik
///   Politikası okundu. Bu bir BİLGİLENDİRME teyididir, açık rıza değildir.
/// - [marketingConsent] (isteğe bağlı, varsayılan kapalı): yeni özellikler ve
///   güncellemeler hakkında e-posta (ticari elektronik ileti onayı).
@immutable
class RegistrationConsent {
  final bool termsAccepted;
  final bool privacyAcknowledged;
  final bool marketingConsent;

  /// Onaylanan yasal metinlerin sürümü (bkz. kLegalDocumentsVersion).
  final String legalVersion;

  /// Onayın verildiği an; metadata'ya UTC ISO-8601 olarak yazılır.
  final DateTime acceptedAt;

  const RegistrationConsent({
    required this.termsAccepted,
    required this.privacyAcknowledged,
    this.marketingConsent = false,
    required this.legalVersion,
    required this.acceptedAt,
  });

  /// Zorunlu iki onay da verildi mi? Verilmeden kayıt isteği gönderilmez.
  bool get hasRequired => termsAccepted && privacyAcknowledged;

  /// Supabase signUp `data` alanına (auth.users.raw_user_meta_data) eklenen
  /// onay kaydı. 'newsletter' anahtarı handle_newsletter_subscription
  /// trigger'ının okuduğu mevcut sözleşmedir; korunur.
  Map<String, dynamic> toMetadata() {
    if (!hasRequired) {
      throw StateError('Zorunlu onaylar verilmeden kayıt metadata\'sı üretilemez.');
    }
    return {
      'newsletter': marketingConsent,
      'marketing_consent': marketingConsent,
      'terms_version': legalVersion,
      'privacy_version': legalVersion,
      'terms_accepted_at': acceptedAt.toUtc().toIso8601String(),
    };
  }
}
