import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
    if (!kIsWeb) {
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
    final requestedAiLanguage = kIsWeb
        ? (Uri.base.queryParameters['ai_lang'] ??
              Uri.base.queryParameters['lang'])
        : null;
    final storedLegacyLanguage = preferences.getString('briefai.ui-language');
    final aiLanguage =
        requestedAiLanguage != null &&
            AppStrings.languageLabels.containsKey(requestedAiLanguage)
        ? requestedAiLanguage
        : preferences.getString('briefai.ai-language') ??
              storedLegacyLanguage ??
              await widget.services.auth.preferredLanguage();
    final storedInterfaceLanguage = preferences.getString(
      'briefai.interface-language',
    );
    final interfaceLanguage =
        storedInterfaceLanguage != null &&
            AppStrings.hasFullyLocalizedInterface(storedInterfaceLanguage)
        ? storedInterfaceLanguage
        : AppStrings.hasFullyLocalizedInterface(aiLanguage)
        ? aiLanguage
        : 'en';
    _state
      ..setLocale(interfaceLanguage)
      ..setAiLanguage(aiLanguage);
    await preferences.setString(
      'briefai.interface-language',
      interfaceLanguage,
    );
    await preferences.setString('briefai.ai-language', aiLanguage);
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
  int _vaultBinding = 0;

  @override
  void initState() {
    super.initState();
    widget.services.household.addListener(_onHouseholdProfileChanged);
    unawaited(_bindLocalVault());
    unawaited(widget.services.analytics.trackPageView());
    if (widget.services.cloudEnabled) {
      _authSubscription = widget.services.auth.authChanges.listen((user) {
        unawaited(_bindLocalVault());
        _entitlementSubscription?.cancel();
        _usageSubscription?.cancel();
        if (mounted) setState(() {});
        if (user != null) {
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

  void _onHouseholdProfileChanged() => unawaited(_bindLocalVault());

  Future<void> _bindLocalVault() async {
    final binding = ++_vaultBinding;
    await _lettersSubscription?.cancel();
    _lettersSubscription = null;
    if (!mounted || binding != _vaultBinding) return;
    widget.state.replaceLetters(const []);

    final baseVault = widget.services.auth.localVaultKey;
    await widget.services.household.bindOwner(baseVault);
    final personalVault = widget.services.household.personalVault(baseVault);
    await widget.services.letters.claimLegacyDeviceVault(personalVault);
    await widget.services.letters.moveBaseVaultToPersonal(
      baseVault,
      personalVault,
    );
    final ownerKey = widget.services.currentVaultKey;
    if (!mounted || binding != _vaultBinding) return;
    _lettersSubscription = widget.services.letters
        .watch(ownerKey)
        .listen(widget.state.replaceLetters);
  }

  @override
  void dispose() {
    _lettersSubscription?.cancel();
    _entitlementSubscription?.cancel();
    _usageSubscription?.cancel();
    _authSubscription?.cancel();
    widget.services.household.removeListener(_onHouseholdProfileChanged);
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
    final cloudUnavailable = !services.cloudEnabled && !kDebugMode;
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
        AnalyticsConsentCard(analytics: services.analytics),
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
                state.isPremium
                    ? strings.text('monthlyPlanActive')
                    : strings.remaining(
                        kFreeAnalysisLimit - state.freeAnalysesUsed,
                      ),
                style: const TextStyle(color: Color(0xFFD7E0FF)),
              ),
              if (cloudUnavailable) ...[
                const SizedBox(height: 10),
                const Text(
                  'Online AI trenutno nije dostupan. '
                  'OCR i lokalna analiza i dalje rade na ovom uređaju.',
                  style: TextStyle(color: Color(0xFFFFE0B2)),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: state.canAnalyse
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
                      : strings.text('choosePlanButton'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _DeadlineOverviewCard(state: state, services: services),
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

class _DeadlineOverviewCard extends StatelessWidget {
  const _DeadlineOverviewCard({required this.state, required this.services});

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final overview = _deadlineOverview(state.letters);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: overview.overdue > 0
              ? Colors.red.withValues(alpha: .12)
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.calendar_month_outlined,
            color: overview.overdue > 0 ? Colors.red.shade700 : null,
          ),
        ),
        title: const Text('Kalendar rokova'),
        subtitle: Text(
          overview.total == 0
              ? 'Nema otvorenih rokova.'
              : '${overview.today} danas · ${overview.thisWeek} ove nedelje · ${overview.overdue} kasni',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                DeadlineCenterScreen(state: state, services: services),
          ),
        ),
      ),
    );
  }
}

class AnalyticsConsentCard extends StatefulWidget {
  const AnalyticsConsentCard({super.key, required this.analytics});
  final PrivacyAnalyticsService analytics;

  @override
  State<AnalyticsConsentCard> createState() => _AnalyticsConsentCardState();
}

class _AnalyticsConsentCardState extends State<AnalyticsConsentCard> {
  bool _loading = true;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final choice = await widget.analytics.consentChoice();
    if (mounted) {
      setState(() {
        _loading = false;
        _visible = choice == null;
      });
    }
  }

  Future<void> _choose(bool allowed) async {
    await widget.analytics.setConsent(allowed);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_visible) return const SizedBox.shrink();
    final code = Localizations.localeOf(context).languageCode;
    final copy = switch (code) {
      'de' => (
        'Datenschutz-Einstellung',
        'Dürfen wir anonyme Besuchs- und Installationsmetriken erfassen? Keine Briefe, OCR-Texte, Chats oder E-Mail-Adressen werden dafür gespeichert.',
        'Ablehnen',
        'Akzeptieren',
      ),
      'en' => (
        'Privacy choice',
        'May we measure anonymous visits and installation clicks? We never store letters, OCR text, chats or email addresses for this.',
        'Decline',
        'Accept',
      ),
      'tr' => (
        'Gizlilik seçimi',
        'Anonim ziyaret ve kurulum tıklamalarını ölçmemize izin veriyor musunuz? Mektuplar, OCR metinleri, sohbetler veya e-posta adresleri saklanmaz.',
        'Reddet',
        'Kabul et',
      ),
      'bg' => (
        'Поверителност',
        'Позволявате ли анонимно измерване на посещения и кликвания за инсталация? Не се съхраняват писма, OCR текстове, чатове или имейл адреси.',
        'Отказ',
        'Приемам',
      ),
      'mk' => (
        'Приватност',
        'Дали дозволувате анонимно мерење на посети и кликови за инсталација? Не се чуваат писма, OCR текстови, разговори или е-пошта.',
        'Одбиј',
        'Прифати',
      ),
      _ => (
        'Izbor privatnosti',
        'Da li dozvoljavate anonimno merenje poseta i klikova za instalaciju? Ne čuvamo pisma, OCR tekst, chat ni email adresu.',
        'Odbij',
        'Prihvatam',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                copy.$1,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(copy.$2),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () => unawaited(_choose(false)),
                    child: Text(copy.$3),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => unawaited(_choose(true)),
                    child: Text(copy.$4),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      state.setLocale(language);
      final preferences = await SharedPreferences.getInstance();
      try {
        await preferences.setString('briefai.interface-language', language);
      } on Object {
        // The visible language changes immediately. Persistence can be retried
        // without reverting the user's explicit selection.
      }
    },
    itemBuilder: (_) => AppStrings.interfaceLanguageEntries
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
                Flexible(child: Text(AppStrings.languagePickerLabel(entry))),
              ],
            ),
          ),
        )
        .toList(),
  );
}

