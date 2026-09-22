import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

/// Root application widget for Nuvex.
class NuvexApp extends StatelessWidget {
  final String initialRoute;

  const NuvexApp({super.key, this.initialRoute = NuvexRoutes.initial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuvex',
      theme: NuvexTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      onGenerateRoute: NuvexRouter.onGenerateRoute,
    );
  }
}
