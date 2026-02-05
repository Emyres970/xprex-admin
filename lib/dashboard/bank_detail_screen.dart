import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BankDetailScreen extends StatelessWidget {
  final String profileId; 
  final String authUserId; // The Key to the Bank/Payout Tables
  final String userName;

  const BankDetailScreen({
    super.key, 
    required this.profileId, 
    required this.authUserId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Stream Wallet Balance (From Profiles - Current Unpaid)
    final walletStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .limit(1);

    // 2. Stream Bank Details (From Bank Table)
    final bankStream = Supabase.instance.client
        .from('creator_bank_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', authUserId) 
        .limit(1);

    // 3. Stream Payout History (From Payouts - Settled/Old Data)
    final payoutStream = Supabase.instance.client
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
            // --- SECTION 1: THE ACTIVE WALLET ---
            // This represents NEW money (Post-Settlement)
            const Text("ACTIVE WALLET (CURRENT CYCLE)", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: walletStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.green));
                  
                  final data = snapshot.data!.isNotEmpty ? snapshot.data!.first : {};
                  final balance = data['earnings_balance'] ?? 0;
                  
                  return Column(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "₦${_formatMoney(balance)}", 
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 8),
                      const Text("UNPAID EARNINGS", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // --- SECTION 2: BANK COORDINATES ---
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
                return Container(
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
                      _buildBankRow("Account Number", bank['account_number'] ?? '000', isCopyable: true, context: context),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // --- SECTION 3: STATEMENT HISTORY (THE ARCHIVE) ---
            // This answers "Where did last month's money go?"
            const Text("STATEMENT HISTORY", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: payoutStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: LinearProgressIndicator(color: Colors.amber));
                
                final payouts = snapshot.data!;
                if (payouts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text("No payout history found.", style: TextStyle(color: Colors.white30, fontStyle: FontStyle.italic)),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payouts.length,
                  itemBuilder: (context, index) {
                    final item = payouts[index];
                    final amount = item['amount'] ?? 0;
                    final status = item['status'] ?? 'Pending';
                    final dateStr = item['period'];
                    final dateLabel = _formatDate(dateStr.toString());
                    final isPaid = status == 'Paid';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: isPaid ? Colors.green : Colors.amber, width: 4)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        title: Text(dateLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(status.toUpperCase(), style: TextStyle(color: isPaid ? Colors.green : Colors.amber, fontSize: 10)),
                        trailing: Text(
                          "₦${_formatMoney(amount)}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
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

  Widget _buildBankRow(String label, String value, {bool isCopyable = false, BuildContext? context}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (isCopyable && context != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                  },
                  child: const Icon(Icons.copy, size: 14, color: Colors.amber),
                ),
              ]
            ],
          ),
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
