// lib/screens/home/consultation/consultation_detail_screen.dart
//
// Opened from History. Shows the saved recommendation snapshot and lets the
// agent change the classification and set/clear the ocular-visit date (the
// "to be followed" case). Saving upserts the SAME booking Ref via n8n, so the
// web tracker and the app stay in sync, with the change appended to Events.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

const List<Map<String, String>> _classes = [
  {'key': 'closable', 'label': 'Closable', 'desc': 'Strong intent — ready to move.'},
  {'key': 'workable', 'label': 'Workable', 'desc': 'Interested — needs follow-up.'},
  {'key': 'inquiry', 'label': 'Inquiry', 'desc': 'Early exploration only.'},
];

class ConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ConsultationDetailScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<ConsultationDetailScreen> createState() => _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  late String _classification;
  late bool _tbf;
  DateTime? _ocular;
  DateTime? _originalOcular; // to detect a newly set/changed date
  bool _saving = false;
  late final TextEditingController _agentCtrl;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final b = widget.booking;
    _classification = '${b['classification'] ?? ''}';
    final s = b['schedule'];
    if (s is String && s.isNotEmpty) {
      _ocular = DateTime.tryParse(s);
    }
    _originalOcular = _ocular;
    _tbf = _ocular == null;
    _agentCtrl = TextEditingController(text: '${b['agent'] ?? ''}');
  }

  @override
  void dispose() {
    _agentCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _snap() {
    try {
      final c = widget.booking['consultation'];
      if (c is String && c.isNotEmpty) return Map<String, dynamic>.from(jsonDecode(c));
      if (c is Map) return Map<String, dynamic>.from(c);
    } catch (_) {}
    return null;
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ap';
  }

  String _peso(num v) {
    final s = v.round().toString();
    final out = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
      out.write(s[i]);
    }
    return out.toString();
  }

  Future<void> _pickOcular() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _ocular ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_ocular ?? now),
    );
    setState(() {
      _ocular = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
      _tbf = false;
    });
  }

  static const _classLabels = {'closable': 'Closable', 'workable': 'Workable', 'inquiry': 'Inquiry'};

  Map<String, dynamic> _bookedPayload() {
    final b = widget.booking;
    final snap = _snap();
    String dateStr = '', timeStr = '';
    if (_ocular != null) {
      dateStr = '${_months[_ocular!.month - 1]} ${_ocular!.day}, ${_ocular!.year}';
      final h = _ocular!.hour % 12 == 0 ? 12 : _ocular!.hour % 12;
      final ap = _ocular!.hour < 12 ? 'AM' : 'PM';
      timeStr = '$h:${_ocular!.minute.toString().padLeft(2, '0')} $ap';
    }
    return {
      'ref': b['ref'],
      'clientName': b['client'] ?? '',
      'clientEmail': snap?['email'] ?? '',
      'clientPhone': snap?['contact'] ?? '',
      'agentName': _agentCtrl.text.trim(),
      'consultationDate': dateStr,
      'consultationTime': timeStr,
      'propertyLocation': snap?['address'] ?? '',
      'clientCategory': _classLabels[_classification] ?? '',
      'notes': _noteCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    if (_classification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a classification.')),
      );
      return;
    }
    setState(() => _saving = true);

    final b = widget.booking;
    List<dynamic> events = [];
    try {
      final e = b['events'];
      if (e is String && e.isNotEmpty) {
        events = jsonDecode(e) as List<dynamic>;
      } else if (e is List) {
        events = List<dynamic>.from(e);
      }
    } catch (_) {}

    final agent = _agentCtrl.text.trim();
    final by = agent.isNotEmpty ? agent : 'Agent';
    final stageKey = (_tbf || _ocular == null) ? 'assigned' : 'scheduled';
    events.add({
      'stageKey': stageKey,
      'time': DateTime.now().toIso8601String(),
      'note': _noteCtrl.text.trim().isEmpty ? 'Updated from History' : _noteCtrl.text.trim(),
      'by': by,
    });

    final payload = {
      'ref': b['ref'],
      'client': b['client'] ?? '',
      'agent': agent.isNotEmpty ? agent : (b['agent'] ?? ''),
      'schedule': (_tbf || _ocular == null) ? '' : _ocular!.toIso8601String(),
      'stage': stageIndex(stageKey),
      'status': stageLabel(stageKey),
      'events': jsonEncode(events),
      'updatedBy': by,
      'updatedAt': DateTime.now().toIso8601String(),
      'classification': _classification,
      'consultation': b['consultation'] ?? '', // keep original snapshot
    };

    final ok = await BookingService.save(payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // Send confirmation email + log only when the date was newly set or changed.
      final nowScheduled = !_tbf && _ocular != null;
      final dateChanged = _ocular != _originalOcular;
      if (nowScheduled && dateChanged) {
        BookingService.fireConsultationBooked(_bookedPayload());
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated'), backgroundColor: Color(0xFF1F9D6B)),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update — check connection and try again.'),
          backgroundColor: Color(0xFFC0392B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final snap = _snap();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Consultation'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${b['client'] ?? 'Walk-in lead'}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${b['ref'] ?? ''}',
                      style: const TextStyle(color: Color(0xFFFFCA5C), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (snap != null) ...[
              _title('Saved Recommendation'),
              const SizedBox(height: 8),
              _snapshotCard(snap),
              const SizedBox(height: 16),
            ],

            _title('Classification'),
            const SizedBox(height: 8),
            for (final c in _classes) _classCard(c),
            const SizedBox(height: 16),

            _title('Ocular Visit'),
            const SizedBox(height: 8),
            _ocularCard(),
            const SizedBox(height: 16),

            _title('Update'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  TextField(
                    controller: _agentCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Assigned consultant', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Note for this update (optional)', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Changes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _title(String t) =>
      Text(t, style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _snapshotCard(Map<String, dynamic> snap) {
    final sys = '${snap['systemType'] ?? ''}' == 'hybrid' ? 'Hybrid (Solar + Battery)' : 'Grid-Tied';
    final bill = snap['avgMonthlyBill'];
    final kwh = snap['monthlyKwh'];
    final recs = (snap['recommendations'] is List) ? snap['recommendations'] as List : const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sys, style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Avg. bill ₱${bill is num ? _peso(bill) : bill} / mo'
            '${kwh != null ? ' · $kwh kWh/mo' : ''}',
            style: const TextStyle(color: _grey, fontSize: 12.5),
          ),
          const Divider(height: 20),
          for (final r in recs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${r['label'] ?? ''} · ${(r['kwp'] is num) ? (r['kwp'] as num).toStringAsFixed(2) : r['kwp']} kWp',
                      style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13),
                    ),
                  ),
                  Text(
                    '₱${r['price'] is num ? _peso(r['price']) : r['price']}',
                    style: const TextStyle(color: _navy, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _classCard(Map<String, String> c) {
    final selected = _classification == c['key'];
    return GestureDetector(
      onTap: () => setState(() => _classification = c['key']!),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF6E6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _gold : const Color(0xFFE6E9F2), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? _gold : _grey, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['label']!,
                      style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(c['desc']!, style: const TextStyle(color: _grey, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ocularCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: _gold,
              title: const Text('To be followed',
                  style: TextStyle(color: _navy, fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Client has not decided on a date yet',
                  style: TextStyle(color: _grey, fontSize: 12)),
              value: _tbf,
              onChanged: (v) => setState(() {
                _tbf = v;
                if (v) _ocular = null;
              }),
            ),
            if (!_tbf) ...[
              const Divider(height: 8),
              InkWell(
                onTap: _pickOcular,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined, color: _navy, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _ocular == null ? 'Tap to set ocular visit date & time' : _fmt(_ocular!),
                          style: TextStyle(
                              color: _ocular == null ? _grey : _navy,
                              fontSize: 14,
                              fontWeight: _ocular == null ? FontWeight.normal : FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: _grey),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}