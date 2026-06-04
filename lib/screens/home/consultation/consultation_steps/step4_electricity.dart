// lib/screens/home/consultation/consultation_steps/step4_electricity.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';

// Distribution utilities and their indicative blended rates (₱/kWh).
// These mirror the website's DU_RATES so the app and site agree.
// The calculator derives the rate from the selected key — there is no
// editable rate field (matching the website flow).
const Map<String, String> kDuLabels = {
  'meralco': 'Meralco (~₱11.50/kWh)',
  'batelec1': 'BATELEC I (~₱10.80/kWh)',
  'batelec2': 'BATELEC II (~₱10.50/kWh)',
  'lima': 'Lima EnerZone (~₱9.00/kWh)',
  'other': 'Other (~₱10.00/kWh)',
};

class Step4Electricity extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step4Electricity({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step4Electricity> createState() => _Step4ElectricityState();
}

class _Step4ElectricityState extends State<Step4Electricity> {
  late TextEditingController _bill1;
  late TextEditingController _bill2;
  late TextEditingController _bill3;
  String? _du;

  @override
  void initState() {
    super.initState();
    _bill1 = TextEditingController(text: widget.data.bill1 > 0 ? '${widget.data.bill1}' : '');
    _bill2 = TextEditingController(text: widget.data.bill2 > 0 ? '${widget.data.bill2}' : '');
    _bill3 = TextEditingController(text: widget.data.bill3 > 0 ? '${widget.data.bill3}' : '');
    _du = widget.data.distributionUtility.isEmpty ? null : widget.data.distributionUtility;
  }

  @override
  void dispose() {
    _bill1.dispose();
    _bill2.dispose();
    _bill3.dispose();
    super.dispose();
  }

  double get _avg {
    final bills = [_bill1.text, _bill2.text, _bill3.text]
        .map((t) => double.tryParse(t) ?? 0)
        .where((v) => v > 0)
        .toList();
    if (bills.isEmpty) return 0;
    return bills.reduce((a, b) => a + b) / bills.length;
  }

  void _saveAndNext() {
    final b1 = double.tryParse(_bill1.text) ?? 0;
    if (b1 <= 0) {
      _toast('Please enter at least the Month 1 bill amount.');
      return;
    }
    if (_du == null) {
      _toast('Please select the distribution utility.');
      return;
    }
    widget.data.bill1 = b1;
    widget.data.bill2 = double.tryParse(_bill2.text) ?? 0;
    widget.data.bill3 = double.tryParse(_bill3.text) ?? 0;
    widget.data.distributionUtility = _du!;
    widget.onNext();
  }

  void _toast(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 4,
      totalSteps: 8,
      title: 'Electricity Details',
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
              'Electricity Details',
              style: TextStyle(
                color: Color(0xFF1B2B6B),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Enter the last 3 monthly bill amounts. The average is used to size the system.",
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 20),

            _billField('Month 1 Bill Amount *', _bill1),
            const SizedBox(height: 12),
            _billField('Month 2 Bill Amount', _bill2),
            const SizedBox(height: 12),
            _billField('Month 3 Bill Amount', _bill3),

            if (_avg > 0) ...[
              const SizedBox(height: 16),
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
                    const Text('AVERAGE MONTHLY BILL',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB8730A))),
                    const SizedBox(height: 4),
                    Text(
                      '₱${_avg.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B2B6B)),
                    ),
                    const SizedBox(height: 2),
                    const Text('Basis for system sizing',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            _label(Icons.business_outlined, 'Distribution Utility'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _du,
              isExpanded: true,
              hint: const Text('— Select provider —', style: TextStyle(fontSize: 14)),
              items: kDuLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _du = v),
              decoration: _fieldDecoration(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _billField(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}), // live average
          decoration: _fieldDecoration().copyWith(
            prefixText: '₱ ',
            prefixStyle: const TextStyle(
                color: Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.w600),
            hintText: 'e.g. 8500.00',
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _label(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B2B6B)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        ],
      );

  InputDecoration _fieldDecoration() => InputDecoration(
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
      );
}