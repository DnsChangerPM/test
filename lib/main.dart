import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';
import 'timer_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Animate.restartOnHotReload = true;
  runApp(const AdvancedTimerApp());
}

class AdvancedTimerApp extends StatefulWidget {
  const AdvancedTimerApp({super.key});

  @override
  State<AdvancedTimerApp> createState() => _AdvancedTimerAppState();
}

class _AdvancedTimerAppState extends State<AdvancedTimerApp> {
  AppTheme _currentTheme = appThemes[0];

  void _setTheme(AppTheme theme) {
    setState(() => _currentTheme = theme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Timer Pro',
      debugShowCheckedModeBanner: false,
      theme: _currentTheme.themeData,
      home: TimerPage(
        currentTheme: _currentTheme,
        onThemeChanged: _setTheme,
      ),
    );
  }
}
