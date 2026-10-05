import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/social/load_error_view.dart';
import '../widgets/social/social_error_text.dart';
import '../widgets/social/user_safety.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/friend_code.dart';
import '../utils/responsive.dart';

/// [FriendsSheet]'i alttan açar. Tablette ve yatay telefonda sheet tam
/// genişliğe yayılmaz (Material 3 varsayılanıyla aynı sınır, açıkça).
Future<void> showFriendsSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => const FriendsSheet(),
  );
}

/// Arkadaşlık RPC yanıtının makine-okunur kodu (not_found, self_add,
/// already_friends, already_pending, accepted, request_sent; proposed/13 ve
/// 14 ile rate_limited, cooldown, blocked, respond'da rejected). Canlı
/// add_friend_by_code ve respond_friend_request yalnızca {success, message}
/// döndürüyor ('code' alanı 13/14 ile gelir); kod yoksa sunucunun sabit
/// Türkçe mesajından çıkarılır. Tanınmayan yanıtta null.
@visibleForTesting
String? friendResponseCode(Map<String, dynamic>? result) {
  final code = result?['code'];
  if (code is String && code.isNotEmpty) return code;
  final message = result?['message']?.toString().toLowerCase() ?? '';
  if (message.contains('bulunamad')) return 'not_found';
  if (message.contains('kendini')) return 'self_add';
  if (message.contains('zaten arkadaş')) return 'already_friends';
  if (message.contains('zaten istek')) return 'already_pending';
  return null;
}

/// Arkadaş ekleme ve arkadaş listesi pop-up ekranı.
/// Ana ekranın sağ üstündeki dairesel "arkadaşlar" butonuna basılınca açılır.
class FriendsSheet extends StatefulWidget {
  /// Veri katmanı (varsayılan: [SupabaseService.instance]; testte sahtesi).
  final SupabaseService? service;

  const FriendsSheet({super.key, this.service});

