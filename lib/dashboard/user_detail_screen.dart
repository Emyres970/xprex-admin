import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailScreen extends StatelessWidget {
  final String profileId;

  const UserDetailScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
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
          
          final name = user['display_name'] ?? user['full_name'] ?? user['username'] ?? 'Unknown';
          final email = user['email'] ?? 'No Email';
          final username = user['username'] ?? 'No Handle';
          final bio = user['bio'] ?? 'No bio provided.';
          final address = user['address'] ?? 'No Address Provided';
          final isVerified = user['is_verified'] ?? false;
          final isPremium = user['is_premium'] ?? false;
          final joinedAt = user['created_at'] ?? 'Unknown Date';
          final avatarUrl = user['avatar_url']; 
          final authUserId = user['auth_user_id'] ?? profileId; 

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: avatarUrl != null ? () => _openFullScreenImage(context, avatarUrl, "Profile Avatar") : null,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: isPremium ? Colors.amber : Colors.grey.shade800,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null 
                            ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: TextStyle(fontSize: 40, color: isPremium ? Colors.black : Colors.white))
                            : null,
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

                // 2. DOCS
                const Text("VERIFICATION DOCUMENTS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLatestVerificationDoc(authUserId),
                  builder: (context, docSnapshot) {
                    if (docSnapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator(color: Colors.amber));
                    final doc = docSnapshot.data;
                    if (doc == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                        child: const Text("No ID Documents Uploaded", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      );
                    }
                    return GestureDetector(
                      onTap: () => _openFullScreenImage(context, doc['id_document_url'], "ID Document"),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: AspectRatio(aspectRatio: 16/9, child: Image.network(doc['id_document_url'], fit: BoxFit.cover)),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                const Text("Latest ID Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(doc['created_at'] != null ? _formatDate(doc['created_at']) : "", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // 3. SAFE STATUS CONTROLS
                const Text("STATUS CONTROLS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildSafeSwitch(context, "Verified Status", isVerified, Icons.verified, Colors.blue, 'is_verified'),
                      const Divider(color: Colors.white10),
                      _buildSafeSwitch(context, "Premium Status", isPremium, Icons.star, Colors.amber, 'is_premium'),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 4. INTEL
                const Text("INTEL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildInfoRow(context, "User ID", profileId, canCopy: true),
                      const Divider(color: Colors.white10),
                      _buildInfoRow(context, "Location", address, canCopy: true),
                      const Divider(color: Colors.white10),
                      _buildInfoRow(context, "Bio", bio),
                      const Divider(color: Colors.white10),
                      _buildInfoRow(context, "Joined On", joinedAt.toString()),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 5. DANGER ZONE
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.block, color: Colors.white),
                    label: const Text("BAN USER (COMING SOON)", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.2)),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nuclear option disabled in MVP."))),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  // --- HELPERS ---
  Future<Map<String, dynamic>?> _fetchLatestVerificationDoc(String userId) async {
    try {
      return await Supabase.instance.client.from('verification_requests')
          .select().eq('user_id', userId).order('created_at', ascending: false).limit(1).maybeSingle();
    } catch (_) { return null; }
  }

  void _openFullScreenImage(BuildContext context, String imageUrl, String title) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(title), iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.network(imageUrl))),
    )));
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    } catch (_) { return isoString; }
  }

  // --- SAFE WIDGET BUILDERS ---

  Widget _buildSafeSwitch(BuildContext context, String label, bool currentValue, IconData icon, Color color, String dbColumn) {
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
          value: currentValue,
          activeColor: color,
          onChanged: (newValue) async {
            // THE SAFETY CHECK
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                title: Text("Change $label?", style: const TextStyle(color: Colors.white)),
                content: const Text("This action will immediately update the user's status in the live database.", style: TextStyle(color: Colors.white70)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("CONFIRM", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
                ],
              ),
            );

            if (confirmed == true) {
              await Supabase.instance.client.from('profiles').update({dbColumn: newValue}).eq('id', profileId);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated $label")));
            }
          },
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool canCopy = false}) {
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard"), duration: Duration(milliseconds: 500)));
              },
              child: const Icon(Icons.copy, size: 16, color: Colors.amber),
            )
        ],
      ),
    );
  }
}
