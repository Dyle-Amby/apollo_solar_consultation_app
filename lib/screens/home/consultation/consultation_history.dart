// lib/screens/home/consultation/consultation_history.dart
//
// Shopee-style "completed orders" list of consultation tickets. Each row shows
// the client name, ticket (booking) ref, creation date, assigned sales agent,
// and current status. Search + filter by client name / agent / ref / date.

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_ticket.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);
const _green = Color(0xFF1F9D6B);
const _blue = Color(0xFF1B6FB8);

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _all = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _filterField = 'client'; // client | agent | ref | date
  DateTime? _filterDate;
  String _dateGran = 'day'; // day | month | year

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await BookingService.listBookings();
    items.sort((a, b) {
      final da = _created(a), db = _created(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1; // undated sinks to the bottom
      if (db == null) return -1;
      return db.compareTo(da); // newest first
    });
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
    });
  }

  String _createdStr(Map b) => '${b['createdAt'] ?? b['updatedAt'] ?? ''}';
  DateTime? _created(Map b) => _parseDt(_createdStr(b));

  // Tolerant parser. Handles ISO ("2026-06-19T01:56:54.118Z") AND the format
  // Google Sheets hands back ("2026-06-19 1:56:54" — space separator and an
  // UNPADDED hour for times before 10am), which DateTime.tryParse rejects.
  static DateTime? _parseDt(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final direct = DateTime.tryParse(s);
    if (direct != null) return direct;
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?')
        .firstMatch(s);
    if (m == null) return null;
    int g(int i, [int d = 0]) => int.tryParse(m.group(i) ?? '') ?? d;
    return DateTime(g(1), g(2), g(3), g(4), g(5), g(6));
  }

  // ── Filtering ──
  String _fieldValue(Map b) {
    switch (_filterField) {
      case 'client':
        return '${b['client'] ?? ''}';
      case 'agent':
        return '${b['agent'] ?? ''}';
      case 'ref':
        return '${b['ref'] ?? ''}';
      default:
        return '';
    }
  }

  bool _matchesDate(Map b) {
    if (_filterDate == null) return true;
    final d = _created(b);
    if (d == null) return false;
    final f = _filterDate!;
    if (_dateGran == 'year') return d.year == f.year;
    if (_dateGran == 'month') return d.year == f.year && d.month == f.month;
    return d.year == f.year && d.month == f.month && d.day == f.day;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterField == 'date') {
      return _all.where(_matchesDate).toList();
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((b) => _fieldValue(b).toLowerCase().contains(q)).toList();
  }

  // ── Display helpers ──
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtDate(DateTime? d) =>
      d == null ? '—' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

  Color _statusColor(String s) {
    final t = s.toLowerCase();
    if (t.contains('did not push through') || t.contains('lost') || t.startsWith('closed')) {
      return const Color(0xFFC0392B); // red — closed / lost
    }
    if (t.contains('workable')) return _gold;
    if (t.contains('install') || t.contains('complete') ||
        t.contains('for closing') || t.contains('approved by client')) return _green;
    if (t.contains('deliver')) return _blue;
    if (t.contains('ocular') || t.contains('quotation')) return _gold;
    return _navy;
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _filterDate = d);
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
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _navy))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty ? _emptyState() : _list(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          // Filter field chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _fieldChip('Client', 'client'),
                _fieldChip('Agent', 'agent'),
                _fieldChip('Ref #', 'ref'),
                _fieldChip('Date', 'date'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_filterField == 'date') _dateControls() else _textSearch(),
        ],
      ),
    );
  }

  Widget _fieldChip(String label, String key) {
    final sel = _filterField == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => setState(() => _filterField = key),
        selectedColor: _navy,
        labelStyle: TextStyle(
            color: sel ? Colors.white : _navy, fontSize: 13, fontWeight: FontWeight.w600),
        backgroundColor: const Color(0xFFF0F2F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: sel ? _navy : const Color(0xFFDDE1EC)),
        ),
      ),
    );
  }

  Widget _textSearch() {
    final hint = {
      'client': 'Search by client name',
      'agent': 'Search by sales agent name',
      'ref': 'Search by booking ref #',
    }[_filterField]!;
    return TextField(
      controller: _searchCtrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, color: _grey),
        suffixIcon: _searchCtrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: _grey),
                onPressed: () => setState(() => _searchCtrl.clear()),
              ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _dateControls() {
    Widget gran(String label, String key) {
      final sel = _dateGran == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => setState(() => _dateGran = key),
          selectedColor: _gold,
          labelStyle: TextStyle(color: sel ? Colors.white : _navy, fontSize: 12),
          backgroundColor: const Color(0xFFF0F2F5),
        ),
      );
    }

    String picked() {
      if (_filterDate == null) return 'Any date';
      final d = _filterDate!;
      if (_dateGran == 'year') return '${d.year}';
      if (_dateGran == 'month') return '${_months[d.month - 1]} ${d.year}';
      return _fmtDate(d);
    }

    return Row(
      children: [
        gran('Day', 'day'),
        gran('Month', 'month'),
        gran('Year', 'year'),
        const SizedBox(width: 4),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickFilterDate,
            icon: const Icon(Icons.event, size: 16, color: _navy),
            label: Text(picked(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _navy, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDDE1EC)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
        ),
        if (_filterDate != null)
          IconButton(
            icon: const Icon(Icons.close, color: _grey),
            onPressed: () => setState(() => _filterDate = null),
          ),
      ],
    );
  }

  Widget _list() {
    final items = _filtered;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) => _tile(items[i]),
    );
  }

  Widget _emptyState() => ListView(
        children: const [
          SizedBox(height: 120),
          Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFBBBBBB)),
          SizedBox(height: 14),
          Center(child: Text('No matching consultations', style: TextStyle(color: _grey, fontSize: 15))),
          SizedBox(height: 6),
          Center(child: Text('Pull down to refresh', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12.5))),
        ],
      );

  Widget _tile(Map<String, dynamic> b) {
    final client = '${b['client'] ?? ''}'.isEmpty ? 'Walk-in lead' : '${b['client']}';
    final status = '${b['status'] ?? 'Pending'}';
    final agent = '${b['agent'] ?? ''}'.isEmpty ? 'Unassigned' : '${b['agent']}';
    final sc = _statusColor(status);
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ConsultationTicketScreen(booking: b)),
        );
        _load();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(client,
                      style: const TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(color: sc, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _metaRow(Icons.confirmation_number_outlined, '${b['ref'] ?? '—'}'),
            const SizedBox(height: 4),
            _metaRow(Icons.event_outlined, 'Created ${_fmtDate(_created(b))}'),
            const SizedBox(height: 4),
            _metaRow(Icons.person_outline, agent),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 14, color: _grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 12.5),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}