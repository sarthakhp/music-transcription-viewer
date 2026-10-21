import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';

// Both routes share one page key so moving between `/` and `/jobs/:id` updates
// the existing HomeScreen instead of rebuilding it (which re-downloaded the
// song and showed a second loading screen). HomeScreen.didUpdateWidget handles
// back/forward.
const _homePageKey = ValueKey('home');

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          const NoTransitionPage(key: _homePageKey, child: HomeScreen()),
    ),
    GoRoute(
      path: '/jobs/:id',
      pageBuilder: (context, state) => NoTransitionPage(
        key: _homePageKey,
        child: HomeScreen(initialJobId: state.pathParameters['id']),
      ),
    ),
  ],
);
