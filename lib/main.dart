import 'package:flutter/material.dart';

import 'src/app_environment.dart';
import 'src/app.dart';
import 'src/demo_studio_repository.dart';
import 'src/firebase_bootstrap_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = VitrifyEnvironment.fromBuildConfig();
  if (environment == VitrifyEnvironment.demo) {
    runApp(VitrifyApp(repository: DemoStudioRepository.seeded()));
    return;
  }

  runApp(FirebaseBootstrapApp(environment: environment));
}
