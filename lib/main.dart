import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// -----------------------------------------------------------------------------
// 1. CONFIGURATION (Keep your keys from the previous step!)
// -----------------------------------------------------------------------------
// RE-PASTE YOUR KEYS HERE
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
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white10,
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

    // 1. If no session, stay on Login
    if (session == null) return '/';

    // 2. THE GATEKEEPER: Check if it's YOU
    final email = session.user.email;
    const adminEmail = 'rudeboyemyres@gmail.com'; // <--- PUT YOUR EMAIL HERE

    if (email != adminEmail) {
      Supabase.instance.client.auth.signOut();
      return '/';
    }

    // 3. If authorized and on Login, go to Dashboard
    if (onLoginPage) return '/dashboard';

    return null; 
  },
);

// -----------------------------------------------------------------------------
// 4. LOGIN PAGE (Now Functional!)
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
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Router handles redirection automatically
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              const Text("XpreX War Room", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Admin Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black) 
                      : const Text("Enter War Room"),
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
// 5. DASHBOARD PAGE (The God View)
// -----------------------------------------------------------------------------
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We assume your table is named 'profiles' or 'users' in public schema
    // Adjust this query if your table name is different!
    final usersStream = Supabase.instance.client
        .from('profiles') // <--- CHECK YOUR TABLE NAME IN SUPABASE
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text("The Roster"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final users = snapshot.data!;

          if (users.isEmpty) return const Center(child: Text("No users found yet."));

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              // Adjust these keys based on your actual database columns
              final name = user['full_name'] ?? user['username'] ?? 'Unknown';
              final email = user['email'] ?? 'No Email';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  trailing: const Chip(
                    label: Text("User"), 
                    backgroundColor: Colors.grey,
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
