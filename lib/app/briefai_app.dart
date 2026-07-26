import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/domain.dart';
import '../core/app_config.dart';
import '../core/app_services.dart';
import '../core/app_localizations.dart';
import '../core/legal.dart';

class BriefAiApp extends StatefulWidget {
  const BriefAiApp({super.key, required this.services});
  final AppServices services;

  @override
  State<BriefAiApp> createState() => _BriefAiAppState();
}

class _BriefAiAppState extends State<BriefAiApp> {
  final AppState _state = AppState();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreAppState());
    if (kPaymentsEnabled && !kIsWeb) {
      _purchaseSubscription = widget.services.purchases.updates.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );
    }
  }

  Future<void> _restoreAppState() async {
    final preferences = await SharedPreferences.getInstance();
    _state.restoreOnboarding(
      preferences.getBool('briefai.onboarding-complete') ?? false,
    );
    _state.setLocale(await widget.services.auth.preferredLanguage());
    if (mounted) setState(() => _restored = true);
  }

  Future<void> _completeOnboarding() async {
    _state.completeOnboarding();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('briefai.onboarding-complete', true);
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          if (await widget.services.purchases.verifyPurchase(purchase)) {
            _state.setPremium(true);
          }
        } catch (_) {
          // The server is authoritative. A failed verification never unlocks
          // Premium, and the next store restore can retry it.
        }
      }
      if (purchase.pendingCompletePurchase) {
        await widget.services.purchases.complete(purchase);
      }
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _state,
    builder: (context, _) => MaterialApp(
      title: 'BriefAI Germany',
      debugShowCheckedModeBanner: false,
      locale: Locale(_state.localeCode),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(),
      home: !_restored
          ? const SplashScreen()
          : _state.onboardingComplete
          ? AppShell(state: _state, services: widget.services)
          : OnboardingScreen(
              state: _state,
              services: widget.services,
              onComplete: () => unawaited(_completeOnboarding()),
            ),
    ),
  );

  ThemeData _theme() {
    const navy = Color(0xFF0B1533);
    const cobalt = Color(0xFF315CFF);
    final scheme = ColorScheme.fromSeed(
      seedColor: cobalt,
      brightness: Brightness.light,
    ).copyWith(primary: cobalt, surface: Colors.white);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F8FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: Color(0xFF0B1533),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF315CFF), Color(0xFF9C76FF)],
              ),
            ),
            child: SizedBox(
              width: 94,
              height: 94,
              child: Icon(Icons.auto_awesome, color: Colors.white, size: 44),
            ),
          ),
          SizedBox(height: 18),
          Text(
            'BriefAI Germany',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Razumi nemačko pismo.',
            style: TextStyle(color: Color(0xFFC7D5FF)),
          ),
          SizedBox(height: 28),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFFC7D5FF),
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.state,
    required this.services,
    required this.onComplete,
  });
  final AppState state;
  final AppServices services;
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final pages = [
      (
        strings.text('onboardPhoto'),
        strings.text('onboardPhotoBody'),
        Icons.document_scanner_outlined,
      ),
      (
        strings.text('onboardAi'),
        strings.text('onboardAiBody'),
        Icons.auto_awesome,
      ),
      (
        strings.text('onboardDeadline'),
        strings.text('onboardDeadlineBody'),
        Icons.notifications_active_outlined,
      ),
    ];
    final item = pages[_page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BriefAI',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _LanguageMenu(state: widget.state, services: widget.services),
                ],
              ),
              const Spacer(),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      const Color(0xFF9C76FF),
                    ],
                  ),
                ),
                child: Icon(item.$3, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 38),
              Text(
                item.$1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => Container(
                    margin: const EdgeInsets.all(4),
                    width: i == _page ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (_page == 2) return widget.onComplete();
                  setState(() => _page++);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(
                  _page == 2 ? strings.text('start') : strings.text('next'),
                ),
              ),
              TextButton(
                onPressed: widget.onComplete,
                child: Text(strings.text('skip')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  StreamSubscription<dynamic>? _lettersSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<dynamic>? _entitlementSubscription;
  StreamSubscription<dynamic>? _usageSubscription;

  @override
  void initState() {
    super.initState();
    _bindLocalVault();
    if (widget.services.cloudEnabled) {
      _authSubscription = widget.services.auth.authChanges.listen((user) {
        _bindLocalVault();
        _entitlementSubscription?.cancel();
        _usageSubscription?.cancel();
        if (user != null) {
          unawaited(
            widget.services.auth.preferredLanguage().then(
              widget.state.setLocale,
            ),
          );
          unawaited(widget.services.auth.touchActivity());
          unawaited(widget.services.reminders.syncToken());
          _entitlementSubscription = widget.services.entitlements
              .watch(user.uid)
              .listen(widget.state.setPremium);
          _usageSubscription = widget.services.entitlements
              .watchFreeUsage(user.uid)
              .listen(widget.state.setFreeAnalysesUsed);
        } else {
          widget.state.setPremium(false);
          _usageSubscription = widget.services.entitlements
              .watchFreeUsage('local-device')
              .listen(widget.state.setFreeAnalysesUsed);
        }
      });
    } else {
      _usageSubscription = widget.services.entitlements
          .watchFreeUsage('local-device')
          .listen(widget.state.setFreeAnalysesUsed);
    }
  }

  void _bindLocalVault() {
    unawaited(_lettersSubscription?.cancel());
    widget.state.replaceLetters(const []);
    _lettersSubscription = widget.services.letters
        .watch(widget.services.auth.localVaultKey)
        .listen(widget.state.replaceLetters);
  }

  @override
  void dispose() {
    _lettersSubscription?.cancel();
    _entitlementSubscription?.cancel();
    _usageSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final screens = [
      HomeScreen(state: widget.state, services: widget.services),
      ArchiveScreen(state: widget.state, services: widget.services),
      AssistantScreen(state: widget.state, services: widget.services),
      ProfileScreen(state: widget.state, services: widget.services),
    ];
    return Scaffold(
      body: SafeArea(child: screens[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.text('home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: strings.text('archive'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: strings.text('assistant'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: strings.text('profile'),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final unavailable = !kFreeBetaMode && !services.cloudEnabled && !kDebugMode;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.text('welcome'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _LanguageMenu(state: state, services: services),
          ],
        ),
        const SizedBox(height: 8),
        Text(strings.text('homeSubtitle')),
        if (services.cloudEnabled && !services.auth.isSignedIn) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(strings.text('accountCta')),
              subtitle: Text(strings.text('accountCtaSubtitle')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SignInScreen(services: services),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1533),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF9DB5FF)),
              const SizedBox(height: 16),
              Text(
                strings.text('analyzeNew'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kFreeBetaMode
                    ? strings.text('freeBetaActive')
                    : state.isPremium
                    ? strings.text('unlimited')
                    : strings.remaining(2 - state.freeAnalysesUsed),
                style: const TextStyle(color: Color(0xFFD7E0FF)),
              ),
              if (unavailable) ...[
                const SizedBox(height: 10),
                Text(
                  services.configurationError ?? 'Usluga nije dostupna.',
                  style: const TextStyle(color: Color(0xFFFFC2C2)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: unavailable
                    ? null
                    : state.canAnalyse
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AnalysisScreen(state: state, services: services),
                        ),
                      )
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SubscriptionScreen(
                            state: state,
                            services: services,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                  state.canAnalyse
                      ? strings.text('addDocument')
                      : strings.text('activatePremium'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          strings.text('recentLetters'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (state.letters.isEmpty)
          _EmptyState(
            icon: Icons.inbox_outlined,
            text: strings.text('emptyLetters'),
          )
        else
          ...state.letters
              .take(3)
              .map(
                (letter) => LetterCard(
                  letter: letter,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(
                        state: state,
                        letter: letter,
                        services: services,
                      ),
                    ),
                  ),
                ),
              ),
      ],
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.state, required this.services});

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.strings.text('appLanguage'),
    initialValue: state.localeCode,
    icon: const Icon(Icons.translate),
    onSelected: (language) async {
      await services.auth.setPreferredLanguage(language);
      state.setLocale(language);
    },
    itemBuilder: (_) => _languageLabels.entries
        .map(
          (entry) => PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                if (entry.key == state.localeCode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 18),
                  ),
                Text(entry.value),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _create ? strings.text('createAccount') : strings.text('signIn'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            strings.text('secureLetters'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: strings.text('email')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: _create
                ? const [AutofillHints.newPassword]
                : const [AutofillHints.password],
            decoration: InputDecoration(labelText: strings.text('password')),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _emailSignIn,
            child: Text(
              _create ? strings.text('createAccount') : strings.text('signIn'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _google,
            icon: const Icon(Icons.g_mobiledata),
            label: Text(strings.text('continueGoogle')),
          ),
          if (Theme.of(context).platform == TargetPlatform.iOS)
            OutlinedButton.icon(
              onPressed: _loading ? null : _apple,
              icon: const Icon(Icons.apple),
              label: Text(strings.text('continueApple')),
            ),
          TextButton(
            onPressed: () => setState(() => _create = !_create),
            child: Text(
              _create
                  ? strings.text('haveAccount')
                  : strings.text('needAccount'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _emailSignIn() => _run(() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 6) {
      throw const FormatException('Proverite email i lozinku.');
    }
    await widget.services.auth.signInWithEmail(
      email,
      _password.text,
      create: _create,
    );
  });
  Future<void> _google() => _run(widget.services.auth.signInWithGoogle);
  Future<void> _apple() => _run(widget.services.auth.signInWithApple);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.strings.text('signInFailed')}: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    required this.state,
    required this.services,
  });
  final AppState state;
  final AppServices services;
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _text = TextEditingController();
  bool _loading = false;
  bool _recognizing = false;
  bool _ocrComplete = false;
  PickedDocument? _document;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('newAnalysis'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.text('uploadDocument'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(strings.text('localProcessing')),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _select(widget.services.documents.capture),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(strings.text('camera')),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _select(widget.services.documents.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(strings.text('gallery')),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _select(widget.services.documents.file),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(strings.text('pdfImage')),
                ),
              ],
            ),
            if (_document != null)
              Card(
                margin: const EdgeInsets.only(top: 12),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (!_document!.isPdf)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _document!.bytes,
                            width: 64,
                            height: 80,
                            cacheWidth: 256,
                            filterQuality: FilterQuality.low,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 64,
                              height: 80,
                              child: Icon(Icons.description_outlined),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          width: 64,
                          height: 80,
                          child: Icon(Icons.picture_as_pdf_outlined, size: 38),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _document!.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _loading
                                  ? strings.text('ocrReading')
                                  : _ocrComplete
                                  ? strings.text('ocrReady')
                                  : strings.text('ocrNotReady'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _ocrComplete
                                        ? Colors.green.shade700
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (_recognizing) ...[
                              const SizedBox(height: 8),
                              const LinearProgressIndicator(minHeight: 3),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _text,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: strings.text('letterText'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _analyse,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _loading
                    ? _recognizing
                          ? strings.text('ocrReading')
                          : strings.text('loadingImage')
                    : strings.text('analyzeLetter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyse() async {
    if (!kFreeBetaMode &&
        widget.services.cloudEnabled &&
        !widget.services.auth.isSignedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SignInScreen(services: widget.services),
        ),
      );
      if (!mounted || !widget.services.auth.isSignedIn) return;
    }
    setState(() => _loading = true);
    final enterTextFirst = context.strings.text('enterTextFirst');
    try {
      final id = newLetterId();
      final language = await widget.services.auth.preferredLanguage();
      if (_document != null && _text.text.trim().isEmpty) {
        _text.text = await widget.services.documents.ocr(_document!);
      }
      if (_text.text.trim().isEmpty) {
        throw StateError(enterTextFirst);
      }
      final analysis = await widget.services.ai.analyse(
        letterId: id,
        text: _text.text,
        language: language,
      );
      await widget.services.letters.save(
        widget.services.auth.localVaultKey,
        analysis,
        document: _document,
      );
      if (!kFreeBetaMode && !widget.state.isPremium) {
        await widget.services.entitlements.recordAnalysis(
          widget.services.auth.uid ?? 'local-device',
        );
      }
      widget.state.addAnalysis(analysis);
      // A notification permission or OEM scheduler failure must never hide a
      // completed AI result. The analysis remains available even if reminders
      // cannot be registered on this device.
      try {
        await widget.services.reminders.schedule(analysis);
      } on Object {
        // The user can still add a reminder manually from the result screen.
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            state: widget.state,
            letter: analysis,
            services: widget.services,
          ),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.strings.text('analysisFailed')}: $error'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _select(Future<PickedDocument?> Function() source) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _recognizing = false;
    });
    try {
      final selected = await source();
      if (selected == null || !mounted) return;
      setState(() {
        _document = selected;
        _ocrComplete = false;
        _recognizing = true;
        _text.clear();
      });
      // Let Flutter paint the thumbnail and OCR status before starting the
      // CPU-intensive WASM recognition job.
      await WidgetsBinding.instance.endOfFrame;
      final recognized = await widget.services.documents.ocr(selected);
      if (!mounted) return;
      setState(() {
        _text.text = recognized;
        _text.selection = TextSelection.collapsed(offset: recognized.length);
        _ocrComplete = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.text('ocrReady'))));
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _ocrComplete = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.strings.text('ocrFailed')}: '
            '${_readableError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _recognizing = false;
        });
      }
    }
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst(
      RegExp(r'^(StateError|Exception):\s*'),
      '',
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.state,
    required this.letter,
    required this.services,
  });
  final AppState state;
  final LetterAnalysis letter;
  final AppServices services;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('resultTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Badge(
            label: letter.urgency.name.toUpperCase(),
            color: letter.urgency == Urgency.high
                ? Colors.red
                : letter.urgency == Urgency.medium
                ? Colors.orange
                : Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            letter.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _ResultSection(
            title: strings.text('simpleExplanation'),
            content: letter.plainExplanation,
          ),
          _ResultSection(
            title: strings.text('category'),
            content: strings.category(letter.category.name),
          ),
          if (letter.deadline != null)
            _ResultSection(
              title: strings.text('deadline'),
              content:
                  '${letter.deadline!.day.toString().padLeft(2, '0')}.${letter.deadline!.month.toString().padLeft(2, '0')}.${letter.deadline!.year}',
            ),
          if (letter.amount != null)
            _ResultSection(
              title: strings.text('amount'),
              content: letter.amount!,
            ),
          _ResultSection(
            title: strings.text('nextSteps'),
            content: letter.suggestedAction,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final document = await services.letters.loadDocument(
                services.auth.localVaultKey,
                letter.id,
              );
              if (!context.mounted) return;
              if (document == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.text('originalMissing'))),
                );
                return;
              }
              await services.exports.shareDocument(document);
            },
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(strings.text('openOriginal')),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ResponseScreen(letter: letter, services: services),
              ),
            ),
            icon: const Icon(Icons.edit_note),
            label: Text(strings.text('generateReply')),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: Text(strings.text('finishHome')),
          ),
        ],
      ),
    );
  }
}

