import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your screens
import '../auth/login_screen.dart';
import '../dashboard/roster_screen.dart';
import '../dashboard/verification_screen.dart';
import '../dashboard/user_detail_screen.dart';
import '../dashboard/bank_detail_screen.dart';
import '../dashboard/treasury_screen.dart';

// LISTENER CLASS
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((AuthState authState) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ROUTER CONFIG
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
  
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/verification',
      builder: (context, state) => const VerificationScreen(),
    ),
    GoRoute(
      path: '/user/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return UserDetailScreen(profileId: id);
      },
    ),
    GoRoute(
      path: '/bank/:profileId/:authId/:name',
      builder: (context, state) {
        return BankDetailScreen(
          profileId: state.pathParameters['profileId']!,
          authUserId: state.pathParameters['authId']!,
          userName: state.pathParameters['name']!,
        );
      },
    ),
    GoRoute(
      path: '/treasury',
      builder: (context, state) => const TreasuryScreen(),
    ),
  ],
  
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final onLoginPage = state.uri.toString() == '/';

    if (session == null) return '/';

    final email = session.user.email;
    const adminEmail = 'rudeboyemyres@gmail.com'; 

    if (email != adminEmail) {
      Supabase.instance.client.auth.signOut();
      return '/';
    }

    if (onLoginPage) return '/dashboard';
    return null; 
  },
);
