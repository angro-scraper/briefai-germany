import 'package:flutter/material.dart';

import 'app/briefai_app.dart';
import 'core/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StartupApp());
}

class StartupApp extends StatefulWidget {
  const StartupApp({super.key});

  @override
  State<StartupApp> createState() => _StartupAppState();
}

class _StartupAppState extends State<StartupApp> {
  late final Future<AppServices> _services;

  @override
  void initState() {
    super.initState();
    // The first Flutter frame must not depend on an external SDK responding.
    // A timed-out bootstrap falls back to the safe local/debug experience and
    // makes the unavailable production service visible in the UI.
    _services = AppServices.bootstrap().timeout(
      const Duration(seconds: 20),
      onTimeout: () => AppServices.unavailable(
        'Pokretanje cloud usluge je isteklo. Pokušajte ponovo kasnije.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
    future: _services,
    builder: (context, snapshot) {
      if (snapshot.hasData) return BriefAiApp(services: snapshot.data!);
      if (snapshot.hasError) {
        return BriefAiApp(
          services: AppServices.unavailable(
            'Pokretanje usluge nije uspelo. Pokušajte ponovo kasnije.',
          ),
        );
      }
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    },
  );
}
