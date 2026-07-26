import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sembast/sembast.dart' hide FieldValue;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'domain.dart';
import '../firebase_options.dart';
import '../features/analysis/analysis_engine.dart';
import '../features/analysis/image_preprocessor.dart';
import '../features/ocr/local_ocr.dart';
import 'local_database_factory.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppServices {
  AppServices._({
    required this.cloudEnabled,
    required this.configurationError,
    required this.auth,
    required this.documents,
    required this.ai,
    required this.letters,
    required this.entitlements,
    required this.reminders,
    required this.purchases,
    required this.exports,
  });

  final bool cloudEnabled;
  final String? configurationError;
  final AuthService auth;
  final DocumentService documents;
  final AiService ai;
  final LetterRepository letters;
  final EntitlementService entitlements;
  final ReminderService reminders;
  final PurchaseService purchases;
  final ReplyExportService exports;

  static AppServices unavailable(String configurationError) => AppServices._(
    cloudEnabled: false,
    configurationError: configurationError,
    auth: AuthService(cloudEnabled: false),
    documents: DocumentService(cloudEnabled: false),
    ai: AiService(cloudEnabled: false),
    letters: LetterRepository(cloudEnabled: false),
    entitlements: EntitlementService(cloudEnabled: false),
    reminders: ReminderService(cloudEnabled: false),
    purchases: PurchaseService(cloudEnabled: false),
    exports: ReplyExportService(),
  );

  static Future<AppServices> bootstrap() async {
    var cloudEnabled = false;
    String? configurationError;
    try {
      // Legal identity is displayed and audited separately. An incomplete
      // legal draft must never silently disable authentication in an otherwise
      // valid release build.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      cloudEnabled = true;
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(
          '6Ldic2YtAAAAAEbpq8I88FwXyTHNXkd6iO53J1cg',
        ),
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      // Analytics is opt-in. Never start behavioral tracking before the
      // user has explicitly accepted it in the privacy settings.
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      configurationError = kDebugMode
          ? 'Firebase nije podešen; uključen je lokalni razvojni režim.'
          : 'Usluga trenutno nije dostupna. Pokušajte ponovo kasnije.';
    }
    final reminders = ReminderService(cloudEnabled: cloudEnabled);
    // Notification plugin startup must never delay the first Flutter frame.
    // It can be slow on a cold Android emulator or while the OS restores a
    // notification channel; reminders initialize in the background instead.
    unawaited(reminders.initialize().catchError((_) {}));
    return AppServices._(
      cloudEnabled: cloudEnabled,
      configurationError: configurationError,
      auth: AuthService(cloudEnabled: cloudEnabled),
      documents: DocumentService(cloudEnabled: cloudEnabled),
      ai: AiService(cloudEnabled: cloudEnabled),
      letters: LetterRepository(cloudEnabled: cloudEnabled),
      entitlements: EntitlementService(cloudEnabled: cloudEnabled),
      reminders: reminders,
      purchases: PurchaseService(cloudEnabled: cloudEnabled),
      exports: ReplyExportService(),
    );
  }
}

class AuthService {
  AuthService({required this.cloudEnabled});
  final bool cloudEnabled;
  final StreamController<Map<String, dynamic>?> _profileUpdates =
      StreamController<Map<String, dynamic>?>.broadcast();

  Stream<User?> get authChanges => cloudEnabled
      ? FirebaseAuth.instance.authStateChanges()
      : Stream<User?>.value(null);
  bool get isSignedIn =>
      cloudEnabled && FirebaseAuth.instance.currentUser != null;
  String? get uid =>
      cloudEnabled ? FirebaseAuth.instance.currentUser?.uid : null;

