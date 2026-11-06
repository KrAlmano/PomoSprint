import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Servis katmanı kullanıcıya metin ÜRETMEZ: hatalar bu kodlarla ifade
/// edilir, UI kodu ARB üzerinden yerelleştirir (bkz. utils/auth_error_text.dart).
enum AuthErrorCode {
  weakPassword,
  passwordTooShort,
  emailAlreadyRegistered,
  emailAlreadyRegisteredResent,
  invalidCredentials,
  emailNotConfirmed,
  rateLimited,
  network,
  invalidEmail,
  cloudUnavailable,
  profileLoadFailed,
  googleSignInFailed,
  appleSignInFailed,
  /// Kayıt isteği zaman aşımına uğradı; kayıt sunucuda tamamlanmış olabilir.
  signUpTimedOut,
  /// Yeni şifre mevcut şifreyle aynı (şifre değiştirme).
  samePassword,
  /// Sunucu daha yeni bir oturum veya ayrıca doğrulama istiyor.
  reauthenticationNeeded,
  /// Sunucunun parola güncellemesini tamamlayıp tamamlamadığı belirsiz.
  passwordChangeOutcomeUnknown,
  unknown,
}

/// Servisin bilinçli olarak fırlattığı kimlik doğrulama hatası.
class AuthFailure implements Exception {
  final AuthErrorCode code;
  final Object? cause;

  const AuthFailure(this.code, [this.cause]);

  @override
  String toString() => 'AuthFailure(${code.name}${cause != null ? ': $cause' : ''})';
}

/// Herhangi bir auth hatasını koda çevirir (AuthFailure, Supabase
/// AuthException ya da ağ hataları).
AuthErrorCode authErrorCodeOf(Object error) {
  if (error is AuthFailure) return error.code;
  if (error is TimeoutException) return AuthErrorCode.network;

  final lower = error.toString().toLowerCase();
  final code = error is AuthException ? (error.code ?? '').toLowerCase() : '';

  if (code == 'reauthentication_needed') {
    return AuthErrorCode.reauthenticationNeeded;
  }
  if (code == 'current_password_mismatch') {
    return AuthErrorCode.invalidCredentials;
  }

  if (code == 'same_password' || lower.contains('same_password') || lower.contains('should be different from the old password')) {
    return AuthErrorCode.samePassword;
  }

  if (error is AuthWeakPasswordException ||
      code == 'weak_password' ||
      lower.contains('weakpassword') ||
      lower.contains('weak_password') ||
      lower.contains('password should contain') ||
      lower.contains('password is too weak') ||
      lower.contains('reasons: [characters]')) {
    return AuthErrorCode.weakPassword;
  }
  if (lower.contains('at least 6 characters') || lower.contains('password should be at least')) {
    return AuthErrorCode.passwordTooShort;
  }
  if (lower.contains('already_registered_resent')) {
    return AuthErrorCode.emailAlreadyRegisteredResent;
  }
  if (code == 'user_already_exists' ||
      code == 'email_exists' ||
      lower.contains('already registered') ||
      lower.contains('already in use') ||
      lower.contains('user_already_exists')) {
    return AuthErrorCode.emailAlreadyRegistered;
  }
  // Supabase, "şifre yanlış" ile "e-posta onaylanmadı" durumlarını hesap
  // keşfini önlemek için aynı genel hatayla döndürebilir.
  if (code == 'invalid_credentials' ||
      lower.contains('invalid login credentials') ||
      lower.contains('invalid_credentials') ||
      lower.contains('invalid_grant')) {
    return AuthErrorCode.invalidCredentials;
  }
  if (code == 'email_not_confirmed' || lower.contains('email not confirmed') || lower.contains('email_not_confirmed')) {
    return AuthErrorCode.emailNotConfirmed;
  }
  if (code.contains('rate_limit') ||
      lower.contains('rate limit') ||
      lower.contains('rate_limit') ||
      lower.contains('too many requests')) {
    return AuthErrorCode.rateLimited;
  }
  if (error is AuthRetryableFetchException || _looksLikeNetworkError(lower)) {
    return AuthErrorCode.network;
  }
  if (code == 'email_address_invalid' || lower.contains('invalid email') || lower.contains('unable to validate email address')) {
    return AuthErrorCode.invalidEmail;
  }
  return AuthErrorCode.unknown;
}

