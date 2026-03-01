import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // --- [NEW] STATE FOR STATUS FILTER ---
  String _currentFilter = 'All'; // Options: 'All', 'Premium', 'Verified', 'Free', 'Banned'
  
  late final Stream<List<Map<String, dynamic>>> _usersStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream here so it doesn't rebuild on every keystroke
    _usersStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- [NEW] HELPER FOR FILTER CHIPS ---
  Widget _buildFilterChip(String label, Color activeColor) {
    final isSelected = _currentFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label, style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70, 
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12
        )),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _currentFilter = selected ? label : 'All';
          });
        },
        backgroundColor: Colors.black,
        selectedColor: activeColor,
        checkmarkColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? activeColor : Colors.white24)
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint("👑 I AM LOGGED IN AS: $myId");

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("THE ROSTER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // --- TREASURY BUTTON (DAILY) ---
          IconButton(
            icon: const Icon(Icons.monetization_on, color: Colors.amber),
            tooltip: "Open Federal Reserve",
            onPressed: () => context.push('/treasury'),
          ),
          
          // --- SETTLEMENT BUTTON (MONTHLY) ---
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.cyanAccent),
            tooltip: "Settlement Office",
            onPressed: () => context.push('/settlement'),
          ),
          
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('verification_requests').stream(primaryKey: ['id']).eq('status', 'pending'),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications), onPressed: () => context.push('/verification')),
                  if (count > 0) 
                    Positioned(
                      right: 8, 
                      top: 8, 
                      child: Container(
                        padding: const EdgeInsets.all(4), 
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), 
                        child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                      )
                    ),
                ],
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () => Supabase.instance.client.auth.signOut()),
        ],
      ),
      body: Column(
        children: [
          // --- SLEEK SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, username, or email...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.white10, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.amber, width: 1),
                ),
              ),
            ),
          ),

          // --- [NEW] STATUS FILTER CHIPS ---
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All', Colors.white),
                _buildFilterChip('Premium', Colors.amber),
                _buildFilterChip('Verified', Colors.blue),
                _buildFilterChip('Free', Colors.grey),
                _buildFilterChip('Banned', Colors.redAccent),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- ROSTER LIST ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.amber));
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error loading roster: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                }

                final allUsers = snapshot.data ?? [];
                
                // --- COMBINED CLIENT-SIDE FILTERING LOGIC ---
                final users = allUsers.where((user) {
                  // 1. Text Search Filter
                  bool matchesText = true;
                  if (_searchQuery.isNotEmpty) {
                    final fullName = (user['full_name'] ?? '').toString().toLowerCase();
                    final displayName = (user['display_name'] ?? '').toString().toLowerCase();
                    final username = (user['username'] ?? '').toString().toLowerCase();
                    final email = (user['email'] ?? '').toString().toLowerCase();
                    
                    matchesText = fullName.contains(_searchQuery) || 
                                  displayName.contains(_searchQuery) || 
                                  username.contains(_searchQuery) || 
                                  email.contains(_searchQuery);
                  }

                  // 2. Status Chip Filter
                  bool matchesStatus = true;
                  if (_currentFilter != 'All') {
                    final isPremium = user['is_premium'] == true;
                    final isVerified = user['is_verified'] == true;
                    final isBanned = user['is_banned'] == true;

                    if (_currentFilter == 'Premium') matchesStatus = isPremium;
                    if (_currentFilter == 'Verified') matchesStatus = isVerified;
                    if (_currentFilter == 'Free') matchesStatus = !isPremium && !isBanned;
                    if (_currentFilter == 'Banned') matchesStatus = isBanned;
                  }

                  return matchesText && matchesStatus;
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty && _currentFilter == 'All' ? "No soldiers found yet." : "No users match your filters.",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                  itemCount: users.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final name = user['full_name'] ?? user['display_name'] ?? user['username'] ?? 'Unknown Agent';
                    final email = user['email'] ?? 'No Email';
                    final isVerified = user['is_verified'] == true;
                    final isPremium = user['is_premium'] == true;
                    final isBanned = user['is_banned'] == true;
                    final userId = user['id']; 

                    // UI POLISH: Premium users get a distinct, luxurious highlight
                    Color cardColor = const Color(0xFF1E1E1E);
                    Color borderColor = Colors.white10;
                    
                    if (isBanned) {
                      cardColor = Colors.red.withOpacity(0.05);
                      borderColor = Colors.red.withOpacity(0.4);
                    } else if (isPremium) {
                      cardColor = Colors.amber.withOpacity(0.05);
                      borderColor = Colors.amber.withOpacity(0.3);
                    }

                    return Card(
                      elevation: 0,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16), 
                        side: BorderSide(color: borderColor, width: 1.5)
                      ),
                      child: InkWell(
                        onTap: () => context.push('/user/$userId'),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isBanned ? Colors.red : (isPremium ? Colors.amber : Colors.grey.withOpacity(0.2)),
                                  foregroundColor: isPremium && !isBanned ? Colors.black : Colors.white,
                                  child: isBanned ? const Icon(Icons.block, color: Colors.white) : Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name, 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 16,
                                          color: isBanned ? Colors.redAccent : Colors.white
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isVerified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified, size: 18, color: Colors.blue)),
                                    if (isPremium && !isBanned) Padding(
                                      padding: const EdgeInsets.only(left: 6), 
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                        child: const Text("ELITE", style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      ),
                                    ),
                                    if (isBanned) const Padding(padding: EdgeInsets.only(left: 6), child: Text("(BANNED)", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(email, style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                              ),
                              const SizedBox(height: 8),
                              const Divider(color: Colors.white10),
                              
                              // SAFE QUICK ACTIONS
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ActionButton(
                                    icon: Icons.badge, 
                                    label: isVerified ? "Verified" : "Verify", 
                                    color: isVerified ? Colors.blue : Colors.grey, 
                                    onTap: () => _safeToggle(context, name, "Verify User", userId, 'is_verified', !isVerified)
                                  ),
                                  _ActionButton(
                                    icon: Icons.star, 
                                    label: "Premium", 
                                    color: isPremium ? Colors.amber : Colors.grey, 
                                    onTap: () => _safeToggle(context, name, "Grant Premium", userId, 'is_premium', !isPremium)
                                  ),
                                  
                                  // --- CONNECTED BANK BUTTON ---
                                  _ActionButton(
                                    icon: Icons.account_balance, 
                                    label: "Bank", 
                                    color: Colors.grey, 
                                    onTap: () {
                                      final authId = user['auth_user_id'] ?? userId; // Handle missing auth_id
                                      final safeName = Uri.encodeComponent(name); 
                                      context.push('/bank/$userId/$authId/$safeName');
                                    }
                                  ),
                                  
                                  _ActionButton(
                                    icon: isBanned ? Icons.restore : Icons.block, 
                                    label: isBanned ? "Unban" : "Ban", 
                                    color: isBanned ? Colors.green : Colors.red.withOpacity(0.8), 
                                    onTap: () => _safeToggle(context, name, isBanned ? "UNBAN USER?" : "BAN USER?", userId, 'is_banned', !isBanned)
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _safeToggle(BuildContext context, String userName, String action, String userId, String column, bool newValue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(action, style: const TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to change status for $userName?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("CONFIRM", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        await _toggleStatus(context, userId, column, newValue);
      }
    }
  }

  Future<void> _toggleStatus(BuildContext context, String userId, String column, bool newValue) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .update({column: newValue})
          .eq('id', userId)
          .select();
      
      if (data.isEmpty) {
        throw "ACCESS DENIED (RLS BLOCKED). Database ignored the update.";
      }

      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("SUCCESS: Updated $column!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      debugPrint("ERROR: $e");
      if(context.mounted) {
        showDialog(context: context, builder: (c) => AlertDialog(
          title: const Text("UPDATE FAILED", style: TextStyle(color: Colors.red)),
          content: Text(e.toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
        ));
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), 
        child: Column(
          children: [
            Icon(icon, color: color, size: 22), 
            const SizedBox(height: 6), 
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))
          ]
        )
      ),
    );
  }
}
