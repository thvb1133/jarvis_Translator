import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment()..debugLogStatus();
  runApp(JarvisApp(config: config));
}
