// lib/screens/home/consultation/consultation_history_screen.dart
//
// Lists every saved consultation (one Bookings record each) via the n8n
// apollo-booking-list endpoint. Pull to refresh; tap a row to view the
// saved recommendation and change the classification or ocular date.

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_detail.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);
const _green = Color(0xFF1F9D6B);

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await BookingService.listBookings();
    items.sort((a, b) => '${b['updatedAt'] ?? ''}'.compareTo('${a['updatedAt'] ?? ''}'));
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  // ── classification chip ──
  Color _classColor(String k) {
    switch (k) {
      case 'closable':
        return _green;
      case 'workable':
        return _gold;
      case 'inquiry':
        return _navy;
      default:
        return _grey;
    }
  }

  String _classLabel(String k) {
    switch (k) {
      case 'closable':
        return 'Closable';
      case 'workable':
        return 'Workable';
      case 'inquiry':
        return 'Inquiry';
      default:
        return 'Unclassified';
    }
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _schedLabel(dynamic s) {
    if (s is! String || s.isEmpty) return 'To be followed';
    final d = DateTime.tryParse(s);
    if (d == null) return 'To be followed';
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Consultation History'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _tile(_items[i]),
                    ),
            ),
    );
  }

  Widget _emptyState() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.history, size: 56, color: Color(0xFFBBBBBB)),
          SizedBox(height: 14),
          Center(
            child: Text('No saved consultations yet',
                style: TextStyle(color: _grey, fontSize: 15)),
          ),
          SizedBox(height: 6),
          Center(
            child: Text('Pull down to refresh',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12.5)),
          ),
        ],
      );

  Widget _tile(Map<String, dynamic> b) {
    final cls = '${b['classification'] ?? ''}';
    final sched = b['schedule'];
    final isTbf = sched is! String || sched.isEmpty;
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ConsultationDetailScreen(booking: b)),
        );
        _load(); // refresh after a possible edit
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${b['client'] ?? 'Walk-in lead'}'.isEmpty ? 'Walk-in lead' : '${b['client']}',
                    style: const TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _classColor(cls).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(_classLabel(cls),
                      style: TextStyle(
                          color: _classColor(cls), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${b['ref'] ?? ''}',
                style: const TextStyle(color: _grey, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(isTbf ? Icons.schedule : Icons.event_available,
                    size: 15, color: isTbf ? _gold : _green),
                const SizedBox(width: 6),
                Text(_schedLabel(sched),
                    style: TextStyle(
                        color: isTbf ? const Color(0xFF8A6F00) : _navy,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            if ((b['status'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${b['status']}', style: const TextStyle(color: _grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}