import 'package:flutter/material.dart';

import 'bench_screen.dart';
import 'design_system.dart';
import 'studio_repository.dart';

class VitrifyApp extends StatelessWidget {
  const VitrifyApp({required this.repository, super.key});

  final StudioRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitrify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) {
                return SelectionArea(child: child ?? const SizedBox.shrink());
              },
            ),
          ],
        );
      },
      home: BenchScreen(repository: repository),
    );
  }
}
