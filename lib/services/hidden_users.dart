import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının gizlediği bir hesap. Sıralamanın Lig ve Aylık sekmeleri
/// kullanıcı kimliği döndürmediği için kimlik yoksa görünen adla eşlenir.
@immutable
class HiddenUser {
  /// Genel kullanıcı kimliği (arkadaşlar ve canlı akış satırlarında var).
  final String? id;
  final String name;

  const HiddenUser({this.id, required this.name});

  String get nameKey => HiddenUserList.nameKey(name);

  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'name': name};

  static HiddenUser? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name']?.toString() ?? '';
    final id = json['id']?.toString();
    if (name.trim().isEmpty && (id == null || id.isEmpty)) return null;
    return HiddenUser(id: (id == null || id.isEmpty) ? null : id, name: name);
  }
}

/// Gizlenen kullanıcılar ve eşleme kuralı.
///
/// Satırın da gizlenen kaydın da kimliği varsa yalnızca kimlikle eşlenir
/// (aynı adlı başka biri gizlenmez). İkisinden birinde kimlik yoksa
/// (Lig/Aylık satırı ya da oradan gizlenen kayıt) görünen adla eşlenir.
@immutable
class HiddenUserList {
  final List<HiddenUser> users;

  const HiddenUserList(this.users);

  static const HiddenUserList empty = HiddenUserList([]);

  bool get isEmpty => users.isEmpty;
  int get length => users.length;

  /// Ad karşılaştırma anahtarı: baş/son boşluk, büyük/küçük harf ve
  /// ardışık boşluk farkı yok sayılır.
  static String nameKey(String? name) => (name ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  bool isHidden({String? id, String? name}) {
    final key = nameKey(name);
    final rowId = (id == null || id.isEmpty) ? null : id;
    for (final user in users) {
      if (user.id != null && rowId != null) {
        if (user.id == rowId) return true;
        continue;
      }
      if (key.isNotEmpty && user.nameKey == key) return true;
    }
    return false;
  }

  /// [user] eklenmiş liste; zaten gizliyse (aynı kimlik ya da kimliksiz
  /// aynı ad) değişmez.
  HiddenUserList adding(HiddenUser user) {
    final exists = users.any((u) =>
        (u.id != null && u.id == user.id) || (u.id == null && user.id == null && u.nameKey == user.nameKey));
    return exists ? this : HiddenUserList([...users, user]);
  }

  HiddenUserList removing(HiddenUser user) => HiddenUserList([
        for (final u in users)
          if (!((u.id != null && u.id == user.id) || (u.id == null && user.id == null && u.nameKey == user.nameKey))) u,
      ]);

  String encode() => jsonEncode([for (final u in users) u.toJson()]);

  static HiddenUserList decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return empty;
      return HiddenUserList([for (final item in list) ?HiddenUser.fromJson(item)]);
    } catch (e) {
      debugPrint('[HIDDEN] Gizlenen kullanıcı listesi okunamadı: $e');
      return empty;
    }
  }
}

/// Hesaba bağlı, cihazda (SharedPreferences) saklanan gizlenen kullanıcı
/// listesi. Sıralama ve canlı akış bunu dinler; Profil'den sıfırlanır.
/// Hesap silinince anahtar silinir.
class HiddenUsersStore {
  HiddenUsersStore._();

  static final HiddenUsersStore instance = HiddenUsersStore._();

  static String keyFor(String userId) => 'hidden_users_uid_$userId';

  /// Oturumdaki hesabın listesi ([load] edilen hesap).
  final ValueNotifier<HiddenUserList> hidden = ValueNotifier(HiddenUserList.empty);

  String? _ownerId;
  Future<void>? _loading;
  String? _loadingFor;

  /// [userId] hesabının listesini yükler; zaten yüklüyse bir şey yapmaz.
  /// Null (oturum yok) listeyi boşaltır.
  Future<void> load(String? userId) {
    if (userId == null || userId.isEmpty) {
      _ownerId = null;
      hidden.value = HiddenUserList.empty;
      return Future.value();
    }
    if (_ownerId == userId) return Future.value();
    if (_loadingFor == userId && _loading != null) return _loading!;
    _loadingFor = userId;
    final future = _read(userId).then((list) {
      if (_loadingFor != userId) return;
      _ownerId = userId;
      hidden.value = list;
    }).whenComplete(() {
      if (_loadingFor == userId) {
        _loading = null;
        _loadingFor = null;
      }
    });
    _loading = future;
    return future;
  }

  Future<HiddenUserList> _read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return HiddenUserList.decode(prefs.getString(keyFor(userId)));
    } catch (e) {
      debugPrint('[HIDDEN] Liste okunamadı: $e');
      return HiddenUserList.empty;
    }
  }

  Future<void> _write(String userId, HiddenUserList list) async {
    if (_ownerId == userId) hidden.value = list;
    final prefs = await SharedPreferences.getInstance();
    if (list.isEmpty) {
      await prefs.remove(keyFor(userId));
    } else {
      await prefs.setString(keyFor(userId), list.encode());
    }
  }

  Future<void> hide(String userId, HiddenUser user) async {
    await load(userId);
    await _write(userId, hidden.value.adding(user));
  }

  Future<void> unhide(String userId, HiddenUser user) async {
    await load(userId);
    await _write(userId, hidden.value.removing(user));
  }

  /// "Gizlenen kullanıcıları göster": listeyi sıfırlar.
  Future<void> clear(String userId) async {
    await load(userId);
    await _write(userId, HiddenUserList.empty);
  }

  /// Hesap silinince: cihazdaki kaydı siler.
  Future<void> forget(String userId) async {
    if (_ownerId == userId) {
      _ownerId = null;
      hidden.value = HiddenUserList.empty;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyFor(userId));
  }

  @visibleForTesting
  void resetForTest() {
    _ownerId = null;
    _loading = null;
    _loadingFor = null;
    hidden.value = HiddenUserList.empty;
  }
}
