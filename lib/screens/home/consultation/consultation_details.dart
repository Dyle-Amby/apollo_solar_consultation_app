// lib/screens/home/consultation/consultation_details.dart
//
// Opened by tapping the ticket header. Shows the ORIGINAL consultation inputs
// captured during the wizard, lets the user edit them, recomputes the
// recommendations (reusing the solar calculator) when pricing-affecting fields
// change, and upserts the same ticket via BookingService.save. An "Export to
// PDF" button is stubbed for the next step.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/booking_service.dart';
import 'package:apollo_solar_consultation_app/services/session.dart';
import 'package:apollo_solar_consultation_app/utils/solar_calculator.dart' as calc;
import 'package:apollo_solar_consultation_app/utils/consultation_pdf.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _green = Color(0xFF1F9D6B);
const _grey = Color(0xFF888888);

class ConsultationDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const ConsultationDetailsScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<ConsultationDetailsScreen> createState() => _ConsultationDetailsScreenState();
}

class _ConsultationDetailsScreenState extends State<ConsultationDetailsScreen> {
  late TextEditingController _name, _contact, _email, _address, _bill, _rL, _rW, _obstr, _notes;

  String _propertyType = 'Residential';
  String _systemType = 'gridtied';
  String _priority = 'savings';
  String _du = 'other';
  String _timeline = '3-6mo';
  String _roofType = 'metal';
  String _roofDir = 'unknown';

  bool _saving = false;

  // Originals — used to detect whether a pricing-affecting field changed.
  late String _origSys, _origDu, _origDir;
  late double _origBill;
  List<Map<String, dynamic>> _origRecs = [];

  // ── option sets ──
  static const _propertyOpts = ['Residential', 'Commercial', 'Industrial'];
  static const _systemOpts = {'gridtied': 'Grid-Tied', 'hybrid': 'Hybrid'};
  static const _priorityOpts = {'savings': 'Maximize savings', 'backup': 'Backup power', 'offgrid': 'Off-grid'};
  static const _duOpts = {
    'meralco': 'Meralco',
    'batelec1': 'BATELEC I',
    'batelec2': 'BATELEC II',
    'lima': 'LIMA',
    'other': 'Other',
  };
  static const _timelineOpts = {
    'asap': 'ASAP',
    '3-6mo': '3–6 months',
    '6-12mo': '6–12 months',
    'exploring': 'Just exploring',
  };
  static const _roofTypeOpts = {'metal': 'Metal', 'tile': 'Tile', 'concrete': 'Concrete', 'other': 'Other'};
  static const _roofDirOpts = {
    'south': 'South',
    'southeast': 'Southeast',
    'southwest': 'Southwest',
    'east': 'East',
    'west': 'West',
    'north': 'North (flag)',
    'unknown': 'Unknown',
  };

  Map<String, dynamic> _snap() {
    try {
      final c = widget.booking['consultation'];
      if (c is String && c.isNotEmpty) return Map<String, dynamic>.from(jsonDecode(c));
      if (c is Map) return Map<String, dynamic>.from(c);
    } catch (_) {}
    return {};
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final s = _snap();
    final roof = (s['roof'] is Map) ? Map<String, dynamic>.from(s['roof']) : <String, dynamic>{};

    _name = TextEditingController(text: '${widget.booking['client'] ?? ''}');
    _contact = TextEditingController(text: '${s['contact'] ?? ''}');
    _email = TextEditingController(text: '${s['email'] ?? ''}');
    _address = TextEditingController(text: '${s['address'] ?? ''}');
    _bill = TextEditingController(text: s['avgMonthlyBill'] == null ? '' : '${_num(s['avgMonthlyBill']).round()}');
    _rL = TextEditingController(text: roof['length'] == null ? '' : '${_num(roof['length'])}');
    _rW = TextEditingController(text: roof['width'] == null ? '' : '${_num(roof['width'])}');
    _obstr = TextEditingController(text: '${s['obstructions'] ?? roof['obstructions'] ?? ''}');
    _notes = TextEditingController(text: '${s['notes'] ?? ''}');

    _propertyType = '${s['propertyType'] ?? 'Residential'}';
    _systemType = '${s['systemType'] ?? 'gridtied'}';
    _priority = '${s['priority'] ?? 'savings'}';
    _du = '${s['distributionUtility'] ?? 'other'}';
    _timeline = '${s['timeline'] ?? '3-6mo'}';
    _roofType = '${roof['type'] ?? 'metal'}';
    _roofDir = '${roof['direction'] ?? 'unknown'}';

    final recs = (s['recommendations'] is List) ? s['recommendations'] as List : const [];
    _origRecs = recs.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    _origSys = _systemType;
    _origDu = _du;
    _origDir = _roofDir;
    _origBill = _num(s['avgMonthlyBill']);
  }

