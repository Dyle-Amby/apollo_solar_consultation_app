// lib/screens/home/consultation/consultation_steps/step2_priority.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/widgets/choice_card.dart';

class Step2Priority extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2Priority({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step2Priority> createState() => _Step2PriorityState();
}

class _Step2PriorityState extends State<Step2Priority> {
  late String _priority;

  static const _options = [
    ChoiceOption(
      value: 'savings',
      icon: Icons.savings_outlined,
      title: 'Reduce electricity bill',
      subtitle: 'Use solar during the day, stay on grid at night. Simplest and most affordable.',
    ),
    ChoiceOption(
      value: 'zeroBill',
      icon: Icons.bar_chart_outlined,
      title: 'Savings + possible Zero Bill (Net Metering)',
      subtitle: 'Export excess solar to the grid for bill credits. May reach a ₱0 electric bill.',
    ),
    ChoiceOption(
      value: 'backup',
      icon: Icons.battery_charging_full_outlined,
      title: 'Power backup during outages',
      subtitle: 'Solar + battery — keep critical loads running when the grid goes down.',
    ),
    ChoiceOption(
      value: 'offgrid',
      icon: Icons.bolt_outlined,
      title: 'Total power without the grid',
      subtitle: 'Full energy independence with a large battery bank for 24/7 solar.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _priority = widget.data.priority;
  }

  void _saveAndNext() {
    if (_priority.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary goal to continue.')),
      );
      return;
    }
    widget.data.priority = _priority;
    // Suggest a system type from the goal (Step 3 lets the agent change it).
    widget.data.systemType =
        (_priority == 'backup' || _priority == 'offgrid') ? 'hybrid' : 'gridtied';
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 2,
      totalSteps: 8,
      title: 'Solar Goals',
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
              'Primary Goal',
              style: TextStyle(
                color: Color(0xFF1B2B6B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "What is the client's main reason for going solar?",
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 20),
            ChoiceGroup(
              value: _priority,
              options: _options,
              onChanged: (v) => setState(() => _priority = v),
            ),
          ],
        ),
      ),
    );
  }
}