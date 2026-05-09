import 'package:flutter/material.dart';
import 'package:palettenfuchs/features/home/presentation/pages/start_page.dart';
import 'package:palettenfuchs/localization/app_language.dart';
import 'app_theme.dart';
import '../features/load_planner/presentation/pages/load_planner_page.dart';

class PalettenFuchsApp extends StatelessWidget {
  const PalettenFuchsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paletten Fuchs',
      theme: AppTheme.lightTheme,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  AppLanguage _language = AppLanguage.de;
  bool _showStartPage = true;

  void _onLanguageChanged(AppLanguage lang) =>
      setState(() => _language = lang);

  @override
  Widget build(BuildContext context) {
    if (_showStartPage) {
      return StartPage(
        language: _language,
        onLanguageChanged: _onLanguageChanged,
        onStart: () => setState(() => _showStartPage = false),
      );
    }
    return LoadPlannerPage(
      language: _language,
      onLanguageChanged: _onLanguageChanged,
    );
  }
}