/// Auth dışındaki servis hataları için kodlar.
enum ServiceErrorCode {
  cloudUnavailable,
  notSignedIn,
  network,
  timeout,
  notFound,
  invalidInput,
  nameTooShort,
  nameTooLong,
  nameNotAllowed,
  premiumRequired,
  insufficientCoins,
  avatarLocked,
  categoryLimitReached,
  categoryNameExists,
  /// Kategori rengi '#RRGGBB' değil (proposed/23, 'category_color_invalid').
  categoryColorInvalid,
  /// Kategori ikon adı geçersiz (proposed/23, 'category_icon_invalid').
  categoryIconInvalid,
  /// Doğum yılı 13 yaş sınırının altında (proposed/24,
  /// 'birth_year_under_minimum_age').
  underMinimumAge,
  server,
  unknown,
}

/// Servisin anlamlı bir kodla fırlattığı hata. Ham hata [cause]'da durur.
class ServiceException implements Exception {
  final ServiceErrorCode code;
  final Object? cause;

  const ServiceException(this.code, [this.cause]);

  /// Ham bir hatayı koduyla sarar (zaten ServiceException ise aynen döner).
  factory ServiceException.wrap(Object error) =>
      error is ServiceException ? error : ServiceException(serviceErrorCodeOf(error), error);

  @override
  String toString() => 'ServiceException(${code.name}${cause != null ? ': $cause' : ''})';
}

/// Herhangi bir hatayı (ServiceException, PostgrestException, ağ hatası…)
/// koda çevirir. UI, hata metnini bu koddan üretmelidir.
ServiceErrorCode serviceErrorCodeOf(Object error) {
  if (error is ServiceException) return error.code;
  if (error is TimeoutException) return ServiceErrorCode.timeout;
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    final code = error.code ?? '';
    if (message.contains('not authenticated')) return ServiceErrorCode.notSignedIn;
    // Canlıda henüz olmayan önerilerin makine-okunur RAISE metinleri (SQLSTATE
    // 23514). Bugünkü sunucu bunları üretmez; uygulanınca genel
    // invalidInput yerine anlaşılır metin gösterilir.
    if (message.contains('category_color_invalid')) return ServiceErrorCode.categoryColorInvalid; // 23
    if (message.contains('category_icon_invalid')) return ServiceErrorCode.categoryIconInvalid; // 23
    if (message.contains('birth_year_under_minimum_age')) return ServiceErrorCode.underMinimumAge; // 24
    // 13: 'profile_name_not_allowed', 'category_name_not_allowed'
    if (message.contains('name_not_allowed')) return ServiceErrorCode.nameNotAllowed;
    // Sunucudaki RAISE metinleri (create_category, enforce_category_limit,
    // purchase_avatar, set_equipped_avatar) henüz makine-okunur kod
    // döndürmüyor; bu eşleştirme onlar için.
    if (message.contains('kategori') && message.contains('en fazla')) {
      return ServiceErrorCode.categoryLimitReached;
    }
    if (message.contains('zaten var') || (code == '23505' && message.contains('categor'))) {
      return ServiceErrorCode.categoryNameExists;
    }
    if (message.contains('yetersiz bakiye')) return ServiceErrorCode.insufficientCoins;
    if (message.contains('premium')) return ServiceErrorCode.premiumRequired;
    if (message.contains('kilitli')) return ServiceErrorCode.avatarLocked;
    if (message.contains('bulunamad')) return ServiceErrorCode.notFound;
    if (code == 'PGRST301') return ServiceErrorCode.notSignedIn;
    if (code.startsWith('22') || code.startsWith('23')) return ServiceErrorCode.invalidInput;
    return ServiceErrorCode.server;
  }
  if (error is AuthException) return ServiceErrorCode.notSignedIn;
  if (_looksLikeNetworkError(error.toString().toLowerCase())) return ServiceErrorCode.network;
  return ServiceErrorCode.unknown;
}

/// Çağrılan RPC sunucuda yok mu (PostgREST PGRST202)? Canlıda henüz
/// olmayan bir öneri RPC'sini deneyen kod bunu "eski sunucu" diye okur ve
/// bugünkü davranışa döner.
bool isMissingRpcError(Object error) => error is PostgrestException && error.code == 'PGRST202';

/// Ağ katmanı hatası mı? (dart:io'ya bağımlı olmamak için metinden bakılır.)
bool isNetworkError(Object error) =>
    error is TimeoutException || _looksLikeNetworkError(error.toString().toLowerCase());

bool _looksLikeNetworkError(String lower) =>
    lower.contains('socketexception') ||
    lower.contains('clientexception') ||
    lower.contains('handshakeexception') ||
    lower.contains('httpexception') ||
    lower.contains('authretryablefetchexception') ||
    lower.contains('failed host lookup') ||
    lower.contains('nodename nor servname') ||
    lower.contains('connection closed') ||
    lower.contains('connection refused') ||
    lower.contains('connection reset') ||
    lower.contains('network is unreachable') ||
    lower.contains('network error');
