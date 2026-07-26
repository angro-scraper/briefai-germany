import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
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
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

import 'domain.dart';
import '../features/analysis/analysis_engine.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class AppServices {
  AppServices._({
    required this.cloudEnabled,
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
  final AuthService auth;
  final DocumentService documents;
  final AiService ai;
  final LetterRepository letters;
  final EntitlementService entitlements;
  final ReminderService reminders;
  final PurchaseService purchases;
  final ReplyExportService exports;

  static Future<AppServices> bootstrap() async {
    var cloudEnabled = false;
    try {
      await Firebase.initializeApp();
      cloudEnabled = true;
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestProvider(),
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      await FirebaseAnalytics.instance.logAppOpen();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {
      // Firebase config is intentionally optional for local UI development.
    }
    final reminders = ReminderService(cloudEnabled: cloudEnabled);
    await reminders.initialize();
    return AppServices._(
      cloudEnabled: cloudEnabled,
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
    await FirebaseFunctions.instanceFor(
      region: 'europe-west3',
    ).httpsCallable('deleteAccount').call<void>();
  }

  Stream<Map<String, dynamic>?> profileChanges() {
    final userId = uid;
    if (!cloudEnabled || userId == null) {
      return Stream<Map<String, dynamic>?>.value(null);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((document) => document.data());
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .set(values, SetOptions(merge: true));
  }

  Future<String> preferredLanguage() async {
    final userId = uid;
    if (!cloudEnabled || userId == null) return 'sr';
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return profile.data()?['preferredLanguage'] as String? ?? 'sr';
  }

  Future<void> _ensureProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'preferredLanguage': 'sr',
      'countryOfOrigin': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    return PickedDocument(
      name: selected.name,
      bytes: selected.bytes!,
      mimeType: isPdf
          ? 'application/pdf'
          : lower.endsWith('.png')
          ? 'image/png'
          : 'image/jpeg',
      ocrPath: isPdf ? null : selected.path,
    );
  }

  Future<String> ocr(PickedDocument document) async {
    if (document.isPdf) {
      throw StateError('PDF OCR se izvršava kroz serverski OCR nakon uploada.');
    }
    if (document.ocrPath == null) {
      throw StateError(
        'OCR za ovaj izvor nije dostupan na trenutnoj platformi.',
      );
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(document.ocrPath!),
      );
      return result.text;
    } finally {
      recognizer.close();
    }
  }

  Future<String> extractUploadedText({
    required String storagePath,
    required String mimeType,
  }) async {
    if (!cloudEnabled) {
      throw StateError(
        'Za PDF je potrebno prijaviti se i povezati Firebase projekat.',
      );
    }
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('extractDocumentText')
        .call<Map<Object?, Object?>>({
          'storagePath': storagePath,
          'mimeType': mimeType,
        });
    final text = result.data['text'];
    if (text is! String || text.trim().isEmpty) {
      throw StateError('OCR nije vratio tekst dokumenta.');
    }
    return text;
  }

  Future<String?> upload({
    required String uid,
    required String letterId,
    required PickedDocument document,
  }) async {
    if (!cloudEnabled) return null;
    final ref = FirebaseStorage.instance.ref(
      'users/$uid/letters/$letterId/original-${document.name}',
    );
    await ref.putData(
      document.bytes,
      SettableMetadata(contentType: document.mimeType),
    );
    return ref.fullPath;
  }

  Future<PickedDocument?> _fromXFile(Future<XFile?> future) async {
    final file = await future;
    if (file == null) return null;
    return PickedDocument(
      name: file.name,
      bytes: await file.readAsBytes(),
      mimeType: file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg',
      ocrPath: file.path,
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
    String? storagePath,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return _local.analyse(text);
    }
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('analyzeLetter')
        .call<Map<Object?, Object?>>({
          'letterId': letterId,
          'ocrText': text,
          'preferredLanguage': language,
          'storagePath': storagePath,
        });
    final data = Map<String, dynamic>.from(result.data['analysis'] as Map);
    return LetterAnalysis.fromMap(id: letterId, map: data, sourceText: text);
  }

  Future<String> generateReply({
    required String letterId,
    required String facts,
    required String language,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return 'Sehr geehrte Damen und Herren,\n\nvielen Dank für Ihr Schreiben. Hiermit bestätige ich den Erhalt und werde die angeforderten Unterlagen fristgerecht einreichen.\n\nMit freundlichen Grüßen';
    }
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('generateReply')
        .call<Map<Object?, Object?>>({
          'letterId': letterId,
          'facts': facts,
          'preferredLanguage': language,
        });
    return result.data['reply'] as String;
  }

  Future<String> askLetterAssistant({
    required String question,
    required String language,
    String? letterId,
  }) async {
    if (!cloudEnabled || FirebaseAuth.instance.currentUser == null) {
      return 'Za odgovor vezan za konkretno pismo prijavite se i povežite Firebase projekat. U lokalnom režimu mogu da prikažem samo osnovne rokove iz analize.';
    }
    final request = <String, String>{
      'question': question,
      'preferredLanguage': language,
    };
    if (letterId != null) request['letterId'] = letterId;
    final result = await FirebaseFunctions.instanceFor(region: 'europe-west3')
        .httpsCallable('askLetterAssistant')
        .call<Map<Object?, Object?>>(request);
    final answer = result.data['answer'];
    if (answer is! String || answer.trim().isEmpty) {
      throw StateError('AI asistent nije vratio odgovor.');
    }
    return answer;
  }
}

class LetterRepository {
  LetterRepository({required this.cloudEnabled});
  final bool cloudEnabled;

  Stream<List<LetterAnalysis>> watch(String uid) {
    if (!cloudEnabled) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('letters')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LetterAnalysis.fromMap(id: doc.id, map: doc.data()))
              .toList(),
        );
  }

  Future<void> save(
    String uid,
    LetterAnalysis letter, {
    String? storagePath,
  }) async {
    if (!cloudEnabled) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('letters')
        .doc(letter.id)
        .set({
          ...letter.toMap(),
          'storagePath': storagePath,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': Timestamp.fromDate(letter.createdAt),
        }, SetOptions(merge: true));
  }

  Future<void> updateStatus(
    String uid,
    String letterId,
    LetterStatus status,
  ) async {
    if (!cloudEnabled) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('letters')
        .doc(letterId)
        .update({
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }
}

class EntitlementService {
  EntitlementService({required this.cloudEnabled});
  final bool cloudEnabled;

  Stream<bool> watch(String uid) {
    if (!cloudEnabled) return Stream<bool>.value(false);
    return FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .snapshots()
        .map(
          (document) =>
              ['active', 'trialing'].contains(document.data()?['status']),
        );
  }
}

class ReminderService {
  ReminderService({required this.cloudEnabled});
  final bool cloudEnabled;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

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
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('deviceTokens').doc(token).set({
      'uid': uid,
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
      final target = letter.deadline!.subtract(Duration(days: days));
      if (target.isBefore(DateTime.now())) continue;
      await _local.zonedSchedule(
        id: '${letter.id}-$days'.hashCode,
        title: 'Rok za: ${letter.title}',
        body: 'Rok je za $days ${days == 1 ? 'dan' : 'dana'}.',
        scheduledDate: tz.TZDateTime.from(target, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
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
  Future<void> copy(String reply) => Clipboard.setData(ClipboardData(text: reply));

  Future<void> composeEmail({required String subject, required String body}) async {
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
}

String newLetterId() => const Uuid().v4();
