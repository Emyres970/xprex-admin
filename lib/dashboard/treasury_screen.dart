import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> {
  late Future<Map<String, dynamic>> _treasuryData;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _treasuryData = _fetchTreasuryStats();
    });
  }

  Future<Map<String, dynamic>> _fetchTreasuryStats() async {
    return await Supabase.instance.client.rpc('get_treasury_stats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("FEDERAL RESERVE"),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _refreshData,
          )
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _treasuryData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
          }

          final data = snapshot.data!;
          final liquidity = data['daily_liquidity'] ?? 0;
          final subs = data['subscribers'] ?? 0;
          final todaySec = data['today_seconds'] ?? 0;
          final yesterdayRate = data['yesterday_rate'] ?? 0;
          final yesterdaySec = data['yesterday_seconds'] ?? 0; // NEW
          final avgRate7d = data['avg_rate_7d'] ?? 0; // NEW

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LIQUIDITY CAP
                const Text("DAILY LIQUIDITY CAP", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                _buildMetricCard(
                  title: "AVAILABLE TODAY",
                  value: "₦${_formatMoney(liquidity)}",
                  subtitle: "$subs Premium Contributors",
                  icon: Icons.account_balance,
                  color: Colors.green,
                ),

                const SizedBox(height: 32),

                // 2. LIVE PULSE (TODAY)
                const Text("LIVE NETWORK PULSE", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "TODAY'S WORK",
                        value: "${_formatCompact(todaySec)}s",
                        subtitle: "Seconds Watched",
                        icon: Icons.timer,
                        color: Colors.blue,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        title: "7-DAY AVG RATE",
                        value: "₦${avgRate7d.toStringAsFixed(2)}",
                        subtitle: "Per Second",
                        icon: Icons.show_chart,
                        color: Colors.purpleAccent,
                        isSmall: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // 3. YESTERDAY'S LEDGER (NEW SECTION)
                const Text("YESTERDAY'S CLOSING", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: "TOTAL SECONDS",
                        value: "${_formatCompact(yesterdaySec)}s",
                        subtitle: "Effective Time (Decayed)",
                        icon: Icons.history,
                        color: Colors.white54,
                        isSmall: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        title: "CLOSING RATE",
                        value: "₦${yesterdayRate.toStringAsFixed(2)}",
                        subtitle: "Final Value/Sec",
                        icon: Icons.price_check,
                        color: Colors.amber,
                        isSmall: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // 4. TRIGGER BUTTON
                const Text("PAYOUT PROTOCOL", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.rocket_launch, color: Colors.white),
                    label: const Text("INITIATE PAYOUT ENGINE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmPayoutRun(context),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "Calculation includes 20% Decay Protocol for re-watches.\nUpdates creator wallets immediately.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required String subtitle, required IconData icon, required Color color, bool isSmall = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: isSmall ? 24 : 32),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: isSmall ? 24 : 40, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _confirmPayoutRun(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("RUN ENGINE?", style: TextStyle(color: Colors.white)),
        content: const Text("This will finalize payments for yesterday using the 20% Decay Logic.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("EXECUTE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      if(context.mounted) _runEngine(context);
    }
  }

  Future<void> _runEngine(BuildContext context) async {
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)));
      
      final response = await Supabase.instance.client.rpc('trigger_daily_payout'); 
      
      if (context.mounted) Navigator.pop(context);

      final data = response; 
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("PAYOUT REPORT", style: TextStyle(color: Colors.green)),
            content: Text(
              "Status: ${data['status']}\nLiquidity: ₦${data['liquidity']}\nEffective Secs: ${data['effective_seconds']}\nRate: ₦${data['rate']}", 
              style: const TextStyle(color: Colors.white70)
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Colors.white)))],
          ),
        );
        _refreshData();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  String _formatMoney(num amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
  
  String _formatCompact(num amount) {
    if (amount >= 1000) return "${(amount / 1000).toStringAsFixed(1)}k";
    return amount.toString();
  }
}
