// lib/screens/home/consultation/consultation_steps/step5_roof_info.dart

import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';

const Map<String, String> kRoofTypes = {
  'metal': 'Metal / Corrugated GI',
  'concrete': 'Concrete / Flat Slab',
  'tile': 'Tile / Clay',
  'ground': 'Ground Mount',
};

// Only the website's three options are exposed. The calculator's direction
// factor map also supports east/west/north/etc. — add entries here if you
// ever want finer orientation choices.
const Map<String, String> kRoofDirections = {
  'unknown': "I'm not sure",
  'south': 'South (ideal)',
  'flat': 'Flat',
};

class Step5RoofInfo extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step5RoofInfo({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step5RoofInfo> createState() => _Step5RoofInfoState();
}

class _Step5RoofInfoState extends State<Step5RoofInfo> {
  late String _roofType;
  late String _direction;
  late TextEditingController _length;
  late TextEditingController _width;
  late TextEditingController _obstructions;

  @override
  void initState() {
    super.initState();
    _roofType = widget.data.roofType.isEmpty ? 'metal' : widget.data.roofType;
    _direction = widget.data.roofDirection.isEmpty ? 'unknown' : widget.data.roofDirection;
    _length = TextEditingController(text: widget.data.roofLength > 0 ? '${widget.data.roofLength}' : '');
    _width = TextEditingController(text: widget.data.roofWidth > 0 ? '${widget.data.roofWidth}' : '');
    _obstructions = TextEditingController(text: widget.data.obstructions);
  }

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    _obstructions.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    widget.data.roofType = _roofType;
    widget.data.roofDirection = _direction;
    widget.data.roofLength = double.tryParse(_length.text) ?? 0;
    widget.data.roofWidth = double.tryParse(_width.text) ?? 0;
    widget.data.obstructions = _obstructions.text;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 5,
      totalSteps: 8,
      title: 'Roof Information',
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
              'Roof Information',
              style: TextStyle(
                  color: Color(0xFF1B2B6B), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe the roof for panel installation. Approximate values are fine.',
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            ),
            const SizedBox(height: 20),

            _label(Icons.home_outlined, 'Construction & Material'),
            const SizedBox(height: 8),
            _dropdown(_roofType, kRoofTypes, (v) => setState(() => _roofType = v!)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _numField('Length (m)', _length)),
                const SizedBox(width: 12),
                Expanded(child: _numField('Width (m)', _width)),
              ],
            ),
            const SizedBox(height: 16),

            _label(Icons.explore_outlined, 'Roof Direction'),
            const SizedBox(height: 8),
            _dropdown(_direction, kRoofDirections, (v) => setState(() => _direction = v!)),
            const SizedBox(height: 16),

            _label(Icons.park_outlined, 'Obstructions Present'),
            const SizedBox(height: 8),
            TextField(
              controller: _obstructions,
              maxLines: 3,
              decoration: _dec().copyWith(
                hintText: 'e.g. trees, taller buildings, chimneys',
                hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField(String label, TextEditingController c) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec().copyWith(hintText: '0'),
          ),
        ],
      );

  Widget _dropdown(String value, Map<String, String> opts, ValueChanged<String?> onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        items: opts.entries
            .map((e) => DropdownMenuItem(
                value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 14))))
            .toList(),
        onChanged: onChanged,
        decoration: _dec(),
      );

  Widget _label(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1B2B6B)),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        ],
      );

  InputDecoration _dec() => InputDecoration(
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