import 'package:flutter/material.dart';
import 'app_theme.dart';
import '../features/load_planner/presentation/pages/load_planner_page.dart';

class PalettenFuchsApp extends StatelessWidget {
  const PalettenFuchsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paletten Fuchs',
      theme: AppTheme.lightTheme,
      home: const LoadPlannerPage(),
    );
  }
}
