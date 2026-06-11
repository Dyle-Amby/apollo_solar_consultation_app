// lib/services/auth_service.dart
//
// Talks to the apollo-auth n8n webhook for registration and login.
//
// ASSUMED CONTRACT (confirm this matches your workflow, or tell me the real
// shape and I'll adjust the parser):
//
//   POST apollo-auth   (Content-Type: application/json)
//   login:    { "action": "login",    "email": "...", "password": "..." }
//   register: { "action": "register", "name": "...", "email": "...",
//               "password": "...", "role": "sales|hos|eng" }
//
//   success: { "ok": true, "user": { "name": "...", "email": "...",
//                                    "role": "sales" }, "token": "..." }
//   failure: { "ok": false, "error": "Invalid credentials" }
//
// The parser is lenient: it accepts name/email/role/token at either the top
// level or under "user", and normalizes role spellings to sales/hos/eng.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:apollo_solar_consultation_app/services/session.dart';

const String kAuthUrl = 'https://bernard100.app.n8n.cloud/webhook/apollo-auth';

class AuthService {
  static String lastError = '';

  static Future<bool> login(String email, String password) {
    final id = email.trim();
    return _post({'action': 'login', 'email': id, 'username': id, 'password': password});
  }

  static Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String contactNumber = '',
    String address = '',
    String birthdate = '',
  }) {
    final id = email.trim();
    return _post({
      'action': 'register',
      'name': name.trim(),
      'fullName': name.trim(), // alias in case the node reads FullName
      'email': id,
      'username': id,
      'password': password,
      'role': role,
      'contactNumber': contactNumber.trim(),
      'address': address.trim(),
      'birthdate': birthdate, // YYYY-MM-DD
    });
  }

  static Future<bool> _post(Map<String, dynamic> body) async {
    lastError = '';
    try {
      final res = await http
          .post(
            Uri.parse(kAuthUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      dynamic d;
      try {
        d = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      } catch (_) {
        d = null;
      }

      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}: ${_short(res.body)}';
        return false;
      }

      if (d is Map && d['ok'] == true) {
        final u = d['user'] is Map ? Map<String, dynamic>.from(d['user']) : <String, dynamic>{};
        Session.set(
          name: '${u['name'] ?? d['name'] ?? body['name'] ?? ''}',
          email: '${u['email'] ?? d['email'] ?? body['email'] ?? ''}',
          role: _normRole('${u['role'] ?? d['role'] ?? body['role'] ?? ''}'),
          token: '${u['token'] ?? d['token'] ?? ''}',
        );
        return true;
      }

      lastError = (d is Map && d['error'] != null)
          ? '${d['error']}'
          : 'Request failed (unexpected response): ${_short(res.body)}';
      return false;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  // Normalize whatever the backend returns into sales | hos | eng.
  static String _normRole(String r) {
    final t = r.toLowerCase().trim();
    if (t.contains('admin')) return 'admin';
    if (t.contains('head') && t.contains('eng')) return 'hoe';
    if (t.contains('head') && t.contains('sale')) return 'hos';
    if (t == 'hoe') return 'hoe';
    if (t == 'hos') return 'hos';
    if (t.contains('eng')) return 'eng';
    if (t.contains('sale')) return 'sales';
    return t; // pass through anything unexpected
  }

  static String _short(String s) => s.length > 240 ? '${s.substring(0, 240)}…' : s;
}