import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BankDetailScreen extends StatelessWidget {
  final String profileId; 
  final String authUserId; 
  final String userName;

  const BankDetailScreen({
    super.key, 
    required this.profileId, 
    required this.authUserId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // Current Wallet (Live from Profile table)
    final walletStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .limit(1);

    // Historical Payouts (The Archive)
    final historyStream = Supabase.instance.client
        .from('payouts')
        .stream(primaryKey: ['id'])
        .eq('user_id', authUserId)
        .order('period', ascending: false);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("FINANCE: $userName".toUpperCase()),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("AVAILABLE BALANCE", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            
            // --- LIVE WALLET CARD ---
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: walletStream,
              builder: (context, snapshot) {
                final balance = (snapshot.hasData && snapshot.data!.isNotEmpty) 
                  ? snapshot.data!.first['earnings_balance'] ?? 0.0 
                  : 0.0;
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text("₦${_formatMoney(balance)}", style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text("CURRENT UNSETTLED EARNINGS", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 40),

            const Text("PAYOUT HISTORY", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),

            // --- PAYOUT LEDGER ---
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: historyStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator(color: Colors.amber);
                final payouts = snapshot.data!;
                
                if (payouts.isEmpty) {
                  return const Text("No previous settlements found.", style: TextStyle(color: Colors.white24));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payouts.length,
                  itemBuilder: (context, index) {
                    final payout = payouts[index];
                    final isPaid = payout['status'] == 'Paid';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(isPaid ? Icons.check_circle : Icons.pending, color: isPaid ? Colors.green : Colors.orange),
                        title: Text("₦${_formatMoney(payout['amount'])}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(payout['period'].toString(), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        trailing: Text(isPaid ? "PAID" : "PROCESSING", style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatMoney(num amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
