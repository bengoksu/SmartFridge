import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'screens/login_page.dart';

void main() {
  runApp(const SmartFridgeApp());
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SmartFridge',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const LoginPage(),
    );
  }
}