  Future<void> signInWithEmail(
    String email,
    String password, {
    bool create = false,
  }) async {
    if (!cloudEnabled) return;
    if (create) {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } else {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
    await _ensureProfile();
  }

  Future<void> signInWithGoogle() async {
    if (!cloudEnabled) return;
    await FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
    await _ensureProfile();
  }

  Future<void> signInWithApple() async {
    if (!cloudEnabled) return;
    await FirebaseAuth.instance.signInWithProvider(AppleAuthProvider());
    await _ensureProfile();
  }

  Future<void> signOut() async {
    if (cloudEnabled) await FirebaseAuth.instance.signOut();
  }

  Future<void> deleteAccount() async {
    if (!cloudEnabled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFunctions.instanceFor(
        region: 'europe-west3',
      ).httpsCallable('deleteAccount').call<void>();
    } on FirebaseFunctionsException catch (error) {
      // Before Functions are activated, Firebase Auth can still honor the
      // user's deletion request. Never use this fallback for authorization or
      // transient failures because server-side subscription data may exist.
      if (error.code != 'not-found' && error.code != 'unimplemented') rethrow;
      await user.delete();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_profileKey(user.uid, 'displayName'));
    await preferences.remove(_profileKey(user.uid, 'countryOfOrigin'));
    await preferences.remove(_profileKey(user.uid, 'preferredLanguage'));
    await FirebaseAuth.instance.signOut();
  }

  /// Requests a server-generated JSON export, downloads it from the caller's
  /// private Storage path, and removes that temporary object immediately.
  Future<String> exportAccountData() async {
    final userId = uid;
    if (!cloudEnabled || userId == null) {
      throw StateError('Prijava je obavezna za izvoz podataka.');
    }
    final result = await FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('exportAccountData').call<Map<Object?, Object?>>();
    final storagePath = result.data['storagePath'];
    final byteLength = result.data['byteLength'];
    if (storagePath is! String ||
        !storagePath.startsWith('users/$userId/exports/') ||
        byteLength is! int ||
        byteLength <= 0 ||
        byteLength > 9 * 1024 * 1024) {
      throw StateError('Server nije vratio važeći izvoz podataka.');
    }
    final ref = FirebaseStorage.instance.ref(storagePath);
    try {
      final bytes = await ref.getData(byteLength + 1024);
      if (bytes == null) throw StateError('Izvoz podataka nije dostupan.');
      return utf8.decode(bytes, allowMalformed: false);
    } finally {
      // A private export is only an implementation bridge to the device share
      // sheet; it must not remain in Storage after it has been retrieved.
      await ref.delete().catchError((_) {});
    }
  }

  Stream<Map<String, dynamic>?> profileChanges() {
    final userId = uid;
    if (!cloudEnabled || userId == null) {
      return Stream<Map<String, dynamic>?>.value(null);
    }
    return _localProfileStream(userId);
  }

  Future<void> updateProfile({
    String? displayName,
    String? countryOfOrigin,
    String? preferredLanguage,
  }) async {
    final userId = uid;
    if (!cloudEnabled || userId == null) {
      throw StateError('Prijava je obavezna za čuvanje profila.');
    }
    final preferences = await SharedPreferences.getInstance();
    if (displayName != null) {
      await preferences.setString(
        _profileKey(userId, 'displayName'),
        displayName,
      );
    }
    if (countryOfOrigin != null) {
      await preferences.setString(
        _profileKey(userId, 'countryOfOrigin'),
        countryOfOrigin,
      );
    }
    if (preferredLanguage != null) {
      await preferences.setString(
        _profileKey(userId, 'preferredLanguage'),
        preferredLanguage,
      );
    }
    _profileUpdates.add(await _localProfile(userId));

    final values = <String, Object?>{'updatedAt': FieldValue.serverTimestamp()};
    if (displayName != null) {
      values['displayName'] = displayName;
    }
    if (countryOfOrigin != null) {
      values['countryOfOrigin'] = countryOfOrigin;
    }
    if (preferredLanguage != null) {
      values['preferredLanguage'] = preferredLanguage;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(values, SetOptions(merge: true));
    } on FirebaseException {
      // The device-local profile is canonical. A temporary Firestore outage or
      // a deliberately closed ruleset must not break login or language choice.
    }
  }

  /// Records a returning authenticated user without changing profile fields.
  /// This keeps the admin panel's 30-day active-user metric accurate even
  /// when the user stays signed in between app launches.
  Future<void> touchActivity() async {
    final userId = uid;
    if (!cloudEnabled || userId == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Activity metrics are best-effort and never block the local app.
    }
  }

  Future<String> preferredLanguage() async {
    final userId = uid;
    if (!cloudEnabled || userId == null) return 'sr';
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_profileKey(userId, 'preferredLanguage')) ??
        'sr';
  }

