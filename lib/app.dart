import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'pipeline/pipeline_controller.dart';
import 'services/provider_registry.dart';
import 'ui/home_screen.dart';
import 'ui/theme/app_theme.dart';

class JarvisApp extends StatelessWidget {
  const JarvisApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    final registry = ProviderRegistry(config);
    return ChangeNotifierProvider(
      create: (_) => PipelineController(config: config, registry: registry),
      child: MaterialApp(
        title: 'JARVIS Translator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
