import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openBriefAiLocalDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final separator =
      directory.path.endsWith('/') || directory.path.endsWith(r'\') ? '' : '/';
  return databaseFactoryIo.openDatabase(
    '${directory.path}${separator}briefai-local-vault.db',
  );
}
