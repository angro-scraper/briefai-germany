import 'package:flutter/widgets.dart';

import 'app/briefai_app.dart';
import 'core/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.bootstrap();
  runApp(BriefAiApp(services: services));
}
