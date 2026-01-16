import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
              final isVerified = user['is_verified'] ?? false; // Assuming you have this column
              final isPremium = user['is_premium'] ?? false; // Assuming you have this column

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white10)),
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
                            if (isVerified) const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.verified, size: 16, color: Colors.blue),
                            ),
                          ],
                        ),
                        subtitle: Text(email, style: const TextStyle(color: Colors.white54)),
                      ),
                      const Divider(color: Colors.white10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _ActionButton(
                            icon: Icons.badge, 
                            label: "Verify", 
                            color: Colors.blue,
                            onTap: () => _toggleStatus(context, user['id'], 'is_verified', !isVerified),
                          ),
                          _ActionButton(
                            icon: Icons.star, 
                            label: "Premium", 
                            color: Colors.amber,
                            onTap: () => _toggleStatus(context, user['id'], 'is_premium', !isPremium),
                          ),
                          _ActionButton(
                            icon: Icons.account_balance, 
                            label: "Bank", 
                            color: Colors.grey,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bank Details View coming in next update.")));
                            },
                          ),
                          _ActionButton(
                            icon: Icons.block, 
                            label: "Ban", 
                            color: Colors.red,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ban Logic coming in next update.")));
                            },
                          ),
                        ],
                      )
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

  Future<void> _toggleStatus(BuildContext context, String userId, String column, bool newValue) async {
    try {
      await Supabase.instance.client.from('profiles').update({column: newValue}).eq('id', userId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated $column to $newValue")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
