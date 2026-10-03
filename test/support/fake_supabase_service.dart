import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/supabase_service.dart';

/// Raporlar ve Kategorilerim ekranlarının kullandığı servis yüzeyinin
/// sahtesi. Sunucu satırları, kuyruk, hata ve gecikme testten yönetilir.
/// Kullanılmayan üyeler noSuchMethod'a düşer (testte çağrılırsa hata).
class FakeSupabaseService implements SupabaseService {
  FakeSupabaseService({UserModel? user}) {
    currentUser.value = user ?? UserModel(id: 'user-1', name: 'Deneme', email: 'deneme@example.com');
  }

  @override
  final ValueNotifier<UserModel?> currentUser = ValueNotifier<UserModel?>(null);

  @override
  final ValueNotifier<int> pendingSessionCount = ValueNotifier<int>(0);

  @override
  final ValueNotifier<int> categoriesRevision = ValueNotifier<int>(0);

  @override
  bool isCloudActive = true;

  @override
  Duration? serverClockOffset;

  // ---- İstatistik dinleyicileri ----

  final List<VoidCallback> _statsListeners = [];

  @override
  void addStatsChangedListener(VoidCallback listener) => _statsListeners.add(listener);

  @override
  void removeStatsChangedListener(VoidCallback listener) => _statsListeners.remove(listener);

  void notifyStatsChanged() {
    for (final l in List.of(_statsListeners)) {
      l();
    }
  }

  // ---- Seanslar ----

  /// Sunucunun study_sessions satırları (select'in döndürdüğü biçimde).
  List<Map<String, dynamic>> remoteRows = [];

  /// Doluysa fetchStudySessions bunu fırlatır.
  Object? fetchError;

  /// Doluysa fetchStudySessions bu tamamlanana kadar bekler.
  Completer<void>? fetchGate;
  int fetchCount = 0;

  @override
  Future<List<StudySession>> fetchStudySessions({DateTime? since}) async {
    fetchCount++;
    final gate = fetchGate;
    if (gate != null) await gate.future;
    final error = fetchError;
    if (error != null) throw error;
    return remoteRows.map(StudySession.fromJson).toList();
  }

  /// Cihazdaki bekleyen seans kuyruğu.
  List<PendingSession> queue = [];

  @override
  Future<List<PendingSession>> getPendingSessions() async => List.of(queue);

  List<RejectedSession> rejected = [];

  @override
  Future<List<RejectedSession>> getRejectedSessions() async => List.of(rejected);

  // ---- Kategoriler ----

  List<CourseCategory> allCategories = [];

  /// Doluysa bir sonraki kategori okuması bunu fırlatır (bir kez).
  Object? categoriesFetchErrorOnce;

  /// Doluysa her kategori yazma işlemi bunu fırlatır.
  Object? mutationError;

  final List<String> calls = [];

  @override
  Future<List<CourseCategory>> fetchUserCategories({bool includeArchived = false}) async {
    calls.add('fetch(includeArchived: $includeArchived)');
    final error = categoriesFetchErrorOnce;
    if (error != null) {
      categoriesFetchErrorOnce = null;
      throw error;
    }
    return [for (final c in allCategories) if (includeArchived || !c.isArchived) c];
  }

  @override
  Future<List<CourseCategory>> ensureServerCategories(List<CourseCategory> localFallback) async {
    calls.add('ensureServerCategories(${localFallback.map((c) => c.name).join(',')})');
    final active = await fetchUserCategories();
    if (active.isNotEmpty) return active;
    final source = localFallback.where((c) => !c.isArchived).toList();
    final seed = source.isNotEmpty ? source : CourseCategory.initialCategories();
    var n = allCategories.length;
    for (final c in seed) {
      allCategories.add(_copy(c, id: 'seed-${n++}'));
    }
    return fetchUserCategories();
  }

  void _mutate(String call) {
    calls.add(call);
    final error = mutationError;
    if (error != null) throw error;
  }

  @override
  Future<String?> createCategory(String name, String colorHex, String iconName) async {
    _mutate('create($name, $colorHex, $iconName)');
    final id = 'new-${allCategories.length}';
    allCategories.add(CourseCategory.fromServerRow({'id': id, 'name': name, 'color_hex': colorHex, 'icon_name': iconName}));
    categoriesRevision.value++;
    return id;
  }

  @override
  Future<void> updateCategory(String categoryId, String name, String colorHex, String iconName) async {
    _mutate('update($categoryId, $name, $colorHex, $iconName)');
    allCategories = [
      for (final c in allCategories)
        c.id == categoryId
            ? CourseCategory.fromServerRow({
                'id': c.id,
                'name': name,
                'color_hex': colorHex,
                'icon_name': iconName,
                'is_archived': c.isArchived,
              })
            : c,
    ];
    categoriesRevision.value++;
  }

  @override
  Future<void> archiveCategory(String categoryId) async {
    _mutate('archive($categoryId)');
    allCategories = [for (final c in allCategories) c.id == categoryId ? _copy(c, archived: true) : c];
    categoriesRevision.value++;
  }

  @override
  Future<void> unarchiveCategory(String categoryId) async {
    _mutate('unarchive($categoryId)');
    allCategories = [for (final c in allCategories) c.id == categoryId ? _copy(c, archived: false) : c];
    categoriesRevision.value++;
  }

  @override
  Future<void> updateCategoryOrders(List<String> orderedIds) async {
    _mutate('order(${orderedIds.join(',')})');
    final byId = {for (final c in allCategories) c.id: c};
    allCategories = [
      for (final id in orderedIds) byId[id]!,
      for (final c in allCategories) if (!orderedIds.contains(c.id)) c,
    ];
    categoriesRevision.value++;
  }

  static CourseCategory _copy(CourseCategory c, {String? id, bool? archived}) => CourseCategory(
        id: id ?? c.id,
        name: c.name,
        color: c.color,
        icon: c.icon,
        isArchived: archived ?? c.isArchived,
        colorHex: c.colorHex,
        iconName: c.iconName,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
