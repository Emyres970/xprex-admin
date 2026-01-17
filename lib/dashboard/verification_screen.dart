import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart'; // Needed for push

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final requestStream = Supabase.instance.client
        .from('verification_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: true);

    return Scaffold(
      appBar: AppBar(title: const Text("PENDING VERIFICATIONS"), backgroundColor: Colors.black),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: requestStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
          
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(child: Text("All clear. No pending requests.", style: TextStyle(color: Colors.white54)));
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
                  children: [
                    // 1. HEADER: USER PROFILE INFO (NOW CLICKABLE)
                    FutureBuilder<Map<String, dynamic>>(
                      future: _fetchUserProfile(userId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(12), child: Text("Loading..."));
                        
                        final profile = snapshot.data!;
                        final name = profile['display_name'] ?? profile['full_name'] ?? profile['username'] ?? 'Unknown';
                        final email = profile['email'] ?? 'No Email';
                        final profileId = profile['id']; // We need the REAL Profile ID for the link
                        
                        // IF we found a valid profile ID, make it clickable
                        final canClick = profileId != null;

                        return InkWell(
                          onTap: canClick ? () => context.push('/user/$profileId') : null, // <--- NAVIGATE TO DOSSIER
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: Row(
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
                                      Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      if (canClick) const Text("Tap to view Dossier >", style: TextStyle(color: Colors.blue, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // 2. IMAGE & 3. BUTTONS (Same as before)
                    if (docUrl != null)
                      Container(
                        height: 300, 
                        width: double.infinity, color: Colors.black,
                        child: Image.network(docUrl, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Text("Image Error"))),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.delete_forever), label: const Text("REJECT"), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => _rejectRequest(context, requestId))),
                          const SizedBox(width: 12),
                          Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.check_circle), label: const Text("APPROVE"), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber), onPressed: () => _approveUser(context, requestId, userId))),
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

  // (Helper functions _fetchUserProfile, _rejectRequest, _approveUser remain exactly the same as previous step)
  Future<Map<String, dynamic>> _fetchUserProfile(String userId) async {
    try {
      final dataByAuth = await Supabase.instance.client.from('profiles').select().eq('auth_user_id', userId).maybeSingle();
      if (dataByAuth != null) return dataByAuth;
      final dataById = await Supabase.instance.client.from('profiles').select().eq('id', userId).maybeSingle();
      if (dataById != null) return dataById;
      return {'display_name': 'Profile Not Found', 'email': 'ID: $userId', 'id': null};
    } catch (e) { return {'display_name': 'Fetch Error', 'email': e.toString(), 'id': null}; }
  }

  Future<void> _rejectRequest(BuildContext context, dynamic id) async {
    await Supabase.instance.client.from('verification_requests').delete().eq('id', id);
  }

  Future<void> _approveUser(BuildContext context, dynamic reqId, String userId) async {
    await Supabase.instance.client.from('verification_requests').update({'status': 'approved'}).eq('id', reqId);
    try { await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('auth_user_id', userId); } 
    catch (_) { await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('id', userId); }
  }
}
