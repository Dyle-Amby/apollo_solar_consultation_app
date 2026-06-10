// lib/screens/home/consultation/consultation_ticket.dart
//
// The role-gated consultation ticket tracker (Flutter port of the HTML
// preview). Opened from the history list. Renders the 7-stage pipeline as a
// vertical timeline; each step is owned by a role and only that role can
// advance it. Advancing appends an event and upserts the booking via n8n.
//
// TEMPORARY: roles aren't in auth yet, so the active role is chosen with the
// selector at the top. Replace `_activeRole` with the logged-in user's role
// once accounts carry a role.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _green = Color(0xFF1F9D6B);
const _grey = Color(0xFF888888);
const _line = Color(0xFFE3E7F0);

String _roleLabel(String r) =>
    {'sales': 'Sales Agent', 'hos': 'Head of Sales', 'eng': 'Engineering'}[r] ?? r;
Color _roleColor(String r) =>
    {'sales': _navy, 'hos': _gold, 'eng': _green}[r] ?? _navy;
String _roleHint(String r) =>
    {'sales': 'books & relays', 'hos': 'Sales sub-role', 'eng': 'field & specs'}[r] ?? '';

class _Step {
  final String key;
  final String label;
  final String owner; // sales | hos | eng
  final String? stageTitle; // set on the first step of a stage
  final String input; // '' | date | text | choice | deliverable | photo | photos
  final bool optional;
  const _Step(this.key, this.label, this.owner,
      {this.stageTitle, this.input = '', this.optional = false});
}

const List<_Step> _steps = [
  _Step('ocular_booked', 'Ocular Visit Booked', 'sales',
      stageTitle: '1 · Ocular Visit', input: 'date'),

  _Step('ocular_ack', 'Ocular Acknowledged', 'eng',
      stageTitle: '2 · Ocular (Engineering)', input: 'date'),
  _Step('ocular_underway', 'Ocular Underway', 'eng'),
  _Step('ocular_ongoing', 'Ocular Visit Ongoing', 'eng'),
  _Step('ocular_finished', 'Ocular Visit Finished', 'eng'),
  _Step('ocular_quote', 'Final Quotation — Price & Specification', 'eng', input: 'deliverable'),
  _Step('hos_quote_ok', 'Quotation Approved by Head of Sales', 'hos'),

  _Step('quote_sent', 'Final Quotation Sent to Client', 'sales',
      stageTitle: '3 · Quotation to Client'),
  _Step('second_opinion', 'Second-Opinion Outcome (if requested)', 'sales',
      input: 'choice', optional: true),

  _Step('client_ok', 'Final Quotation Approved by Client', 'sales',
      stageTitle: '4 · Client Approval & Scheduling'),
  _Step('delivery_date', 'Delivery Date Booked', 'sales', input: 'date'),
  _Step('install_date', 'Installation Date Booked', 'sales', input: 'date'),

  _Step('eng_assign', 'Assign Engineering Team', 'eng',
      stageTitle: '5 · Engineering Approval', input: 'text'),
  _Step('eng_dates', 'Engineering Confirms / Adjusts Dates', 'eng', input: 'date'),
  _Step('hos_final', 'Head of Sales Final Approval', 'hos'),

  _Step('materials_underway', 'Materials Underway', 'eng', stageTitle: '6 · Delivery'),
  _Step('delivery_way', 'Delivery on the Way', 'eng'),
  _Step('pod', 'Proof of Delivery', 'eng', input: 'photo'),

  _Step('install_underway', 'Installation Underway', 'eng', stageTitle: '7 · Installation'),
  _Step('install_photos', 'Photos: Before / During / After', 'eng', input: 'photos'),
  _Step('completed', 'Installation Complete', 'eng'),
];

class ConsultationTicketScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ConsultationTicketScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<ConsultationTicketScreen> createState() => _ConsultationTicketScreenState();
}

