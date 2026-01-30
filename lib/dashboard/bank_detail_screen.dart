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
    // 1. Stream Wallet Balance
    final walletStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', profileId)
        .limit(1);

    // 2. Stream Bank Details
    final bankStream = Supabase.instance.client
        .from('creator_bank_accounts')
        .stream(primaryKey: ['id'])
        .eq('user_id', authUserId) 
        .limit(1);

    return Scaffold(
      backgroundColor: Colors.black, // Ensure background matches theme
      appBar: AppBar(
        title: Text("FINANCE: $userName".toUpperCase()),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView( // <--- THE FIX: Allows full scrolling
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: THE WALLET ---
            const Text("CURRENT WALLET BALANCE", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
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
                  if (snapshot.data!.isEmpty) return const Text("₦0.00", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white));

                  final data = snapshot.data!.first;
                  final balance = data['earnings_balance'] ?? 0;
                  
                  return Column(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        "₦${balance.toString()}", 
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 8),
                      const Text("PAYABLE AMOUNT", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 40),

            // --- SECTION 2: BANK COORDINATES ---
            const Text("BANK COORDINATES", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            
            // Removed 'Expanded' to allow scrolling
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: bankStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.no_accounts, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text("$userName has not linked a bank account.", style: const TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                }

                final bank = snapshot.data!.first;
                final bankName = bank['bank_name'] ?? 'Unknown Bank';
                final accNumber = bank['account_number'] ?? '0000000000';
                final accName = bank['account_name'] ?? 'Unknown Name';

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
                          _buildBankRow("Bank Name", bankName),
                          const Divider(color: Colors.white10),
                          _buildBankRow("Account Name", accName),
                          const Divider(color: Colors.white10),
                          _buildBankRow("Account Number", accNumber, isCopyable: true, context: context),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32), // Breathing room
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Number Copied! Ready to Pay.")));
                        },
                      ),
                    ),
                    // Extra padding at bottom for easy scrolling
                    const SizedBox(height: 40),
                  ],
                );
              },
            ),
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
              if (isCopyable) ...[
                const SizedBox(width: 8),
                const Icon(Icons.copy, size: 14, color: Colors.amber),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
