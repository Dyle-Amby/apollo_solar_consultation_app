// lib/screens/home/consultation/consultation_steps/step3_system_type.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/widgets/choice_card.dart';

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
            const Text(
              'System Type Preference',
              style: TextStyle(
                color: Color(0xFF1B2B6B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Recommend a configuration. You can override the suggestion.',
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
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