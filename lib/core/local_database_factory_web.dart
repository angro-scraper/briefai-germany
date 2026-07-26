import 'package:sembast_web/sembast_web.dart';

Future<Database> openBriefAiLocalDatabase() =>
    databaseFactoryWeb.openDatabase('briefai-local-vault.db');
