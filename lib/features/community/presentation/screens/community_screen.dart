import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';

/// Full-featured community screen with user search, follow/unfollow,
/// and lists of followers / following.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  // ── Search ──
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _searchLoading = false;
  Timer? _debounce;

  // ── Follow list ──
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _following = [];
  bool _followersLoading = false;
  bool _followingLoading = false;

  // ── Follow action loading per user id ──
  final Set<String> _loadingIds = {};

  // ── Current user ──
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadFollowing();
    _loadFollowers();
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadFollowers() async {
    setState(() => _followersLoading = true);
    try {
      // Get follower IDs
      final followsRes = await Supabase.instance.client
          .from('user_follows')
          .select('follower_id')
          .eq('followed_id', _currentUserId);

      final followerIds = (followsRes as List)
          .map((e) => e['follower_id'] as String)
          .toList();

      List<Map<String, dynamic>> list = [];
      if (followerIds.isNotEmpty) {
        final orConditions =
            followerIds.map((id) => 'id.eq.$id').join(',');
        final usersRes = await Supabase.instance.client
            .from('users')
            .select('id, full_name, email, avatar_url')
            .or(orConditions);

        list = (usersRes as List).cast<Map<String, dynamic>>();
      }

      if (mounted) setState(() => _followers = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar seguidores: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followersLoading = false);
    }
  }

  Future<void> _loadFollowing() async {
    setState(() => _followingLoading = true);
    try {
      // Get followed user IDs
      final followsRes = await Supabase.instance.client
          .from('user_follows')
          .select('followed_id')
          .eq('follower_id', _currentUserId);

      final followedIds = (followsRes as List)
          .map((e) => e['followed_id'] as String)
          .toList();

      List<Map<String, dynamic>> list = [];
      if (followedIds.isNotEmpty) {
        final orConditions =
            followedIds.map((id) => 'id.eq.$id').join(',');
        final usersRes = await Supabase.instance.client
            .from('users')
            .select('id, full_name, email, avatar_url')
            .or(orConditions);

        list = (usersRes as List).cast<Map<String, dynamic>>();
      }

      if (mounted) setState(() => _following = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar seguidos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _followingLoading = false);
    }
  }

  /// Search users by full_name or email.
  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searchLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('id, full_name, email, avatar_url')
          .or(
            'full_name.ilike.%$query%,email.ilike.%$query%',
          )
          .limit(20);

      final list = (res as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() => _searchResults = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en la búsqueda: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  /// Check if current user follows a given user.
  Future<bool> _isFollowing(String userId) async {
    if (userId == _currentUserId) return false;
    final res = await Supabase.instance.client
        .from('user_follows')
        .select('id')
        .eq('follower_id', _currentUserId)
        .eq('followed_id', userId)
        .maybeSingle();
    return res != null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // FOLLOW / UNFOLLOW
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _toggleFollow(String userId, {bool? currentlyFollowing}) async {
    if (userId == _currentUserId) return;

    setState(() => _loadingIds.add(userId));

    try {
      final isFollowing =
          currentlyFollowing ?? await _isFollowing(userId);

      if (isFollowing) {
        // Unfollow
        await Supabase.instance.client
            .from('user_follows')
            .delete()
            .eq('follower_id', _currentUserId)
            .eq('followed_id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dejaste de seguir')),
          );
        }

        // Refresh lists
        await Future.wait([_loadFollowers(), _loadFollowing()]);
      } else {
        // Follow
        await Supabase.instance.client.from('user_follows').insert({
          'follower_id': _currentUserId,
          'followed_id': userId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Ahora sigues a este motero!')),
          );
        }

        // Refresh lists
        await Future.wait([_loadFollowers(), _loadFollowing()]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(userId));
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════

  bool _isInUserList(
      String userId, List<Map<String, dynamic>> list) {
    return list.any((u) => u['id'] == userId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidad'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTypography.buttonSmall,
          unselectedLabelStyle: AppTypography.buttonSmall,
          tabs: const [
            Tab(text: 'Buscar'),
            Tab(text: 'Siguiendo'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSearchTab(),
          _buildFollowTab(),
        ],
      ),
    );
  }

  // ── SEARCH TAB ──
  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: AppSpacing.screenPadding,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar moteros por nombre o email...',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(AppIcons.search, color: AppColors.textMuted),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.input,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdCircular,
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                _search(value);
              });
              // Clear results if empty
              if (value.trim().isEmpty) {
                setState(() => _searchResults = []);
              }
            },
          ),
        ),
        if (_searchLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        if (!_searchLoading && _searchResults.isEmpty && _searchCtrl.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(AppIcons.search, size: 48, color: AppColors.textMuted.withAlpha(80)),
                const SizedBox(height: 12),
                Text(
                  'No se encontraron moteros',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        if (!_searchLoading && _searchCtrl.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(AppIcons.group, size: 48, color: AppColors.textMuted.withAlpha(80)),
                const SizedBox(height: 12),
                Text(
                  'Busca moteros por nombre o email',
                  style: AppTypography.body.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            itemBuilder: (_, i) => _buildUserTile(
              _searchResults[i],
              isSearchResult: true,
            ),
          ),
        ),
      ],
    );
  }

  // ── FOLLOW TAB ──
  Widget _buildFollowTab() {
    return Column(
      children: [
        // Segmented control
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _buildSegment(
                  label: 'Seguidores (${_followers.length})',
                  selected: _tabCtrl.index == 0,
                  onTap: () => _tabCtrl.animateTo(0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSegment(
                  label: 'Siguiendo (${_following.length})',
                  selected: _tabCtrl.index == 1,
                  onTap: () => _tabCtrl.animateTo(1),
                ),
              ),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFollowList(_followers, _followersLoading, isFollowers: true),
              _buildFollowList(_following, _followingLoading, isFollowers: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegment({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(25) : AppColors.input,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(
            color: selected ? AppColors.primary.withAlpha(100) : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.buttonSmall.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowList(
    List<Map<String, dynamic>> users,
    bool loading, {
    required bool isFollowers,
  }) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFollowers ? AppIcons.group : AppIcons.profile,
                size: 48,
                color: AppColors.textMuted.withAlpha(80),
              ),
              const SizedBox(height: 12),
              Text(
                isFollowers ? 'Sin seguidores aún' : 'No sigues a nadie aún',
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                isFollowers
                    ? 'Comparte tu perfil para conectar'
                    : 'Busca moteros para seguir',
                style: AppTypography.caption.copyWith(color: AppColors.textDisabled),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (_, i) => _buildUserTile(users[i], isSearchResult: false),
    );
  }

  // ── USER TILE ──
  Widget _buildUserTile(Map<String, dynamic> user, {bool isSearchResult = false}) {
    final userId = user['id'] as String? ?? '';
    final name = (user['full_name'] as String? ?? 'Usuario').toString();
    final email = (user['email'] as String? ?? '').toString();
    final isSelf = userId == _currentUserId;
    final isLoading = _loadingIds.contains(userId);

    // Determine follow state
    final isFollowing = _isInUserList(userId, _following);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              color: AppColors.input,
            ),
            child: const Icon(AppIcons.profile, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Follow button
          if (!isSelf)
            SizedBox(
              height: 32,
              child: isLoading
                  ? const SizedBox(
                      width: 32,
                      child: Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : isFollowing
                      ? _buildFollowingButton(userId)
                      : _buildFollowButton(userId),
            ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(String userId) {
    return OutlinedButton(
      onPressed: () => _toggleFollow(userId, currentlyFollowing: false),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
        textStyle: AppTypography.buttonSmall,
      ),
      child: const Text('Seguir'),
    );
  }

  Widget _buildFollowingButton(String userId) {
    return ElevatedButton(
      onPressed: () => _toggleFollow(userId, currentlyFollowing: true),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnAmber,
        minimumSize: const Size(100, 32),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smCircular),
        textStyle: AppTypography.buttonSmall,
        elevation: 0,
        shadowColor: AppColors.primaryGlow,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14),
          SizedBox(width: 4),
          Text('Siguiendo'),
        ],
      ),
    );
  }
}
