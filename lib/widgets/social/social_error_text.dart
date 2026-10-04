import '../../l10n/app_localizations.dart';
import '../../services/service_errors.dart';

/// Sosyal/profil/avatar akışlarındaki servis hatalarını kullanıcıya
/// gösterilecek yerelleştirilmiş metne çevirir. Ham hata metni gösterilmez.
String socialErrorText(AppLocalizations l10n, Object error) {
  if (isNetworkError(error)) return l10n.socialErrNetwork;
  switch (serviceErrorCodeOf(error)) {
    case ServiceErrorCode.cloudUnavailable:
    case ServiceErrorCode.network:
    case ServiceErrorCode.timeout:
      return l10n.socialErrNetwork;
    case ServiceErrorCode.notSignedIn:
      return l10n.socialErrSession;
    case ServiceErrorCode.nameTooShort:
      return l10n.profileNameTooShort;
    case ServiceErrorCode.nameTooLong:
      return l10n.profileNameTooLong;
    case ServiceErrorCode.nameNotAllowed:
      return l10n.nameNotAllowed;
    case ServiceErrorCode.insufficientCoins:
      return l10n.socialErrInsufficientCoins;
    case ServiceErrorCode.premiumRequired:
      return l10n.avatarPremiumBody;
    case ServiceErrorCode.avatarLocked:
      return l10n.socialErrAvatarLocked;
    case ServiceErrorCode.notFound:
    case ServiceErrorCode.invalidInput:
    case ServiceErrorCode.categoryLimitReached:
    case ServiceErrorCode.categoryNameExists:
    case ServiceErrorCode.categoryColorInvalid:
    case ServiceErrorCode.categoryIconInvalid:
    case ServiceErrorCode.underMinimumAge:
    case ServiceErrorCode.server:
    case ServiceErrorCode.unknown:
      return l10n.socialErrGeneric;
  }
}