  @override
  void dispose() {
    for (final c in [_name, _contact, _email, _address, _bill, _rL, _rW, _obstr, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _pricingChanged() {
    final bill = double.tryParse(_bill.text.trim()) ?? 0;
    return _systemType != _origSys || _du != _origDu || _roofDir != _origDir || bill != _origBill;
  }

  List<Map<String, dynamic>> _displayRecs() {
    if (!_pricingChanged()) return _origRecs;
    final rate = calc.duRates[_du] ?? 10.5;
    final bill = double.tryParse(_bill.text.trim()) ?? 0;
    final mKwh = bill > 0 ? bill / rate : 0.0;
    final tiers = calc.calcAllTiers(
      systemType: _systemType,
      monthlyKwh: mKwh,
      kwhRate: rate,
      roofDir: _roofDir,
    );
    return tiers
        .map((t) => {
              'label': t.label,
              'kwp': t.actualKwp,
              'panels': t.panels,
              'panelWp': t.panelWp,
              'price': t.totalSRP,
              'paybackYears': t.roiYears,
              'monthlySavings': t.monthlySavings,
            })
        .toList();
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final b = widget.booking;
    final bill = double.tryParse(_bill.text.trim()) ?? 0;
    final rate = calc.duRates[_du] ?? 10.5;
    final mKwh = bill > 0 ? bill / rate : 0.0;
    final recs = _displayRecs();

    final snap = {
      'systemType': _systemType,
      'priority': _priority,
      'avgMonthlyBill': bill,
      'monthlyKwh': mKwh.round(),
      'distributionUtility': _du,
      'timeline': _timeline,
      'contact': _contact.text.trim(),
      'email': _email.text.trim(),
      'propertyType': _propertyType,
      'address': _address.text.trim(),
      'roof': {
        'type': _roofType,
        'length': double.tryParse(_rL.text.trim()) ?? 0,
        'width': double.tryParse(_rW.text.trim()) ?? 0,
        'direction': _roofDir,
        'obstructions': _obstr.text.trim(),
      },
      'obstructions': _obstr.text.trim(),
      'notes': _notes.text.trim(),
      'pricingSource': calc.pricingSource,
      'recommendations': recs,
    };

    // Append a (non-pipeline) edit event so the change is logged, without
    // moving the ticket along its steps.
    List<dynamic> events = [];
    try {
      final e = b['events'];
      if (e is String && e.isNotEmpty) {
        events = jsonDecode(e) as List<dynamic>;
      } else if (e is List) {
        events = List<dynamic>.from(e);
      }
    } catch (_) {}
    events.add({
      'stepKey': 'consultation_edited',
      'label': 'Consultation details edited',
      'time': DateTime.now().toIso8601String(),
      'by': Session.name.isEmpty ? 'User' : Session.name,
      'role': Session.role,
      'value': '',
      'note': '',
    });

    final payload = {
      'ref': b['ref'],
      'client': _name.text.trim(),
      'agent': b['agent'] ?? '', // unchanged — sales creator
      'schedule': b['schedule'] ?? '', // unchanged — pipeline position preserved
      'stage': b['stage'] ?? 0,
      'status': b['status'] ?? '',
      'currentOwner': b['currentOwner'] ?? '',
      'events': jsonEncode(events),
      'consultation': jsonEncode(snap),
      'createdAt': b['createdAt'] ?? '',
      'updatedBy': Session.name.isEmpty ? 'User' : Session.name,
      'updatedAt': DateTime.now().toIso8601String(),
      // flat columns
      'clientType': _propertyType,
      'contact': _contact.text.trim(),
      'email': _email.text.trim(),
      'location': _address.text.trim(),
      'systemType': _systemType == 'hybrid' ? 'Hybrid' : 'Grid-Tied',
      'obstructions': _obstr.text.trim(),
      'notes': _notes.text.trim(),
    };

    final ok = await BookingService.save(payload);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      // reflect changes in the in-memory booking so the ticket screen updates
      b['client'] = _name.text.trim();
      b['agent'] = b['agent'] ?? '';
      b['consultation'] = jsonEncode(snap);
      b['events'] = jsonEncode(events);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation updated'), backgroundColor: _green),
      );
      Navigator.of(context).pop();
    } else {
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

  Future<void> _exportPdf() async {
    final bill = double.tryParse(_bill.text.trim()) ?? 0;
    final rate = calc.duRates[_du] ?? 10.5;
    final mKwh = bill > 0 ? bill / rate : 0.0;

    final rL = double.tryParse(_rL.text.trim()) ?? 0;
    final rW = double.tryParse(_rW.text.trim()) ?? 0;
    final dims = (rL > 0 && rW > 0) ? '$rL × $rW m' : '—';

    final data = ConsultationPdfData(
      ref: '${widget.booking['ref'] ?? ''}',
      clientName: _name.text.trim(),
      contact: _contact.text.trim(),
      email: _email.text.trim(),
      propertyType: _propertyType,
      address: _address.text.trim(),
      systemTypeLabel: _systemOpts[_systemType] ?? _systemType,
      priorityLabel: _priorityOpts[_priority] ?? _priority,
      avgBill: bill,
      duLabel: _duOpts[_du] ?? _du,
      monthlyKwh: mKwh,
      timelineLabel: _timelineOpts[_timeline] ?? _timeline,
      roofType: _roofTypeOpts[_roofType] ?? _roofType,
      roofDims: dims,
      roofDirLabel: _roofDirOpts[_roofDir] ?? _roofDir,
      obstructions: _obstr.text.trim(),
      notes: _notes.text.trim(),
      agent: '${widget.booking['agent'] ?? ''}',
      recommendations: _displayRecs(),
    );

    try {
      await exportConsultationPdf(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PDF: $e'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recs = _displayRecs();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Consultation Details'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export to PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('Client', [
            _field('Client name', _name),
            _field('Contact number', _contact, keyboard: TextInputType.phone),
            _field('Email', _email, keyboard: TextInputType.emailAddress),
            _dropdown('Property type', _propertyType,
                {for (final p in _propertyOpts) p: p}, (v) => setState(() => _propertyType = v)),
            _field('Address', _address, lines: 2),
          ]),
          _section('System & Usage', [
            _dropdown('System type', _systemType, _systemOpts, (v) => setState(() => _systemType = v)),
            _dropdown('Priority', _priority, _priorityOpts, (v) => setState(() => _priority = v)),
            _field('Avg. monthly bill (₱)', _bill,
                keyboard: TextInputType.number, onChanged: (_) => setState(() {})),
            _dropdown('Distribution utility', _du, _duOpts, (v) => setState(() => _du = v)),
            _dropdown('Timeline', _timeline, _timelineOpts, (v) => setState(() => _timeline = v)),
          ]),
          _section('Roof', [
            _dropdown('Roof type', _roofType, _roofTypeOpts, (v) => setState(() => _roofType = v)),
            Row(children: [
              Expanded(child: _field('Length (m)', _rL, keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _field('Width (m)', _rW, keyboard: TextInputType.number)),
            ]),
            _dropdown('Facing', _roofDir, _roofDirOpts, (v) => setState(() => _roofDir = v)),
            _field('Obstructions', _obstr, lines: 2),
          ]),
          _section('Notes', [
            _field('Additional notes', _notes, lines: 3),
          ]),
          _recsCard(recs),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Export to PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      );

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboard, int lines = 1, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: lines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> opts, ValueChanged<String> onChanged) {
    // Make sure the current value is always selectable, even if it's not a known option.
    final items = {...opts};
    if (!items.containsKey(value) && value.isNotEmpty) items[value] = value;
    return DropdownButtonFormField<String>(
      value: items.containsKey(value) ? value : (items.keys.isNotEmpty ? items.keys.first : null),
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _recsCard(List<Map<String, dynamic>> recs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Recommended Options',
                  style: TextStyle(color: _navy, fontSize: 15, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_pricingChanged())
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Recalculated',
                      style: TextStyle(color: Color(0xFF8A6200), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Derived from the inputs above — saving stores these.',
              style: TextStyle(color: _grey, fontSize: 11.5)),
          const Divider(height: 20),
          if (recs.isEmpty)
            const Text('No recommendations yet.', style: TextStyle(color: _grey, fontSize: 13))
          else
            for (final r in recs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${r['label'] ?? ''} · ${(r['kwp'] is num) ? (r['kwp'] as num).toStringAsFixed(2) : r['kwp']} kWp',
                          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        Text('₱${r['price'] is num ? _peso(r['price']) : r['price']}',
                            style: const TextStyle(color: _navy, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Payback ${r['paybackYears'] ?? '—'} yrs · saves ₱${r['monthlySavings'] is num ? _peso(r['monthlySavings']) : r['monthlySavings']}/mo',
                      style: const TextStyle(color: _grey, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}