class _AiLanguageMenu extends StatelessWidget {
  const _AiLanguageMenu({required this.state, required this.services});

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: context.strings.text('preferredLanguage'),
    initialValue: state.aiLanguageCode,
    icon: const Icon(Icons.keyboard_arrow_down),
    onSelected: (language) async {
      state.setAiLanguage(language);
      try {
        await services.auth.setPreferredLanguage(language);
      } on Object {
        // AI language remains selected locally even if cloud profile sync is
        // temporarily unavailable.
      }
    },
    itemBuilder: (_) => AppStrings.aiLanguageEntries
        .map(
          (entry) => PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                if (entry.key == state.aiLanguageCode)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.check, size: 18),
                  ),
                Flexible(child: Text(AppStrings.languagePickerLabel(entry))),
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
  // Most people arriving here from the public landing page are new.  Starting
  // with registration prevents them from mistaking the sign-in form for a
  // broken registration flow; returning users can switch to sign-in directly.
  bool _create = true;
  bool _loading = false;
  bool _showEmailForm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final appleAvailable =
        kIsWeb || Theme.of(context).platform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: Text(
          _create ? strings.text('createAccount') : strings.text('signIn'),
        ),
        backgroundColor: const Color(0xFF0B1533),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
              children: [
                Text(
                  _create
                      ? strings.text('createAccount')
                      : strings.text('signIn'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF0B1533),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.text('secureLetters'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF4C5B78),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                _GoogleSignInButton(
                  onPressed: _loading ? null : _google,
                  label: Text(strings.text('continueGoogle')),
                ),
                if (appleAvailable) ...[
                  const SizedBox(height: 12),
                  IgnorePointer(
                    ignoring: _loading,
                    child: Opacity(
                      opacity: _loading ? 0.6 : 1,
                      child: SignInWithAppleButton(
                        key: const ValueKey('apple-sign-in'),
                        onPressed: _apple,
                        text: strings.text('continueApple'),
                        height: 48,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Divider(color: const Color(0xFFD8DFEC), height: 1),
                const SizedBox(height: 12),
                TextButton.icon(
                  key: const ValueKey('show-email-auth'),
                  onPressed: _loading
                      ? null
                      : () => setState(() => _showEmailForm = !_showEmailForm),
                  icon: Icon(
                    _showEmailForm ? Icons.expand_less : Icons.mail_outline,
                  ),
                  label: Text(strings.text('continueEmail')),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: !_showEmailForm
                      ? const SizedBox.shrink(
                          key: ValueKey('email-auth-hidden'),
                        )
                      : Padding(
                          key: const ValueKey('email-auth-visible'),
                          padding: const EdgeInsets.only(top: 16),
                          child: _EmailAuthForm(
                            create: _create,
                            loading: _loading,
                            email: _email,
                            password: _password,
                            strings: strings,
                            onModeChanged: (value) =>
                                setState(() => _create = value),
                            onSubmit: _emailSignIn,
                          ),
                        ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 22),
                  const Center(
                    child: SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _emailSignIn() async {
    final email = _email.text.trim();
    if (!email.contains('@') || _password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.strings.text('signInFailed')}. '
            '${context.strings.text('tryAgain')}',
          ),
        ),
      );
      return;
    }
    await _run(() async {
      await widget.services.auth.signInWithEmail(
        email,
        _password.text,
        create: _create,
      );
      if (_create) unawaited(widget.services.analytics.trackRegistration());
    });
  }

  Future<void> _google() => _run(widget.services.auth.signInWithGoogle);
  Future<void> _apple() => _run(widget.services.auth.signInWithApple);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_authenticationError(error))));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      if (error.code == 'unauthenticated') {
        await widget.services.auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('sessionExpired'))),
        );
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SignInScreen(services: widget.services),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.strings.text('signInFailed')}. '
            '${context.strings.text('tryAgain')}',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.strings.text('signInFailed')}. '
              '${context.strings.text('tryAgain')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _authenticationError(FirebaseAuthException _) =>
      '${context.strings.text('signInFailed')}. '
      '${context.strings.text('tryAgain')}';
}

class _EmailAuthForm extends StatelessWidget {
  const _EmailAuthForm({
    required this.create,
    required this.loading,
    required this.email,
    required this.password,
    required this.strings,
    required this.onModeChanged,
    required this.onSubmit,
  });

