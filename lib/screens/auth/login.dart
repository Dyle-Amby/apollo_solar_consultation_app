import 'package:flutter/material.dart';
import 'package:apollo_solar_consultation_app/services/auth_service.dart';
import 'package:apollo_solar_consultation_app/screens/auth/registration.dart';
// ⚠️ If your forgot-password file/class is named differently, fix THIS line and
// the class name in _goForgot() below to match (e.g. ForgotPassScreen).
import 'package:apollo_solar_consultation_app/screens/auth/forgot_pass.dart';
import 'package:apollo_solar_consultation_app/screens/home/dashboard.dart';

const _navy = Color(0xFF1A2A6C);
const _gold = Color(0xFFC8A200);
const _grey = Color(0xFF888888);

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const LoginScreen({super.key, this.onSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String _error = '';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final ok = await AuthService.login(_email.text, _password.text);
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

  void _goRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(onSuccess: widget.onSuccess)),
    );
  }

  void _goForgot() {
    Navigator.of(context).push(
      // ⚠️ Match this class name to whatever forgot_pass.dart actually exports.
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: const Text('A',
                      style: TextStyle(color: _navy, fontSize: 30, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 16),
                const Text('Apollo Solar Ventures',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('Consultation System', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _field(_email, 'Email', Icons.email_outlined,
                          keyboard: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _field(_password, 'Password', Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: _grey),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(0, 34),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: _busy ? null : _goForgot,
                          child: const Text('Forgot password?',
                              style: TextStyle(color: _navy, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
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
                            backgroundColor: _navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : const Text('Sign In',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _busy ? null : _goRegister,
                  child: const Text('No account? Register', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
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