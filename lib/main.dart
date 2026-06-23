import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';

void main() {
  runApp(const ProviderScope(child: ReefTrackerApp()));
}

class ReefTrackerApp extends StatelessWidget {
  const ReefTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0277BD); // reef blue
    return MaterialApp.router(
      title: 'ReefTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
