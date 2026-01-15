import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// -----------------------------------------------------------------------------
// 1. CONFIGURATION (Replace with your actual keys from the mobile app)
// -----------------------------------------------------------------------------
const supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';

// -----------------------------------------------------------------------------
// 2. MAIN ENTRY POINT
// -----------------------------------------------------------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const XprexAdminApp());
}

// -----------------------------------------------------------------------------
// 3. THE APP SHELL
// -----------------------------------------------------------------------------
class XprexAdminApp extends StatelessWidget {
  const XprexAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'XpreX Admin',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber, // The "Gold" standard
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      routerConfig: _router,
    );
  }
}

// -----------------------------------------------------------------------------
// 4. ROUTING & GATEKEEPER
// -----------------------------------------------------------------------------
final _router = GoRouter(
  initialLocation: '/',
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

    // If not logged in, force Login Page
    if (session == null) return '/';

    // THE GATEKEEPER: Check if it's YOU
    final email = session.user.email;
    // REPLACE THIS WITH YOUR EXACT EMAIL
    const adminEmail = 'YOUR_EMAIL@gmail.com'; 

    if (email != adminEmail) {
      // Kick them out if they aren't the Architect
      Supabase.instance.client.auth.signOut();
      return '/';
    }

    // If logged in and on Login Page, go to Dashboard
    if (onLoginPage) return '/dashboard';

    return null; 
  },
);

// -----------------------------------------------------------------------------
// 5. SIMPLE UI PAGES (Placeholders)
// -----------------------------------------------------------------------------
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // MVP: Trigger Supabase Magic Link or Password Login here
            // We will add the logic in the next step
            print("Login Clicked");
          },
          child: const Text("Enter War Room"),
        ),
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("XpreX Ops Command")),
      body: const Center(
        child: Text("Welcome, Architect."),
      ),
    );
  }
}
