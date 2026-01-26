import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard copy
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailScreen extends StatelessWidget {
  final String profileId;

  const UserDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    // Stream specific to this user so updates (like verification) happen live
    final userStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .limit(1);

    return Scaffold(
      appBar: AppBar(
        title: const Text("AGENT DOSSIER"),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          if (snapshot.data!.isEmpty) return const Center(child: Text("Agent Not Found"));

          final user = snapshot.data!.first;
          
          // Data Extraction with Fallbacks
          final name = user['display_name'] ?? user['full_name'] ?? user['username'] ?? 'Unknown';
          final email = user['email'] ?? 'No Email';
          final username = user['username'] ?? 'No Handle';
          final bio = user['bio'] ?? 'No bio provided.';
          final address = user['address'] ?? 'No Address Provided'; // <--- NEW LOGISTICS DATA
          final isVerified = user['is_verified'] ?? false;
          final isPremium = user['is_premium'] ?? false;
          final joinedAt = user['created_at'] ?? 'Unknown Date';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER IDENTITY
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: isPremium ? Colors.amber : Colors.grey.shade800,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "?",
                          style: TextStyle(fontSize: 40, color: isPremium ? Colors.black : Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text("@$username", style: const TextStyle(color: Colors.amber, fontSize: 16)),
                      Text(email, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 2. GOD MODE CONTROLS
                const Text("STATUS CONTROLS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildSwitch(context, "Verified Status", isVerified, Icons.verified, Colors.blue, 'is_verified'),
                      const Divider(color: Colors.white10),
                      _buildSwitch(context, "Premium Status", isPremium, Icons.star, Colors.amber, 'is_premium'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3. RAW DATA INSPECTOR
                const Text("INTEL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildInfoRow("User ID", profileId, canCopy: true),
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Location", address, canCopy: true), // <--- NEW ADDRESS ROW
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Bio", bio),
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Joined On", joinedAt.toString()),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 4. DANGER ZONE
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.block, color: Colors.white),
                    label: const Text("BAN USER (COMING SOON)", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
                    onPressed: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nuclear option disabled in MVP.")));
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwitch(BuildContext context, String label, bool value, IconData icon, Color color, String dbColumn) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        Switch(
          value: value,
          activeColor: color,
          onChanged: (newValue) async {
            await Supabase.instance.client.from('profiles').update({dbColumn: newValue}).eq('id', profileId);
            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated $label")));
          },
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
          if (canCopy)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                // Optional: Show a tiny toast confirming copy if you want, but icon feedback is usually enough
              },
              child: const Icon(Icons.copy, size: 16, color: Colors.amber),
            )
        ],
      ),
    );
  }
}
