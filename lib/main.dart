import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your new Theme and Router
import 'theme.dart';
import 'router/app_router.dart';

// CONFIGURATION
const supabaseUrl = 'https://svyuxdowffweanjjzvis.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN2eXV4ZG93ZmZ3ZWFuamp6dmlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzODI2NzYsImV4cCI6MjA3ODk1ODY3Nn0.YZqPUaeJKp7kdc_FPBoPfoIruDpTka3ptCmanGpMjR0';

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
      title: 'XpreX War Room',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // Still using your custom theme
      routerConfig: appRouter, // Now using the modular router
    );
  }
}