class ResponseScreen extends StatefulWidget {
  const ResponseScreen({
    super.key,
    required this.letter,
    required this.services,
  });
  final LetterAnalysis letter;
  final AppServices services;

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  late final Future<GeneratedReply> _response = () async {
    final language = await widget.services.auth.preferredLanguage();
    return widget.services.ai.generateReply(
      letterId: widget.letter.id,
      sourceText: widget.letter.sourceText,
      facts: 'No additional user-supplied facts.',
      language: language,
    );
  }();
  bool _emailVersion = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('replyTitle'))),
      body: FutureBuilder<GeneratedReply>(
        future: _response,
        builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                strings.text('formalReply'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (snapshot.hasData)
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.article_outlined),
                      label: Text(strings.text('letter')),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.email_outlined),
                      label: Text('E-mail'),
                    ),
                  ],
                  selected: {_emailVersion},
                  onSelectionChanged: (selected) =>
                      setState(() => _emailVersion = selected.first),
                ),
              if (snapshot.hasData) const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: snapshot.hasError
                      ? Text(
                          '${strings.text('responseUnavailable')}: ${snapshot.error}',
                        )
                      : snapshot.hasData
                      ? SelectableText(
                          _emailVersion
                              ? snapshot.data!.email
                              : snapshot.data!.letter,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.hasData) ...[
                FilledButton.icon(
                  onPressed: () async {
                    await widget.services.exports.copy(
                      _emailVersion
                          ? snapshot.data!.email
                          : snapshot.data!.letter,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(strings.text('replyCopied'))),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: Text(strings.text('copyReply')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.services.exports.composeEmail(
                    subject: 'Odgovor na: ${widget.letter.title}',
                    body: snapshot.data!.email,
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(strings.text('sendEmail')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => widget.services.exports.savePdf(
                    title: 'BriefAI Germany — ${widget.letter.title}',
                    body: _emailVersion
                        ? snapshot.data!.email
                        : snapshot.data!.letter,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(strings.text('savePdf')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          strings.text('archive'),
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(strings.text('archiveSubtitle')),
        const SizedBox(height: 20),
        if (state.letters.isEmpty)
          _EmptyState(
            icon: Icons.folder_off_outlined,
            text: strings.text('emptyLetters'),
          )
        else
          ...state.letters.map(
            (letter) => LetterCard(
              letter: letter,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    state: state,
                    letter: letter,
                    services: services,
                  ),
                ),
              ),
              onStatus: (status) async {
                state.updateStatus(letter.id, status);
                await services.letters.updateStatus(
                  services.auth.localVaultKey,
                  letter.id,
                  status,
                );
              },
              onDelete: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text('${strings.text('deleteDocument')}?'),
                  content: Text(strings.text('deleteDocumentBody')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(strings.text('cancel')),
                    ),
                    FilledButton(
                      onPressed: () async {
                        await services.letters.delete(
                          services.auth.localVaultKey,
                          letter.id,
                        );
                        await services.reminders.cancel(letter.id);
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      },
                      child: Text(strings.text('delete')),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.state,
    required this.services,
  });
  final AppState state;
  final AppServices services;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _question = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final visibleMessages = _messages.isEmpty
        ? [_ChatMessage(text: strings.text('assistantHello'), fromUser: false)]
        : _messages;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('assistantTitle'))),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: visibleMessages
                  .map(
                    (message) => Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: message.fromUser
                              ? const Color(0xFFDDE5FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(message.text),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _question,
                    decoration: InputDecoration(
                      hintText: strings.text('assistantHint'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _ask,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ask() async {
    final question = _question.text.trim();
    if (question.isEmpty || _sending) return;
    final letter = widget.state.letters.isEmpty
        ? null
        : widget.state.letters.first;
    setState(() {
      _messages.add(_ChatMessage(text: question, fromUser: true));
      _question.clear();
      _sending = true;
    });
    try {
      final language = await widget.services.auth.preferredLanguage();
      final answer = await widget.services.ai.askLetterAssistant(
        question: question,
        language: language,
        letter: letter,
      );
      if (!mounted) return;
      setState(
        () => _messages.add(_ChatMessage(text: answer, fromUser: false)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: '${context.strings.text('responseUnavailable')}: $error',
            fromUser: false,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.person, size: 34),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            strings.text('myProfile'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        if (services.cloudEnabled && services.auth.isSignedIn)
          StreamBuilder<Map<String, dynamic>?>(
            stream: services.auth.profileChanges(),
            builder: (context, snapshot) {
              final profile = snapshot.data ?? const <String, dynamic>{};
              final language = profile['preferredLanguage'] as String? ?? 'sr';
              final country = profile['countryOfOrigin'] as String? ?? '';
              final name = profile['displayName'] as String? ?? '';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(strings.text('name')),
                    subtitle: Text(
                      name.isEmpty ? strings.text('addName') : name,
                    ),
                    onTap: () => _editTextProfile(
                      context,
                      services,
                      strings.text('name'),
                      name,
                      (value) =>
                          services.auth.updateProfile(displayName: value),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(strings.text('preferredLanguage')),
                    subtitle: Text(_languageLabels[language] ?? language),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        await services.auth.setPreferredLanguage(value);
                        state.setLocale(value);
                      },
                      itemBuilder: (_) => _languageLabels.entries
                          .map(
                            (entry) => PopupMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: Text(strings.text('country')),
                    subtitle: Text(
                      country.isEmpty ? strings.text('addCountry') : country,
                    ),
                    onTap: () => _editTextProfile(
                      context,
                      services,
                      strings.text('country'),
                      country,
                      (value) =>
                          services.auth.updateProfile(countryOfOrigin: value),
                    ),
                  ),
                ],
              );
            },
          )
        else ...[
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(strings.text('appLanguage')),
            subtitle: Text(
              _languageLabels[state.localeCode] ?? state.localeCode,
            ),
            trailing: _LanguageMenu(state: state, services: services),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(strings.text('country')),
            subtitle: Text(strings.text('signInForProfile')),
          ),
        ],
        const Divider(),
        if (kPaymentsEnabled)
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: Text(
              state.isPremium
                  ? strings.text('premiumActive')
                  : strings.text('premiumName'),
            ),
            subtitle: Text(strings.text('premiumSubtitle')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SubscriptionScreen(state: state, services: services),
              ),
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: Text(strings.text('freeBetaTitle')),
            subtitle: Text(strings.text('freeBetaBody')),
          ),
        if (services.cloudEnabled && !services.auth.isSignedIn)
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(strings.text('accountCta')),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SignInScreen(services: services),
              ),
            ),
          ),
        if (services.cloudEnabled && services.auth.isSignedIn)
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(strings.text('signOut')),
            onTap: services.auth.signOut,
          ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: Text(strings.text('privacyPolicy')),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LegalScreen(privacy: true)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: Text(strings.text('terms')),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const LegalScreen(privacy: false),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(strings.text('exportData')),
          subtitle: Text(strings.text('exportSubtitle')),
          onTap: () => _exportAccountData(context, state, services),
        ),
        if (!services.auth.isSignedIn)
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            title: Text(strings.text('deleteLocal')),
            subtitle: Text(strings.text('deleteLocalSubtitle')),
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text('${strings.text('deleteLocal')}?'),
                content: Text(strings.text('deleteLocalBody')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(strings.text('cancel')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      await services.letters.clearAll(
                        services.auth.localVaultKey,
                      );
                      await services.reminders.cancelAll();
                      state.replaceLetters(const []);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    child: Text(strings.text('delete')),
                  ),
                ],
              ),
            ),
          ),
        if (services.cloudEnabled && services.auth.isSignedIn)
          ListTile(
            leading: const Icon(
              Icons.delete_forever_outlined,
              color: Colors.red,
            ),
            title: Text(strings.text('deleteAccount')),
            onTap: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(strings.text('deleteAccountQuestion')),
                content: Text(strings.text('deleteAccountBody')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(strings.text('cancel')),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        await services.letters.clearAll(
                          services.auth.localVaultKey,
                        );
                        await services.reminders.cancelAll();
                        state.replaceLetters(const []);
                        await services.auth.deleteAccount();
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } on Object catch (error) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Lokalni podaci su obrisani, ali brisanje naloga '
                                'nije završeno: $error',
                              ),
                            ),
                          );
                        }
                      }
                    },
                    child: Text(strings.text('delete')),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _languageLabels = {
  'sr': 'Srpski',
  'hr': 'Hrvatski',
  'bs': 'Bosanski',
  'mk': 'Makedonski',
  'de': 'Nemački',
  'en': 'Engleski',
  'bg': 'Bugarski',
};

