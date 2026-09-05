import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme/app_theme.dart';

class AlkoQuestApp extends StatelessWidget {
  const AlkoQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Алко-Квест',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.mainMenu,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
