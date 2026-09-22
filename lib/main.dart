import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const initialRoute = String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: NuvexRoutes.initial,
  );
  runApp(const NuvexApp(initialRoute: initialRoute));
}
