import 'dart:async';
import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/ticket_pipeline.dart';
import 'package:apollo_solar_consultation_app/services/notification_service.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_flow.dart';
// NOTE: match these import names to your actual filenames.
import 'package:apollo_solar_consultation_app/screens/auth/login.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_history.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_ticket.dart';
import 'package:apollo_solar_consultation_app/screens/home/notification_screen.dart';

const _navy = Color(0xFF1B2B6B);
const _gold = Color(0xFFC8A200);
const _green = Color(0xFF1F9D6B);
const _grey = Color(0xFF888888);

Color _roleColor(String r) => {'sales': _navy, 'hos': _gold, 'eng': _green}[r] ?? _navy;

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  bool _loading = true;
  List<Map<String, dynamic>> _all = [];

  // derived counts
  int _awaiting = 0;
  int _inProgress = 0;
  int _completed = 0;
  int _newCount = 0; // unseen items for the notification bell badge
  // tickets whose current step is owned by my role
  final List<Map<String, dynamic>> _pending = [];

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Keep the badge live while the app is open (Tier 1 polling).
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await BookingService.listBookings();

    int awaiting = 0, inProgress = 0, completed = 0;
    final pending = <Map<String, dynamic>>[];
    final myRole = Session.role;

    for (final b in items) {
      if (ticketIsClosed(b['events'])) continue; // Did Not Push Through — closed
      final step = ticketCurrentStep(b['events']);
      if (step == null) {
        completed++;
      } else {
        inProgress++;
        if (myRole.isNotEmpty && step.owner == myRole) {
          awaiting++;
          pending.add({'booking': b, 'step': step});
        }
      }
    }

    if (!mounted) return;
    final queue = NotificationService.queueFrom(items);
    final newCount = await NotificationService.newCount(queue);
    if (!mounted) return;
    setState(() {
      _all = items;
      _awaiting = awaiting;
      _inProgress = inProgress;
      _completed = completed;
      _newCount = newCount;
      _pending
        ..clear()
        ..addAll(pending);
      _loading = false;
    });
  }

  void _logout() {
    Session.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) _load(); // opening the inbox marks items seen → badge clears
  }

  Widget _bell() {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: _openNotifications,
        ),
        if (_newCount > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: _navy, width: 1.5),
              ),
              child: Text(
                _newCount > 9 ? '9+' : '$_newCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = Session.role;
    final isEng = role == 'eng';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF243580), borderRadius: BorderRadius.circular(18)),
              child: const Icon(Icons.wb_sunny_outlined, color: Color(0xFFE8830A), size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apollo Solar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Ventures', style: TextStyle(color: Color(0xFFADB5D6), fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          _bell(),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _greeting(role),
                    const SizedBox(height: 16),

                    // Stats
                    Row(
                      children: [
                        Expanded(child: _statCard(Icons.notifications_active_outlined, _roleColor(role), 'Awaiting You', _awaiting)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(Icons.timelapse, _navy, 'In Progress', _inProgress)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard(Icons.check_circle_outline, _green, 'Completed', _completed)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Pending approvals
                    const Text('AWAITING YOUR ACTION',
                        style: TextStyle(color: _grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    if (_pending.isEmpty) _emptyPending() else ..._pending.map(_pendingCard),

                    const SizedBox(height: 24),

                    // Quick actions
                    const Text('QUICK ACTIONS',
                        style: TextStyle(color: _grey, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    if (!isEng) ...[
                      _actionCard(
                        icon: Icons.add_circle_outline,
                        title: 'New Consultation',
                        subtitle: 'Start a client consultation',
                        filled: true,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationFlow()));
                          _load();
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    _actionCard(
                      icon: Icons.history,
                      title: 'Consultation History',
                      subtitle: 'View & search all tickets',
                      filled: false,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsultationHistoryScreen()));
                        _load();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _greeting(String role) {
    final name = Session.name.isEmpty ? 'there' : Session.name;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, $name', style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(role.isEmpty ? 'No role set' : 'Signed in as ${roleLabel(role)}',
                  style: const TextStyle(color: _grey, fontSize: 13)),
            ],
          ),
        ),
        if (role.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(color: _roleColor(role).withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(roleLabel(role),
                style: TextStyle(color: _roleColor(role), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _statCard(IconData icon, Color color, String label, int value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _grey, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _emptyPending() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, size: 40, color: Color(0xFFBBBBBB)),
          SizedBox(height: 10),
          Text('Nothing awaiting your action', style: TextStyle(color: _grey, fontSize: 14)),
          SizedBox(height: 2),
          Text('Pull down to refresh', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> entry) {
    final b = entry['booking'] as Map<String, dynamic>;
    final step = entry['step'] as TicketStep;
    final client = '${b['client'] ?? ''}'.isEmpty ? 'Walk-in lead' : '${b['client']}';
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ConsultationTicketScreen(booking: b)));
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _roleColor(step.owner), width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client, style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('${b['ref'] ?? ''}', style: const TextStyle(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.pending_actions, size: 14, color: _gold),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Needs: ${step.label}',
                            style: const TextStyle(color: Color(0xFF555555), fontSize: 12.5),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _grey),
          ],
        ),
      ),
    );
  }

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
          color: filled ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: filled ? const Color(0xFF243580) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: filled ? Colors.white : _navy, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: filled ? Colors.white : const Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: filled ? const Color(0xFFADB5D6) : _grey, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: filled ? Colors.white : _grey),
          ],
        ),
      ),
    );
  }
}