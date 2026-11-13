import 'package:flutter/material.dart';

import 'reminders.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/splash.dart';
import 'state.dart';
import 'voice.dart';
import 'widgets/ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.load();
  await contentStore.load();
  await initReminders();
  final voice = VoiceSpeaker();
  appSpeaker = voice;
  voice.init(); // finds which voice files are ready
  contentStore.refresh(); // looks for new lessons in the background
  runApp(const ScolApp());
}

class ScolApp extends StatefulWidget {
  const ScolApp({super.key});

  @override
  State<ScolApp> createState() => _ScolAppState();
}

class _ScolAppState extends State<ScolApp> with WidgetsBindingObserver {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-plan reminders whenever the app goes to the background, so they match today's progress.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) planReminders(appState, contentStore.bundle);
  }

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
      home: !_splashDone
          ? SplashScreen(onDone: () => setState(() => _splashDone = true))
          : ListenableBuilder(
              listenable: Listenable.merge([appState, contentStore]),
              builder: (_, __) => appState.onboarded ? const HomeScreen() : const OnboardingScreen(),
            ),
    );
  }
}