Future<void> _exportAccountData(
  BuildContext context,
  AppState state,
  AppServices services,
) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.text('prepareExport'))),
    );
    final payload = <String, dynamic>{
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'privacyModel':
          'Original documents, OCR text and analyses are stored locally.',
      'account': await services.auth.localAccountData(),
      'premiumActive': state.isPremium,
      'letters': await services.letters.exportRecords(
        services.auth.localVaultKey,
      ),
    };
    await services.exports.shareJsonExport(jsonEncode(payload));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('exportUnavailable'))),
      );
    }
  }
}

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final sections = privacy ? _privacySections : _termsSections;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          privacy ? strings.text('privacyPolicy') : strings.text('terms'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            privacy ? strings.text('privacyPolicy') : strings.text('terms'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(strings.text('lastUpdated')),
          const SizedBox(height: 20),
          if (!LegalConfig.isComplete) const _LegalWarning(),
          ...sections.map(
            (section) => Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.$1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(section.$2),
                ],
              ),
            ),
          ),
          const Divider(),
          Text(
            '${strings.text('dataController')}: ${LegalConfig.displayedEntity}',
          ),
          Text('${strings.text('contact')}: ${LegalConfig.displayedContact}'),
          Text('${strings.text('address')}: ${LegalConfig.displayedAddress}'),
        ],
      ),
    );
  }
}

