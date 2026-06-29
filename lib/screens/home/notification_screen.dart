// lib/screens/home/notifications_screen.dart
//
// Tier 1 in-app inbox: the tickets currently waiting on the signed-in user's
// role. Opening this screen marks them "seen" (clears the bell's NEW badge).
// Tapping a row opens that ticket.

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/notification_service.dart';
// NOTE: match this import + class to your actual ticket file (the live one is
// consultation_ticket.dart → ConsultationTicketScreen).
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_ticket.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _green = Color(0xFF1F9D6B);
const _grey = Color(0xFF888888);

Color _roleColor(String r) =>
    {'sales': _navy, 'hos': _gold, 'eng': _green, 'hoe': _green, 'admin': _navy}[r] ?? _navy;
String _roleLabel(String r) =>
    {'sales': 'Sales Agent', 'hos': 'Head of Sales', 'eng': 'Engineering',
     'hoe': 'Head of Engineering', 'admin': 'Admin'}[r] ?? r;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<QueueItem> _queue = [];
  Set<String> _new = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await BookingService.listBookings();
    final q = NotificationService.queueFrom(items);
    final newRefs = await NotificationService.newRefs(q); // before marking seen
    await NotificationService.markAllSeen(q);
    if (!mounted) return;
    setState(() {
      _queue = q;
      _new = newRefs;
      _loading = false;
    });
  }

  Future<void> _open(QueueItem q) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ConsultationTicketScreen(booking: q.booking)),
    );
    if (mounted) _load(); // a step may have been actioned
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : RefreshIndicator(
              onRefresh: _load,
              child: _queue.isEmpty ? _empty() : _list(),
            ),
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(Icons.notifications_none, size: 64, color: _grey.withOpacity(0.5)),
        const SizedBox(height: 12),
        const Center(
          child: Text("You're all caught up",
              style: TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('No tickets are waiting on you right now.',
              style: TextStyle(color: _grey, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _list() {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final q = _queue[i];
        final isNew = _new.contains(q.ref);
        final c = _roleColor(q.step.owner);
        return InkWell(
          onTap: () => _open(q),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isNew ? c.withOpacity(0.5) : const Color(0xFFE6E9F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: c.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.assignment_outlined, color: c, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.client.isEmpty ? 'Walk-in lead' : q.client,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (isNew)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10)),
                              child: const Text('NEW',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('Waiting on: ${q.step.label}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF444444), fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text('${q.ref}${q.agent.isNotEmpty ? ' · ${q.agent}' : ''}',
                          style: const TextStyle(color: _grey, fontSize: 11.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _grey),
              ],
            ),
          ),
        );
      },
    );
  }
}