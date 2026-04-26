import 'package:flutter/material.dart';

import 'src/app_environment.dart';
import 'src/app.dart';
import 'src/demo_studio_repository.dart';
import 'src/firebase_atelier_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = VitrifyEnvironment.fromBuildConfig();
  if (environment == VitrifyEnvironment.demo) {
    runApp(VitrifyApp(repository: DemoStudioRepository.seeded()));
    return;
  }

  final session = await FirebaseAtelierBootstrap.start(environment);
  runApp(
    VitrifyApp(
      repository: session.repository,
      initialUser: session.currentUser,
      persistUser: false,
    ),
  );
}
