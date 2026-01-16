import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// -----------------------------------------------------------------------------
// 1. CONFIGURATION
// -----------------------------------------------------------------------------
const supabaseUrl = 'https://svyuxdowffweanjjzvis.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2eXV4ZG93ZmZ3ZWFuamp6dmlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzODI2NzYsImV4cCI6MjA3ODk1ODY3Nn0.YZqPUaeJKp7kdc_FPBoPfoIruDpTka3ptCmanGpMjR0';

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

class XprexAdminApp extends StatelessWidget {
  const XprexAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'XpreX Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        // FIX: This theme prevents the "Strikethrough" glitch
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C), // Dark Grey background
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none, // No border line to cut through text
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
          labelStyle: const TextStyle(color: Colors.white70),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
      routerConfig: _router,
    );
  }
}

// -----------------------------------------------------------------------------
// 3. ROUTING & GATEKEEPER
// -----------------------------------------------------------------------------
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginPage()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
  ],
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final onLoginPage = state.uri.toString() == '/';

    if (session == null) return '/';

    // THE GATEKEEPER logic
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

// -----------------------------------------------------------------------------
// 4. LOGIN PAGE
// -----------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      final email = response.user?.email;
      if (email != 'rudeboyemyres@gmail.com') {
        throw "Access Denied. You are not the Architect.";
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Login Failed", style: TextStyle(color: Colors.red)),
          content: Text(e.toString().replaceAll("AuthException:", "").trim()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, size: 64, color: Colors.amber),
              const SizedBox(height: 24),
              const Text("WAR ROOM ACCESS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Commander Email'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black) 
                      : const Text("INITIALIZE LINK", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. DASHBOARD PAGE (The Roster)
// -----------------------------------------------------------------------------
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usersStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("THE ROSTER"),
        centerTitle: false,
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Just triggers a UI rebuild effectively in stream builder
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));

          final users = snapshot.data!;

          if (users.isEmpty) return const Center(child: Text("No soldiers found yet."));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              final name = user['full_name'] ?? user['username'] ?? 'Unknown Agent';
              final email = user['email'] ?? 'No Email';
              final joinedAt = user['created_at'] != null 
                  ? user['created_at'].toString().substring(0, 10) 
                  : 'Unknown';
              
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.amber)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: const TextStyle(color: Colors.white54)),
                      const SizedBox(height: 4),
                      Text("Joined: $joinedAt", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.verified_user_outlined, color: Colors.green),
                        onPressed: () {
                           // TODO: Add verification logic
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verify feature coming in Phase 2")));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red),
                        onPressed: () {
                           // TODO: Add ban logic
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ban feature coming in Phase 2")));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
