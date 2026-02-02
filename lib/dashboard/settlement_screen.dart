import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Removed 'intl' import to fix build error

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("SETTLEMENT OFFICE"),
        backgroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: "MONTHLY CLOSE"),
            Tab(text: "DISBURSEMENT QUEUE"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MonthlyCloseTab(),
          _DisbursementTab(),
        ],
      ),
    );
  }
}

// --- TAB 1: GENERATE INVOICES ---
class _MonthlyCloseTab extends StatelessWidget {
  const _MonthlyCloseTab();

  Future<void> _runCloseBooks(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("CLOSE LAST MONTH?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will:\n1. Sum up all earnings for last month.\n2. Generate Payout Records.\n3. DEDUCT funds from user wallets.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXECUTE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if(context.mounted) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.amber)));
      }
      
      final res = await Supabase.instance.client.rpc('close_monthly_books');
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("BOOKS CLOSED", style: TextStyle(color: Colors.green)),
            content: Text(res.toString(), style: const TextStyle(color: Colors.white70)),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white)))],
          ),
        );
      }
    } catch (e) {
      if(context.mounted) Navigator.pop(context);
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMonth = DateTime.now().subtract(const Duration(days: 30));
    // CUSTOM FORMATTER: No external package needed
    final monthName = _formatMonthYear(lastMonth);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text("READY TO CLOSE:", style: TextStyle(color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(monthName, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.lock_clock, color: Colors.black),
              label: const Text("GENERATE INVOICES", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
              onPressed: () => _runCloseBooks(context),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "This action moves funds from 'Active Wallet' to 'Processing Payouts'.\nRun this on the 1st of every month.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white30),
          ),
        ],
      ),
    );
  }

  // Simple helper to avoid 'intl' package dependency
  String _formatMonthYear(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[date.month - 1]} ${date.year}";
  }
}

// --- TAB 2: MARK AS PAID ---
class _DisbursementTab extends StatelessWidget {
  const _DisbursementTab();

  @override
  Widget build(BuildContext context) {
    // Stream Payouts where status is 'Processing'
    final payoutsStream = Supabase.instance.client
        .from('payouts')
        .stream(primaryKey: ['id'])
        .eq('status', 'Processing')
        .order('amount', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: payoutsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.amber));
        final items = snapshot.data!;
        
        if (items.isEmpty) {
          return const Center(child: Text("All Clear! No pending payouts.", style: TextStyle(color: Colors.white54)));
        }

        return ListView.builder(
          itemCount: items.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = items[index];
            final amount = item['amount'];
            final dateStr = item['period'];
            final payoutId = item['id'];
            final userId = item['user_id'];
            
            // Format date safely
            String displayDate = dateStr.toString();
            try {
              final date = DateTime.parse(dateStr.toString());
              // Use the same helper function
              const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
              displayDate = "${months[date.month - 1]} ${date.year}";
            } catch (_) {}

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.pending, color: Colors.orange),
                title: Text("₦$amount", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text("User: $userId\nPeriod: $displayDate", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: "Mark as Paid",
                  onPressed: () => _markPaid(context, payoutId, amount),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markPaid(BuildContext context, String id, dynamic amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("CONFIRM PAYMENT?", style: TextStyle(color: Colors.white)),
        content: Text("Mark ₦$amount as SENT to the user's bank?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("CONFIRM", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.rpc('mark_payout_paid', params: {'payout_id': id});
      if(context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as Paid!"), backgroundColor: Colors.green));
      }
    }
  }
}