class _LegalWarning extends StatelessWidget {
  const _LegalWarning();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 22),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Text(
      'Ovo je razvojna verzija. Pre javne objave vlasnik aplikacije mora uneti pravni identitet, kontakt, adresu i potvrditi dokumente sa nemačkim pravnikom.',
    ),
  );
}

const _privacySections = [
  (
    '1. Odgovorno lice i obim',
    'BriefAI Germany koristi podatke potrebne za rad aplikacije: nalog, lokalni profil i jezik, dokumente koje korisnik doda, OCR tekst, analize, status pretplate i, ako korisnik dozvoli, uređajni token za obaveštenja.',
  ),
  (
    '2. Lokalno čuvanje dokumenata',
    'Originalni dokument, lokalno prepoznati OCR tekst, analiza, odgovor i razgovor o pismu čuvaju se u lokalnom skladištu uređaja. BriefAI ih ne otprema u Firebase Storage niti u Firestore arhivu. Brisanje podataka pregledača ili aplikacije može nepovratno ukloniti ovu lokalnu arhivu.',
  ),
  (
    '3. Obrada i primaoci',
    'Firebase se koristi za autentifikaciju, status pretplate, ograničenje korišćenja i opcionalne push tokene. Kada je cloud AI uključen, samo OCR tekst potreban za trenutni zahtev šalje se OpenAI-ju radi analize ili odgovora i ne upisuje se u cloud arhivu. Stripe obrađuje web naplatu, a Apple ili Google mobilne pretplate.',
  ),
  (
    '4. Rok čuvanja i bezbednost',
    'Lokalni dokumenti i analize ostaju na uređaju do pojedinačnog brisanja, brisanja naloga ili podataka aplikacije. Prenos naloga i kratkotrajnog AI zahteva je zaštićen, a podsetnici na zaključanom ekranu ne sadrže tekst pisma.',
  ),
  (
    '5. Vaša prava',
    'U aplikaciji možete ispraviti profil, napraviti lokalni JSON izvoz koji uključuje analize i originalne dokumente u Base64 obliku ili trajno obrisati lokalne podatke i nalog. Za dodatne zahteve koristite kontakt na kraju dokumenta.',
  ),
];

