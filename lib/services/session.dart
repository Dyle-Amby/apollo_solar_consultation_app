// lib/services/session.dart
//
// Holds the currently signed-in user for the whole app. In-memory only, so a
// cold app restart requires logging in again; add shared_preferences later if
// you want the session to persist across restarts.

class Session {
  static String name = '';
  static String email = '';
  static String role = ''; // 'sales' | 'hos' | 'eng'
  static String token = '';

  static bool get isLoggedIn => email.isNotEmpty || token.isNotEmpty;

  static void set({
    required String name,
    required String email,
    required String role,
    String token = '',
  }) {
    Session.name = name;
    Session.email = email;
    Session.role = role;
    Session.token = token;
  }

  static void clear() {
    name = '';
    email = '';
    role = '';
    token = '';
  }
}