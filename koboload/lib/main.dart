import 'package:flutter/material.dart';
import 'ui/home_page.dart';

void main() {
  runApp(const KoboloadApp());
}

class KoboloadApp extends StatelessWidget {
  const KoboloadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KoboLoad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(), // <-- Altere apenas esta linha
    );
  }
}