const _termsSections = [
  (
    '1. Prihvatanje i namena',
    'Korišćenjem BriefAI Germany prihvatate ove uslove. Aplikacija pomaže da se razumeju nemačka službena pisma na običnom jeziku.',
  ),
  (
    '2. Nije pravni, poreski, medicinski ili finansijski savet',
    'AI analiza može pogrešiti i ne zamenjuje advokata, poreskog savetnika, lekara, osiguranje ili nadležni organ. Korisnik je odgovoran da proveri rokove, iznose i sadržaj originalnog pisma.',
  ),
  (
    '3. Pretplate i otkazivanje',
    'Tokom besplatne beta faze naplata nije aktivna. Premium i Pro planovi biće ponuđeni tek nakon provere kvaliteta i uz jasno prikazanu cenu i uslove pre kupovine.',
  ),
  (
    '4. Prihvatljivo korišćenje',
    'Ne smete koristiti aplikaciju za nezakonite radnje, unos tuđih dokumenata bez ovlašćenja, pokušaj zaobilaženja ograničenja ili napad na uslugu.',
  ),
  (
    '5. Izmene',
    'Uslovi mogu biti izmenjeni kada je to potrebno zbog zakona, bezbednosti ili funkcionalnosti. Važne izmene biće prikazane u aplikaciji pre nastavka korišćenja kada je to zakonski potrebno.',
  ),
];