  final bool create;
  final bool loading;
  final TextEditingController email;
  final TextEditingController password;
  final AppStrings strings;
  final ValueChanged<bool> onModeChanged;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SegmentedButton<bool>(
        segments: [
          ButtonSegment<bool>(
            value: true,
            label: Text(strings.text('createAccount')),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
          ButtonSegment<bool>(
            value: false,
            label: Text(strings.text('signIn')),
            icon: const Icon(Icons.login),
          ),
        ],
        selected: {create},
        onSelectionChanged: loading
            ? null
            : (selection) => onModeChanged(selection.single),
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey('email-auth-field'),
        controller: email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: strings.text('email')),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: password,
        obscureText: true,
        autofillHints: create
            ? const [AutofillHints.newPassword]
            : const [AutofillHints.password],
        decoration: InputDecoration(labelText: strings.text('password')),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: loading ? null : () => unawaited(onSubmit()),
        child: Text(
          create ? strings.text('createAccount') : strings.text('signIn'),
        ),
      ),
      TextButton(
        onPressed: loading ? null : () => onModeChanged(!create),
        child: Text(
          create ? strings.text('haveAccount') : strings.text('needAccount'),
        ),
      ),
    ],
  );
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          disabledForegroundColor: const Color(
            0xFF1F1F1F,
          ).withValues(alpha: 0.5),
          side: const BorderSide(color: Color(0xFF747775)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
        // Google’s sign-in layout keeps its mark on the leading edge while
        // the label remains centered in the full button. OutlinedButton.icon
        // centers both as a single group, which makes the control look wrong
        // on wide screens and tablets.
        child: SizedBox(
          width: double.infinity,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox.square(
                  dimension: 20,
                  child: Padding(
                    padding: EdgeInsets.all(1),
                    child: _GoogleMark(),
                  ),
                ),
              ),
              Center(child: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/branding/google_g_logo.svg',
    semanticsLabel: 'Google',
  );
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
  static const _maxDocumentPages = 20;
  static const _maxDocumentBytes = 50 * 1024 * 1024;

  final _text = TextEditingController();
  final List<PickedDocument> _documents = [];
  bool _loading = false;
  bool _selecting = false;
  bool _recognizing = false;
  bool _ocrComplete = false;
  int _ocrCurrentPage = 0;

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
                      : () => _selectOne(widget.services.documents.capture),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(strings.text('camera')),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _selectMany(
                          widget.services.documents.galleryMultiple,
                        ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(strings.text('gallery')),
                ),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _selectMany(widget.services.documents.files),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(strings.text('pdfImage')),
                ),
              ],
            ),
            if (_documents.isNotEmpty) _buildDocumentPages(strings),
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
                          ? strings.ocrProgress(
                              _ocrCurrentPage,
                              _documents.length,
                            )
                          : _selecting
                          ? strings.text('loadingImage')
                          : strings.text('processing')
                    : strings.text('analyzeLetter'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentPages(AppStrings strings) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.pagesSelected(_documents.length),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              _recognizing
                  ? strings.ocrProgress(_ocrCurrentPage, _documents.length)
                  : _ocrComplete
                  ? strings.text('ocrReady')
                  : strings.text('photoReadyForAnalysis'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _ocrComplete
                    ? Colors.green.shade700
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_recognizing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                minHeight: 3,
                value: _documents.isEmpty
                    ? null
                    : _ocrCurrentPage / _documents.length,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _documents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final document = _documents[index];
                  return SizedBox(
                    width: 92,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: document.isPdf
                                      ? ColoredBox(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.picture_as_pdf_outlined,
                                            size: 38,
                                          ),
                                        )
                                      : Image.memory(
                                          document.bytes,
                                          cacheWidth: 256,
                                          filterQuality: FilterQuality.low,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const ColoredBox(
                                                color: Color(0xFFE8ECF4),
                                                child: Icon(
                                                  Icons.description_outlined,
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: IconButton.filledTonal(
                                  constraints: const BoxConstraints.tightFor(
                                    width: 30,
                                    height: 30,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  tooltip: strings.text('removePage'),
                                  onPressed: _loading
                                      ? null
                                      : () => _removeDocument(index),
                                  icon: const Icon(Icons.close, size: 17),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strings.text('page')} ${index + 1}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyse() async {
    if (!await _ensureCloudAiAccess(context, widget.services)) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _selecting = false;
    });
    final enterTextFirst = context.strings.text('enterTextFirst');
    try {
      final id = newLetterId();
      final language = widget.state.aiLanguageCode;
      if (_documents.isNotEmpty && _text.text.trim().isEmpty) {
        setState(() {
          _recognizing = true;
          _ocrCurrentPage = 1;
        });
        await WidgetsBinding.instance.endOfFrame;
        final recognized = await widget.services.documents.ocrAll(
          _documents,
          onProgress: (current, _) {
            if (mounted) setState(() => _ocrCurrentPage = current);
          },
        );
        if (!mounted) return;
        setState(() {
          _text.text = recognized;
          _text.selection = TextSelection.collapsed(offset: recognized.length);
          _ocrComplete = true;
          _recognizing = false;
        });
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
        widget.services.currentVaultKey,
        analysis,
        documents: List<PickedDocument>.unmodifiable(_documents),
      );
      if (!widget.state.isPremium && widget.services.auth.uid == null) {
        await widget.services.entitlements.recordAnalysis('local-device');
        widget.state.setFreeAnalysesUsed(widget.state.freeAnalysesUsed + 1);
      }
      widget.state.addAnalysis(analysis);
      // A notification permission or OEM scheduler failure must never hide a
      // completed AI result. The analysis remains available even if reminders
      // cannot be registered on this device.
      try {
        await widget.services.reminders.schedule(analysis, language: language);
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
        setState(() {
          _loading = false;
          _recognizing = false;
        });
      }
    }
  }

  Future<void> _selectOne(Future<PickedDocument?> Function() source) async {
    await _selectMany(() async {
      final selected = await source();
      return selected == null ? const <PickedDocument>[] : [selected];
    });
  }

  Future<void> _selectMany(
    Future<List<PickedDocument>> Function() source,
  ) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _selecting = true;
      _recognizing = false;
    });
    try {
      final selected = await source();
      if (selected.isEmpty || !mounted) return;
      _appendDocuments(selected);
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
          _selecting = false;
          _recognizing = false;
        });
      }
    }
  }

  void _appendDocuments(List<PickedDocument> selected) {
    final availableSlots = _maxDocumentPages - _documents.length;
    final accepted = <PickedDocument>[];
    var totalBytes = _documents.fold<int>(
      0,
      (sum, document) => sum + document.bytes.length,
    );
    var sizeLimitReached = false;
    for (final document in selected.take(math.max(0, availableSlots))) {
      if (totalBytes + document.bytes.length > _maxDocumentBytes) {
        sizeLimitReached = true;
        break;
      }
      accepted.add(document);
      totalBytes += document.bytes.length;
    }
    if (accepted.isNotEmpty) {
      setState(() {
        _documents.addAll(accepted);
        _ocrComplete = false;
        _ocrCurrentPage = 0;
        _text.clear();
      });
    }
    if (selected.length > availableSlots) {
      _showSelectionMessage(context.strings.maxPages(_maxDocumentPages));
    } else if (sizeLimitReached) {
      _showSelectionMessage(context.strings.text('filesTooLarge'));
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
      _ocrComplete = false;
      _ocrCurrentPage = 0;
      _text.clear();
    });
  }

  void _showSelectionMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          if (letter.documentType != null)
            _ResultSection(
              title: strings.text('documentType'),
              content: letter.documentType!,
            ),
          if (letter.senderName != null)
            _ResultSection(
              title: strings.text('senderName'),
              content: letter.senderName!,
            ),
          if (letter.recipientName != null)
            _ResultSection(
              title: strings.text('recipientName'),
              content: letter.recipientName!,
            ),
          if (letter.paymentRecipient != null)
            _ResultSection(
              title: strings.text('paymentRecipient'),
              content: letter.paymentRecipient!,
            ),
          if (letter.paymentIban != null)
            _ResultSection(title: 'IBAN', content: letter.paymentIban!),
          if (letter.invoiceNumber != null)
            _ResultSection(
              title: strings.text('invoiceNumber'),
              content: letter.invoiceNumber!,
            ),
          if (letter.servicePeriod != null)
            _ResultSection(
              title: strings.text('servicePeriod'),
              content: letter.servicePeriod!,
            ),
          if (letter.paymentReference != null)
            _ResultSection(
              title: strings.text('paymentReference'),
              content: letter.paymentReference!,
            ),
          _ResultSection(
            title: strings.text('simpleExplanation'),
            content: letter.plainExplanation,
          ),
          _ResultSection(
            title: strings.text('category'),
            content: strings.category(letter.category.name),
          ),
          _ResultSection(title: 'Folder', content: _folderLabel(letter.folder)),
          if (letter.tags.isNotEmpty)
            _ResultSection(title: 'Oznake', content: letter.tags.join(', ')),
          if (letter.deadline != null)
            _ResultSection(
              title: strings.text('deadline'),
              content:
                  '${letter.deadline!.day.toString().padLeft(2, '0')}.${letter.deadline!.month.toString().padLeft(2, '0')}.${letter.deadline!.year}',
            ),
          if (letter.isPaymentObligation)
            _ResultSection(
              title: strings.text('paymentObligation'),
              content: letter.paymentPaid
                  ? strings.text('paymentPaid')
                  : strings.text('paymentOpen'),
            ),
          if (letter.paymentDueDate != null)
            _ResultSection(
              title: strings.text('paymentDueDate'),
              content:
                  '${letter.paymentDueDate!.day.toString().padLeft(2, '0')}.${letter.paymentDueDate!.month.toString().padLeft(2, '0')}.${letter.paymentDueDate!.year}',
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
              final documents = await services.letters.loadDocuments(
                services.currentVaultKey,
                letter.id,
              );
              if (!context.mounted) return;
              if (documents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.text('originalMissing'))),
                );
                return;
              }
              await services.exports.shareDocuments(documents);
            },
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(strings.text('openOriginal')),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              if (!await _ensureCloudAiAccess(context, services) ||
                  !context.mounted) {
                return;
              }
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResponseScreen(
                    state: state,
                    letter: letter,
                    services: services,
                  ),
                ),
              );
            },
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
    required this.state,
    required this.letter,
    required this.services,
  });
  final AppState state;
  final LetterAnalysis letter;
  final AppServices services;

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  final _facts = TextEditingController();
  late final String _vaultKey;
  Future<GeneratedReply>? _response;
  bool _emailVersion = false;
  bool _restoringReply = true;

  @override
  void initState() {
    super.initState();
    // Keep a response tied to the same local owner that opened this letter.
    // An auth refresh or a manual sign-out while AI is generating must never
    // redirect the save to another account's archive.
    _vaultKey = widget.services.currentVaultKey;
    unawaited(_restoreSavedReply());
  }

  @override
  void dispose() {
    _facts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('replyTitle'))),
      body: _restoringReply
          ? const Center(child: CircularProgressIndicator())
          : _response == null
          ? _buildFactsForm(strings)
          : _buildGeneratedReply(strings),
    );
  }

  Widget _buildFactsForm(AppStrings strings) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          strings.text('replyFactsTitle'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(strings.text('replyFactsHelp')),
        const SizedBox(height: 16),
        TextField(
          controller: _facts,
          minLines: 7,
          maxLines: 14,
          maxLength: 30000,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: strings.text('replyFactsHint'),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _generateReply,
          icon: const Icon(Icons.auto_awesome),
          label: Text(strings.text('generateReply')),
        ),
      ],
    );
  }

  Widget _buildGeneratedReply(AppStrings strings) {
    final response = _response!;
    return FutureBuilder<GeneratedReply>(
      future: response,
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
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(strings.text('replySavedLocally'))),
                ],
              ),
              const SizedBox(height: 12),
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
                onPressed: () => _composeEmail(snapshot.data!, strings),
                icon: const Icon(Icons.email_outlined),
                label: Text(strings.text('sendEmail')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _savePdf(snapshot.data!, strings),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(strings.text('savePdf')),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _response = null),
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.text('editReplyContext')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _restoreSavedReply() async {
    try {
      // Analyses created moments before the user signs in lived in the local
      // anonymous vault. Claim them once for this account before reading the
      // reply, so a long letter never appears to vanish during that handoff.
      await widget.services.letters.claimLegacyDeviceVault(_vaultKey);
      final saved = await widget.services.letters.loadGeneratedReply(
        _vaultKey,
        widget.letter.id,
      );
      if (!mounted) return;
      if (saved != null) {
        _facts.text = saved.userContext;
        _response = Future<GeneratedReply>.value(saved.reply);
      }
    } finally {
      if (mounted) setState(() => _restoringReply = false);
    }
  }

  Future<void> _generateReply() async {
    final facts = _facts.text.trim();
    final response = widget.services.ai.generateReply(
      letterId: widget.letter.id,
      sourceText: widget.letter.sourceText,
      facts: facts.isEmpty
          ? 'The user did not provide additional facts.'
          : facts,
    );
    setState(() {
      _response = response;
    });
    try {
      final generated = await response;
      await widget.services.letters.claimLegacyDeviceVault(_vaultKey);
      final saved = await widget.services.letters.saveGeneratedReply(
        _vaultKey,
        widget.letter.id,
        generated,
        userContext: facts,
      );
      if (!saved) {
        throw StateError('The letter is not available in this local archive.');
      }
      await widget.services.letters.updateOrganisation(
        _vaultKey,
        widget.letter.id,
        status: LetterStatus.replyPrepared,
      );
      widget.state.updateStatus(widget.letter.id, LetterStatus.replyPrepared);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('replySavedLocally'))),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.strings.text('responseUnavailable')}. '
              '${context.strings.text('tryAgain')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _savePdf(GeneratedReply reply, AppStrings strings) async {
    try {
      await widget.services.exports.savePdf(
        title: 'BriefAI Germany — ${widget.letter.title}',
        body: _emailVersion ? reply.email : reply.letter,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('pdfReady'))));
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${strings.text('pdfSaveFailed')}: $error')),
        );
      }
    }
  }

  Future<void> _composeEmail(GeneratedReply reply, AppStrings strings) async {
    try {
      await widget.services.exports.composeEmail(
        subject: 'Antwort: ${widget.letter.title}',
        body: reply.email,
      );
      await widget.services.letters.updateOrganisation(
        _vaultKey,
        widget.letter.id,
        status: LetterStatus.sent,
      );
      widget.state.updateStatus(widget.letter.id, LetterStatus.sent);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${strings.text('emailOpenFailed')}: $error')),
        );
      }
    }
  }
}

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  LetterFolder? _folder;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final letters = _folder == null
        ? widget.state.letters
        : widget.state.letters
              .where((letter) => letter.folder == _folder)
              .toList(growable: false);
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
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sve'),
              selected: _folder == null,
              onSelected: (_) => setState(() => _folder = null),
            ),
            ...LetterFolder.values.map(
              (folder) => ChoiceChip(
                label: Text(_folderLabel(folder)),
                selected: _folder == folder,
                onSelected: (_) => setState(() => _folder = folder),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (letters.isEmpty)
          _EmptyState(
            icon: Icons.folder_off_outlined,
            text: _folder == null
                ? strings.text('emptyLetters')
                : 'Nema pisama u ovom folderu.',
          )
        else
          ...letters.map(
            (letter) => LetterCard(
              letter: letter,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    state: widget.state,
                    letter: letter,
                    services: widget.services,
                  ),
                ),
              ),
              onStatus: (status) async {
                widget.state.updateStatus(letter.id, status);
                await widget.services.letters.updateStatus(
                  widget.services.currentVaultKey,
                  letter.id,
                  status,
                );
                if (status == LetterStatus.done) {
                  await widget.services.reminders.cancel(letter.id);
                } else {
                  await widget.services.reminders.schedule(
                    letter.copyWith(status: status),
                    language: widget.state.aiLanguageCode,
                  );
                }
              },
              onOrganize: () => _showLetterOrganiser(
                context,
                letter: letter,
                state: widget.state,
                services: widget.services,
              ),
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
                        await widget.services.letters.delete(
                          widget.services.currentVaultKey,
                          letter.id,
                        );
                        await widget.services.reminders.cancel(letter.id);
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
  String? _selectedLetterId;
  bool _sending = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final letters = widget.state.letters;
    final selectedLetter =
        letters.where((letter) => letter.id == _selectedLetterId).firstOrNull ??
        (letters.isEmpty ? null : letters.first);
    final archiveCopy = _assistantArchiveCopy(widget.state.aiLanguageCode);
    final visibleMessages = _messages.isEmpty
        ? [
            _ChatMessage(
              text: selectedLetter == null
                  ? strings.text('assistantHello')
                  : '${archiveCopy.ready}\n${selectedLetter.title}',
              fromUser: false,
            ),
          ]
        : _messages;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('assistantTitle'))),
      body: Column(
        children: [
          if (letters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    archiveCopy.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedLetter?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: letters
                        .map(
                          (letter) => DropdownMenuItem(
                            value: letter.id,
                            child: Text(
                              '${letter.title} · ${letter.category.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _sending
                        ? null
                        : (id) => setState(() {
                            _selectedLetterId = id;
                            // Questions about one letter must never be used as
                            // context for another locally archived letter.
                            _messages.clear();
                          }),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _sending || selectedLetter == null
                        ? null
                        : () {
                            _question.text = archiveCopy.explainAgain;
                            _ask();
                          },
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(archiveCopy.explainButton),
                  ),
                ],
              ),
            ),
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
    if (!await _ensureCloudAiAccess(context, widget.services) || !mounted) {
      return;
    }
    final letter =
        widget.state.letters
            .where((candidate) => candidate.id == _selectedLetterId)
            .firstOrNull ??
        (widget.state.letters.isEmpty ? null : widget.state.letters.first);
    final conversation = _messages
        .take(8)
        .map(
          (message) => {
            'role': message.fromUser ? 'user' : 'assistant',
            'text': message.text,
          },
        )
        .toList();
    setState(() {
      _messages.add(_ChatMessage(text: question, fromUser: true));
      _question.clear();
      _sending = true;
    });
    try {
      final language = widget.state.aiLanguageCode;
      final answer = await widget.services.ai.askLetterAssistant(
        question: question,
        language: language,
        letter: letter,
        conversation: conversation,
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

class _AssistantArchiveCopy {
  const _AssistantArchiveCopy({
    required this.label,
    required this.ready,
    required this.explainButton,
    required this.explainAgain,
  });

  final String label;
  final String ready;
  final String explainButton;
  final String explainAgain;
}

_AssistantArchiveCopy _assistantArchiveCopy(String language) {
  switch (language) {
    case 'hr':
      return const _AssistantArchiveCopy(
        label: 'Pismo iz arhive',
        ready: 'Odabrano pismo iz lokalne arhive:',
        explainButton: 'Ponovno objasni ovo pismo',
        explainAgain:
            'Objasni mi ovo pismo ponovno detaljno i jednostavnim jezikom. Što se točno traži od mene i koji je sljedeći korak?',
      );
    case 'bs':
      return const _AssistantArchiveCopy(
        label: 'Pismo iz arhive',
        ready: 'Izabrano pismo iz lokalne arhive:',
        explainButton: 'Ponovo objasni ovo pismo',
        explainAgain:
            'Objasni mi ovo pismo ponovo detaljno i jednostavnim jezikom. Šta se tačno traži od mene i koji je sljedeći korak?',
      );
    case 'mk':
      return const _AssistantArchiveCopy(
        label: 'Писмо од архивата',
        ready: 'Избрано писмо од локалната архива:',
        explainButton: 'Објасни го писмово повторно',
        explainAgain:
            'Објасни ми го ова писмо повторно детално и со едноставен јазик. Што точно се бара од мене и кој е следниот чекор?',
      );
    case 'bg':
      return const _AssistantArchiveCopy(
        label: 'Писмо от архива',
        ready: 'Избрано писмо от локалния архив:',
        explainButton: 'Обясни отново това писмо',
        explainAgain:
            'Обясни ми това писмо отново подробно и на разбираем език. Какво точно се иска от мен и каква е следващата стъпка?',
      );
    case 'de':
      return const _AssistantArchiveCopy(
        label: 'Brief aus dem Archiv',
        ready: 'Ausgewählter Brief aus dem lokalen Archiv:',
        explainButton: 'Diesen Brief erneut erklären',
        explainAgain:
            'Erkläre mir diesen Brief noch einmal ausführlich und einfach. Was wird genau von mir verlangt und was ist mein nächster Schritt?',
      );
    case 'en':
      return const _AssistantArchiveCopy(
        label: 'Letter from archive',
        ready: 'Selected letter from the local archive:',
        explainButton: 'Explain this letter again',
        explainAgain:
            'Explain this letter again in detail and in simple language. What exactly is required from me and what should I do next?',
      );
    case 'tr':
      return const _AssistantArchiveCopy(
        label: 'Arşivdeki mektup',
        ready: 'Yerel arşivden seçilen mektup:',
        explainButton: 'Bu mektubu yeniden açıkla',
        explainAgain:
            'Bu mektubu tekrar ayrıntılı ve sade bir dille açıkla. Benden tam olarak ne isteniyor ve sonraki adımım nedir?',
      );
    case 'ru':
      return const _AssistantArchiveCopy(
        label: 'Письмо из архива',
        ready: 'Выбрано письмо из локального архива:',
        explainButton: 'Объяснить это письмо ещё раз',
        explainAgain:
            'Объясни это письмо ещё раз подробно и простыми словами. Что именно от меня требуется и что мне делать дальше?',
      );
    case 'uk':
      return const _AssistantArchiveCopy(
        label: 'Лист з архіву',
        ready: 'Вибрано лист із локального архіву:',
        explainButton: 'Пояснити цей лист ще раз',
        explainAgain:
            'Поясни цей лист ще раз докладно й простими словами. Що саме від мене вимагається і що мені робити далі?',
      );
    case 'ar':
      return const _AssistantArchiveCopy(
        label: 'رسالة من الأرشيف',
        ready: 'تم اختيار رسالة من الأرشيف المحلي:',
        explainButton: 'اشرح هذه الرسالة مرة أخرى',
        explainAgain:
            'اشرح لي هذه الرسالة مرة أخرى بالتفصيل وبلغة بسيطة. ما المطلوب مني تحديداً وما الخطوة التالية؟',
      );
    case 'ro':
      return const _AssistantArchiveCopy(
        label: 'Scrisoare din arhivă',
        ready: 'Scrisoare selectată din arhiva locală:',
        explainButton: 'Explică din nou această scrisoare',
        explainAgain:
            'Explică-mi din nou această scrisoare, detaliat și în limbaj simplu. Ce mi se cere exact și care este următorul pas?',
      );
    case 'pl':
      return const _AssistantArchiveCopy(
        label: 'Pismo z archiwum',
        ready: 'Wybrane pismo z lokalnego archiwum:',
        explainButton: 'Wyjaśnij to pismo ponownie',
        explainAgain:
            'Wyjaśnij mi to pismo ponownie, szczegółowo i prostym językiem. Czego dokładnie się ode mnie wymaga i jaki jest następny krok?',
      );
    case 'it':
      return const _AssistantArchiveCopy(
        label: 'Lettera dall’archivio',
        ready: 'Lettera selezionata dall’archivio locale:',
        explainButton: 'Spiega di nuovo questa lettera',
        explainAgain:
            'Spiegami di nuovo questa lettera in modo dettagliato e semplice. Che cosa mi viene richiesto esattamente e qual è il prossimo passo?',
      );
    case 'el':
      return const _AssistantArchiveCopy(
        label: 'Επιστολή από το αρχείο',
        ready: 'Επιλεγμένη επιστολή από το τοπικό αρχείο:',
        explainButton: 'Εξήγησε ξανά αυτή την επιστολή',
        explainAgain:
            'Εξήγησέ μου ξανά αυτή την επιστολή αναλυτικά και με απλά λόγια. Τι ακριβώς ζητείται από εμένα και ποιο είναι το επόμενο βήμα;',
      );
    case 'sq':
      return const _AssistantArchiveCopy(
        label: 'Letër nga arkivi',
        ready: 'Letra e zgjedhur nga arkivi lokal:',
        explainButton: 'Shpjegoje përsëri këtë letër',
        explainAgain:
            'Ma shpjego përsëri këtë letër me hollësi dhe me gjuhë të thjeshtë. Çfarë kërkohet saktësisht nga unë dhe cili është hapi tjetër?',
      );
    case 'sr':
      return const _AssistantArchiveCopy(
        label: 'Pismo iz arhive',
        ready: 'Izabrano pismo iz lokalne arhive:',
        explainButton: 'Objasni ovo pismo ponovo',
        explainAgain:
            'Objasni mi ovo pismo ponovo detaljno i jednostavnim jezikom. Šta se tačno traži od mene i koji je sledeći korak?',
      );
    default:
      return const _AssistantArchiveCopy(
        label: 'Letter from archive',
        ready: 'Selected letter from the local archive:',
        explainButton: 'Explain this letter again',
        explainAgain:
            'Explain this letter again in detail and in simple language. What exactly is required from me and what should I do next?',
      );
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
              final aiLanguage = state.aiLanguageCode;
              final country = profile['countryOfOrigin'] as String? ?? '';
              final name = profile['displayName'] as String? ?? '';
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(strings.text('optionalProfileName')),
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
                    title: Text(strings.text('appLanguage')),
                    subtitle: Text(
                      AppStrings.languageLabels[state.localeCode] ??
                          state.localeCode,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        state.setLocale(value);
                        try {
                          final preferences =
                              await SharedPreferences.getInstance();
                          await preferences.setString(
                            'briefai.interface-language',
                            value,
                          );
                        } on Object {
                          // Keep the selected UI language even during a
                          // temporary local-storage or cloud synchronization
                          // failure.
                        }
                      },
                      itemBuilder: (_) => AppStrings.interfaceLanguageEntries
                          .map(
                            (entry) => PopupMenuItem(
                              value: entry.key,
                              child: Text(
                                AppStrings.languagePickerLabel(entry),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(strings.text('preferredLanguage')),
                    subtitle: Text(
                      AppStrings.languageLabels[aiLanguage] ?? aiLanguage,
                    ),
                    trailing: PopupMenuButton<String>(
                      initialValue: aiLanguage,
                      onSelected: (value) async {
                        state.setAiLanguage(value);
                        try {
                          await services.auth.setPreferredLanguage(value);
                        } on Object {
                          // A local choice remains active if profile sync is
                          // temporarily unavailable.
                        }
                      },
                      itemBuilder: (_) => AppStrings.aiLanguageEntries
                          .map(
                            (entry) => PopupMenuItem(
                              value: entry.key,
                              child: Text(
                                AppStrings.languagePickerLabel(entry),
                              ),
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
              AppStrings.languageLabels[state.localeCode] ?? state.localeCode,
            ),
            trailing: _LanguageMenu(state: state, services: services),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(strings.text('preferredLanguage')),
            subtitle: Text(
              AppStrings.languageLabels[state.aiLanguageCode] ??
                  state.aiLanguageCode,
            ),
            trailing: _AiLanguageMenu(state: state, services: services),
          ),
          ListTile(
            leading: const Icon(Icons.public),
            title: Text(strings.text('country')),
            subtitle: Text(strings.text('signInForProfile')),
          ),
        ],
        const Divider(),
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
          leading: const Icon(Icons.family_restroom_outlined),
          title: const Text('Porodični profili'),
          subtitle: Text('Aktivan profil: ${services.household.active.name}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HouseholdProfilesScreen(services: services),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: const Text('Šifrovani backup arhive'),
          subtitle: const Text('Izvoz i vraćanje samo uz vašu lozinku'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  EncryptedBackupScreen(state: state, services: services),
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
                      await services.letters.clearAll(services.currentVaultKey);
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
                          services.currentVaultKey,
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

class HouseholdProfilesScreen extends StatefulWidget {
  const HouseholdProfilesScreen({super.key, required this.services});
  final AppServices services;

  @override
  State<HouseholdProfilesScreen> createState() =>
      _HouseholdProfilesScreenState();
}

class _HouseholdProfilesScreenState extends State<HouseholdProfilesScreen> {
  Future<void> _add() async {
    final name = TextEditingController();
    final pin = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Novi porodični profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Ime profila'),
              ),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'PIN (opciono)',
                  helperText: 'Za zajednički uređaj preporučujemo PIN.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kreiraj'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.services.household.add(
        name: name.text,
        pin: pin.text.isEmpty ? null : pin.text,
      );
      if (mounted) setState(() {});
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      name.dispose();
      pin.dispose();
    }
  }

  Future<void> _activate(HouseholdProfile profile) async {
    var pin = '';
    if (profile.hasPin) {
      final controller = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('PIN: ${profile.name}'),
          content: TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Otkaži'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Otvori'),
            ),
          ],
        ),
      );
      pin = controller.text;
      controller.dispose();
      if (ok != true) return;
    }
    final activated = await widget.services.household.activate(
      profile.id,
      pin: pin,
    );
    if (!mounted) return;
    if (!activated) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN nije ispravan.')));
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.services.household.profiles;
    return Scaffold(
      appBar: AppBar(title: const Text('Porodični profili')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Dodaj profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Svaki profil ima odvojenu lokalnu arhivu. Originali, OCR i odgovori ne odlaze u cloud.',
          ),
          const SizedBox(height: 16),
          ...profiles.map(
            (profile) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    profile.hasPin ? Icons.lock_outline : Icons.person_outline,
                  ),
                ),
                title: Text(profile.name),
                subtitle: Text(
                  profile.id == widget.services.household.activeId
                      ? 'Aktivan profil'
                      : 'Odvojena lokalna arhiva',
                ),
                trailing: profile.id == widget.services.household.activeId
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: () => _activate(profile),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EncryptedBackupScreen extends StatefulWidget {
  const EncryptedBackupScreen({
    super.key,
    required this.state,
    required this.services,
  });
  final AppState state;
  final AppServices services;

  @override
  State<EncryptedBackupScreen> createState() => _EncryptedBackupScreenState();
}

class _EncryptedBackupScreenState extends State<EncryptedBackupScreen> {
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    if (_password.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lozinka mora imati najmanje 10 znakova.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final payload = <String, dynamic>{
        'schemaVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'profile': widget.services.household.active.name,
        'letters': await widget.services.letters.exportRecords(
          widget.services.currentVaultKey,
        ),
      };
      final encrypted = await widget.services.backups.encrypt(
        payload: payload,
        passphrase: _password.text,
      );
      await widget.services.exports.shareEncryptedBackup(encrypted);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Šifrovani backup je spreman za čuvanje.'),
          ),
        );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup nije uspeo: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_password.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unesite lozinku backupa.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final encoded = await widget.services.backups.pickEncryptedBackup();
      if (encoded == null) return;
      final payload = await widget.services.backups.decrypt(
        encodedBackup: encoded,
        passphrase: _password.text,
      );
      final rawLetters = payload['letters'];
      if (rawLetters is! List)
        throw const FormatException('Backup does not contain an archive.');
      final records = rawLetters
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
      final count = await widget.services.letters.importRecords(
        widget.services.currentVaultKey,
        records,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vraćeno lokalno: $count pisama.')),
        );
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Vraćanje nije uspelo: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Šifrovani backup')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.enhanced_encryption_outlined, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Backup je AES-256-GCM šifrovan vašom lozinkom. Lozinku ne čuvamo i ne možemo je vratiti.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Lozinka za backup',
            helperText: 'Najmanje 10 znakova',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Napravi šifrovani backup'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.restore_page_outlined),
          label: const Text('Vrati backup na ovaj profil'),
        ),
      ],
    ),
  );
}

Future<bool> _ensureCloudAiAccess(
  BuildContext context,
  AppServices services,
) async {
  if (!kCloudAiEnabled || !services.cloudEnabled) return true;
  final hasFreshSession = await services.auth.ensureFreshSession();
  if (!context.mounted) return false;
  if (!hasFreshSession) {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SignInScreen(services: services)));
    if (!context.mounted || !await services.auth.ensureFreshSession()) {
      return false;
    }
  }
  final preferences = await SharedPreferences.getInstance();
  if (preferences.getBool('cloudAiConsentV1') == true) return true;
  if (!context.mounted) return false;
  final language = Localizations.localeOf(context).languageCode;
  final copy = _cloudAiConsentCopy[language] ?? _cloudAiConsentCopy['en']!;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(copy.$1),
      content: Text(copy.$2),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(copy.$3),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(copy.$4),
        ),
      ],
    ),
  );
  if (accepted != true) return false;
  await preferences.setBool('cloudAiConsentV1', true);
  return true;
}

