import 'package:flutter/material.dart';
import 'services/session.dart';
import 'screens/auth/login.dart';
import 'screens/home/dashboard.dart';

void main() {
  runApp(const ApolloApp());
}

class ApolloApp extends StatelessWidget {
  const ApolloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Apollo',
      // On a cold start the in-memory session is empty, so this shows Login.
      // login_screen pushReplacement's to the dashboard after a successful
      // sign-in. (Add shared_preferences later if you want to stay logged in
      // across restarts — then this gate restores the dashboard directly.)
      home: Session.isLoggedIn ? const DashboardPage() : const LoginScreen(),
    );
  }
}