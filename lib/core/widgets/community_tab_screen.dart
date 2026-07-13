/// Community Tab — segmented tab screen for clubs, routes & leaderboard.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../../features/clubs/presentation/screens/club_list_screen.dart';
import '../../features/routes/presentation/screens/route_list_screen.dart';
import '../../features/progression/presentation/screens/leaderboard_screen.dart';

/// A screen with a segmented TabBar at the top containing Clubs, Routes, and
/// Ranking tabs. Used as the Comunidad tab in the bottom navigation.
class CommunityTabScreen extends StatelessWidget {
  const CommunityTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Comunidad'),
          bottom: TabBar(
            tabs: const [
              Tab(text: '🏁 Clubs'),
              Tab(text: '📡 Rutas'),
              Tab(text: '🏆 Ranking'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
          ),
        ),
        body: const TabBarView(
          children: [
            ClubListScreen(),
            RouteListScreen(),
            LeaderboardScreen(),
          ],
        ),
      ),
    );
  }
}
