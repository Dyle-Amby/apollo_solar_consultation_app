import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/auth_service.dart';
import 'package:apollo_solar_consultation_app/screens/home/dashboard.dart';

const _navy = Color(0xFF1A2A6C);
const _navySoft = Color(0xFF243580);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF8A90A6);
const _fieldFill = Color(0xFFF4F6FB);

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
  // field. AuthService normalizes them to internal keys for Session + gating.
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
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
      backgroundColor: _navy,
      body: SafeArea(
        child: Column(
          children: [
            _hero(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('ACCOUNT'),
                      const SizedBox(height: 12),
                      _input(_name, 'Full name', Icons.person_outline),
                      const SizedBox(height: 14),
                      _input(_email, 'Email', Icons.email_outlined,
                          keyboard: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _input(_password, 'Password', Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                                color: _grey, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                      const SizedBox(height: 24),
                      _sectionLabel('PERSONAL DETAILS'),
                      const SizedBox(height: 12),
                      _input(_contact, 'Contact number', Icons.phone_outlined,
                          keyboard: TextInputType.phone),
                      const SizedBox(height: 14),
                      _input(_address, 'Address', Icons.location_on_outlined),
                      const SizedBox(height: 14),
                      _dateField(),
                      const SizedBox(height: 24),
                      _sectionLabel('ROLE'),
                      const SizedBox(height: 12),
                      _roleDropdown(),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text('Role may be reviewed/approved by an admin.',
                            style: TextStyle(color: _grey, fontSize: 11.5)),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _errorBox(),
                      ],
                      const SizedBox(height: 24),
                      _registerButton(),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton(
                          onPressed: _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Already have an account?  ',
                              style: TextStyle(color: _grey, fontSize: 13.5),
                              children: [
                                TextSpan(
                                  text: 'Sign in',
                                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero header ──
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _gold,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: const Text('A',
                style: TextStyle(color: _navy, fontSize: 28, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 14),
          const Text('Create Account',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          const Text('Apollo Solar Ventures — Consultation System',
              style: TextStyle(color: Color(0xFFB9C0E0), fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t,
        style: const TextStyle(
            color: _navy, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1),
      );

  // ── Inputs ──
  Widget _input(TextEditingController c, String label, IconData icon,
      {bool obscure = false, TextInputType keyboard = TextInputType.text, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 15),
      decoration: _decoration(label, icon, suffix: suffix),
    );
  }

  Widget _dateField() {
    final has = _birthdate != null;
    return InkWell(
      onTap: _pickBirthdate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _decoration('Birthdate', Icons.cake_outlined),
        child: Text(
          has ? _fmtBirthdate() : 'Select date',
          style: TextStyle(fontSize: 15, color: has ? const Color(0xFF1A1A1A) : const Color(0xFFB0B5C8)),
        ),
      ),
    );
  }

  Widget _roleDropdown() {
    return DropdownButtonFormField<String>(
      value: _role,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _navy),
      decoration: _decoration('Role', Icons.badge_outlined),
      borderRadius: BorderRadius.circular(12),
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A1A)),
      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
      onChanged: (v) => setState(() => _role = v ?? 'Sales'),
    );
  }

  InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _grey, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: _navy, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: _navy, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE6E9F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 1.6),
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEDED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3C6C6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC0392B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error,
                style: const TextStyle(color: Color(0xFFC0392B), fontSize: 12.8, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _registerButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _busy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: _gold.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _busy
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}