import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/jobs/:id',
      builder: (context, state) =>
          HomeScreen(initialJobId: state.pathParameters['id']),
    ),
  ],
);
