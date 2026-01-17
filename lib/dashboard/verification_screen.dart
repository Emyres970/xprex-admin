import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // LISTENING TO THE QUEUE
    final requestStream = Supabase.instance.client
        .from('verification_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("PENDING VERIFICATIONS"),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: requestStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text("All clear. No pending requests.", style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final requestId = req['id'];
              final userId = req['user_id']; 
              final docUrl = req['id_document_url'];

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HEADER: USER PROFILE INFO (Fetched Dynamically with Smart Search)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _fetchUserProfile(userId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Text("Loading User Details...", style: TextStyle(color: Colors.grey));
                          
                          final profile = snapshot.data!;
                          // Checks for multiple possible name columns to be safe
                          final name = profile['display_name'] ?? profile['full_name'] ?? profile['username'] ?? 'Unknown';
                          final email = profile['email'] ?? 'No Email';
                          final username = profile['username'] ?? '';
                          
                          return Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.amber.withOpacity(0.2),
                                child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.amber)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                    if (username.isNotEmpty)
                                      Text("@$username", style: const TextStyle(color: Colors.amber, fontSize: 12)),
                                    Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                    Text("ID: $userId", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // 2. THE ID CARD IMAGE
                    if (docUrl != null)
                      Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.black,
                        child: Image.network(
                          docUrl, 
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (c, e, s) => const Center(child: Text("Image Load Failed", style: TextStyle(color: Colors.red))),
                        ),
                      ),

                    // 3. ACTION BUTTONS
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever, color: Colors.white),
                              label: const Text("REJECT", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.withOpacity(0.8),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _rejectRequest(context, requestId),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, color: Colors.black),
                              label: const Text("APPROVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () => _approveUser(context, requestId, userId),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // HELPER: Smart Fetch (Checks auth_user_id first, then id)
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      // 1. Try finding by auth_user_id (The most likely link)
      final dataByAuth = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (dataByAuth != null) return dataByAuth;

      // 2. Fallback: Try finding by primary key 'id'
      final dataById = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (dataById != null) return dataById;

      // 3. If neither works, return a placeholder instead of crashing
      return {
        'display_name': 'Profile Not Found', 
        'email': 'ID: $userId', 
        'username': 'Unknown'
      };
    } catch (e) {
      return {'display_name': 'Fetch Error', 'email': e.toString()};
    }
  }

  Future<void> _rejectRequest(BuildContext context, dynamic id) async {
    await Supabase.instance.client.from('verification_requests').delete().eq('id', id);
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Rejected & Deleted")));
  }

  Future<void> _approveUser(BuildContext context, dynamic reqId, String userId) async {
    try {
      // 1. Approve Request
      await Supabase.instance.client.from('verification_requests').update({'status': 'approved'}).eq('id', reqId);
      
      // 2. Verify User (Try updating by auth_user_id first, then id)
      try {
        await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('auth_user_id', userId);
      } catch (_) {
         // If that fails, try the ID directly
        await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('id', userId);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Verified Successfully!")));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