  Future<Map<String, dynamic>> localAccountData() async {
    final user = cloudEnabled ? FirebaseAuth.instance.currentUser : null;
    if (user == null) return const <String, dynamic>{};
    return <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'profile': await _localProfile(user.uid),
    };
  }

  Future<void> _ensureProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final preferences = await SharedPreferences.getInstance();
    final languageKey = _profileKey(user.uid, 'preferredLanguage');
    if (!preferences.containsKey(languageKey)) {
      await preferences.setString(languageKey, 'sr');
    }
    final displayNameKey = _profileKey(user.uid, 'displayName');
    if (!preferences.containsKey(displayNameKey)) {
      await preferences.setString(displayNameKey, user.displayName ?? '');
    }
    final countryKey = _profileKey(user.uid, 'countryOfOrigin');
    if (!preferences.containsKey(countryKey)) {
      await preferences.setString(countryKey, '');
    }
    _profileUpdates.add(await _localProfile(user.uid));
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'displayName': user.displayName,
        'preferredLanguage': preferences.getString(languageKey) ?? 'sr',
        'countryOfOrigin': preferences.getString(countryKey) ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      // Authentication has succeeded. Profile mirroring is best-effort so a
      // closed Firestore ruleset cannot turn a successful login into an error.
    }
  }

  String _profileKey(String userId, String field) =>
      'briefai.profile.$userId.$field';

  Future<Map<String, dynamic>> _localProfile(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return <String, dynamic>{
      'displayName':
          preferences.getString(_profileKey(userId, 'displayName')) ?? '',
      'countryOfOrigin':
          preferences.getString(_profileKey(userId, 'countryOfOrigin')) ?? '',
      'preferredLanguage':
          preferences.getString(_profileKey(userId, 'preferredLanguage')) ??
          'sr',
    };
  }

  Stream<Map<String, dynamic>?> _localProfileStream(String userId) async* {
    yield await _localProfile(userId);
    yield* _profileUpdates.stream;
  }
}

class PickedDocument {
  const PickedDocument({
    required this.name,
    required this.bytes,
    required this.mimeType,
    required this.ocrPath,
  });
  final String name;
  final Uint8List bytes;
  final String mimeType;
  final String? ocrPath;
  bool get isPdf => mimeType == 'application/pdf';
}

class DocumentService {
  DocumentService({required this.cloudEnabled});
  final bool cloudEnabled;
  final ImagePicker _picker = ImagePicker();

  Future<PickedDocument?> capture() => _fromXFile(
    _picker.pickImage(source: ImageSource.camera, imageQuality: 92),
  );
  Future<PickedDocument?> gallery() => _fromXFile(
    _picker.pickImage(source: ImageSource.gallery, imageQuality: 92),
  );

  Future<PickedDocument?> file() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final selected = result?.files.single;
    if (selected == null || selected.bytes == null) return null;
    final lower = selected.name.toLowerCase();
    final isPdf = lower.endsWith('.pdf');
    final document = PickedDocument(
      name: selected.name,
      bytes: selected.bytes!,
      mimeType: isPdf
          ? 'application/pdf'
          : lower.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg',
      ocrPath: isPdf ? null : selected.path,
    );
    return isPdf ? document : _preprocess(document);
  }

  Future<String> ocr(PickedDocument document) async {
    final text = await recognizeLocalDocument(
      bytes: document.bytes,
      mimeType: document.mimeType,
      path: document.ocrPath,
    );
    if (text.isEmpty) {
      throw StateError(
        'Tekst nije prepoznat. Fotografiju uslikajte ravno i pri dobrom svetlu.',
      );
    }
    return text;
  }

  Future<PickedDocument?> _fromXFile(Future<XFile?> future) async {
    final file = await future;
    if (file == null) return null;
    return _preprocess(
      PickedDocument(
        name: file.name,
        bytes: await file.readAsBytes(),
        mimeType: file.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg',
        ocrPath: file.path,
      ),
    );
  }

  PickedDocument _preprocess(PickedDocument document) {
    final processed = preprocessImageForOcr(
      name: document.name,
      bytes: document.bytes,
    );
    if (processed == null) return document;
    return PickedDocument(
      name: processed.name,
      bytes: processed.bytes,
      mimeType: processed.mimeType,
      ocrPath: document.ocrPath,
    );
  }
}

