// lib/screens/home/consultation/consultation_steps/step8_results.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/utils/solar_calculator.dart' as calc;

const _navy = Color(0xFF1B2B6B);
const _grey = Color(0xFF888888);
const _gold = Color(0xFFE8830A);

const Map<String, Color> _tierColors = {
  'entry': Color(0xFF1B4F8A),
  'mid': Color(0xFFE8830A),
  'high': Color(0xFF2D7A3A),
};

class Step8Results extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onBack;
  final ValueChanged<int> onEditStep; // jump back to a step, then return here
  final VoidCallback onConfirm; // hand off to the (future) finalize screen

  const Step8Results({
    Key? key,
    required this.data,
    required this.onBack,
    required this.onEditStep,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<Step8Results> createState() => _Step8ResultsState();
}

class _Step8ResultsState extends State<Step8Results> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    calc.ensurePricing().then((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // ── Derived values ────────────────────────────────────────
  double get _rate => calc.duRates[widget.data.distributionUtility] ?? 10.5;
  double get _mBill => widget.data.avgMonthlyBill;
  double get _mKwh => _mBill > 0 ? _mBill / _rate : 0;

  String get _systemLabel {
    if (widget.data.systemType == 'hybrid') return 'Hybrid (Solar + Battery)';
    return 'Grid-Tied${widget.data.priority == 'zeroBill' ? ' (Net Metering)' : ''}';
  }

  static const _priorityLabels = {
    'savings': 'Bill Reduction',
    'zeroBill': 'Zero Bill / Net Metering',
    'backup': 'Backup Power',
    'offgrid': 'Off-Grid Independence',
  };
  static const _timelineLabels = {
    'asap': 'Immediately',
    '1-3mo': '1–3 Months',
    '3-6mo': '3–6 Months',
    'justlooking': 'Exploring',
  };

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 8,
      totalSteps: 8,
      title: 'Your Recommendation',
      isLastStep: true, // orange "Complete Consultation" button
      onBack: widget.onBack,
      onNext: widget.onConfirm,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(color: _navy)),
            )
          : _results(),
    );
  }

  Widget _results() {
    final tiers = calc.calcAllTiers(
      systemType: widget.data.systemType,
      monthlyKwh: _mKwh,
      kwhRate: _rate,
      roofDir: widget.data.roofDirection,
    );
    final live = calc.pricingSource == 'live';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text('Solar System Estimate',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(_systemLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFCA5C), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Avg. bill ₱${_fmt(_mBill)}/mo · ${_mKwh.round()} kWh/mo',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (live ? const Color(0xFF2D7A3A) : _gold).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  live ? '✓ Live pricing' : '⚡ Offline pricing',
                  style: TextStyle(
                      color: live ? const Color(0xFF8FE3A6) : const Color(0xFFFFCA5C),
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text('Recommended Options',
            style: TextStyle(color: _navy, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        for (final t in tiers) ...[
          _tierCard(t),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 4),
        _editableSummary(),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withOpacity(0.3)),
          ),
          child: Text(
            'Estimate is partial (~70% accuracy). Basis: PSH ${calc.kPsh} · '
            'Loss ${(calc.kLoss * 100).round()}% · Degradation ${(calc.kDegrad * 100)}%/yr. '
            'Final specs follow an ocular site visit.',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A6200), height: 1.5),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── One tier card (specs + price + ROI) ──
  Widget _tierCard(calc.TierResult t) {
    final accent = _tierColors[t.color] ?? _navy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: accent, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.label,
                    style: const TextStyle(
                        color: _navy, fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(t.tag,
                      style: TextStyle(
                          color: accent, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('${t.panels} panels × ${t.panelWp}W',
                style: const TextStyle(color: _grey, fontSize: 12)),
            const SizedBox(height: 12),

            _row('System Size', '${t.actualKwp.toStringAsFixed(2)} kWp'),
            _row('Inverter', '${t.invKw % 1 == 0 ? t.invKw.toInt() : t.invKw} kW'),
            if (t.battKwh > 0) _row('Battery', '${t.battKwh} kWh'),
            _row('Panels', '${t.panels} pcs'),
            _row('Space Needed', '~${t.spaceM2} m²'),

            const SizedBox(height: 12),
            Text('₱${_fmt(t.totalSRP.toDouble())}',
                style: const TextStyle(
                    color: _navy, fontSize: 22, fontWeight: FontWeight.bold)),
            Text('₱${t.perWp.toStringAsFixed(1)}/Wp',
                style: const TextStyle(color: _grey, fontSize: 11)),

            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _roiStat('Payback', '${t.roiYears} yrs')),
                Expanded(child: _roiStat('Saves', '₱${_fmt(t.monthlySavings.toDouble())}/mo')),
                Expanded(child: _roiStat('Daily Yield', '${t.dailyYield.toStringAsFixed(1)} kWh')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: const TextStyle(color: _grey, fontSize: 13)),
            Text(v,
                style: const TextStyle(
                    color: Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _roiStat(String l, String v) => Column(
        children: [
          Text(v,
              style: const TextStyle(
                  color: _navy, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(l, style: const TextStyle(color: _grey, fontSize: 10)),
        ],
      );

  // ── Editable summary: tap a row → jump to its step, then return ──
  Widget _editableSummary() {
    final d = widget.data;
    final rows = <List<dynamic>>[
      ['Client', d.fullName.isEmpty ? '—' : d.fullName, 1],
      ['Contact', d.contactNumber.isEmpty ? '—' : d.contactNumber, 1],
      ['Property', d.propertyType, 1],
      ['Address', d.address.isEmpty ? '—' : d.address, 1],
      ['Priority', _priorityLabels[d.priority] ?? '—', 2],
      ['System', _systemLabel, 3],
      ['Avg. Bill', '₱${_fmt(_mBill)}', 4],
      ['Utility', d.distributionUtility.isEmpty ? '—' : d.distributionUtility.toUpperCase(), 4],
      ['Roof', '${d.roofType}${d.roofLength > 0 ? ' · ${d.roofLength}m×${d.roofWidth}m' : ''}', 5],
      if (d.systemType == 'hybrid')
        ['Backup', '${d.acuCount} ACU · ${d.acuTotalHp} HP · ${d.batteryQty} batt', 6],
      ['Timeline', _timelineLabels[d.timeline] ?? '—', 7],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Client Data  ·  tap a row to edit',
                style: TextStyle(color: _navy, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          for (int i = 0; i < rows.length; i++) ...[
            InkWell(
              onTap: () => widget.onEditStep(rows[i][2] as int),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(rows[i][0] as String,
                          style: const TextStyle(color: _grey, fontSize: 13)),
                    ),
                    Expanded(
                      child: Text(rows[i][1] as String,
                          style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    const Icon(Icons.edit_outlined, size: 15, color: _grey),
                  ],
                ),
              ),
            ),
            if (i != rows.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFEEEEEE)),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _fmt(double v) {
    // Thousands separator, no decimals for whole pesos.
    final s = v.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}