const _cloudAiConsentCopy = <String, (String, String, String, String)>{
  'sr': (
    'OpenAI analiza',
    'Radi kvalitetnije analize, prepoznati OCR tekst ovog pisma biće bezbedno poslat OpenAI-ju samo za trenutni zahtev. Originalna fotografija/PDF, analiza i arhiva ostaju lokalno na ovom uređaju i ne čuvaju se u Firebase-u. Ne nastavljajte ako ne želite slanje OCR teksta.',
    'Odustani',
    'Prihvatam i nastavi',
  ),
  'hr': (
    'OpenAI analiza',
    'Radi kvalitetnije analize, prepoznati OCR tekst ovog pisma sigurno će se poslati OpenAI-ju samo za trenutačni zahtjev. Izvorna fotografija/PDF, analiza i arhiva ostaju lokalno na uređaju i ne spremaju se u Firebase.',
    'Odustani',
    'Prihvaćam i nastavi',
  ),
  'bs': (
    'OpenAI analiza',
    'Radi kvalitetnije analize, prepoznati OCR tekst ovog pisma sigurno će se poslati OpenAI-ju samo za trenutni zahtjev. Originalna fotografija/PDF, analiza i arhiva ostaju lokalno na uređaju i ne čuvaju se u Firebase-u.',
    'Odustani',
    'Prihvatam i nastavi',
  ),
  'mk': (
    'OpenAI анализа',
    'За поквалитетна анализа, препознаениот OCR текст ќе биде безбедно испратен до OpenAI само за тековното барање. Оригиналната фотографија/PDF, анализата и архивата остануваат локално на уредот.',
    'Откажи',
    'Прифаќам и продолжи',
  ),
  'bg': (
    'OpenAI анализ',
    'За по-качествен анализ разпознатият OCR текст ще бъде изпратен сигурно до OpenAI само за текущата заявка. Оригиналната снимка/PDF, анализът и архивът остават локално на устройството.',
    'Отказ',
    'Приемам и продължи',
  ),
  'de': (
    'OpenAI-Analyse',
    'Für eine bessere Analyse wird der erkannte OCR-Text nur für diese Anfrage sicher an OpenAI gesendet. Originalfoto/PDF, Analyse und Archiv bleiben lokal auf diesem Gerät und werden nicht in Firebase gespeichert.',
    'Abbrechen',
    'Zustimmen und fortfahren',
  ),
  'en': (
    'OpenAI analysis',
    'For a higher-quality analysis, the recognized OCR text will be sent securely to OpenAI for this request only. The original photo/PDF, analysis, and archive remain local on this device and are not stored in Firebase.',
    'Cancel',
    'Agree and continue',
  ),
  'tr': (
    'OpenAI analizi',
    'Daha kaliteli bir analiz için tanınan OCR metni yalnızca bu istek kapsamında güvenli biçimde OpenAI’ye gönderilir. Orijinal fotoğraf/PDF, analiz ve arşiv bu cihazda yerel kalır ve Firebase’de saklanmaz.',
    'İptal',
    'Kabul et ve devam et',
  ),
  'ru': (
    'Анализ OpenAI',
    'Для более качественного анализа распознанный текст этого письма будет безопасно отправлен OpenAI только для текущего запроса. Оригинальная фотография или PDF, анализ и архив остаются локально на этом устройстве и не сохраняются в Firebase.',
    'Отмена',
    'Согласиться и продолжить',
  ),
  'uk': (
    'Аналіз OpenAI',
    'Для якіснішого аналізу розпізнаний текст цього листа буде безпечно надіслано OpenAI лише для поточного запиту. Оригінальна фотографія або PDF, аналіз і архів залишаються локально на цьому пристрої та не зберігаються у Firebase.',
    'Скасувати',
    'Погодитися й продовжити',
  ),
  'ar': (
    'تحليل OpenAI',
    'لتحليل أكثر جودة، سيُرسل النص المستخرج من هذه الرسالة بأمان إلى OpenAI لهذا الطلب فقط. تبقى الصورة الأصلية أو ملف PDF والتحليل والأرشيف محلياً على هذا الجهاز ولا تُحفظ في Firebase.',
    'إلغاء',
    'موافق والمتابعة',
  ),
  'ro': (
    'Analiză OpenAI',
    'Pentru o analiză mai bună, textul OCR recunoscut va fi trimis în siguranță către OpenAI numai pentru această solicitare. Fotografia sau PDF-ul original, analiza și arhiva rămân local pe acest dispozitiv și nu sunt stocate în Firebase.',
    'Anulează',
    'Sunt de acord și continuă',
  ),
  'pl': (
    'Analiza OpenAI',
    'Aby zapewnić lepszą analizę, rozpoznany tekst OCR zostanie bezpiecznie wysłany do OpenAI wyłącznie na potrzeby tego zapytania. Oryginalne zdjęcie lub PDF, analiza i archiwum pozostają lokalnie na tym urządzeniu i nie są przechowywane w Firebase.',
    'Anuluj',
    'Zgadzam się i kontynuuję',
  ),
  'it': (
    'Analisi OpenAI',
    'Per un’analisi migliore, il testo OCR riconosciuto verrà inviato in modo sicuro a OpenAI solo per questa richiesta. La foto o il PDF originale, l’analisi e l’archivio restano in locale su questo dispositivo e non vengono salvati in Firebase.',
    'Annulla',
    'Accetta e continua',
  ),
  'el': (
    'Ανάλυση OpenAI',
    'Για καλύτερη ανάλυση, το αναγνωρισμένο κείμενο OCR θα αποσταλεί με ασφάλεια στο OpenAI μόνο για αυτό το αίτημα. Η αρχική φωτογραφία ή το PDF, η ανάλυση και το αρχείο παραμένουν τοπικά σε αυτή τη συσκευή και δεν αποθηκεύονται στο Firebase.',
    'Ακύρωση',
    'Συμφωνώ και συνεχίζω',
  ),
  'sq': (
    'Analizë OpenAI',
    'Për një analizë më të mirë, teksti i njohur me OCR do t’i dërgohet në mënyrë të sigurt OpenAI vetëm për këtë kërkesë. Fotografia ose PDF-ja origjinale, analiza dhe arkivi mbeten lokalisht në këtë pajisje dhe nuk ruhen në Firebase.',
    'Anulo',
    'Pranoj dhe vazhdo',
  ),
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
          'Original documents and the archive are stored locally. With consent, OCR text is sent transiently to OpenAI for the requested analysis and is not stored in the Firebase archive.',
      'account': await services.auth.localAccountData(),
      'premiumActive': state.isPremium,
      'letters': await services.letters.exportRecords(services.currentVaultKey),
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
    'Firebase se koristi za autentifikaciju, status pretplate, ograničenje korišćenja i opcionalne push tokene. Kada je cloud AI uključen, samo OCR tekst potreban za trenutni zahtev šalje se OpenAI-ju radi analize ili odgovora i ne upisuje se u cloud arhivu. Web i mobilnu naplatu obrađuju odgovarajući ovlašćeni pružaoci plaćanja.',
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
    'Svaki novi nalog uključuje 5 uvodnih analiza bez naplate. Posle toga korisnik bira mesečni paket od 50, 100 ili 150 analiza. Neiskorišćene analize se ne prenose u sledeći mesec. Pretplata se automatski obnavlja dok je korisnik ne otkaže u podešavanjima naloga prodavnice aplikacija najmanje 24 sata pre obnove. Brisanje aplikacije ne otkazuje pretplatu.',
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
                  for (final plan in kSubscriptionPlans) ...[
                    _PlanCard(
                      title:
                          '${plan.key.toUpperCase()} · '
                          '${plan.monthlyAnalysisLimit}',
                      price: strings
                          .text('pricePerMonth')
                          .replaceFirst(
                            '{price}',
                            productById[plan.productId]?.price ??
                                wrapperPrices[plan.productId] ??
                                plan.fallbackPrice,
                          ),
                      features: [
                        strings
                            .text('analysesPerMonth')
                            .replaceFirst(
                              '{count}',
                              plan.monthlyAnalysisLimit.toString(),
                            ),
                        strings.text('premiumFeature2'),
                        strings.text('premiumFeature3'),
                      ],
                      action: kIsWeb
                          ? () => _webCheckout(plan.key)
                          : () => _buy(productById[plan.productId]),
                    ),
                    const SizedBox(height: 12),
                  ],
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
                        ? strings.purchaseMessage('unavailable')
                        : kIsWeb && snapshot.data?.nativeWrapper != true
                        ? strings.purchaseMessage('webInfo')
                        : strings.purchaseMessage('storeInfo'),
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
        SnackBar(
          content: Text(context.strings.purchaseMessage('notConfigured')),
        ),
      );
      return;
    }
    try {
      await widget.services.purchases.buy(product);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.purchaseMessage('failed'))),
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
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.purchaseMessage('failed'))),
        );
      }
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await widget.services.purchases.restore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.purchaseMessage('checking'))),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.purchaseMessage('failed'))),
        );
      }
    }
  }

  Future<void> _manageSubscription() async {
    try {
      await widget.services.purchases.openSubscriptionManagement();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.purchaseMessage('failed'))),
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
    this.onOrganize,
    this.onDelete,
    this.onTap,
  });
  final LetterAnalysis letter;
  final ValueChanged<LetterStatus>? onStatus;
  final VoidCallback? onOrganize;
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
        '${letter.isPaymentObligation ? ' • ${letter.paymentPaid ? context.strings.text('paymentPaid') : context.strings.text('paymentOpen')}' : ''}'
        '${(letter.paymentDueDate ?? letter.deadline) == null ? '' : ' • ${context.strings.text(letter.paymentDueDate != null ? 'paymentDueDate' : 'deadline')} ${(letter.paymentDueDate ?? letter.deadline)!.day}.${(letter.paymentDueDate ?? letter.deadline)!.month}.'}',
      ),
      trailing: onStatus == null && onDelete == null && onOrganize == null
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
                if (onOrganize != null)
                  IconButton(
                    tooltip: 'Organizuj',
                    onPressed: onOrganize,
                    icon: const Icon(Icons.tune_rounded),
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
                        value: LetterStatus.replyPrepared,
                        child: Text(_statusLabel(LetterStatus.replyPrepared)),
                      ),
                      PopupMenuItem(
                        value: LetterStatus.sent,
                        child: Text(_statusLabel(LetterStatus.sent)),
                      ),
                      PopupMenuItem(
                        value: LetterStatus.awaitingReply,
                        child: Text(_statusLabel(LetterStatus.awaitingReply)),
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

class DeadlineCenterScreen extends StatelessWidget {
  const DeadlineCenterScreen({
    super.key,
    required this.state,
    required this.services,
  });

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final groups = _deadlineGroups(state.letters);
    return Scaffold(
      appBar: AppBar(title: const Text('Kalendar rokova')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Otvoreni rokovi i računi ostaju lokalno na ovom uređaju.',
          ),
          const SizedBox(height: 20),
          _DeadlineGroup(
            title: 'Kasni',
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            letters: groups.overdue,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: 'Danas',
            icon: Icons.today_outlined,
            color: Colors.orange,
            letters: groups.today,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: 'Ove nedelje',
            icon: Icons.date_range_outlined,
            color: Colors.blue,
            letters: groups.thisWeek,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: 'Kasnije',
            icon: Icons.event_available_outlined,
            color: Colors.teal,
            letters: groups.later,
            state: state,
            services: services,
          ),
        ],
      ),
    );
  }
}

