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
          
          // Data Extraction
          final name = user['display_name'] ?? user['full_name'] ?? user['username'] ?? 'Unknown';
          final email = user['email'] ?? 'No Email';
          final username = user['username'] ?? 'No Handle';
          final bio = user['bio'] ?? 'No bio provided.';
          final address = user['address'] ?? 'No Address Provided';
          final isVerified = user['is_verified'] ?? false;
          final isPremium = user['is_premium'] ?? false;
          final joinedAt = user['created_at'] ?? 'Unknown Date';
          final avatarUrl = user['avatar_url']; // Check for profile picture
          final authUserId = user['auth_user_id'] ?? profileId; // Link to verification table

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER IDENTITY (With Clickable Avatar)
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: avatarUrl != null 
                            ? () => _openFullScreenImage(context, avatarUrl, "Profile Avatar") 
                            : null,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: isPremium ? Colors.amber : Colors.grey.shade800,
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null 
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : "?",
                                style: TextStyle(fontSize: 40, color: isPremium ? Colors.black : Colors.white),
                              )
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

                // 2. VERIFICATION DOCUMENTS (New Section)
                const Text("VERIFICATION DOCUMENTS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLatestVerificationDoc(authUserId),
                  builder: (context, docSnapshot) {
                    if (docSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: LinearProgressIndicator(color: Colors.amber));
                    }
                    
                    final doc = docSnapshot.data;
                    if (doc == null) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                        child: const Text("No ID Documents Uploaded", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      );
                    }

                    final docUrl = doc['id_document_url'];
                    final uploadedAt = doc['created_at'];

                    return GestureDetector(
                      onTap: () => _openFullScreenImage(context, docUrl, "ID Document"),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E), 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: AspectRatio(
                                aspectRatio: 16/9,
                                child: Image.network(
                                  docUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (c, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                                  errorBuilder: (c, e, s) => const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Latest ID Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text(uploadedAt != null ? _formatDate(uploadedAt) : "", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // 3. STATUS CONTROLS
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

                // 4. INTEL
                const Text("INTEL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildInfoRow("User ID", profileId, canCopy: true),
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Location", address, canCopy: true),
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Bio", bio),
                      const Divider(color: Colors.white10),
                      _buildInfoRow("Joined On", joinedAt.toString()),
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

  // --- LOGIC HELPERS ---

  Future<Map<String, dynamic>?> _fetchLatestVerificationDoc(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('verification_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false) // Get the newest one
          .limit(1)
          .maybeSingle();
      return data;
    } catch (e) {
      debugPrint("Error fetching docs: $e");
      return null;
    }
  }

  void _openFullScreenImage(BuildContext context, String imageUrl, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(title),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    } catch (_) {
      return isoString;
    }
  }

  // --- WIDGET BUILDERS ---

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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard"), duration: Duration(milliseconds: 500)));
              },
              child: const Icon(Icons.copy, size: 16, color: Colors.amber),
            )
        ],
      ),
    );
  }
}
