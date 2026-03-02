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
    // Current Wallet
    final walletStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .limit(1);

    // Bank Details
    final bankStream = Supabase.instance.client
        .from('creator_bank_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', authUserId) 
        .limit(1);

    // Historical Payouts
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
            
            // --- ACTIVE WALLET ---
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

            // --- BANK DETAILS ---
            const Text("BANK DESTINATION", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: bankStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)),
                    child: const Column(children: [
                      Icon(Icons.no_accounts, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("No Bank Linked", style: TextStyle(color: Colors.grey))
                    ]),
                  );
                }

                final bank = snapshot.data!.first;
                final accNumber = bank['account_number'] ?? '000';

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildBankRow("Bank Name", bank['bank_name'] ?? 'Unknown'),
                          const Divider(color: Colors.white10),
                          _buildBankRow("Account Name", bank['account_name'] ?? 'Unknown'),
                          const Divider(color: Colors.white10),
                          // Just text here, button is below
                          _buildBankRow("Account Number", accNumber),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // THE BIG BUTTON IS BACK
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy, color: Colors.black),
                        label: const Text("COPY ACCOUNT NUMBER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: accNumber));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Number Copied!")));
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 40),

            const Text("STATEMENT HISTORY", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
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
                    final dateLabel = _formatDate(payout['period'].toString());
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: isPaid ? Colors.green : Colors.amber, width: 4)),
                      ),
                      child: ListTile(
                        leading: Icon(isPaid ? Icons.check_circle : Icons.pending, color: isPaid ? Colors.green : Colors.amber),
                        title: Text("₦${_formatMoney(payout['amount'])}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(dateLabel, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        trailing: Text(isPaid ? "PAID" : "PROCESSING", style: TextStyle(color: isPaid ? Colors.green : Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBankRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  String _formatMoney(num amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      return "${months[date.month - 1]} ${date.year}";
    } catch (_) {
      return isoString;
    }
  }
}
