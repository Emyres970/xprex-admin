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

  // --- RECURSIVE STORAGE SWEEPER HELPER ---
  Future<List<String>> _getFilesRecursively(String bucket, String path) async {
    List<String> filePaths = [];
    final storage = Supabase.instance.client.storage.from(bucket);
    
    // Fetch items in the current path with a high limit
    final items = await storage.list(path: path, searchOptions: const SearchOptions(limit: 1000));

    for (final item in items) {
      if (item.name == '.emptyFolderPlaceholder') continue;
      
      final currentItemPath = path.isEmpty ? item.name : '$path/${item.name}';

      // Supabase storage.list() returns items without an ID if they are folders
      if (item.id == null) {
        // It's a folder: recursively search inside it
        final nestedFiles = await _getFilesRecursively(bucket, currentItemPath);
        filePaths.addAll(nestedFiles);
      } else {
        // It's a file: add its exact path to the kill list
        filePaths.add(currentItemPath);
      }
    }
    return filePaths;
  }

  // --- MANUAL STORAGE SWEEPER ---
  Future<void> _purgeTempVideos() async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red))
    );

    try {
      final bucketName = 'raw_uploads';
      
      // 1. Recursively find every single file in the bucket
      final filesToDelete = await _getFilesRecursively(bucketName, '');

      // 2. Safely bulk delete the files in chunks to avoid API timeouts
      if (filesToDelete.isNotEmpty) {
        final storage = Supabase.instance.client.storage.from(bucketName);
        const chunkSize = 100;
        
        for (var i = 0; i < filesToDelete.length; i += chunkSize) {
          final chunk = filesToDelete.sublist(
            i, 
            i + chunkSize > filesToDelete.length ? filesToDelete.length : i + chunkSize
          );
          await storage.remove(chunk);
        }
      }

      // 3. Success UI
      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Deleted ${filesToDelete.length} temporary files"), 
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      // 4. Error UI
      if (mounted) {
        Navigator.pop(context); // Close Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error purging files: $e"), 
            backgroundColor: Colors.red,
          )
        );
      }
    }
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
          final yesterdaySec = data['yesterday_seconds'] ?? 0; 
          final avgRate7d = data['avg_rate_7d'] ?? 0; 

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

                // 3. YESTERDAY'S LEDGER
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
                
                const SizedBox(height: 48),

                // 5. STORAGE MAINTENANCE
                const Text("STORAGE MAINTENANCE", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_sweep, color: Colors.white),
                    label: const Text("PURGE TEMP VIDEOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmPurge(context),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    "Manually clears the raw_uploads bucket.\nUse this fallback if the automated cron job fails.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),
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

  Future<void> _confirmPurge(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("PURGE TEMP VIDEOS?", style: TextStyle(color: Colors.white)),
        content: const Text("This will permanently delete all raw files in the temporary upload bucket. Proceed?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("PURGE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      if(context.mounted) _purgeTempVideos();
    }
  }

  Future<void> _runEngine(BuildContext context) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red))
    );

    try {
      final response = await Supabase.instance.client.rpc('calculate_daily_earnings'); 
      
      if (context.mounted) Navigator.pop(context); // Close Loading

      final data = response as Map<String, dynamic>;
      final int count = data['payout_count'] ?? 0;
      final double total = (data['total_paid'] ?? 0).toDouble();
      
      final formattedTotal = total.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
        (Match m) => '${m[1]},'
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 10),
                const Text("PAYOUT COMPLETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Funds successfully distributed.", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                _buildSummaryRow("Creators Paid:", "$count", Colors.white),
                const SizedBox(height: 8),
                _buildSummaryRow("Total Amount:", "₦$formattedTotal", Colors.greenAccent),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx), 
                child: const Text("EXCELLENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              )
            ],
          ),
        );
        _refreshData(); 
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  String _formatMoney(num amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }
  
  String _formatCompact(num amount) {
    if (amount >= 1000) return "${(amount / 1000).toStringAsFixed(1)}k";
    return amount.toString();
  }
}
