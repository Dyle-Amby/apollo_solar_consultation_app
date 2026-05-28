import 'package:flutter/material.dart';
import 'screens/auth/login.dart' as login;
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
      home: const login.LoginScreen(),
    );
  }
}