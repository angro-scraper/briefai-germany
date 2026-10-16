import 'package:sembast_web/sembast_web.dart';

Future<Database> openBriefAiLocalDatabase([
  String databaseName = 'briefai-local-vault.db',
]) => databaseFactoryWeb.openDatabase(databaseName);
