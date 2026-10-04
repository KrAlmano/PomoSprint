import '../models/avatar_model.dart';
import 'service_errors.dart';

/// Avatarı kuşanır ([equip] = set_equipped_avatar).
///
/// Kataloğa sonradan eklenen varsayılan (ücretsiz) avatarın avatar_unlocks
/// kaydı yoktur (give_default_avatars yalnızca profil oluşurken çalışır).
/// İstemci onu sahip sayar ([AvatarCharacter.isOwned]) ama canlı
/// set_equipped_avatar 'Bu avatar kilitli.' der (t4-F9); proposed/22 kaydı
/// sunucuda kendisi açar. 22'den önce: kilitli hatasında, avatar katalogda
/// varsayılan ve bedelsizse ([isFreeDefaultAvatar]) kayıt [unlockFree]
/// (purchase_avatar; bedeli 0, kum düşmez) ile açılır ve kuşanma bir kez
/// yeniden denenir. Diğer her hata aynen fırlatılır.
///
/// Kaydı bu çağrıda istemci açtıysa true döner.
Future<bool> equipAvatarWithDefaultUnlock({
  required String avatarId,
  required Future<void> Function() equip,
  required Future<void> Function() unlockFree,
}) async {
  try {
    await equip();
    return false;
  } catch (e) {
    if (serviceErrorCodeOf(e) != ServiceErrorCode.avatarLocked || !isFreeDefaultAvatar(avatarId)) rethrow;
  }
  await unlockFree();
  await equip();
  return true;
}

/// Katalogda varsayılan ve bedelsiz mi (Premium'a özel ya da lig ödülü
/// değil)? purchase_avatar böyle bir avatarı kum düşmeden açar.
bool isFreeDefaultAvatar(String avatarId) {
  if (!AvatarCharacter.isFreeAvatarId(avatarId)) return false;
  final avatar = AvatarCharacter.byId(avatarId);
  return avatar.requiredCoins == 0 && !avatar.isPremiumOnly && !avatar.isLeagueAward;
}
