// lib/screens/home/consultation/finalize_screen.dart
//
// Reached from the Results page's orange "Complete Consultation" button.
// The agent sets an ocular-visit date (or marks it
// "To be followed" if undecided), then saves. Saving upserts a booking via
// the same n8n API the web tracker uses, so it appears in Consultation
// History and can be changed there later.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';
import 'package:apollo_solar_consultation_app/utils/solar_calculator.dart' as calc;

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

class FinalizeScreen extends StatefulWidget {
  final ConsultationData data;
  const FinalizeScreen({Key? key, required this.data}) : super(key: key);

  @override
  State<FinalizeScreen> createState() => _FinalizeScreenState();
}

class _FinalizeScreenState extends State<FinalizeScreen> {
  bool _tbf = false; // "to be followed" — client hasn't decided on a date
  DateTime? _ocular;
  bool _saving = false;

  late final TextEditingController _agentCtrl;
  final TextEditingController _noteCtrl = TextEditingController();
  late final String _ref = _genRef();

  @override
  void initState() {
    super.initState();
    // Default the agent to the signed-in user (still editable if someone is
    // logging a consultation on behalf of another agent).
    _agentCtrl = TextEditingController(text: Session.name);
  }

  @override
  void dispose() {
    _agentCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _genRef() {
    final n = DateTime.now();
    String two(int x) => x.toString().padLeft(2, '0');
    return 'ASV-BK-${two(n.year % 100)}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  // ── Ocular date picker ──
  Future<void> _pickOcular() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _ocular ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
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

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ap = d.hour < 12 ? 'AM' : 'PM';
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $ap';
  }

  // ── Build the snapshot stored for History ──
  Map<String, dynamic> _snapshot() {
    final d = widget.data;
    final rate = calc.duRates[d.distributionUtility] ?? 10.5;
    final mBill = d.avgMonthlyBill;
    final mKwh = mBill > 0 ? mBill / rate : 0.0;
    final tiers = calc.calcAllTiers(
      systemType: d.systemType,
      monthlyKwh: mKwh,
      kwhRate: rate,
      roofDir: d.roofDirection,
    );
    return {
      'systemType': d.systemType,
      'priority': d.priority,
      'avgMonthlyBill': mBill,
      'monthlyKwh': mKwh.round(),
      'distributionUtility': d.distributionUtility,
      'timeline': d.timeline,
      'contact': d.contactNumber,
      'email': d.email,
      'propertyType': d.propertyType,
      'address': d.address,
      'roof': {
        'type': d.roofType,
        'length': d.roofLength,
        'width': d.roofWidth,
        'direction': d.roofDirection,
        'obstructions': d.obstructions,
      },
      'obstructions': d.obstructions,
      'notes': _noteCtrl.text.trim(),
      'pricingSource': calc.pricingSource,
      'recommendations': [
        for (final t in tiers)
          {
            'label': t.label,
            'kwp': t.actualKwp,
            'panels': t.panels,
            'panelWp': t.panelWp,
            'price': t.totalSRP,
            'paybackYears': t.roiYears,
            'monthlySavings': t.monthlySavings,
          }
      ],
    };
  }

  Map<String, dynamic> _payload() {
    final d = widget.data;
    final agent = _agentCtrl.text.trim();
    final by = agent.isNotEmpty ? agent : 'Agent';
    final hasDate = !_tbf && _ocular != null;

    // Use the ticket tracker's vocabulary. A dated booking completes the
    // first step ("Ocular Visit Booked"); a "to be followed" booking starts
    // empty so the tracker opens on that first step.
    final events = hasDate
        ? [
            {
              'stepKey': 'ocular_booked',
              'label': 'Ocular Visit Booked',
              'time': DateTime.now().toIso8601String(),
              'by': by,
              'role': 'sales',
              'value': _ocular!.toIso8601String(),
              'note': _noteCtrl.text.trim(),
            }
          ]
        : [
            // "To be followed" — no date yet, but still log that the consultation
            // was created so Events / Status History aren't blank. This is NOT a
            // pipeline step, so the tracker still opens on "Ocular Visit Booked".
            {
              'stepKey': 'consultation_logged',
              'label': 'Consultation Logged — To Be Followed',
              'time': DateTime.now().toIso8601String(),
              'by': by,
              'role': 'sales',
              'value': 'To be followed',
              'note': _noteCtrl.text.trim(),
            }
          ];

    return {
      'ref': _ref,
      'client': d.fullName,
      'agent': agent,
      'schedule': hasDate ? _ocular!.toIso8601String() : '',
      'stage': hasDate ? 1 : 0,
      'status': hasDate ? 'Ocular Acknowledged' : 'Ocular Visit Booked',
      // Whose turn it is now: a dated booking waits on Engineering's ack,
      // an undated one still waits on Sales to book the ocular.
      'currentOwner': hasDate ? 'eng' : 'sales',
      'events': jsonEncode(events),
      // Stable creation timestamp — set ONCE here and re-sent unchanged on every
      // tracker update, so the Sheet's "Created" column never resets.
      'createdAt': DateTime.now().toIso8601String(),
      'updatedBy': by,
      'updatedAt': DateTime.now().toIso8601String(),
      // Flat, human-readable columns for the Google Sheet, so staff don't have
      // to open the Consultation JSON to see who/where.
      'clientType': d.propertyType,
      'contact': d.contactNumber,
      'email': d.email,
      'location': d.address,
      'systemType': d.isHybrid ? 'Hybrid' : 'Grid-Tied',
      'obstructions': d.obstructions,
      'notes': _noteCtrl.text.trim(),
      // Full recommendation snapshot for the ticket view (kept as JSON).
      'consultation': jsonEncode(_snapshot()),
    };
  }

  // Payload for the "Consultation Booked" workflow (Sheets log + email).
  Map<String, dynamic> _bookedPayload() {
    final d = widget.data;
    String dateStr = '', timeStr = '';
    if (_ocular != null) {
      dateStr = '${_months[_ocular!.month - 1]} ${_ocular!.day}, ${_ocular!.year}';
      final h = _ocular!.hour % 12 == 0 ? 12 : _ocular!.hour % 12;
      final ap = _ocular!.hour < 12 ? 'AM' : 'PM';
      timeStr = '$h:${_ocular!.minute.toString().padLeft(2, '0')} $ap';
    }
    return {
      'ref': _ref,
      'clientName': d.fullName,
      'clientEmail': d.email,
      'clientPhone': d.contactNumber,
      'agentName': _agentCtrl.text.trim(),
      'consultationDate': dateStr,
      'consultationTime': timeStr,
      'propertyLocation': d.address,
      'clientCategory': '',
      'notes': _noteCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    // ONE atomic call: the create chain makes the "ClientName-RefNo" Drive
    // folder, then appends the row with that folder baked in. If the folder
    // can't be made, the whole booking fails (hard-fail) and nothing is written,
    // so we never end up with a folderless ticket.
    final result = await BookingService.createBooking(_payload());
    final ok = result != null;
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // Email stays on its own untouched webhook; fire only when a date exists.
      if (!_tbf && _ocular != null) {
        BookingService.fireConsultationBooked(_bookedPayload());
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Consultation saved'),
          content: Text('Reference: $_ref\n\nIt will appear in Consultation History and can be updated there.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).popUntil((r) => r.isFirst); // back to dashboard
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Save failed'),
          content: SingleChildScrollView(
            child: SelectableText(
              BookingService.lastError.isEmpty
                  ? 'Unknown error.'
                  : BookingService.lastError,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Finalize Consultation'),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _refCard(),
            const SizedBox(height: 16),
            _sectionTitle('Ocular Visit'),
            const SizedBox(height: 8),
            _ocularCard(),
            const SizedBox(height: 16),
            _sectionTitle('Details'),
            const SizedBox(height: 8),
            _detailsCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _saveBar(),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _refCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Booking Reference',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_ref,
                style: const TextStyle(
                    color: Color(0xFFFFCA5C), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.data.fullName.isEmpty ? 'Walk-in lead' : widget.data.fullName,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );

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

  Widget _detailsCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            TextField(
              controller: _agentCtrl,
              decoration: const InputDecoration(
                labelText: 'Assigned consultant',
                hintText: 'e.g. Joselito Villegas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Bring 14kWp ROI study',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      );

  Widget _saveBar() => SafeArea(
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
                  : const Text('Save Consultation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      );
}