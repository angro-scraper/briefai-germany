import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _appUrl = 'https://briefai-germany-download.onrender.com/app/';
const _appHost = 'briefai-germany-download.onrender.com';
const _wrapperImageMaxSide = 2200;

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  String? _purchaseWaiter;
  Timer? _purchaseWaiterTimer;
  var _progress = 0;
  var _preparingFile = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      )
      ..loadRequest(Uri.parse(_appUrl));
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) => _enqueuePurchase({
        'ok': false,
        'error': 'Store tok je prekinut: $error',
      }),
    );
    _configureAndroidFileChooser();
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
        case 'products':
          final response = await InAppPurchase.instance.queryProductDetails({
            'briefai_premium_monthly',
            'briefai_pro_monthly',
          });
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
