import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'core/app_config.dart';
import 'firebase_options.dart';

const _appUrl = 'https://briefai.salvesca.com/app/';
const _appHost = 'briefai.salvesca.com';
const _wrapperImageMaxSide = 2200;

int _nativeNotificationId(String letterId, int days) {
  var hash = 0x811c9dc5;
  for (final codeUnit in '$letterId-$days'.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _nativeReminderBody(String language, int days, bool isPayment) {
  final one = days == 1;
  return switch (language) {
    'de' =>
      isPayment
          ? 'Die Zahlung ist in $days ${one ? 'Tag' : 'Tagen'} fällig.'
          : 'Die Frist endet in $days ${one ? 'Tag' : 'Tagen'}.',
    'en' =>
      isPayment
          ? 'Payment is due in $days ${one ? 'day' : 'days'}.'
          : 'The deadline is in $days ${one ? 'day' : 'days'}.',
    'mk' =>
      isPayment
          ? 'Плаќањето доспева за $days ${one ? 'ден' : 'дена'}.'
          : 'Рокот истекува за $days ${one ? 'ден' : 'дена'}.',
    'bg' =>
      isPayment
          ? 'Плащането е дължимо след $days ${one ? 'ден' : 'дни'}.'
          : 'Срокът изтича след $days ${one ? 'ден' : 'дни'}.',
    'tr' =>
      isPayment
          ? 'Ödemenin son tarihi $days ${one ? 'gün' : 'gün'} sonra.'
          : 'Son tarih $days ${one ? 'gün' : 'gün'} sonra.',
    'hr' || 'bs' =>
      isPayment
          ? 'Plaćanje dospijeva za $days ${one ? 'dan' : 'dana'}.'
          : 'Rok istječe za $days ${one ? 'dan' : 'dana'}.',
    _ =>
      isPayment
          ? 'Plaćanje dospeva za $days ${one ? 'dan' : 'dana'}.'
          : 'Rok ističe za $days ${one ? 'dan' : 'dana'}.',
  };
}

Future<String> _resizeWrapperImage(Map<String, String> job) async {
  final input = File(job['input']!);
  final decoded = img.decodeImage(await input.readAsBytes());
  if (decoded == null) return job['input']!;
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final resized = longest > _wrapperImageMaxSide
      ? img.copyResize(
          oriented,
          width: oriented.width >= oriented.height
              ? _wrapperImageMaxSide
              : null,
          height: oriented.height > oriented.width
              ? _wrapperImageMaxSide
              : null,
          interpolation: img.Interpolation.linear,
        )
      : oriented;
  await File(
    job['output']!,
  ).writeAsBytes(img.encodeJpg(resized, quality: 84), flush: true);
  return job['output']!;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BriefAiWrapper());
}

class BriefAiWrapper extends StatelessWidget {
  const BriefAiWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BriefAI Germany',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff3563ff),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const _WrapperScreen(),
    );
  }
}

class _WrapperScreen extends StatefulWidget {
  const _WrapperScreen();

  @override
  State<_WrapperScreen> createState() => _WrapperScreenState();
}