class AiService {
  AiService({required this.cloudEnabled});
  final bool cloudEnabled;
  final _local = const AnalysisEngine();

  Future<LetterAnalysis> analyse({
    required String letterId,
    required String text,
    required String language,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return _local.analyse(text, language: language, id: letterId);
    }
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('analyzeLetter')
          .call<Map<Object?, Object?>>({
            'letterId': letterId,
            'ocrText': text,
            'preferredLanguage': language,
          });
      final data = Map<String, dynamic>.from(result.data['analysis'] as Map);
      return LetterAnalysis.fromMap(id: letterId, map: data, sourceText: text);
    } on FirebaseFunctionsException catch (error) {
      if (!_backendUnavailable(error)) rethrow;
      return _local.analyse(text, language: language, id: letterId);
    }
  }

  Future<GeneratedReply> generateReply({
    required String letterId,
    required String sourceText,
    required String facts,
    required String language,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return _localReply(facts);
    }
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('generateReply')
          .call<Map<Object?, Object?>>({
            'letterId': letterId,
            'sourceText': sourceText,
            'facts': facts,
            'preferredLanguage': language,
          });
      final reply = result.data['reply'];
      if (reply is! Map) {
        throw StateError('AI odgovor nema očekivani format.');
      }
      final letter = reply['letter'];
      final email = reply['email'];
      if (letter is! String ||
          letter.trim().isEmpty ||
          email is! String ||
          email.trim().isEmpty) {
        throw StateError('AI odgovor nema obe verzije.');
      }
      return GeneratedReply(letter: letter, email: email);
    } on FirebaseFunctionsException catch (error) {
      if (!_backendUnavailable(error)) rethrow;
      return _localReply(facts);
    }
  }

  Future<String> askLetterAssistant({
    required String question,
    required String language,
    LetterAnalysis? letter,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return _localAssistant(language, letter);
    }
    final request = <String, String>{
      'question': question,
      'preferredLanguage': language,
    };
    if (letter != null) {
      request['letterContext'] = jsonEncode({
        ...letter.toMap(),
        'sourceText': letter.sourceText,
      });
    }
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
          .httpsCallable('askLetterAssistant')
          .call<Map<Object?, Object?>>(request);
      final answer = result.data['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw StateError('AI asistent nije vratio odgovor.');
      }
      return answer;
    } on FirebaseFunctionsException catch (error) {
      if (!_backendUnavailable(error)) rethrow;
      return _localAssistant(language, letter);
    }
  }

  bool _backendUnavailable(FirebaseFunctionsException error) => const {
    'not-found',
    'unavailable',
    'internal',
    'deadline-exceeded',
  }.contains(error.code);

  GeneratedReply _localReply(String facts) {
    final detail = facts.trim().isEmpty
        ? ''
        : '\n\nZusätzliche Angaben:\n${facts.trim()}';
    return GeneratedReply(
      letter:
          'Sehr geehrte Damen und Herren,\n\nvielen Dank für Ihr Schreiben. '
          'Hiermit bestätige ich den Erhalt. Ich werde Ihr Anliegen prüfen und '
          'die angeforderten Unterlagen fristgerecht einreichen.$detail'
          '\n\nMit freundlichen Grüßen',
      email:
          'Betreff: Antwort auf Ihr Schreiben\n\nSehr geehrte Damen und Herren,'
          '\n\nvielen Dank für Ihre Nachricht. Ich bestätige den Erhalt und '
          'werde Ihr Anliegen sowie die angeforderten Unterlagen fristgerecht '
          'bearbeiten.$detail\n\nMit freundlichen Grüßen',
    );
  }

  String _localAssistant(String language, LetterAnalysis? letter) {
    final deadline = letter?.deadline?.toIso8601String().split('T').first;
    final amount = letter?.amount;
    final locale = language.toLowerCase().split(RegExp('[-_]')).first;
    final details = <String>[
      if (deadline != null) '📅 $deadline',
      if (amount != null) '💶 $amount',
    ].join(' · ');
    final suffix = details.isEmpty ? '' : '\n\n$details';
    return switch (locale) {
      'hr' =>
        'Prema lokalnoj analizi: ${letter?.plainExplanation ?? 'najprije analizirajte pismo.'} ${letter?.suggestedAction ?? ''}$suffix',
      'bs' =>
        'Prema lokalnoj analizi: ${letter?.plainExplanation ?? 'prvo analizirajte pismo.'} ${letter?.suggestedAction ?? ''}$suffix',
      'mk' =>
        'Според локалната анализа: ${letter?.plainExplanation ?? 'прво анализирајте го писмото.'} ${letter?.suggestedAction ?? ''}$suffix',
      'bg' =>
        'Според локалния анализ: ${letter?.plainExplanation ?? 'първо анализирайте писмото.'} ${letter?.suggestedAction ?? ''}$suffix',
      'de' =>
        'Lokale Analyse: ${letter?.plainExplanation ?? 'Analysieren Sie zuerst das Schreiben.'} ${letter?.suggestedAction ?? ''}$suffix',
      'en' =>
        'Local analysis: ${letter?.plainExplanation ?? 'Analyse the letter first.'} ${letter?.suggestedAction ?? ''}$suffix',
      _ =>
        'Prema lokalnoj analizi: ${letter?.plainExplanation ?? 'prvo analizirajte pismo.'} ${letter?.suggestedAction ?? ''}$suffix',
    };
  }
}

