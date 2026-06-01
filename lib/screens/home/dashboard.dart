import 'package:apollo_solar_consultation_app/screens/auth/login.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  // Dummy data - will be replaced with real API data later
  int totalConsults = 0;
  int closedSales = 0;
  int hotLeads = 0;
  int warmLeads = 0;
  int coldLeads = 0;
  int salesLost = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      // Header
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B2B6B),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF243580),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.wb_sunny_outlined,
                color: Color(0xFFE8830A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Apollo Solar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ventures',
                  style: TextStyle(
                    color: Color(0xFFADB5D6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const SizedBox(height: 8),

            // Stats row
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFF1B2B6B),
                    label: 'Total Consults',
                    value: totalConsults,
                    labelColor: const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.trending_up,
                    iconColor: Colors.green,
                    label: 'Closed Sales',
                    value: closedSales,
                    labelColor: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions label
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            // New Consultation - filled navy
            _actionCard(
              icon: Icons.add_circle_outline,
              title: 'New Consultation',
              subtitle: 'Start a client consultation',
              filled: true,
              onTap: () {},
            ),

            const SizedBox(height: 8),

            // Consultation History
            _actionCard(
              icon: Icons.history,
              title: 'Consultation History',
              subtitle: 'View past consultations',
              filled: false,
              onTap: () {},
            ),

            const SizedBox(height: 8),
            /*
            // Admin Dashboard
            _actionCard(
              icon: Icons.people_outline,
              title: 'Admin Dashboard',
              subtitle: 'Manage sales agents',
              filled: false,
              onTap: () {},
            ),
            */
            const SizedBox(height: 24),

            // Summary label
            const Text(
              'SUMMARY',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            // Summary card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _summaryRow('Hot Leads (Closable)', hotLeads, Colors.green),
                  _divider(),
                  _summaryRow('Warm Leads (Workable)', warmLeads, Colors.orange),
                  _divider(),
                  _summaryRow('Cold Leads (Inquiry)', coldLeads, Colors.grey),
                  _divider(),
                  _summaryRow('Sales Lost', salesLost, Colors.red),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Stat card widget
  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required int value,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  // Action card widget
  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF1B2B6B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: filled
                    ? const Color(0xFF243580)
                    : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: filled ? Colors.white : const Color(0xFF1B2B6B),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: filled ? Colors.white : const Color(0xFF1A1A1A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: filled
                          ? const Color(0xFFADB5D6)
                          : const Color(0xFF888888),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: filled ? Colors.white : const Color(0xFF888888),
            ),
          ],
        ),
      ),
    );
  }

  // Summary row widget
  Widget _summaryRow(String label, int value, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Divider between summary rows
  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Color(0xFFEEEEEE),
    );
  }
}