import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // LISTENING TO THE QUEUE
    final requestStream = Supabase.instance.client
        .from('verification_requests') // CORRECTED: Plural
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
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.badge, color: Colors.amber),
                      title: Text("Request from User...", style: const TextStyle(color: Colors.white)),
                      subtitle: Text("ID: $userId", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                    if (docUrl != null)
                      Container(
                        height: 250,
                        width: double.infinity,
                        color: Colors.black,
                        child: Image.network(
                          docUrl, 
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (c, e, s) => const Center(child: Text("Image Load Failed", style: TextStyle(color: Colors.red))),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever, color: Colors.white),
                              label: const Text("REJECT (DELETE)", style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => _rejectRequest(context, requestId),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, color: Colors.black),
                              label: const Text("APPROVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
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

  Future<void> _rejectRequest(BuildContext context, dynamic id) async {
    // Delete from plural table
    await Supabase.instance.client.from('verification_requests').delete().eq('id', id);
    if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Rejected & Deleted")));
  }

  Future<void> _approveUser(BuildContext context, dynamic reqId, String userId) async {
    try {
      // 1. Mark request as approved in plural table
      await Supabase.instance.client.from('verification_requests').update({'status': 'approved'}).eq('id', reqId);
      
      // 2. Update the actual Profile to Verified
      await Supabase.instance.client.from('profiles').update({'is_verified': true}).eq('id', userId);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User Verified Successfully!")));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
