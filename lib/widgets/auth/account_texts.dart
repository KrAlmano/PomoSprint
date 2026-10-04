import '../../l10n/app_localizations.dart';
import '../../services/sign_out_notice.dart';
import '../../utils/user_report.dart';

/// Hesap silme onayı: neyin silineceği, bu cihazdaki gönderilmemiş seanslar,
/// (iOS'ta Apple kimliği olan hesapta) Apple'ın yeniden doğrulayacağı ve
/// veri kopyasının silmeden önce destek adresinden istenebileceği (KVKK m.11
/// başvurusu Aydınlatma Metni'ndeki e-posta yoluyla yapılır).
String deleteAccountConfirmText(
  AppLocalizations l10n, {
  required int pendingCount,
  required bool appleReauthorization,
}) {
  return [
    l10n.profileDeleteConfirm,
    if (pendingCount > 0) l10n.profileDeleteConfirmPending(pendingCount),
    if (appleReauthorization) l10n.profileDeleteConfirmApple,
    l10n.profileDeleteConfirmCopyHint(kSupportEmail),
  ].join('\n\n');
}

/// Çıkış onayının gövdesi: gönderilmemiş seans ve süren sayaç uyarıları;
/// ikisi de yoksa düz onay metni.
String logoutConfirmText(
  AppLocalizations l10n, {
  required int pendingCount,
  required bool hasActiveSession,
}) {
  final warnings = [
    if (pendingCount > 0) l10n.logoutPendingWarning(pendingCount),
    if (hasActiveSession) l10n.logoutRunningWarning,
  ];
  return warnings.isEmpty ? l10n.logoutConfirmBody : warnings.join('\n\n');
}

/// Giriş ekranında oturumun neden kapandığını açıklayan metin.
String signOutNoticeText(AppLocalizations l10n, SignOutNotice notice) {
  switch (notice.kind) {
    case SignOutNoticeKind.accountDeleted:
      return notice.needsAppleSettingsHint
          ? '${l10n.accountDeletedNotice}\n\n${l10n.accountDeletedAppleNotice}'
          : l10n.accountDeletedNotice;
    case SignOutNoticeKind.sessionExpired:
      return l10n.sessionExpiredNotice;
    case SignOutNoticeKind.appleCredentialRevoked:
      return l10n.appleCredentialRevokedNotice;
  }
}