class _DeadlineGroup extends StatelessWidget {
  const _DeadlineGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.letters,
    required this.state,
    required this.services,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<LetterAnalysis> letters;
  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('${letters.length}'),
            ],
          ),
          if (letters.isNotEmpty) const Divider(),
          ...letters.map(
            (letter) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(letter.title),
              subtitle: Text(_dueText(letter)),
              trailing: letter.isPaymentObligation && !letter.paymentPaid
                  ? const Icon(Icons.payments_outlined)
                  : null,
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
          if (letters.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Nema stavki.'),
            ),
        ],
      ),
    ),
  );
}

Future<void> _showLetterOrganiser(
  BuildContext context, {
  required LetterAnalysis letter,
  required AppState state,
  required AppServices services,
}) async {
  var folder = letter.folder;
  var status = letter.status;
  var paid = letter.paymentPaid;
  final tags = TextEditingController(text: letter.tags.join(', '));
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Organizuj pismo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LetterFolder>(
                  initialValue: folder,
                  decoration: const InputDecoration(labelText: 'Folder'),
                  items: LetterFolder.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_folderLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => folder = value ?? folder),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LetterStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Status komunikacije',
                  ),
                  items: LetterStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tags,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Oznake',
                    hintText: 'npr. hitno, žalba, deca',
                    helperText: 'Odvojite oznake zarezom.',
                  ),
                ),
                if (letter.isPaymentObligation) ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Račun je plaćen'),
                    subtitle: Text(letter.amount ?? 'Iznos nije prepoznat'),
                    value: paid,
                    onChanged: (value) => setSheetState(() => paid = value),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    final cleanedTags = tags.text
                        .split(',')
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toSet()
                        .take(12)
                        .toList(growable: false);
                    final updated = letter.copyWith(
                      folder: folder,
                      status: status,
                      tags: cleanedTags,
                      paymentPaid: paid,
                      paymentPaidAt: paid ? DateTime.now() : null,
                      clearPaymentPaidAt: !paid,
                    );
                    await services.letters.updateOrganisation(
                      services.currentVaultKey,
                      letter.id,
                      folder: folder,
                      status: status,
                      tags: cleanedTags,
                      paymentPaid: paid,
                    );
                    state.replaceLetters([
                      for (final item in state.letters)
                        if (item.id == letter.id) updated else item,
                    ]);
                    if (status == LetterStatus.done || paid) {
                      await services.reminders.cancel(letter.id);
                    } else {
                      await services.reminders.schedule(
                        updated,
                        language: state.aiLanguageCode,
                      );
                    }
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Sačuvaj lokalno'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } finally {
    tags.dispose();
  }
}

