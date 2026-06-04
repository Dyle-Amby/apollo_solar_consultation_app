// lib/screens/home/consultation/consultation_flow.dart
//
// Controller for the consultation. Owns the current step and the single
// shared ConsultationData object. Steps 1–7 are built; Step 8 (Results)
// is still a placeholder and will be dropped in next — at which point this
// file gets one more update to add the edit-return navigation it needs.


import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step1_client_info.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step2_priority.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step3_system_type.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step4_electricity.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step5_roof_info.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step6_battery.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step7_timeline.dart';
// import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step8_results.dart';

class ConsultationFlow extends StatefulWidget {
  const ConsultationFlow({Key? key}) : super(key: key);

  @override
  State<ConsultationFlow> createState() => _ConsultationFlowState();
}

class _ConsultationFlowState extends State<ConsultationFlow> {
  static const int totalSteps = 8;

  int _currentStep = 1;
  final ConsultationData _data = ConsultationData();

  // Note: no Grid-tied skip here. The battery step (6) stays visible and
  // shows a "Hybrid only" notice for Grid-tied, keeping the progress bar
  // smooth — so the controller just moves one step at a time.
  void _nextStep() {
    setState(() {
      if (_currentStep < totalSteps) _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).maybePop(); // leave the flow from Step 1
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: _buildStep(),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 1:
        return Step1ClientInfo(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 2:
        return Step2Priority(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 3:
        return Step3SystemType(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 4:
        return Step4Electricity(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 5:
        return Step5RoofInfo(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 6:
        return Step6Battery(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 7:
        return Step7Timeline(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 8:
        // return Step8Results(data: _data, onBack: _prevStep, onEditStep: ...);
        return _placeholder('Your Recommendation', 8, isLast: true);
      default:
        return const SizedBox();
    }
  }

  // Temporary placeholder for Step 8 until the Results page is built.
  Widget _placeholder(String title, int step, {bool isLast = false}) {
    return StepScaffold(
      currentStep: step,
      totalSteps: totalSteps,
      title: title,
      isLastStep: isLast,
      onNext: _nextStep,
      onBack: _prevStep,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.construction_outlined, size: 40, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 12),
            Text('$title — coming next',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}