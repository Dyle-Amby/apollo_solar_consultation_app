// lib/screens/home/consultation/consultation_steps/step7_timeline.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/widgets/choice_card.dart';

class Step7Timeline extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step7Timeline({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step7Timeline> createState() => _Step7TimelineState();
}

class _Step7TimelineState extends State<Step7Timeline> {
  late String _timeline;

  static const _options = [
    ChoiceOption(value: 'asap', icon: Icons.local_fire_department_outlined, title: 'As soon as possible'),
    ChoiceOption(value: '1-3mo', icon: Icons.calendar_today_outlined, title: 'Within 1–3 months'),
    ChoiceOption(value: '3-6mo', icon: Icons.hourglass_empty_outlined, title: 'Within 3–6 months'),
    ChoiceOption(value: 'justlooking', icon: Icons.visibility_outlined, title: 'Just exploring / Researching'),
  ];

  @override
  void initState() {
    super.initState();
    _timeline = widget.data.timeline;
  }

  void _saveAndNext() {
    if (_timeline.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a timeline to continue.')),
      );
      return;
    }
    widget.data.timeline = _timeline;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 7,
      totalSteps: 8,
      title: 'Timeline',
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
            const Text('Timeline',
                style: TextStyle(
                    color: Color(0xFF1B2B6B), fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('When is the client hoping to go solar?',
                style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
            const SizedBox(height: 20),
            ChoiceGroup(
              value: _timeline,
              options: _options,
              onChanged: (v) => setState(() => _timeline = v),
            ),
          ],
        ),
      ),
    );
  }
}