Future<void> _editTextProfile(
  BuildContext context,
  AppServices services,
  String label,
  String initialValue,
  Future<void> Function(String value) save,
) async {
  final controller = TextEditingController(text: initialValue);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(label),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.strings.text('cancel')),
        ),
        FilledButton(
          onPressed: () async {
            await save(controller.text.trim());
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: Text(context.strings.text('save')),
        ),
      ],
    ),
  );
  controller.dispose();
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({
    super.key,
    required this.state,
    required this.services,
  });
  final AppState state;
  final AppServices services;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late final Future<
    ({
      ProductDetailsResponse products,
      Map<String, String> wrapperPrices,
      bool nativeWrapper,
    })
  >
  _offers;

  @override
  void initState() {
    super.initState();
    _offers = () async {
      if (kIsWeb) {
        final nativeWrapper = await widget.services.purchases
            .isNativeStoreWrapper();
        return (
          products: ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: const [],
          ),
          wrapperPrices: await widget.services.purchases.wrapperProductPrices(),
          nativeWrapper: nativeWrapper,
        );
      }
      return (
        products: await widget.services.purchases.products(),
        wrapperPrices: const <String, String>{},
        nativeWrapper: false,
      );
    }();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('choosePlan'))),
      body:
          FutureBuilder<
            ({
              ProductDetailsResponse products,
              Map<String, String> wrapperPrices,
              bool nativeWrapper,
            })
          >(
            future: _offers,
            builder: (context, snapshot) {
              final productById = {
                for (final product
                    in snapshot.data?.products.productDetails ??
                        <ProductDetails>[])
                  product.id: product,
              };
              final wrapperPrices =
                  snapshot.data?.wrapperPrices ?? const <String, String>{};
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    strings.text('planTagline'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PlanCard(
                    title: 'FREE',
                    price: '0 €',
                    features: [strings.text('freeFeature')],
                    selected: !widget.state.isPremium,
                  ),
                  _PlanCard(
                    title: 'PREMIUM',
                    price:
                        productById[PurchaseService.premiumId]?.price ??
                        wrapperPrices[PurchaseService.premiumId] ??
                        '4,99 € / mesečno',
                    features: [
                      strings.text('premiumFeature1'),
                      strings.text('premiumFeature2'),
                      strings.text('premiumFeature3'),
                    ],
                    action: kIsWeb
                        ? () => _webCheckout('premium')
                        : () => _buy(productById[PurchaseService.premiumId]),
                  ),
                  _PlanCard(
                    title: 'PRO',
                    price:
                        productById[PurchaseService.proId]?.price ??
                        wrapperPrices[PurchaseService.proId] ??
                        '9,99 € / mesečno',
                    features: [
                      strings.text('proFeature1'),
                      strings.text('proFeature2'),
                    ],
                    action: kIsWeb
                        ? () => _webCheckout('pro')
                        : () => _buy(productById[PurchaseService.proId]),
                  ),
                  const SizedBox(height: 12),
                  if (!kIsWeb || snapshot.data?.nativeWrapper == true)
                    OutlinedButton.icon(
                      onPressed: _restorePurchases,
                      icon: const Icon(Icons.restore),
                      label: Text(strings.text('restorePurchases')),
                    ),
                  if (widget.state.isPremium) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _manageSubscription,
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: Text(strings.text('manageSubscription')),
                    ),
                  ],
                  if (!kIsWeb || snapshot.data?.nativeWrapper == true)
                    const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? 'Kupovine trenutno nisu dostupne: ${snapshot.error}'
                        : kIsWeb && snapshot.data?.nativeWrapper != true
                        ? 'Web pretplata se obrađuje preko Stripe Checkout-a. Entitlement aktivira potpisani webhook.'
                        : 'Plaćanje se obrađuje preko Google Play Billing / Apple In-App Purchase. Entitlement se aktivira tek nakon serverske verifikacije.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _buy(ProductDetails? product) async {
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proizvod još nije konfigurisan u prodavnici.'),
        ),
      );
      return;
    }
    try {
      await widget.services.purchases.buy(product);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kupovina nije pokrenuta: $error')),
        );
      }
    }
  }

  Future<void> _webCheckout(String plan) async {
    final base = Uri.base;
    final success = base.replace(
      queryParameters: {...base.queryParameters, 'checkout': 'success'},
    );
    final cancel = base.replace(
      queryParameters: {...base.queryParameters, 'checkout': 'cancel'},
    );
    try {
      await widget.services.purchases.startStripeCheckout(
        plan: plan,
        successUrl: success,
        cancelUrl: cancel,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Stripe Checkout nije pokrenut: $error')),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await widget.services.purchases.restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proveravamo ranije kupovine…')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kupovine nije moguće vratiti: $error')),
        );
      }
    }
  }

  Future<void> _manageSubscription() async {
    try {
      await widget.services.purchases.openSubscriptionManagement();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pretplatu nije moguće otvoriti: $error')),
        );
      }
    }
  }
}

