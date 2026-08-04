import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';

/// Arkadaş ekleme ve arkadaş listesi pop-up ekranı.
/// Ana ekranın sağ üstündeki dairesel "arkadaşlar" butonuna basılınca açılır.
class FriendsSheet extends StatefulWidget {
  const FriendsSheet({super.key});

  @override
  State<FriendsSheet> createState() => _FriendsSheetState();
}

class _FriendsSheetState extends State<FriendsSheet> {
  final _codeController = TextEditingController();
  String? _myCode;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String? _respondingId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final code = await SupabaseService.instance.getMyFriendCode();
    final friends = await SupabaseService.instance.fetchFriends();
    final pending = await SupabaseService.instance.fetchPendingFriendRequests();
    if (mounted) {
      setState(() {
        _myCode = code;
        _friends = friends;
        _pendingRequests = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAddFriend() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _isAdding) return;
    final isTurkish = LanguageService.instance.isTurkish;

    setState(() {
      _isAdding = true;
      _errorMessage = null;
    });

    final result = await SupabaseService.instance.addFriendByCode(code);

    if (!mounted) return;
    setState(() => _isAdding = false);

    if (result['success'] == true) {
      _codeController.clear();
      await _loadData();
      if (mounted) {
        final name = result['friend']?['name']?.toString() ?? (isTurkish ? 'Kullanıcı' : 'User');
        final autoAccepted = result['auto_accepted'] == true;
        final message = autoAccepted
            ? (isTurkish ? '✅ $name arkadaş listene eklendi!' : '✅ $name was added to your friends list!')
            : (isTurkish
                ? '📨 $name kullanıcısına arkadaşlık isteği gönderildi. Onay bekleniyor.'
                : '📨 Friend request sent to $name. Waiting for approval.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: autoAccepted ? Colors.green : AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      setState(() => _errorMessage = result['message']?.toString() ?? 'Bir hata oluştu.');
    }
  }

  Future<void> _handleRespond(String fromUserId, bool accept) async {
    if (_respondingId != null) return;
    final isTurkish = LanguageService.instance.isTurkish;
    setState(() => _respondingId = fromUserId);

    final result = await SupabaseService.instance.respondToFriendRequest(fromUserId, accept);

    if (!mounted) return;
    setState(() => _respondingId = null);

    if (result['success'] == true) {
      await _loadData();
      if (mounted && accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTurkish ? '✅ Arkadaşlık isteği kabul edildi!' : '✅ Friend request accepted!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? (isTurkish ? 'Bir hata oluştu.' : 'An error occurred.')),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  AvatarCharacter _getAvatar(String? avatarId) {
    final avatars = AvatarCharacter.allAvatars();
    return avatars.firstWhere(
      (a) => a.id == avatarId,
      orElse: () => avatars.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTurkish = lang.isTurkish;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isTurkish ? 'Arkadaşlar' : 'Friends',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      // Kendi kodun
                      Container(
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
                              isTurkish ? 'Senin Arkadaşlık Kodun' : 'Your Friend Code',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  _myCode ?? '------',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: AppColors.primary),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                                  onPressed: _myCode == null
                                      ? null
                                      : () {
                                          Clipboard.setData(ClipboardData(text: _myCode!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(isTurkish ? 'Kod kopyalandı!' : 'Code copied!'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Kod ile arkadaş ekle
                      Text(
                        isTurkish ? 'Kod ile Arkadaş Ekle' : 'Add Friend by Code',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              textCapitalization: TextCapitalization.characters,
                              maxLength: 6,
                              decoration: InputDecoration(
                                hintText: isTurkish ? 'Örn: A1B2C3' : 'E.g: A1B2C3',
                                counterText: '',
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
                                : Text(isTurkish ? 'Ekle' : 'Add'),
                          ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ],

                      if (_pendingRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          isTurkish ? 'Gelen İstekler (${_pendingRequests.length})' : 'Incoming Requests (${_pendingRequests.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ..._pendingRequests.map((r) {
                          final avatar = _getAvatar(r['avatar_id']?.toString());
                          final requesterId = r['id']?.toString() ?? '';
                          final isResponding = _respondingId == requesterId;
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
                                AvatarWidget(avatar: avatar, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    r['name']?.toString() ?? (isTurkish ? 'Kullanıcı' : 'User'),
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
                                    tooltip: isTurkish ? 'Kabul et' : 'Accept',
                                    onPressed: () => _handleRespond(requesterId, true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 26),
                                    tooltip: isTurkish ? 'Reddet' : 'Reject',
                                    onPressed: () => _handleRespond(requesterId, false),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 24),

                      Text(
                        isTurkish ? 'Arkadaşların (${_friends.length})' : 'Your Friends (${_friends.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (_friends.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline, size: 40, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                isTurkish
                                    ? 'Henüz arkadaşın yok. Kodunu paylaş veya yukarıdan bir kod gir!'
                                    : 'No friends yet. Share your code or enter one above!',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        )
                      else
                        ...(_friends..sort((a, b) => (b['points'] as int? ?? 0).compareTo(a['points'] as int? ?? 0)))
                            .map((f) {
                          final avatar = _getAvatar(f['avatar_id']?.toString());
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                AvatarWidget(avatar: avatar, size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f['name']?.toString() ?? 'Kullanıcı',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Text(
                                        '${f['total_minutes'] ?? 0} dk',
                                        style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
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
                                    '${f['points'] ?? 0}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onPrimaryFixed),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
