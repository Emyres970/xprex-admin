import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TreasuryScreen extends StatelessWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Live Stream of Premium Users to calculate the "Pot"
    final poolStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('is_premium', true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("FEDERAL RESERVE"),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: THE POOL SIZE ---
            const Text("ESTIMATED MONTHLY POOL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: poolStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
                  
                  final premiumCount = snapshot.data!.length;
                  // The Math: Users * 7000
                  final poolValue = premiumCount * 7000; 
                  
                  return Column(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "₦${_formatMoney(poolValue)}", 
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text("$premiumCount ACTIVE CONTRIBUTORS", style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 48),

            // --- SECTION 2: THE ENGINE TRIGGER ---
            const Text("PAYOUT PROTOCOL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            const Text(
              "Status: STANDBY\nAuthorization: FOUNDER ONLY",
              style: TextStyle(color: Colors.white54, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.rocket_launch, color: Colors.white),
                label: const Text("INITIATE DAILY PAYOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                onPressed: () => _confirmPayoutRun(context),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                "This will calculate earnings for all creators based on yesterday's watch time and update their wallets immediately.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPayoutRun(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("INITIATE PAYOUT?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to run the calculation engine? This action interacts with live wallets.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXECUTE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      _runEngine(context);
    }
  }

  Future<void> _runEngine(BuildContext context) async {
    try {
      // Show Loading
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
      );

      // 🚀 CALL THE SECURE SQL WRAPPER
      final response = await Supabase.instance.client
          .rpc('trigger_daily_payout'); 
      
      if (context.mounted) Navigator.pop(context); // Close Loading

      final data = response; 
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("ENGINE REPORT", style: TextStyle(color: Colors.green)),
            content: SingleChildScrollView(
              child: Text(
                // Pretty print the JSON result from SQL
                "Status: ${data['status']}\n"
                "Date: ${data['date']}\n"
                "Pool Size: ₦${data['pool']}\n"
                "Rate/Sec: ₦${data['rate']}", 
                style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("DISMISS", style: TextStyle(color: Colors.white))),
            ],
          ),
        );
      }

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close Loading
        // Show specific error (e.g., Access Denied)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failure: $e"), backgroundColor: Colors.red));
      }
    }
  }

  String _formatMoney(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
}
