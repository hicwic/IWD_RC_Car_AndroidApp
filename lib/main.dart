// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/control_screen.dart';
import 'screens/telemetry_screen.dart';
import 'screens/settings_screen.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() {
  runApp(const ProviderScope(child: RCCarApp()));  
}

class RCCarApp extends StatelessWidget {
  const RCCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RC Car App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      navigatorObservers: [routeObserver],
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/control': (context) => const ControlScreen(),
        '/telemetry': (context) => const TelemetryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