class LetterRepository {
  LetterRepository({required this.cloudEnabled});
  final bool cloudEnabled;
  final StoreRef<String, Map<String, Object?>> _store = stringMapStoreFactory
      .store('letters');
  Database? _database;

  Future<Database> _db() async =>
      _database ??= await openBriefAiLocalDatabase();

  Stream<List<LetterAnalysis>> watch(String uid) {
    return Stream.fromFuture(_db()).asyncExpand(
      (database) => _store
          .query(finder: Finder(sortOrders: [SortOrder('createdAt', false)]))
          .onSnapshots(database)
          .map(
            (records) => records
                .map(
                  (record) => LetterAnalysis.fromMap(
                    id: record.key,
                    map: Map<String, dynamic>.from(record.value),
                  ),
                )
                .toList(),
          ),
    );
  }

  Future<void> save(
    String uid,
    LetterAnalysis letter, {
    PickedDocument? document,
  }) async {
    final database = await _db();
    await _store.record(letter.id).put(database, {
      ...letter.toMap(),
      'createdAt': letter.createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      if (document != null) ...{
        'documentName': document.name,
        'documentMimeType': document.mimeType,
        'documentBytes': Blob(document.bytes),
      },
    });
  }

  Future<void> updateStatus(
    String uid,
    String letterId,
    LetterStatus status,
  ) async {
    final database = await _db();
    await _store.record(letterId).update(database, {
      'status': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> exportRecords() async {
    final database = await _db();
    final records = await _store.find(
      database,
      finder: Finder(sortOrders: [SortOrder('createdAt', false)]),
    );
    return records
        .map((record) {
          final values = <String, dynamic>{'id': record.key};
          for (final entry in record.value.entries) {
            final value = entry.value;
            values[entry.key] = value is Blob
                ? base64Encode(value.bytes)
                : value;
          }
          return values;
        })
        .toList(growable: false);
  }

  Future<void> clearAll() async {
    final database = await _db();
    await _store.delete(database);
  }

  Future<void> delete(String letterId) async {
    final database = await _db();
    await _store.record(letterId).delete(database);
  }

  Future<PickedDocument?> loadDocument(String letterId) async {
    final database = await _db();
    final values = await _store.record(letterId).get(database);
    final bytes = values?['documentBytes'];
    final name = values?['documentName'];
    final mimeType = values?['documentMimeType'];
    if (bytes is! Blob || name is! String || mimeType is! String) return null;
    return PickedDocument(
      name: name,
      bytes: Uint8List.fromList(bytes.bytes),
      mimeType: mimeType,
      ocrPath: null,
    );
  }
}

class EntitlementService {
  EntitlementService({required this.cloudEnabled});
  final bool cloudEnabled;

  Stream<bool> watch(String uid) {
    if (!cloudEnabled) return Stream<bool>.value(false);
    return _watch(uid);
  }

  Stream<int> watchFreeUsage(String uid) {
    return _watchUsage(uid);
  }

  Future<void> recordAnalysis(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _localUsageKey(uid);
    final current = preferences.getInt(key) ?? 0;
    await preferences.setInt(key, (current + 1).clamp(0, 2));
  }

  Stream<bool> _watch(String uid) async* {
    yield false;
    try {
      await for (final document
          in FirebaseFirestore.instance
              .collection('subscriptions')
              .doc(uid)
              .snapshots()) {
        yield ['active', 'trialing'].contains(document.data()?['status']);
      }
    } on FirebaseException {
      // A closed or temporarily unavailable Firestore must not crash AppShell.
    }
  }

  Stream<int> _watchUsage(String uid) async* {
    final preferences = await SharedPreferences.getInstance();
    yield preferences.getInt(_localUsageKey(uid)) ?? 0;
    if (!cloudEnabled || uid == 'local-device') return;
    try {
      await for (final document
          in FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('usage')
              .doc('current')
              .snapshots()) {
        final data = document.data();
        if (data?['monthKey'] != _berlinMonthKey()) {
          yield 0;
          continue;
        }
        final usage = data?['analysesThisMonth'];
        yield usage is int ? usage.clamp(0, 2).toInt() : 0;
      }
    } on FirebaseException {
      // The local free tier remains available while metrics are unavailable.
    }
  }

  String _berlinMonthKey() {
    final now = tz.TZDateTime.now(tz.getLocation('Europe/Berlin'));
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  String _localUsageKey(String uid) =>
      'briefai.usage.$uid.${_berlinMonthKey()}';
}

class ReminderService {
  ReminderService({required this.cloudEnabled});
  final bool cloudEnabled;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  String? _pendingToken;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    if (!cloudEnabled) return;
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      _pendingToken = token;
      await _saveToken(token);
    }
  }

  /// Saves the device token after authentication becomes available. App startup
  /// normally obtains an FCM token before an anonymous user reaches the sign-in
  /// screen, so this second synchronization is required for server reminders.
  Future<void> syncToken() async {
    if (!cloudEnabled) return;
    final token = _pendingToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    _pendingToken = token;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    _pendingToken = token;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('deviceTokens')
          .doc(token)
          .set({
            'uid': uid,
            'token': token,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } on FirebaseException {
      // Local deadline notifications remain functional without cloud tokens.
    }
  }

  Future<void> schedule(LetterAnalysis letter) async {
    if (letter.deadline == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'deadlines',
        'Rokovi',
        channelDescription: 'Podsetnici za rokove',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final days in [7, 3, 1]) {
      final deadline = letter.deadline!;
      final target = DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        9,
      ).subtract(Duration(days: days));
      if (target.isBefore(DateTime.now())) continue;
      await _local.zonedSchedule(
        id: '${letter.id}-$days'.hashCode,
        // Do not expose letter content through a lock-screen notification.
        title: 'BriefAI Germany',
        body: 'Rok je za $days ${days == 1 ? 'dan' : 'dana'}.',
        scheduledDate: tz.TZDateTime.from(target, tz.local),
        notificationDetails: details,
        // A day-level deadline reminder does not need Android's privileged
        // exact-alarm permission. Using an inexact alarm keeps analysis
        // functional on Android 12+ even when the user denies that permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> cancelAll() => _local.cancelAll();

  Future<void> cancel(String letterId) async {
    for (final days in [7, 3, 1]) {
      await _local.cancel(id: '$letterId-$days'.hashCode);
    }
  }
}

class PurchaseService {
  PurchaseService({required this.cloudEnabled});
  final bool cloudEnabled;
  static const premiumId = 'briefai_premium_monthly';
  static const proId = 'briefai_pro_monthly';

  Future<ProductDetailsResponse> products() async {
    if (!await InAppPurchase.instance.isAvailable()) {
      throw StateError('Store plaćanja nije dostupan na ovom uređaju.');
    }
    return InAppPurchase.instance.queryProductDetails({premiumId, proId});
  }

  Stream<List<PurchaseDetails>> get updates =>
      InAppPurchase.instance.purchaseStream;
  Future<void> buy(ProductDetails product) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (!cloudEnabled || userId == null) {
      throw StateError('Prijavite se pre kupovine pretplate.');
    }
    return InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: userId,
      ),
    );
  }

  Future<bool> verifyPurchase(PurchaseDetails purchase) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (!cloudEnabled || userId == null) return false;
    final provider = purchase.verificationData.source;
    if (provider != 'google_play' && provider != 'app_store') return false;
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('verifyStorePurchase')
        .call<Map<Object?, Object?>>({
          'provider': provider,
          'productId': purchase.productID,
          'purchaseId': purchase.purchaseID,
          'verificationData': purchase.verificationData.serverVerificationData,
        });
    return result.data['isActive'] == true;
  }

  Future<void> restore() => InAppPurchase.instance.restorePurchases();
  Future<void> complete(PurchaseDetails purchase) =>
      InAppPurchase.instance.completePurchase(purchase);

  Future<void> startStripeCheckout({
    required String plan,
    required Uri successUrl,
    required Uri cancelUrl,
  }) async {
    if (!cloudEnabled) {
      throw StateError('Web naplata zahteva povezani Firebase projekat.');
    }
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('createStripeCheckout')
        .call<Map<Object?, Object?>>({
          'plan': plan,
          'successUrl': successUrl.toString(),
          'cancelUrl': cancelUrl.toString(),
        });
    final checkoutUrl = result.data['url'];
    if (checkoutUrl is! String ||
        !await launchUrl(
          Uri.parse(checkoutUrl),
          mode: LaunchMode.externalApplication,
        )) {
      throw StateError('Stripe Checkout nije moguće otvoriti.');
    }
  }
}

class ReplyExportService {
  Future<void> copy(String reply) =>
      Clipboard.setData(ClipboardData(text: reply));

