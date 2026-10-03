import 'package:flutter/foundation.dart';

/// Oturumun neden kapandığı. Giriş ekranı bunu bir kez açıklar; kullanıcının
/// kendi "Çıkış Yap"ı açıklama gerektirmez (notice yok).
enum SignOutNoticeKind {
  /// Hesap ve veriler silindi.
  accountDeleted,

  /// Oturum uzaktan düştü: token yenilenemedi (şifre değişti, hesap başka
  /// cihazdan kapatıldı ya da silindi).
  sessionExpired,

  /// Bu cihazda Apple ile Giriş izni kaldırıldı (getCredentialState).
  appleCredentialRevoked,
}

/// Hesap silmede Sign in with Apple token'ının durumu.
enum AppleRevocation {
  /// Hesapta Apple kimliği yok.
  notApplicable,

  /// Token Apple'da iptal edildi (delete-account Edge Function).
  revoked,

  /// İptal yapılamadı (kullanıcı Apple doğrulamasından vazgeçti, Android,
  /// fonksiyon ya da Apple secret'ları yok, Apple hata verdi). Kullanıcıya
  /// Ayarlar'dan "Kullanmayı Durdur" talimatı gösterilir.
  notRevoked,
}

@immutable
class SignOutNotice {
  final SignOutNoticeKind kind;
  final AppleRevocation apple;

  const SignOutNotice(this.kind, {this.apple = AppleRevocation.notApplicable});

  const SignOutNotice.accountDeleted({AppleRevocation apple = AppleRevocation.notApplicable})
      : this(SignOutNoticeKind.accountDeleted, apple: apple);

  static const SignOutNotice sessionExpired = SignOutNotice(SignOutNoticeKind.sessionExpired);
  static const SignOutNotice appleCredentialRevoked = SignOutNotice(SignOutNoticeKind.appleCredentialRevoked);

  /// Silinen hesabın Apple bağlantısını kullanıcının Ayarlar'dan kaldırması gerekiyor mu?
  bool get needsAppleSettingsHint => kind == SignOutNoticeKind.accountDeleted && apple == AppleRevocation.notRevoked;

  @override
  bool operator ==(Object other) => other is SignOutNotice && other.kind == kind && other.apple == apple;

  @override
  int get hashCode => Object.hash(kind, apple);

  @override
  String toString() => 'SignOutNotice(${kind.name}, apple: ${apple.name})';
}

/// delete-account Edge Function yanıtından Apple iptal durumu
/// (`{"deleted": true, "apple": {"status": "revoked" | "skipped" | "not_applicable"}}`).
/// Hesapta Apple kimliği yoksa her zaman [AppleRevocation.notApplicable].
AppleRevocation appleRevocationFromResponse(Object? data, {required bool hasAppleIdentity}) {
  if (!hasAppleIdentity) return AppleRevocation.notApplicable;
  if (data is Map) {
    final apple = data['apple'];
    if (apple is Map && apple['status'] == 'revoked') return AppleRevocation.revoked;
  }
  return AppleRevocation.notRevoked;
}