class _WrapperScreenState extends State<_WrapperScreen> {
  late final WebViewController _controller;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  final List<Map<String, dynamic>> _purchaseQueue = [];
  final Map<String, PurchaseDetails> _pendingCompletion = {};
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Future<void>? _notificationsReady;
  String? _purchaseWaiter;
  Timer? _purchaseWaiterTimer;
  var _progress = 0;
  var _preparingFile = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _notificationsReady = _initializeNotifications();
    if (kDebugMode && Platform.isAndroid) {
      unawaited(AndroidWebViewController.enableDebugging(true));
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff5f7ff))
      ..addJavaScriptChannel(
        'BriefAiNative',
        onMessageReceived: (message) {
          unawaited(_handleNativeMessage(message.message));
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageStarted: (_) => setState(() => _error = null),
          onPageFinished: (_) {
            unawaited(_removeStaleWebAppCache());
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _error = error.description);
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final isTrusted =
                uri.scheme == 'https' &&
                (uri.host == _appHost ||
                    uri.host.endsWith('.firebaseapp.com') ||
                    uri.host.endsWith('.googleapis.com') ||
                    uri.host.endsWith('.gstatic.com'));
            if (isTrusted) return NavigationDecision.navigate;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      );
    unawaited(_loadLiveWebApp());
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) => _enqueuePurchase({
        'ok': false,
        'error': 'Store tok je prekinut: $error',
      }),
    );
    _configureAndroidFileChooser();
  }

  Future<void> _loadLiveWebApp() async {
    try {
      // The wrapper must always display the current hosted application. This
      // clears only HTTP resources; user authentication, preferences and the
      // local document vault remain untouched.
      await _controller.clearCache();
    } on Object {
      // A cache cleanup failure must not prevent the hosted app from opening.
    }
    await _controller.loadRequest(
      Uri.parse(_appUrl).replace(
        queryParameters: {
          'nativeWrapper': '1',
          // Forces the WebView to request the current hosted shell on every
          // cold start. LocalStorage/IndexedDB remain intact, so login,
          // preferences and the private document vault are preserved.
          'webVersion': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    );
  }

  Future<void> _removeStaleWebAppCache() async {
    try {
      await _controller.runJavaScript(r'''
        (() => {
          const marker = 'briefai-wrapper-web-cache-v1';
          if (window.sessionStorage.getItem(marker) === 'done') return;
          window.sessionStorage.setItem(marker, 'done');
          Promise.all([
            ('serviceWorker' in navigator)
              ? navigator.serviceWorker.getRegistrations().then(
                  registrations => Promise.all(
                    registrations.map(registration => registration.unregister())
                  )
                )
              : Promise.resolve(),
            ('caches' in window)
              ? caches.keys().then(
                  keys => Promise.all(keys.map(key => caches.delete(key)))
                )
              : Promise.resolve(),
          ]).then(() => {
            if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
              window.location.reload();
            }
          });
        })();
      ''');
    } on Object {
      // The live app is still usable when a WebView vendor blocks this API.
    }
  }

  @override
  void dispose() {
    _purchaseWaiterTimer?.cancel();
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleNativeMessage(String rawMessage) async {
    String? requestId;
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) throw const FormatException();
      requestId = decoded['requestId'] as String?;
      final action = decoded['action'] as String?;
      final payload = decoded['payload'] is Map
          ? Map<String, dynamic>.from(decoded['payload'] as Map)
          : const <String, dynamic>{};
      if (requestId == null || action == null) throw const FormatException();
      switch (action) {
        case 'capabilities':
          await _resolveNative(requestId, {
            'ok': true,
            'nativeAuth': true,
            'wrapperBuild': 30,
          });
        case 'authGoogle':
          final credential = await FirebaseAuth.instance.signInWithProvider(
            GoogleAuthProvider()
              ..setCustomParameters({'prompt': 'select_account'}),
          );
          final idToken = await credential.user?.getIdToken(true);
          if (idToken == null || idToken.isEmpty) {
            throw StateError('Google prijava nije vratila token.');
          }
          await _resolveNative(requestId, {'ok': true, 'idToken': idToken});
        case 'authApple':
          final credential = await FirebaseAuth.instance.signInWithProvider(
            AppleAuthProvider(),
          );
          final idToken = await credential.user?.getIdToken(true);
          if (idToken == null || idToken.isEmpty) {
            throw StateError('Apple prijava nije vratila token.');
          }
          await _resolveNative(requestId, {'ok': true, 'idToken': idToken});
        case 'authSignOut':
          await FirebaseAuth.instance.signOut();
          await _resolveNative(requestId, {'ok': true});
        case 'products':
          final response = await InAppPurchase.instance.queryProductDetails(
            kSubscriptionPlans.map((plan) => plan.productId).toSet(),
          );
          await _resolveNative(requestId, {
            'ok': true,
            'products': [
              for (final product in response.productDetails)
                {
                  'id': product.id,
                  'title': product.title,
                  'description': product.description,
                  'price': product.price,
                },
            ],
          });
        case 'buy':
          final productId = payload['productId'];
          if (productId is! String) throw StateError('Nedostaje proizvod.');
          final response = await InAppPurchase.instance.queryProductDetails({
            productId,
          });
          if (response.productDetails.isEmpty) {
            throw StateError('Store proizvod nije pronađen.');
          }
          final started = await InAppPurchase.instance.buyNonConsumable(
            purchaseParam: PurchaseParam(
              productDetails: response.productDetails.single,
              applicationUserName: payload['applicationUserName'] as String?,
            ),
          );
          await _resolveNative(requestId, {'ok': started});
        case 'waitPurchase':
          if (_purchaseQueue.isNotEmpty) {
            await _resolveNative(requestId, _purchaseQueue.removeAt(0));
          } else {
            if (_purchaseWaiter != null) {
              throw StateError('Store zahtev je već u toku.');
            }
            _purchaseWaiter = requestId;
            _purchaseWaiterTimer = Timer(const Duration(seconds: 115), () {
              if (_purchaseWaiter != requestId) return;
              _purchaseWaiter = null;
              unawaited(
                _resolveNative(requestId!, {
                  'ok': false,
                  'error': 'Store odgovor je istekao.',
                }),
              );
            });
          }
        case 'complete':
          final transactionKey = payload['transactionKey'];
          if (transactionKey is! String) {
            throw StateError('Nedostaje Store transakcija.');
          }
          final purchase = _pendingCompletion.remove(transactionKey);
          if (purchase == null) {
            throw StateError('Store transakcija nije pronađena.');
          }
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          await _resolveNative(requestId, {'ok': true});
        case 'restore':
          await InAppPurchase.instance.restorePurchases();
          await _resolveNative(requestId, {'ok': true});
        case 'manage':
          final uri = Platform.isAndroid
              ? Uri.parse(
                  'https://play.google.com/store/account/subscriptions'
                  '?package=com.briefai.briefai_germany',
                )
              : Uri.parse('https://apps.apple.com/account/subscriptions');
          final opened = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          await _resolveNative(requestId, {'ok': opened});
        case 'scheduleReminders':
          await _scheduleReminders(payload);
          await _resolveNative(requestId, {'ok': true});
        case 'cancelReminders':
          final letterId = payload['letterId'];
          if (letterId is! String || letterId.isEmpty) {
            throw StateError('Nedostaje oznaka pisma.');
          }
          await _cancelReminders(letterId);
          await _resolveNative(requestId, {'ok': true});
        default:
          throw StateError('Nepoznata native akcija.');
      }
    } on Object catch (error) {
      if (requestId != null) {
        await _resolveNative(requestId, {
          'ok': false,
          'error': error.toString(),
        });
      }
    }
  }

  Future<void> _initializeNotifications() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> _scheduleReminders(Map<String, dynamic> payload) async {
    await _notificationsReady;
    final letterId = payload['letterId'];
    final rawDueDate = payload['dueDate'];
    if (letterId is! String || letterId.isEmpty || rawDueDate is! String) {
      throw StateError('Podaci za podsetnik nisu potpuni.');
    }
    final dueDate = DateTime.tryParse(rawDueDate);
    if (dueDate == null) throw StateError('Rok nije ispravan.');
    final language = payload['language'] as String? ?? 'sr';
    final isPayment = payload['isPayment'] == true;
    await _cancelReminders(letterId);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'deadlines',
        'Rokovi i plaćanja',
        channelDescription: 'Podsetnici 7, 3 i 1 dan pre roka',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final days in const [7, 3, 1]) {
      final target = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        9,
      ).subtract(Duration(days: days));
      if (!target.isAfter(DateTime.now())) continue;
      await _notifications.zonedSchedule(
        id: _nativeNotificationId(letterId, days),
        title: 'BriefAI Germany',
        body: _nativeReminderBody(language, days, isPayment),
        scheduledDate: tz.TZDateTime.from(target, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    }
  }

  Future<void> _cancelReminders(String letterId) async {
    await _notificationsReady;
    for (final days in const [7, 3, 1]) {
      await _notifications.cancel(id: _nativeNotificationId(letterId, days));
    }
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        _enqueuePurchase({
          'ok': false,
          'error': purchase.error?.message ?? 'Kupovina je otkazana.',
        });
        continue;
      }
      final transactionKey =
          purchase.purchaseID ??
          '${purchase.productID}:${DateTime.now().microsecondsSinceEpoch}';
      _pendingCompletion[transactionKey] = purchase;
      _enqueuePurchase({
        'ok': true,
        'transactionKey': transactionKey,
        'provider': purchase.verificationData.source,
        'productId': purchase.productID,
        'purchaseId': purchase.purchaseID,
        'verificationData': purchase.verificationData.serverVerificationData,
      });
    }
  }

  void _enqueuePurchase(Map<String, dynamic> payload) {
    final waiter = _purchaseWaiter;
    if (waiter == null) {
      _purchaseQueue.add(payload);
      return;
    }
    _purchaseWaiter = null;
    _purchaseWaiterTimer?.cancel();
    _purchaseWaiterTimer = null;
    unawaited(_resolveNative(waiter, payload));
  }

  Future<void> _resolveNative(String requestId, Map<String, dynamic> payload) {
    return _controller.runJavaScript(
      'window.briefAiNativeResolve('
      '${jsonEncode(requestId)},${jsonEncode(payload)});',
    );
  }

  void _configureAndroidFileChooser() {
    if (!Platform.isAndroid) return;
    final android = _controller.platform as AndroidWebViewController;
    android.setOnShowFileSelector((params) async {
      if (params.isCaptureEnabled &&
          params.acceptTypes.any((type) => type.startsWith('image/'))) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 84,
          maxWidth: _wrapperImageMaxSide.toDouble(),
          maxHeight: _wrapperImageMaxSide.toDouble(),
        );
        return image == null ? <String>[] : <String>[image.path];
      }
      final acceptsPdf = params.acceptTypes.any(
        (type) => type == 'application/pdf' || type.contains('pdf'),
      );
      final selection = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: acceptsPdf ? FileType.custom : FileType.image,
        allowedExtensions: acceptsPdf
            ? const ['pdf', 'png', 'jpg', 'jpeg']
            : null,
      );
      final paths = selection?.paths.whereType<String>().toList() ?? <String>[];
      if (paths.isEmpty) return paths;
      if (mounted) setState(() => _preparingFile = true);
      try {
        return await Future.wait(paths.map(_prepareSelectedFile));
      } finally {
        if (mounted) setState(() => _preparingFile = false);
      }
    });
  }

  Future<String> _prepareSelectedFile(String path) async {
    if (path.toLowerCase().endsWith('.pdf')) return path;
    try {
      final temporaryDirectory = await getTemporaryDirectory();
      final output =
          '${temporaryDirectory.path}${Platform.pathSeparator}'
          'briefai-${DateTime.now().microsecondsSinceEpoch}.jpg';
      return await compute(_resizeWrapperImage, {
        'input': path,
        'output': output,
      }).timeout(const Duration(seconds: 18));
    } on Object {
      return path;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _controller.canGoBack()) {
          await _controller.goBack();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100)
                LinearProgressIndicator(value: _progress / 100),
              if (_preparingFile)
                ColoredBox(
                  color: const Color(0xaa071633),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 22,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Pripremam fotografiju…',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 52),
                          const SizedBox(height: 16),
                          const Text(
                            'Aplikacija trenutno nije dostupna.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Proverite internet vezu i pokušajte ponovo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () => _controller.reload(),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Pokušaj ponovo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
