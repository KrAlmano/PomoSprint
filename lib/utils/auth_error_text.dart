import '../l10n/app_localizations.dart';
import '../services/service_errors.dart';

/// [AuthErrorCode]'u kullanıcıya gösterilecek yerelleştirilmiş metne çevirir.
/// Servis katmanı metin üretmez; tüm auth hata metinleri buradan geçer.
String authErrorText(AppLocalizations l10n, AuthErrorCode code) {
  switch (code) {
    case AuthErrorCode.weakPassword:
      return l10n.authErrWeakPassword;
    case AuthErrorCode.passwordTooShort:
      return l10n.errShortPassword;
    case AuthErrorCode.emailAlreadyRegistered:
      return l10n.errEmailExists;
    case AuthErrorCode.emailAlreadyRegisteredResent:
      return l10n.authErrEmailExistsResent;
    case AuthErrorCode.invalidCredentials:
      return l10n.authErrInvalidCredentials;
    case AuthErrorCode.emailNotConfirmed:
      return l10n.authErrEmailNotConfirmed;
    case AuthErrorCode.rateLimited:
      return l10n.authErrRateLimited;
    case AuthErrorCode.network:
      return l10n.authErrNetwork;
    case AuthErrorCode.invalidEmail:
      return l10n.authErrInvalidEmail;
    case AuthErrorCode.cloudUnavailable:
      return l10n.authErrCloudUnavailable;
    case AuthErrorCode.profileLoadFailed:
      return l10n.authErrProfileLoad;
    case AuthErrorCode.googleSignInFailed:
      return l10n.authErrGoogleFailed;
    case AuthErrorCode.appleSignInFailed:
      return l10n.authErrAppleFailed;
    case AuthErrorCode.unknown:
      return l10n.authErrUnknown;
  }
}
