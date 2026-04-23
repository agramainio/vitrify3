import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/demo_studio_repository.dart';

void main() {
  runApp(VitrifyApp(repository: DemoStudioRepository.seeded()));
}
