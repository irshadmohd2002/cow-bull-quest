import 'package:flutter/material.dart';

import 'app_startup.dart';
import 'core/error_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandlers();
  runApp(AppStartup());
}
