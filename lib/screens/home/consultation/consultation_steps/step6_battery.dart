// lib/screens/home/consultation/consultation_steps/step6_battery.dart
//
// Hybrid-only. For Grid-tied the page shows a notice and just lets the
// agent continue (the flow keeps the step visible so the progress bar
// stays smooth, matching the Backup Power screen in the mockups).
//
// Backup-time math is ported from the website's updated battery step:
//   load (kW)   = totalHP * 900W/HP / 1000
//   usable/batt = 314Ah * 51.2V /1000 * 0.90 DoD * 0.95 eff  ≈ 13.75 kWh
//   hours       = (qty * usablePerBatt) / load

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';

const double _kAcuWPerHp = 900;
const double _kBattModuleKwh = 314 * 51.2 / 1000; // 16.08 kWh per 314Ah @ 51.2V
const double _kBattDod = 0.90;
const double _kBattEff = 0.95;
const double _kBattUsableKwh = _kBattModuleKwh * _kBattDod * _kBattEff; // ≈13.75

class Step6Battery extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step6Battery({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step6Battery> createState() => _Step6BatteryState();
}

class _Step6BatteryState extends State<Step6Battery> {
  late TextEditingController _acuCount;
  late TextEditingController _acuHp;
  late TextEditingController _battQty;

  @override
  void initState() {
    super.initState();
    _acuCount = TextEditingController(text: widget.data.acuCount > 0 ? '${widget.data.acuCount}' : '');
    _acuHp = TextEditingController(text: widget.data.acuTotalHp > 0 ? '${widget.data.acuTotalHp}' : '');
    _battQty = TextEditingController(text: '${widget.data.batteryQty < 1 ? 1 : widget.data.batteryQty}');
  }

  @override
  void dispose() {
    _acuCount.dispose();
    _acuHp.dispose();
    _battQty.dispose();
    super.dispose();
  }

  double get _hp => double.tryParse(_acuHp.text) ?? 0;
  int get _qty {
    final q = int.tryParse(_battQty.text) ?? 1;
    return q < 1 ? 1 : q;
  }

  double get _loadKw => _hp * _kAcuWPerHp / 1000;
  double get _hours => _loadKw > 0 ? (_qty * _kBattUsableKwh) / _loadKw : 0;

  void _saveAndNext() {
    if (widget.data.systemType == 'hybrid') {
      widget.data.acuCount = int.tryParse(_acuCount.text) ?? 0;
      widget.data.acuTotalHp = _hp;
      widget.data.batteryQty = _qty;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final isHybrid = widget.data.systemType == 'hybrid';
    return StepScaffold(
      currentStep: 6,
      totalSteps: 8,
      title: 'Backup Power',
      onNext: _saveAndNext,
      onBack: widget.onBack,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isHybrid ? _hybridForm() : _gridTiedNotice(),
      ),
    );
  }

  Widget _gridTiedNotice() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 44, color: Color(0xFFCCCCCC)),
            SizedBox(height: 16),
            Text('This step is only applicable for Hybrid systems.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), fontSize: 15)),
            SizedBox(height: 4),
            Text('You selected "Grid-tied"',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          ],
        ),
      );

  Widget _hybridForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Backup Power',
              style: TextStyle(
                  color: Color(0xFF1B2B6B), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Which equipment needs backup during an outage? Aircon units (ACUs) are usually the biggest load.',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 20),

          _field('How many ACUs need backup?', _acuCount, 'e.g. 3', 'units'),
          const SizedBox(height: 16),
          _field('Total HP of those ACUs', _acuHp, 'e.g. 4.5', 'HP'),
          const SizedBox(height: 16),
          _field('Quantity of Batteries', _battQty, '1', '× 314Ah'),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6E6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8830A).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                const Text('TENTATIVE BACKUP TIME',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB8730A))),
                const SizedBox(height: 4),
                Text(
                  _hp > 0 ? '≈ ${_hours.toStringAsFixed(1)} hours' : '—',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B2B6B)),
                ),
                const SizedBox(height: 2),
                Text(
                  _hp > 0
                      ? 'Load ${_loadKw.toStringAsFixed(2)} kW · $_qty × 314Ah (${(_qty * _kBattModuleKwh).toStringAsFixed(1)} kWh total)'
                      : 'Enter total HP to see the estimate.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Note: tentative estimate (~70% accuracy). Final specs are confirmed after an ocular site visit.',
            style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      );

  Widget _field(String label, TextEditingController c, String hint, String unit) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              suffixText: unit,
              suffixStyle: const TextStyle(color: Color(0xFF888888), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1B2B6B)),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
            ),
          ),
        ],
      );
}