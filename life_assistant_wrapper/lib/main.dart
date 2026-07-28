import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _assistantUrl = 'https://asistent.salvesca.com/';
const _assistantHost = 'asistent.salvesca.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifeAssistantApp());
}

class LifeAssistantApp extends StatelessWidget {
  const LifeAssistantApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Asistent za život u Nemačkoj',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2859D7),
            brightness: Brightness.light,
          ),
        ),
        home: const AssistantWebShell(),
      );
}

class AssistantWebShell extends StatefulWidget {
  const AssistantWebShell({super.key});

  @override
  State<AssistantWebShell> createState() => _AssistantWebShellState();
}

class _AssistantWebShellState extends State<AssistantWebShell> {
  late final WebViewController _controller;
  var _loading = 0;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF6F8FC))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _failed = false);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _loading = progress);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = 100);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() => _failed = true);
            }
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(_liveAssistantUri());
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      unawaited(AndroidWebViewController.enableDebugging(false));
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Uri _liveAssistantUri() => Uri.parse(_assistantUrl).replace(
        queryParameters: {
          'nativeWrapper': '1',
          'webVersion': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

  Future<NavigationDecision> _handleNavigation(NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    final isAssistant = uri.scheme == 'https' && uri.host == _assistantHost;
    if (isAssistant) return NavigationDecision.navigate;

    // Official sources, e-mail links and privacy pages should open in the
    // user's normal browser instead of taking the assistant out of context.
    if (uri.scheme == 'https' || uri.scheme == 'mailto' || uri.scheme == 'tel') {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  Future<bool> _onWillPop() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (!didPop && await _onWillPop()) {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading < 100 && !_failed)
                  LinearProgressIndicator(value: _loading / 100),
                if (_failed)
                  _ConnectionError(onRetry: () {
                    setState(() => _failed = false);
                    _controller.loadRequest(_liveAssistantUri());
                  }),
              ],
            ),
          ),
        ),
      );
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF6F8FC),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  'Asistent trenutno nije dostupan.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Proverite internet vezu i pokušajte ponovo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj ponovo'),
                ),
              ],
            ),
          ),
        ),
      );
}