  @override
  State<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<FriendsSheet> {
  final _codeController = TextEditingController();
  String? _myCode;
  List<Map<String, dynamic>> _friends = const [];
  List<Map<String, dynamic>> _pendingRequests = const [];
  List<Map<String, dynamic>> _outgoingRequests = const [];
  List<Map<String, dynamic>> _blockedUsers = const [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  bool _loadFailed = false;
  bool _isAdding = false;
  String? _respondingId;
  String? _errorMessage;

  SupabaseService get _service => widget.service ?? SupabaseService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final service = _service;
    final codeFuture = service.getMyFriendCode();
    List<Map<String, dynamic>>? friends;
    List<Map<String, dynamic>>? pending;
    List<Map<String, dynamic>>? outgoing;
    List<Map<String, dynamic>>? blocked;
    try {
      final results = await Future.wait([
        service.fetchFriends(),
        service.fetchPendingFriendRequests(),
        service.fetchOutgoingFriendRequests(),
        service.fetchBlockedUsers(),
      ]);
      friends = results[0];
      pending = results[1];
      outgoing = results[2];
      blocked = results[3];
    } catch (e) {
      debugPrint('[SOCIAL] Arkadaş listesi alınamadı: $e');
    }
    final code = await codeFuture;
    if (!mounted) return;
    setState(() {
      _myCode = code ?? _myCode;
      if (friends != null && pending != null) {
        _friends = [...friends]
          ..sort((a, b) => _asInt(b['lifetime_points']).compareTo(_asInt(a['lifetime_points'])));
        _pendingRequests = pending;
        _outgoingRequests = outgoing!;
        _blockedUsers = blocked!;
        _hasLoaded = true;
      }
      _loadFailed = friends == null;
      _isLoading = false;
    });
  }

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  Future<void> _handleAddFriend() async {
    final l10n = AppLocalizations.of(context)!;
    final code = normalizeFriendCode(_codeController.text);
    if (code.isEmpty || _isAdding) return;
    // Biçimce geçersiz kod gönderilmez (proposed/13 her denemeyi saatlik
    // sınıra sayar; canlıda da yalnızca "bulunamadı" döner).
    if (!isValidFriendCode(code)) {
      setState(() => _errorMessage = l10n.friendsErrInvalidCode);
      return;
    }
    if (_myCode != null && code == normalizeFriendCode(_myCode!)) {
      setState(() => _errorMessage = l10n.friendsErrSelf);
      return;
    }

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    Map<String, dynamic>? result;
    String? error;
    try {
      result = await _service.addFriendByCode(code);
    } catch (e) {
      error = socialErrorText(l10n, e);
    }

    if (!mounted) return;
    setState(() => _isAdding = false);

    if (result != null && result['success'] == true) {
      _codeController.clear();
      final name = result['friend']?['name']?.toString() ?? l10n.userDefault;
      final autoAccepted = result['auto_accepted'] == true || friendResponseCode(result) == 'accepted';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(autoAccepted ? l10n.friendsAdded(name) : l10n.friendsRequestSent(name)),
          backgroundColor: autoAccepted ? Colors.green : AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    } else {
      setState(() => _errorMessage = error ?? _addFailureText(l10n, result));
    }
  }

  // Sunucunun yanıt kodu (bkz. [friendResponseCode]) yerelleştirilir.
  // Tanınmayan yanıtta yalnızca Türkçe arayüzde sunucunun Türkçe mesajı
  // gösterilir; aksi halde genel metin.
  String _addFailureText(AppLocalizations l10n, Map<String, dynamic>? result) {
    switch (friendResponseCode(result)) {
      case 'not_found':
        return l10n.friendsErrNotFound;
      case 'self_add':
        return l10n.friendsErrSelf;
      case 'already_friends':
        return l10n.friendsErrAlreadyFriends;
      case 'already_pending':
        return l10n.friendsErrAlreadyPending;
      case 'rate_limited':
        return l10n.friendsErrRateLimited;
      case 'cooldown':
        return l10n.friendsErrCooldown;
      case 'blocked':
        return l10n.friendsErrBlocked;
    }
    final message = result?['message']?.toString().trim() ?? '';
    if (l10n.localeName == 'tr' && message.isNotEmpty) return message;
    return l10n.friendsErrAddFailed;
  }

  Future<void> _handleRespond(String fromUserId, bool accept) async {
    if (_respondingId != null) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _respondingId = fromUserId);

    Map<String, dynamic>? result;
    String? error;
    try {
      result = await _service.respondToFriendRequest(fromUserId, accept);
    } catch (e) {
      error = socialErrorText(l10n, e);
    }

    if (!mounted) return;
    setState(() => _respondingId = null);

    final messenger = ScaffoldMessenger.of(context);
    if (result != null && result['success'] == true) {
      if (accept) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.friendsAccepted),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadData();
    } else {
      final gone = friendResponseCode(result) == 'not_found';
      messenger.showSnackBar(
        SnackBar(
          content: Text(error ?? (gone ? l10n.friendsRequestGone : l10n.friendsRespondFailed)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Sunucu yanıt verdiyse liste tazelenir: istek başka cihazdan
      // yanıtlanmış ya da gönderen hesabını silmiş olabilir; bayat kart
      // kalıp her dokunuşta hata vermez.
      if (result != null) await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final shortHeight = Responsive.of(context).isShortHeight;

    final handle = Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              l10n.friendsTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    const loader = Center(child: CircularProgressIndicator(color: AppColors.primary));
    final isFirstLoad = _isLoading && !_hasLoaded;

    final Widget content;
    if (shortHeight) {
      // Yatay telefonda sabit başlık listeye neredeyse yer bırakmaz (klavye
      // açıkken hiç bırakmaz): tutamaç ve başlık da listeyle birlikte kayar.
      content = ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          handle,
          header,
          if (isFirstLoad)
            const Padding(padding: EdgeInsets.all(24), child: loader)
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildContent(l10n, isDark, muted),
              ),
            ),
        ],
      );
    } else {
      content = Column(
        children: [
          handle,
          header,
          Expanded(
            child: isFirstLoad
                ? loader
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: _buildContent(l10n, isDark, muted),
                  ),
          ),
        ],
      );
    }

    final sheet = Container(
      height: MediaQuery.sizeOf(context).height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: content,
    );
    if (!shortHeight) return sheet;
    // Yatay telefonda klavye sheet'in çoğunu örter: sheet klavyenin üstüne
    // alınır, kod alanı görünür kalır ve kalan alanda içerik kaydırılır.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: sheet,
    );
  }

  List<Widget> _buildContent(AppLocalizations l10n, bool isDark, Color muted) {
    return [
      _buildMyCodeCard(l10n, muted),
      const SizedBox(height: 20),
      ..._buildAddByCode(l10n, isDark),
      if (!_hasLoaded) ...[
        const SizedBox(height: 24),
        LoadErrorView(message: l10n.friendsLoadError, onRetry: _loadData),
      ] else ...[
        if (_loadFailed) ...[
          const SizedBox(height: 12),
          StaleDataNotice(onRetry: _loadData),
        ],
        ..._buildPendingRequests(l10n),
        ..._buildManagedUsers(l10n, _outgoingRequests, outgoing: true),
        const SizedBox(height: 24),
        Text(
          l10n.friendsYourFriends(_friends.length),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_friends.isEmpty)
          _buildEmptyFriends(l10n, isDark, muted)
        else
          for (final f in _friends) _buildFriendTile(f, l10n, isDark, muted),
        ..._buildManagedUsers(l10n, _blockedUsers, outgoing: false),
      ],
    ];
  }

  Widget _buildMyCodeCard(AppLocalizations l10n, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.friendsMyCode,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Büyük metin ölçeğinde kod tek satırda küçülür, kopyala düğmesi
              // sağda kalır.
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    // Koyu temada darkPrimary (okunur kontrast).
                    child: Text(
                      _myCode ?? '------',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                tooltip: l10n.friendsCopyCode,
                onPressed: _myCode == null
                    ? null
                    : () {
                        unawaited(Clipboard.setData(ClipboardData(text: _myCode!)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.friendsCodeCopied),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAddByCode(AppLocalizations l10n, bool isDark) {
    return [
      Text(
        l10n.friendsAddByCode,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              // Eski 6 hex ve yeni 6–8 karakterlik Crockford kodlar: yapıştırılan
              // koddaki boşluk/tire önce silinir, büyük harfe çevrilir, O/I/L
              // rakama eşlenir, sonra kısaltılır (bkz. normalizeFriendCode).
              inputFormatters: const [FriendCodeInputFormatter()],
              onSubmitted: (_) => _handleAddFriend(),
              decoration: InputDecoration(
                hintText: l10n.friendsCodeHint,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isAdding ? null : _handleAddFriend,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isAdding
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(l10n.addBtn),
          ),
        ],
      ),
      if (_errorMessage != null) ...[
        const SizedBox(height: 8),
        Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
      ],
    ];
  }

  List<Widget> _buildPendingRequests(AppLocalizations l10n) {
    if (_pendingRequests.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Text(
        l10n.friendsIncoming(_pendingRequests.length),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      for (final r in _pendingRequests) _buildRequestTile(r, l10n),
    ];
  }

  List<Widget> _buildManagedUsers(AppLocalizations l10n, List<Map<String, dynamic>> users, {required bool outgoing}) {
    if (users.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      Text(
        outgoing ? l10n.friendsOutgoingTitle : l10n.blockedUsersTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final user in users)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: AvatarWidget(avatar: AvatarCharacter.byId(user['avatar_id']?.toString()), size: 40),
          title: Text(user['name']?.toString() ?? l10n.userDefault),
          trailing: IconButton(
            tooltip: outgoing ? l10n.friendsCancelRequest : l10n.unblockUserAction,
            icon: Icon(outgoing ? Icons.cancel_outlined : Icons.lock_open),
            onPressed: user['id'] == null
                ? null
                : () async {
                    await confirmFriendAction(
                      context,
                      title: outgoing ? l10n.friendsCancelRequest : l10n.unblockUserAction,
                      body: outgoing ? l10n.friendsCancelConfirm : l10n.unblockUserConfirm,
                      operation: () => outgoing
                          ? _service.cancelFriendRequest(user['id'].toString())
                          : _service.unblockUser(user['id'].toString()),
                    );
                    if (mounted) await _loadData();
                  },
          ),
        ),
    ];
  }

  // Gizleme yereldir; engelleme ve arkadaşlıktan çıkarma sunucu işlemleridir.
  void _openReport(Map<String, dynamic> user, AppLocalizations l10n, UserReportPlace place) {
    unawaited(
      showUserSafetySheet(
        context,
        target: UserSafetyTarget(
          name: user['name']?.toString() ?? l10n.userDefault,
          userId: user['id']?.toString(),
          avatarId: user['avatar_id']?.toString(),
        ),
        place: place,
        allowHide: false,
        allowRemoveFriend: place == UserReportPlace.friendsList,
        service: _service,
        onChanged: () async {
          if (mounted) await _loadData();
        },
      ),
    );
  }

  Widget _buildRequestTile(Map<String, dynamic> r, AppLocalizations l10n) {
    final requesterId = r['id']?.toString() ?? '';
    final isResponding = _respondingId == requesterId;
    return GestureDetector(
      onLongPress: () => _openReport(r, l10n, UserReportPlace.friendRequest),
      child: _buildRequestCard(r, l10n, requesterId, isResponding),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r, AppLocalizations l10n, String requesterId, bool isResponding) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AvatarWidget(avatar: AvatarCharacter.byId(r['avatar_id']?.toString()), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              r['name']?.toString() ?? l10n.userDefault,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (isResponding)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 26),
              tooltip: l10n.friendsAccept,
              onPressed: requesterId.isEmpty ? null : () => _handleRespond(requesterId, true),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 26),
              tooltip: l10n.friendsReject,
              onPressed: requesterId.isEmpty ? null : () => _handleRespond(requesterId, false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyFriends(AppLocalizations l10n, bool isDark, Color muted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: muted),
          const SizedBox(height: 8),
          Text(
            l10n.friendsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> f, AppLocalizations l10n, bool isDark, Color muted) {
    return GestureDetector(
      onLongPress: () => _openReport(f, l10n, UserReportPlace.friendsList),
      child: _buildFriendCard(f, l10n, isDark, muted),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> f, AppLocalizations l10n, bool isDark, Color muted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AvatarWidget(avatar: AvatarCharacter.byId(f['avatar_id']?.toString()), size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f['name']?.toString() ?? l10n.userDefault,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  l10n.minutesStudy(_asInt(f['total_minutes'])),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_asInt(f['lifetime_points'])}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onPrimaryFixed),
            ),
          ),
          UserActionsButton(onPressed: () => _openReport(f, l10n, UserReportPlace.friendsList)),
        ],
      ),
    );
  }
}