class _ConsultationTicketScreenState extends State<ConsultationTicketScreen> {
  String _activeRole = 'sales';
  bool _saving = false;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    // Use the signed-in user's role when available; otherwise fall back to the
    // selector (handy while testing before everyone has a role set).
    if (Session.role.isNotEmpty) _activeRole = Session.role;
    _events = _parseEvents(widget.booking['events']);
  }

  List<Map<String, dynamic>> _parseEvents(dynamic raw) {
    try {
      if (raw is String && raw.isNotEmpty) {
        final d = jsonDecode(raw);
        if (d is List) return d.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Set<String> get _doneKeys =>
      _events.map((e) => '${e['stepKey'] ?? ''}').where((k) => k.isNotEmpty).toSet();

  int get _currentIndex {
    for (int i = 0; i < _steps.length; i++) {
      if (!_doneKeys.contains(_steps[i].key)) return i;
    }
    return _steps.length;
  }

  Map<String, dynamic>? _eventFor(String key) {
    for (final e in _events) {
      if ('${e['stepKey'] ?? ''}' == key) return e;
    }
    return null;
  }

  // ── Date / format helpers ──
  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmtDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:${d.minute.toString().padLeft(2, '0')} $ap';
  }
  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
  bool _looksIso(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s);

  // ── Advancing a step ──
  Future<void> _advance(_Step s) async {
    String value = '';
    switch (s.input) {
      case 'date':
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: now,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (d == null) return;
        value = d.toIso8601String();
        break;
      case 'text':
        final t = await _textDialog();
        if (t == null) return;
        value = t.isEmpty ? 'Team assigned' : t;
        break;
      case 'choice':
        final c = await _choiceSheet();
        if (c == null) return;
        value = c;
        break;
      case 'deliverable':
        value = 'Quotation submitted';
        break;
      case 'photo':
        value = 'Proof of delivery — photo upload pending Drive integration';
        break;
      case 'photos':
        value = 'Before / During / After — photo upload pending Drive integration';
        break;
      default:
        value = '';
    }
    await _persist(s, value);
  }

  Future<String?> _textDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Assign Engineering Team'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Engr. Diaz, Engr. Lingao'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Assign')),
        ],
      ),
    );
  }

  Future<String?> _choiceSheet() async {
    return showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Client second-opinion outcome',
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: _green),
              title: const Text('Approved — proceed'),
              onTap: () => Navigator.pop(context, 'Approved — proceed'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: _gold),
              title: const Text('Needs another quote / ocular'),
              onTap: () => Navigator.pop(context, 'Needs another quote / ocular'),
            ),
            ListTile(
              leading: const Icon(Icons.skip_next, color: _grey),
              title: const Text('No second opinion'),
              onTap: () => Navigator.pop(context, 'No second opinion'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _persist(_Step s, String value) async {
    setState(() => _saving = true);
    final by = Session.name.isNotEmpty ? Session.name : _roleLabel(_activeRole);
    final newEvents = [
      ..._events,
      {
        'stepKey': s.key,
        'label': s.label,
        'time': DateTime.now().toIso8601String(),
        'by': by,
        'role': _activeRole,
        'value': value,
      }
    ];

    // current status = next pending step's label, or "Completed"
    final doneNow = newEvents.map((e) => '${e['stepKey']}').toSet();
    String statusLabel = 'Completed';
    int stageIdx = _steps.length;
    for (int i = 0; i < _steps.length; i++) {
      if (!doneNow.contains(_steps[i].key)) {
        statusLabel = _steps[i].label;
        stageIdx = i;
        break;
      }
    }

    final b = widget.booking;
    final payload = {
      'ref': b['ref'],
      'client': b['client'] ?? '',
      'agent': b['agent'] ?? '',
      'schedule': b['schedule'] ?? '',
      'stage': stageIdx,
      'status': statusLabel,
      'events': jsonEncode(newEvents),
      'consultation': b['consultation'] ?? '', // preserve snapshot
      'updatedBy': by,
      'updatedAt': DateTime.now().toIso8601String(),
    };

    final ok = await BookingService.save(payload);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _events = newEvents;
        widget.booking['events'] = jsonEncode(newEvents);
        widget.booking['status'] = statusLabel;
      }
    });

    if (!ok) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Update failed'),
          content: SingleChildScrollView(
            child: SelectableText(
              BookingService.lastError.isEmpty ? 'Unknown error.' : BookingService.lastError,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final cur = _currentIndex;
    final done = cur >= _steps.length;
    final statusText = done ? 'Completed' : _steps[cur].label;
    final statusColor = done ? _green : _roleColor(_steps[cur].owner);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Consultation Ticket'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Ticket summary
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${b['client'] ?? 'Walk-in lead'}'.isEmpty ? 'Walk-in lead' : '${b['client']}',
                                  style: const TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.bold)),
                              Text('${b['ref'] ?? ''}',
                                  style: const TextStyle(color: _grey, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Sales Agent: ${('${b['agent'] ?? ''}'.isEmpty) ? 'Unassigned' : b['agent']}',
                        style: const TextStyle(color: Color(0xFF555555), fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Temporary role selector
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Acting as  (temporary — until login roles are added)',
                        style: TextStyle(color: _grey, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final r in const ['sales', 'hos', 'eng']) _rolePill(r),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Timeline
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _steps.length; i++) _stepRow(i, cur),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          if (_saving)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator(color: _navy)),
            ),
        ],
      ),
    );
  }

  Widget _rolePill(String r) {
    final sel = _activeRole == r;
    final c = _roleColor(r);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _activeRole = r),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            decoration: BoxDecoration(
              color: sel ? c : const Color(0xFFFAFBFE),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sel ? c : _line),
            ),
            child: Column(
              children: [
                Text(_roleLabel(r),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? Colors.white : const Color(0xFF555555),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(_roleHint(r),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: sel ? Colors.white70 : _grey, fontSize: 9.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepRow(int i, int cur) {
    final s = _steps[i];
    final isDone = _doneKeys.contains(s.key);
    final isCur = i == cur;
    final last = i == _steps.length - 1;
    final ev = _eventFor(s.key);

    Color dotColor;
    Widget dotChild;
    if (isDone) {
      dotColor = _green;
      dotChild = const Icon(Icons.check, color: Colors.white, size: 15);
    } else if (isCur) {
      dotColor = _navy;
      dotChild = const Text('●', style: TextStyle(color: Colors.white, fontSize: 12));
    } else {
      dotColor = const Color(0xFFB8BECC);
      dotChild = Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.stageTitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6, left: 2),
            child: Text(s.stageTitle!.toUpperCase(),
                style: const TextStyle(
                    color: _navy, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: dotChild,
                  ),
                  if (!last)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isDone ? _green : _line,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.label + (s.optional ? '  (optional)' : ''),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDone || isCur ? const Color(0xFF222222) : const Color(0xFFAAAAAA)),
                            ),
                          ),
                          _ownerBadge(s.owner),
                        ],
                      ),
                      if (isDone && ev != null) ...[
                        const SizedBox(height: 3),
                        Text(_doneSubtitle(ev),
                            style: const TextStyle(color: _grey, fontSize: 11.5)),
                      ],
                      if (isCur) _actionFor(s),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _doneSubtitle(Map<String, dynamic> ev) {
    final t = '${ev['time'] ?? ''}';
    final by = '${ev['by'] ?? ''}';
    final v = '${ev['value'] ?? ''}';
    final vs = v.isEmpty ? '' : (_looksIso(v) ? ' · ${_fmtDate(v)}' : ' · $v');
    return '${_fmtDateTime(t)} · by $by$vs';
  }

  Widget _ownerBadge(String owner) {
    final c = _roleColor(owner);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(_roleLabel(owner),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _actionFor(_Step s) {
    final mine = _activeRole == s.owner;
    if (!mine) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0DCA0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 15, color: Color(0xFF8A6200)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Waiting on ${_roleLabel(s.owner)}',
                  style: const TextStyle(color: Color(0xFF8A6200), fontSize: 12.5)),
            ),
          ],
        ),
      );
    }

    String label;
    switch (s.input) {
      case 'date':
        label = 'Set date';
        break;
      case 'text':
        label = 'Assign team';
        break;
      case 'choice':
        label = 'Record outcome';
        break;
      case 'deliverable':
        label = 'Submit quotation';
        break;
      case 'photo':
      case 'photos':
        label = 'Mark done (photos: Drive soon)';
        break;
      default:
        label = 'Mark “${s.label}” done';
    }

    final isPhoto = s.input == 'photo' || s.input == 'photos';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _advance(s),
              style: ElevatedButton.styleFrom(
                backgroundColor: _roleColor(s.owner),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          if (isPhoto)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Photo upload to Google Drive arrives in the next phase.',
                  style: TextStyle(color: _grey, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}