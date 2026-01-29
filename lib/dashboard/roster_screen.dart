import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

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
        backgroundColor: Colors.black,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('verification_requests').stream(primaryKey: ['id']).eq('status', 'pending'),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications), onPressed: () => context.push('/verification')),
                  if (count > 0) Positioned(right: 8, top: 8, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
                ],
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () => Supabase.instance.client.auth.signOut()),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          final users = snapshot.data!;
          if (users.isEmpty) return const Center(child: Text("No soldiers found yet."));

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];
              final name = user['full_name'] ?? user['display_name'] ?? user['username'] ?? 'Unknown Agent';
              final email = user['email'] ?? 'No Email';
              final isVerified = user['is_verified'] ?? false;
              final isPremium = user['is_premium'] ?? false;
              final userId = user['id']; 

              return Card(
                elevation: 0,
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
                child: InkWell(
                  onTap: () => context.push('/user/$userId'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isPremium ? Colors.amber : Colors.grey.withOpacity(0.2),
                            foregroundColor: isPremium ? Colors.black : Colors.white,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?"),
                          ),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              if (isVerified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 16, color: Colors.blue)),
                            ],
                          ),
                          subtitle: Text(email, style: const TextStyle(color: Colors.white54)),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        ),
                        const Divider(color: Colors.white10),
                        
                        // SAFE QUICK ACTIONS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ActionButton(
                              icon: Icons.badge, 
                              label: "Verify", 
                              color: Colors.blue, 
                              onTap: () => _safeToggle(context, name, "Verify User", userId, 'is_verified', !isVerified)
                            ),
                            _ActionButton(
                              icon: Icons.star, 
                              label: "Premium", 
                              color: Colors.amber, 
                              onTap: () => _safeToggle(context, name, "Grant Premium", userId, 'is_premium', !isPremium)
                            ),
                            _ActionButton(icon: Icons.account_balance, label: "Bank", color: Colors.grey, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bank module coming soon.")))),
                            _ActionButton(icon: Icons.block, label: "Ban", color: Colors.red, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ban module coming soon.")))),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- SAFETY PROTOCOL HELPER ---
  Future<void> _safeToggle(BuildContext context, String userName, String action, String userId, String column, bool newValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(action, style: const TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to change status for $userName?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("CONFIRM", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await _toggleStatus(context, userId, column, newValue);
    }
  }

  Future<void> _toggleStatus(BuildContext context, String userId, String column, bool newValue) async {
    try {
      await Supabase.instance.client.from('profiles').update({column: newValue}).eq('id', userId);
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated $column successfully.")));
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 4), Text(label, style: TextStyle(color: color, fontSize: 10))])),
    );
  }
}
