// lib/screens/home/consultation/consultation_flow.dart
//
// Controller for the consultation. Owns the current step and the single
// shared ConsultationData object. All 8 steps are wired.
//
// Edit-return: from the Results page (Step 8) the agent can tap a summary
// row to jump back to a specific step; saving (Next) or cancelling (Back)
// on that step returns straight to Results instead of stepping linearly.
//
// Pricing warm-up: ensurePricing() is kicked off in initState so the (slow)
// Google-Sheets fetch runs in the background during data entry and is ready
// by the time the agent reaches Results.

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/utils/solar_calculator.dart' as calc;
import 'package:apollo_solar_consultation_app/screens/home/consultation/finalize_screen.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step1_client_info.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step2_priority.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step3_system_type.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step4_electricity.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step5_roof_info.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step6_battery.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step7_timeline.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_steps/step8_result_screen.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_history.dart';
import 'package:apollo_solar_consultation_app/screens/home/consultation/consultation_ticket.dart';

class ConsultationFlow extends StatefulWidget {
  const ConsultationFlow({Key? key}) : super(key: key);

  @override
  State<ConsultationFlow> createState() => _ConsultationFlowState();
}

class _ConsultationFlowState extends State<ConsultationFlow> {
  static const int totalSteps = 8;

  int _currentStep = 1;
  int? _editReturn; // when set, Next/Back from the current step returns here
  final ConsultationData _data = ConsultationData();

  @override
  void initState() {
    super.initState();
    // Warm the pricing fetch while the agent fills out the steps, so the
    // Results screen is instant and shows "Live".
    calc.ensurePricing();
  }

  // Jump to a step from Results, remembering to come back.
  void _editStep(int step) {
    setState(() {
      _editReturn = totalSteps;
      _currentStep = step;
    });
  }

  void _nextStep() {
    setState(() {
      if (_editReturn != null) {
        _currentStep = _editReturn!;
        _editReturn = null;
      } else if (_currentStep < totalSteps) {
        _currentStep++;
      }
    });
  }

  void _prevStep() {
    if (_editReturn != null) {
      setState(() {
        _currentStep = _editReturn!; // cancel edit → back to Results
        _editReturn = null;
      });
    } else if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).maybePop(); // leave the flow from Step 1
    }
  }

  void _confirmConsultation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FinalizeScreen(data: _data)),
    );
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
        return Step8Results(
          data: _data,
          onBack: _prevStep,
          onEditStep: _editStep,
          onConfirm: _confirmConsultation,
        );
      default:
        return const SizedBox();
    }
  }
}