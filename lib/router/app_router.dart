import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your screens
import '../auth/login_screen.dart';
import '../dashboard/roster_screen.dart';

// -----------------------------------------------------------------------------
// THE LISTENER CLASS (The Fix for the "Refresh Bug")
// -----------------------------------------------------------------------------
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (AuthState authState) {
        notifyListeners();
      },
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// THE ROUTER CONFIG
// -----------------------------------------------------------------------------
final appRouter = GoRouter(
  initialLocation: '/',
  // THIS LINE FIXES THE BUG: It forces a re-check whenever Auth state changes
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
  ],
  
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final onLoginPage = state.uri.toString() == '/';

    // 1. If not logged in, force them to Login Page
    if (session == null) {
      return '/';
    }

    // 2. THE GATEKEEPER (Security Check)
    final email = session.user.email;
    // REPLACE WITH YOUR EXACT EMAIL
    const adminEmail = 'rudeboyemyres@gmail.com'; 

    if (email != adminEmail) {
      // If they are logged in but not YOU, kick them out
      Supabase.instance.client.auth.signOut();
      return '/';
    }

    // 3. If they are authorized and stuck on Login Page, send to Dashboard
    if (onLoginPage) {
      return '/dashboard';
    }

    // 4. No action needed (let them go where they want)
    return null; 
  },
);
