import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:flutter/material.dart';

class ConsultationFlow extends StatefulWidget {
  const ConsultationFlow({Key? key}) : super(key: key);

  @override
  State<ConsultationFlow> createState() => _ConsultationFlowState();
}

class _ConsultationFlowState extends State<ConsultationFlow> {
  int _currentStep = 1;
  final ConsultationData _data = ConsultationData();

  void _nextStep() {
    setState(() {
      // Skip step 5 if Grid-tied
      if (_currentStep == 4 && _data.systemType == 'Grid-tied') {
        _currentStep = 6;
      } else {
        _currentStep++;
      }
    });
  }

  void _prevStep() {
    setState(() {
      if (_currentStep == 6 && _data.systemType == 'Grid-tied') {
        _currentStep = 4;
      } else {
        _currentStep--;
      }
    });
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
      case 1: return Step1ClientInfo(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 2: return Step2SolarGoals(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 3: return Step3Electricity(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 4: return Step4RoofInfo(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 5: return Step5BackupPower(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 6: return Step6BudgetTimeline(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 7: return Step7SolarCalculator(data: _data, onNext: _nextStep, onBack: _prevStep);
      case 10: return Step10SalesBooking(data: _data, onBack: _prevStep);
      default: return const SizedBox();
    }
  }
}