class _DeadlineOverview {
  const _DeadlineOverview({
    required this.today,
    required this.thisWeek,
    required this.overdue,
    required this.total,
  });
  final int today;
  final int thisWeek;
  final int overdue;
  final int total;
}

class _DeadlineGroups {
  const _DeadlineGroups({
    required this.overdue,
    required this.today,
    required this.thisWeek,
    required this.later,
  });
  final List<LetterAnalysis> overdue;
  final List<LetterAnalysis> today;
  final List<LetterAnalysis> thisWeek;
  final List<LetterAnalysis> later;
}

_DeadlineOverview _deadlineOverview(List<LetterAnalysis> letters) {
  final groups = _deadlineGroups(letters);
  return _DeadlineOverview(
    today: groups.today.length,
    thisWeek: groups.thisWeek.length,
    overdue: groups.overdue.length,
    total:
        groups.overdue.length +
        groups.today.length +
        groups.thisWeek.length +
        groups.later.length,
  );
}

_DeadlineGroups _deadlineGroups(List<LetterAnalysis> letters) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final weekEnd = todayStart.add(const Duration(days: 7));
  final overdue = <LetterAnalysis>[];
  final today = <LetterAnalysis>[];
  final thisWeek = <LetterAnalysis>[];
  final later = <LetterAnalysis>[];
  for (final letter in letters) {
    if (letter.status == LetterStatus.done || letter.paymentPaid) continue;
    final due = letter.paymentDueDate ?? letter.deadline;
    if (due == null) continue;
    final day = DateTime(due.year, due.month, due.day);
    if (day.isBefore(todayStart)) {
      overdue.add(letter);
    } else if (day == todayStart) {
      today.add(letter);
    } else if (day.isBefore(weekEnd)) {
      thisWeek.add(letter);
    } else {
      later.add(letter);
    }
  }
  int byDue(LetterAnalysis a, LetterAnalysis b) =>
      (a.paymentDueDate ?? a.deadline)!.compareTo(
        b.paymentDueDate ?? b.deadline!,
      );
  for (final group in [overdue, today, thisWeek, later]) {
    group.sort(byDue);
  }
  return _DeadlineGroups(
    overdue: overdue,
    today: today,
    thisWeek: thisWeek,
    later: later,
  );
}

String _dueText(LetterAnalysis letter) {
  final due = letter.paymentDueDate ?? letter.deadline;
  if (due == null) return 'Bez roka';
  return '${letter.isPaymentObligation ? 'Plaćanje do' : 'Rok'} ${due.day.toString().padLeft(2, '0')}.${due.month.toString().padLeft(2, '0')}.${due.year}';
}

String _statusLabel(LetterStatus status) => switch (status) {
  LetterStatus.newLetter => 'Novo',
  LetterStatus.inProgress => 'Rešavam',
  LetterStatus.replyPrepared => 'Odgovor pripremljen',
  LetterStatus.sent => 'Poslato',
  LetterStatus.awaitingReply => 'Čeka se odgovor',
  LetterStatus.done => 'Završeno',
};

String _folderLabel(LetterFolder folder) => switch (folder) {
  LetterFolder.inbox => 'Prijemno',
  LetterFolder.housing => 'Stanovanje',
  LetterFolder.work => 'Posao',
  LetterFolder.family => 'Porodica',
  LetterFolder.insurance => 'Osiguranje',
  LetterFolder.taxes => 'Porezi',
  LetterFolder.finance => 'Finansije',
};

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