class LetterCard extends StatelessWidget {
  const LetterCard({
    super.key,
    required this.letter,
    this.onStatus,
    this.onDelete,
    this.onTap,
  });
  final LetterAnalysis letter;
  final ValueChanged<LetterStatus>? onStatus;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Icon(
          letter.urgency == Urgency.high
              ? Icons.priority_high
              : Icons.description_outlined,
        ),
      ),
      title: Text(letter.title),
      subtitle: Text(
        '${context.strings.category(letter.category.name)}'
        '${letter.deadline == null ? '' : ' • ${context.strings.text('deadline')} ${letter.deadline!.day}.${letter.deadline!.month}.'}',
      ),
      trailing: onStatus == null && onDelete == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onDelete != null)
                  IconButton(
                    tooltip: context.strings.text('deleteDocument'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                if (onStatus != null)
                  PopupMenuButton<LetterStatus>(
                    tooltip: context.strings.text('progressStatus'),
                    onSelected: onStatus,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: LetterStatus.newLetter,
                        child: Text(context.strings.text('newStatus')),
                      ),
                      PopupMenuItem(
                        value: LetterStatus.inProgress,
                        child: Text(context.strings.text('progressStatus')),
                      ),
                      PopupMenuItem(
                        value: LetterStatus.done,
                        child: Text(context.strings.text('doneStatus')),
                      ),
                    ],
                  ),
              ],
            ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Colors.blueGrey),
        const SizedBox(height: 12),
        Text(text),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: .12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    ),
  );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.content});
  final String title;
  final String content;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    this.action,
    this.selected = false,
  });
  final String title;
  final String price;
  final List<String> features;
  final VoidCallback? action;
  final bool selected;
  @override
  Widget build(BuildContext context) => Card(
    color: selected ? const Color(0xFFE7ECFF) : null,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(price, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('✓ $f'),
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton(
                onPressed: action,
                child: Text(context.strings.text('choosePlanButton')),
              ),
            ),
        ],
      ),
    ),
  );
}
