import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _appUrl = 'https://briefai-germany-download.onrender.com/app/';
const _appHost = 'briefai-germany-download.onrender.com';

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
  var _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xfff5f7ff))
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
    _configureAndroidFileChooser();
  }

  void _configureAndroidFileChooser() {
    if (!Platform.isAndroid) return;
    final android = _controller.platform as AndroidWebViewController;
    android.setOnShowFileSelector((params) async {
      if (params.isCaptureEnabled &&
          params.acceptTypes.any((type) => type.startsWith('image/'))) {
        final image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
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
      return selection?.paths.whereType<String>().toList() ?? <String>[];
    });
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
