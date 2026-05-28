import 'package:flutter/material.dart';

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
      home: const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Apollo App',
            style: TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}