  Future<void> composeEmail({
    required String subject,
    required String body,
  }) async {
    final mailto = Uri(
      scheme: 'mailto',
      queryParameters: {'subject': subject, 'body': body},
    );
    if (!await launchUrl(mailto)) {
      throw StateError('Aplikacija za e-mail nije dostupna na ovom uređaju.');
    }
  }

  Future<void> savePdf({required String title, required String body}) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Header(level: 0, child: pw.Text(title)),
          pw.SizedBox(height: 16),
          pw.Paragraph(text: body),
        ],
      ),
    );
    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'briefai-odgovor.pdf',
    );
  }

  Future<void> shareJsonExport(String json) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'BriefAI Germany — izvoz podataka',
        text: 'Vaš JSON izvoz podataka iz BriefAI Germany.',
        files: [
          XFile.fromData(
            utf8.encode(json),
            mimeType: 'application/json',
            name: 'briefai-izvoz-podataka.json',
          ),
        ],
        fileNameOverrides: const ['briefai-izvoz-podataka.json'],
      ),
    );
  }

  Future<void> shareDocument(PickedDocument document) async {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Originalni dokument — BriefAI Germany',
        files: [
          XFile.fromData(
            document.bytes,
            mimeType: document.mimeType,
            name: document.name,
          ),
        ],
        fileNameOverrides: [document.name],
      ),
    );
  }
}

String newLetterId() => const Uuid().v4();
