import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/models/consultation_data.dart';
import 'package:apollo_solar_consultation_app/widgets/step_scaffold.dart';
import 'package:apollo_solar_consultation_app/widgets/location_picker_field.dart';

class Step1ClientInfo extends StatefulWidget {
  final ConsultationData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step1ClientInfo({
    Key? key,
    required this.data,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<Step1ClientInfo> createState() => _Step1ClientInfoState();
}

class _Step1ClientInfoState extends State<Step1ClientInfo> {
  late TextEditingController _nameController;
  late TextEditingController _contactController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  String _propertyType = 'Residential';

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing data if user comes back to this step
    _nameController = TextEditingController(text: widget.data.fullName);
    _contactController = TextEditingController(text: widget.data.contactNumber);
    _emailController = TextEditingController(text: widget.data.email);
    _addressController = TextEditingController(text: widget.data.address);
    _propertyType = widget.data.propertyType.isEmpty ? 'Residential' : widget.data.propertyType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _saveAndNext() {
    // Save to shared data object before moving forward.
    // NOTE: latitude/longitude are written directly by LocationPickerField,
    // so we must NOT overwrite them here.
    widget.data.fullName = _nameController.text;
    widget.data.contactNumber = _contactController.text;
    widget.data.email = _emailController.text;
    widget.data.propertyType = _propertyType;
    widget.data.address = _addressController.text;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return StepScaffold(
      currentStep: 1,
      totalSteps: 8,
      title: 'Client Information',
      onNext: _saveAndNext, // saves data then calls flow's onNext
      onBack: widget.onBack,
      showBack: false, // Step 1 has no previous step
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Card title
          const Text(
            'Client Information',
            style: TextStyle(
              color: Color(0xFF1B2B6B),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the client\'s personal and contact details',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 20),

          // Full Name
          _fieldLabel(Icons.person_outline, 'Full Name'),
          const SizedBox(height: 8),
          _inputField('Carlos Sainz', _nameController),
          const SizedBox(height: 16),

          // Contact Number
          _fieldLabel(Icons.phone_outlined, 'Contact Number'),
          const SizedBox(height: 8),
          _inputField('09XXXXXXXXX', _contactController,
              keyboard: TextInputType.phone),
          const SizedBox(height: 16),

          // Email
          _fieldLabel(Icons.email_outlined, 'Email Address'),
          const SizedBox(height: 8),
          _inputField('client@email.com', _emailController,
              keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),

          // Property Type dropdown
          _fieldLabel(Icons.home_outlined, 'Property Type'),
          const SizedBox(height: 8),
          _dropdownField(
            _propertyType,
            ['Residential', 'Commercial', 'Agricultural', 'Industrial'],
            (val) => setState(() => _propertyType = val!),
          ),
          const SizedBox(height: 16),

          // Full Address
          _fieldLabel(Icons.location_on_outlined, 'Full Address'),
          const SizedBox(height: 8),
          _inputField('Block X Lot X City', _addressController),
          const SizedBox(height: 16),

          // Map pin (writes latitude/longitude/address into data).
          // When a pin is dropped, mirror the geocoded address back into
          // the address field so _saveAndNext persists it.
          LocationPickerField(
            data: widget.data,
            onPicked: () => setState(() {
              _addressController.text = widget.data.address;
            }),
          ),
        ],
      ),
    );
  }

  // ── Reusable helpers ────────────────────────────────────────

  Widget _fieldLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1B2B6B)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B2B6B)),
        ),
      ),
    );
  }

  Widget _dropdownField(
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 14)),
              ))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B2B6B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1B2B6B)),
        ),
      ),
    );
  }
}