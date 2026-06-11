import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/auth_service.dart';
import 'package:apollo_solar_consultation_app/screens/home/dashboard.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const RegisterScreen({Key? key, this.onSuccess}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  DateTime? _birthdate;
  String _role = 'Sales';
  bool _busy = false;
  bool _obscure = true;
  String _error = '';

  // EXACT Airtable Role single-select options — sent as-is so they match the
  // field. AuthService normalizes them to internal keys (sales/eng/hos/hoe/
  // admin) for Session + gating.
  static const _roles = [
    'Sales',
    'Engineering',
    'Head of Sales',
    'Head of Engineering',
    'Admin',
  ];

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _contact.dispose();
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  String _fmtBirthdate() {
    final d = _birthdate;
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (d != null) setState(() => _birthdate = d);
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _contact.text.trim().isEmpty ||
        _address.text.trim().isEmpty ||
        _birthdate == null) {
      setState(() => _error = 'Please complete all fields.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final ok = await AuthService.register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
      role: _role,
      contactNumber: _contact.text,
      address: _address.text,
      birthdate: _fmtBirthdate(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      }
    } else {
      setState(() => _error = AuthService.lastError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _field(_name, 'Full name', Icons.person_outline),
                const SizedBox(height: 14),
                _field(_email, 'Email', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(_contact, 'Contact number', Icons.phone_outlined, keyboard: TextInputType.phone),
                const SizedBox(height: 14),
                _field(_address, 'Address', Icons.location_on_outlined),
                const SizedBox(height: 14),
                _dateField(),
                const SizedBox(height: 14),
                _field(_password, 'Password', Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _grey),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.badge_outlined, color: _grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _roles
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? 'Sales'),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Role may be reviewed/approved by an admin.',
                      style: TextStyle(color: _grey, fontSize: 11.5)),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error, style: const TextStyle(color: Color(0xFFC0392B), fontSize: 12.5)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField() {
    final text = _birthdate == null ? '' : _fmtBirthdate();
    return InkWell(
      onTap: _pickBirthdate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Birthdate',
          prefixIcon: const Icon(Icons.cake_outlined, color: _grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(
          text.isEmpty ? 'Select date' : text,
          style: TextStyle(
            fontSize: 16,
            color: text.isEmpty ? const Color(0xFFAAAAAA) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType keyboard = TextInputType.text, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _grey),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}