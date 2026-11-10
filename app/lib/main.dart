import 'package:flutter/material.dart';

import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'state.dart';
import 'tutor.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.load();
  await contentStore.load();
  appSpeaker = TtsSpeaker();
  contentStore.refresh(); // look for new lessons in the background
  runApp(const ScolApp());
}

class ScolApp extends StatelessWidget {
  const ScolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scol',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: indigo),
        scaffoldBackgroundColor: cream,
      ),
      home: ListenableBuilder(
        listenable: Listenable.merge([appState, contentStore]),
        builder: (_, __) => appState.onboarded ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
