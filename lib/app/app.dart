import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root application widget for Nuvex.
class NuvexApp extends StatelessWidget {
  const NuvexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvex',
      theme: NuvexTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: NuvexRoutes.initial,
      onGenerateRoute: NuvexRouter.onGenerateRoute,
    );
  }
}
