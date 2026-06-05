// lib/screens/home/consultation/consultation_steps/step3_system_type.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/widgets/choice_card.dart';

const _navy = Color(0xFF1B2B6B);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

class Step3SystemType extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step3SystemType({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step3SystemType> createState() => _Step3SystemTypeState();
}

class _Step3SystemTypeState extends State<Step3SystemType> {
  late String _sysType;

  static const _options = [
    ChoiceOption(
      value: 'gridtied',
      icon: Icons.wb_sunny_outlined,
      title: 'Grid-Tied',
      subtitle: 'Connected to the grid, no batteries. Best for savings and net metering.',
    ),
    ChoiceOption(
      value: 'hybrid',
      icon: Icons.battery_charging_full_outlined,
      title: 'Hybrid',
      subtitle: 'Solar + battery backup. Works during outages and can still net-meter.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sysType = widget.data.systemType.isEmpty ? 'gridtied' : widget.data.systemType;
  }

  void _saveAndNext() {
    widget.data.systemType = _sysType;
    widget.onNext();
  }

  String? get _recommendation {
    switch (widget.data.priority) {
      case 'savings':
      case 'zeroBill':
        return 'Based on the goal, Grid-Tied is the most cost-effective fit.';
      case 'backup':
      case 'offgrid':
        return 'Based on the goal, Hybrid is recommended for battery backup.';
      default:
        return null;
    }
  }

  // -- Explainer pop-up --------------------------------------
  void _showDifference() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Grid-Tied vs Hybrid',
                style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Which solar setup fits the client?',
                style: TextStyle(color: _grey, fontSize: 13)),
            const SizedBox(height: 20),
            _explainCard(
              icon: Icons.wb_sunny_outlined,
              accent: _navy,
              title: 'Grid-Tied',
              tagline: 'Solar that runs alongside the grid - no batteries.',
              good: const [
                'Lowest upfront cost - no battery to buy.',
                'Cuts the daytime bill; can net-meter excess for credits.',
                'Simplest system, fastest payback.',
              ],
              watch: const [
                'No power during a blackout (shuts off for safety).',
                'Savings happen mostly while the sun is up.',
              ],
              bestFor: 'Clients whose main goal is lowering the bill or reaching a zero bill via net metering.',
            ),
            const SizedBox(height: 14),
            _explainCard(
              icon: Icons.battery_charging_full_outlined,
              accent: _gold,
              title: 'Hybrid',
              tagline: 'Solar plus a battery - keeps power on when the grid drops.',
              good: const [
                'Backup power during outages for critical loads.',
                'Stores daytime solar for use at night.',
                'Can still net-meter excess (if the DU allows).',
              ],
              watch: const [
                'Higher upfront cost - batteries add to the price.',
                'Battery is sized to the loads you choose to back up.',
              ],
              bestFor: 'Clients who need outage protection, have frequent brownouts, or want energy independence.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Rule of thumb: if the priority is savings or a zero bill, Grid-Tied. '
                'If it is backup or going off-grid, Hybrid.',
                style: TextStyle(fontSize: 12.5, color: _navy, height: 1.5),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _explainCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String tagline,
    required List<String> good,
    required List<String> watch,
    required String bestFor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9F2)),
        boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text(tagline, style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
            const SizedBox(height: 12),
            for (final g in good) _bullet(g, Icons.check_circle, const Color(0xFF1F9D6B)),
            for (final w in watch) _bullet(w, Icons.info_outline, _gold),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              const TextSpan(
                  text: 'Best for: ',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _navy)),
              TextSpan(text: bestFor, style: const TextStyle(fontSize: 12.5, color: Color(0xFF555555))),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text, IconData icon, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.4)),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 3,
      totalSteps: 8,
      title: 'System Type',
      onNext: _saveAndNext,
      onBack: widget.onBack,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'System Type Preference',
                    style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showDifference,
                  icon: const Icon(Icons.help_outline, size: 18, color: _gold),
                  label: const Text("What's the difference?",
                      style: TextStyle(color: _gold, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Recommend a configuration. You can override the suggestion.',
              style: TextStyle(color: _grey, fontSize: 14),
            ),
            if (_recommendation != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8830A).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFB8730A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _recommendation!,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A6200)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            ChoiceGroup(
              value: _sysType,
              options: _options,
              onChanged: (v) => setState(() => _sysType = v),
            ),
          ],
        ),
      ),
    );
  }
}