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

/// The single visual language for BriefAI.  Business flows intentionally do
/// not own colours or geometry, so screens cannot drift back to an older
/// visual style while features evolve.
abstract final class BriefAiDesign {
  static const navy = Color(0xFF0C173A);
  static const ink = Color(0xFF17203A);
  static const blue = Color(0xFF3563FF);
  static const blueDark = Color(0xFF204BDB);
  static const blueSoft = Color(0xFFEAF0FF);
  static const canvas = Color(0xFFF7F8FC);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF0F3F9);
  static const border = Color(0xFFDCE3F0);
  static const muted = Color(0xFF62708D);
  static const green = Color(0xFF197A57);
  static const greenSoft = Color(0xFFE4F5EC);
  static const amber = Color(0xFFAA6500);
  static const amberSoft = Color(0xFFFFF1D9);
  static const red = Color(0xFFB32727);
  static const redSoft = Color(0xFFFFE7E7);
  static const radius = 18.0;
}

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
    final requestedLanguageIsValid =
        requestedAiLanguage != null &&
        AppStrings.languageLabels.containsKey(requestedAiLanguage);
    final storedAiLanguage =
        preferences.getString('briefai.ai-language') ??
        storedLegacyLanguage ??
        await widget.services.auth.preferredLanguage();
    final storedInterfaceLanguage = preferences.getString(
      'briefai.interface-language',
    );
    final inferredInterfaceLanguage = requestedLanguageIsValid
        ? requestedAiLanguage
        : storedAiLanguage;
    final interfaceLanguage =
        storedInterfaceLanguage != null &&
            AppStrings.hasFullyLocalizedInterface(storedInterfaceLanguage)
        ? storedInterfaceLanguage
        : AppStrings.hasFullyLocalizedInterface(inferredInterfaceLanguage)
        ? inferredInterfaceLanguage
        : 'en';
    // Older builds could leave the visible interface and AI explanation
    // language out of sync. Unless the user explicitly chose a separate AI
    // language in Profile, the visible interface is the source of truth.
    final aiLanguage = requestedLanguageIsValid
        ? requestedAiLanguage
        : preferences.getBool('briefai.ai-language-explicit') == true
        ? storedAiLanguage
        : interfaceLanguage;
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
          final result = await widget.services.purchases.verifyPurchase(
            purchase,
          );
          if (result.isPremium) {
            _state.setPremium(true);
          }
          if (result.creditsAdded > 0) {
            _state.setAnalysisCredits(result.analysisCredits);
          }
          if (result.questionnaireCreditsAdded > 0) {
            _state.setQuestionnaireCredits(result.questionnaireCredits);
          }
        } catch (_) {
          // The server is authoritative. A failed verification never unlocks
          // Premium, and the next store restore can retry it.
        }
      }
      if (purchase.pendingCompletePurchase ||
          PurchaseService.isConsumableProduct(purchase.productID)) {
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
      locale: AppStrings.interfaceLocale(_state.localeCode),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(),
      // Android 15+ can draw Flutter content edge-to-edge by default. Keep
      // every page above the system navigation area so that the final action
      // or line of text is never hidden behind the phone's Back/Home buttons.
      // The system buttons remain available; only the app content is inset.
      builder: (context, child) =>
          SafeArea(top: false, child: child ?? const SizedBox.shrink()),
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
    final scheme =
        ColorScheme.fromSeed(
          seedColor: BriefAiDesign.blue,
          brightness: Brightness.light,
        ).copyWith(
          primary: BriefAiDesign.blue,
          secondary: BriefAiDesign.blue,
          surface: Colors.white,
          onSurface: BriefAiDesign.ink,
          outline: BriefAiDesign.border,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BriefAiDesign.canvas,
      textTheme: ThemeData.light().textTheme
          .apply(
            bodyColor: BriefAiDesign.ink,
            displayColor: BriefAiDesign.ink,
            fontFamilyFallback: const ['NotoSansArabic'],
          )
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 31,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
            headlineSmall: const TextStyle(
              fontSize: 25,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -.45,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.42),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: BriefAiDesign.canvas,
        foregroundColor: BriefAiDesign.navy,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: BriefAiDesign.navy,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          fontFamilyFallback: ['NotoSansArabic'],
        ),
      ),
      cardTheme: CardThemeData(
        color: BriefAiDesign.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          side: const BorderSide(color: BriefAiDesign.border),
        ),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BriefAiDesign.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BriefAiDesign.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BriefAiDesign.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BriefAiDesign.blue, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          backgroundColor: BriefAiDesign.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          side: const BorderSide(color: BriefAiDesign.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: BriefAiDesign.border),
        selectedColor: BriefAiDesign.blueSoft,
        backgroundColor: BriefAiDesign.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: BriefAiDesign.surface,
        indicatorColor: BriefAiDesign.blueSoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Color(0xFF0B1533),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/branding/briefai_logo_v2.png',
              width: 94,
              height: 94,
              fit: BoxFit.cover,
              semanticLabel: 'BriefAI',
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'BRIEFAI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onComplete,
                    child: Text(strings.text('skip')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: (_page + 1) / pages.length,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE9E9F0),
                ),
              ),
              const Spacer(),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: BriefAiDesign.blueSoft,
                  border: Border.all(color: const Color(0xFFBDD0FF)),
                ),
                child: Icon(item.$3, color: BriefAiDesign.blue, size: 58),
              ),
              const SizedBox(height: 34),
              Text(
                item.$1,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                item.$2,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5D6375)),
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
              const SizedBox(height: 10),
              _LanguageMenu(state: widget.state, services: widget.services),
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
  StreamSubscription<dynamic>? _questionnairesSubscription;
  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<dynamic>? _entitlementSubscription;
  StreamSubscription<dynamic>? _usageSubscription;
  StreamSubscription<dynamic>? _creditsSubscription;
  StreamSubscription<dynamic>? _questionnaireUsageSubscription;
  StreamSubscription<dynamic>? _questionnaireCreditsSubscription;
  int _vaultBinding = 0;
  String? _roleRefreshUid;

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
        _creditsSubscription?.cancel();
        _questionnaireUsageSubscription?.cancel();
        _questionnaireCreditsSubscription?.cancel();
        if (mounted) setState(() {});
        if (user != null) {
          if (_roleRefreshUid != user.uid) {
            _roleRefreshUid = user.uid;
            unawaited(widget.services.auth.refreshCurrentProfile());
          }
          unawaited(widget.services.auth.touchActivity());
          unawaited(widget.services.reminders.syncToken());
          _entitlementSubscription = widget.services.entitlements
              .watch(user.uid)
              .listen(widget.state.setPremium);
          _usageSubscription = widget.services.entitlements
              .watchFreeUsage(user.uid)
              .listen(widget.state.setFreeAnalysesUsed);
          _creditsSubscription = widget.services.entitlements
              .watchAnalysisCredits(user.uid)
              .listen(widget.state.setAnalysisCredits);
          _questionnaireUsageSubscription = widget.services.entitlements
              .watchFreeQuestionnaireUsage(user.uid)
              .listen(widget.state.setFreeQuestionnairesUsed);
          _questionnaireCreditsSubscription = widget.services.entitlements
              .watchQuestionnaireCredits(user.uid)
              .listen(widget.state.setQuestionnaireCredits);
        } else {
          _roleRefreshUid = null;
          widget.state.setPremium(false);
          _usageSubscription = widget.services.entitlements
              .watchFreeUsage('local-device')
              .listen(widget.state.setFreeAnalysesUsed);
          widget.state.setAnalysisCredits(0);
          _questionnaireUsageSubscription = widget.services.entitlements
              .watchFreeQuestionnaireUsage('local-device')
              .listen(widget.state.setFreeQuestionnairesUsed);
          widget.state.setQuestionnaireCredits(0);
        }
      });
    } else {
      _usageSubscription = widget.services.entitlements
          .watchFreeUsage('local-device')
          .listen(widget.state.setFreeAnalysesUsed);
      widget.state.setAnalysisCredits(0);
      _questionnaireUsageSubscription = widget.services.entitlements
          .watchFreeQuestionnaireUsage('local-device')
          .listen(widget.state.setFreeQuestionnairesUsed);
      widget.state.setQuestionnaireCredits(0);
    }
  }

  void _onHouseholdProfileChanged() => unawaited(_bindLocalVault());

  Future<void> _bindLocalVault() async {
    final binding = ++_vaultBinding;
    await _lettersSubscription?.cancel();
    _lettersSubscription = null;
    await _questionnairesSubscription?.cancel();
    _questionnairesSubscription = null;
    if (!mounted || binding != _vaultBinding) return;
    widget.state.replaceLetters(const []);

    final baseVault = widget.services.auth.localVaultKey;
    await widget.services.household.bindOwner(baseVault);
    final personalVault = widget.services.household.personalVault(baseVault);

    // Firebase restores a persisted session asynchronously.  Migrating while
    // it is still reporting the anonymous vault would move a signed-in user's
    // archive into an anonymous household profile and make it look as though
    // every letter had vanished after an update.  Anonymous letters remain
    // readable locally until a real account is available, then that account
    // claims them exactly once.
    if (widget.services.auth.uid != null) {
      await widget.services.letters.claimLegacyDeviceVault(personalVault);
      await widget.services.letters.moveBaseVaultToPersonal(
        baseVault,
        personalVault,
      );
    }
    final ownerKey = widget.services.currentVaultKey;
    if (!mounted || binding != _vaultBinding) return;
    _lettersSubscription = widget.services.letters
        .watch(ownerKey)
        .listen(widget.state.replaceLetters);
    _questionnairesSubscription = widget.services.questionnaires
        .watch(ownerKey)
        .listen(widget.state.replaceQuestionnaires);
  }

  @override
  void dispose() {
    _lettersSubscription?.cancel();
    _questionnairesSubscription?.cancel();
    _entitlementSubscription?.cancel();
    _usageSubscription?.cancel();
    _creditsSubscription?.cancel();
    _questionnaireUsageSubscription?.cancel();
    _questionnaireCreditsSubscription?.cancel();
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRIEFAI',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: BriefAiDesign.blue,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.text('welcome'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _LanguageMenu(state: state, services: services),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          strings.text('homeSubtitle'),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: BriefAiDesign.muted),
        ),
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
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: BriefAiDesign.navy,
            borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.document_scanner_outlined,
                        color: Color(0xFFD7E2FF),
                        size: 25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.text('analyzeNew'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                state.isPremium
                    ? strings.text('monthlyPlanActive')
                    : state.analysisCredits > 0
                    ? strings.creditPackText(
                        'balance',
                        count: state.analysisCredits,
                      )
                    : strings.remaining(
                        kFreeAnalysisLimit - state.freeAnalysesUsed,
                      ),
                style: const TextStyle(color: Color(0xFFD5DDF6), height: 1.35),
              ),
              if (cloudUnavailable) ...[
                const SizedBox(height: 10),
                Text(
                  strings.text('offlineAiUnavailable'),
                  style: const TextStyle(color: Color(0xFFFFE0B2)),
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
                style: FilledButton.styleFrom(
                  backgroundColor: BriefAiDesign.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _QuestionnaireOverviewCard(state: state, services: services),
        const SizedBox(height: 14),
        _DeadlineOverviewCard(state: state, services: services),
        const SizedBox(height: 30),
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

class _QuestionnaireOverviewCard extends StatelessWidget {
  const _QuestionnaireOverviewCard({
    required this.state,
    required this.services,
  });

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final allowance = state.questionnaireCredits > 0
        ? strings.format('questionnaireCredits', {
            'count': state.questionnaireCredits,
          })
        : strings.format('questionnaireRemaining', {
            'count': math.max(
              0,
              kFreeQuestionnaireLimit - state.freeQuestionnairesUsed,
            ),
          });
    return InkWell(
      borderRadius: BorderRadius.circular(BriefAiDesign.radius),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              QuestionnaireHubScreen(state: state, services: services),
        ),
      ),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BriefAiDesign.surface,
          borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          border: Border.all(color: BriefAiDesign.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: BriefAiDesign.blueSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                color: BriefAiDesign.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('questionnaires'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allowance,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BriefAiDesign.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BriefAiDesign.muted),
          ],
        ),
      ),
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
    return InkWell(
      borderRadius: BorderRadius.circular(BriefAiDesign.radius),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              DeadlineCenterScreen(state: state, services: services),
        ),
      ),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: BriefAiDesign.surface,
          borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          border: Border.all(color: BriefAiDesign.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: overview.overdue > 0
                    ? BriefAiDesign.redSoft
                    : BriefAiDesign.blueSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: overview.overdue > 0
                    ? BriefAiDesign.red
                    : BriefAiDesign.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.text('deadlineCalendar'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    overview.total == 0
                        ? context.strings.text('deadlineNone')
                        : context.strings.format('deadlineSummary', {
                            'today': overview.today,
                            'week': overview.thisWeek,
                            'overdue': overview.overdue,
                          }),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: BriefAiDesign.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BriefAiDesign.muted),
          ],
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
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.text('privacyChoiceTitle'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(strings.text('privacyChoiceBody')),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () => unawaited(_choose(false)),
                    child: Text(strings.text('decline')),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => unawaited(_choose(true)),
                    child: Text(strings.text('accept')),
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
    child: Semantics(
      button: true,
      label: context.strings.text('appLanguage'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: BriefAiDesign.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: BriefAiDesign.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              AppStrings.languageLabels[state.localeCode] ??
                  state.localeCode.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 2),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    ),
    onSelected: (language) async {
      state.setLocale(language);
      // A user-facing language choice must also become the language of new AI
      // explanations. Keeping two unrelated values made it possible for a
      // Serbian interface to keep producing answers in a previously selected
      // language such as Russian.
      state.setAiLanguage(language);
      final preferences = await SharedPreferences.getInstance();
      try {
        await preferences.setString('briefai.interface-language', language);
        await preferences.setString('briefai.ai-language', language);
        await preferences.setBool('briefai.ai-language-explicit', false);
        await services.auth.setPreferredLanguage(language);
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
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool('briefai.ai-language-explicit', true);
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
                    color: BriefAiDesign.navy,
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
      final created = await widget.services.auth.signInWithEmail(
        email,
        _password.text,
        create: _create,
      );
      // People frequently choose the visible "create account" option even
      // though they already registered with this e-mail.  AuthService then
      // signs them into that existing account rather than reporting a false
      // failure.  Count a registration only when Firebase actually created a
      // new identity.
      if (created) unawaited(widget.services.analytics.trackRegistration());
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

class _DocumentInputButton extends StatelessWidget {
  const _DocumentInputButton({
    required this.icon,
    required this.title,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(72),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: BriefAiDesign.blueSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: BriefAiDesign.blue),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: BriefAiDesign.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: BriefAiDesign.muted),
      ],
    ),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DocumentInputButton(
                  icon: Icons.camera_alt_outlined,
                  title: strings.text('camera'),
                  onPressed: _loading
                      ? null
                      : () => _selectOne(widget.services.documents.capture),
                ),
                const SizedBox(height: 10),
                _DocumentInputButton(
                  icon: Icons.photo_library_outlined,
                  title: strings.text('gallery'),
                  onPressed: _loading
                      ? null
                      : () => _selectMany(
                          widget.services.documents.galleryMultiple,
                        ),
                ),
                const SizedBox(height: 10),
                _DocumentInputButton(
                  icon: Icons.upload_file_outlined,
                  title: strings.text('pdfImage'),
                  onPressed: _loading
                      ? null
                      : () => _selectMany(widget.services.documents.files),
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

class QuestionnaireHubScreen extends StatelessWidget {
  const QuestionnaireHubScreen({
    super.key,
    required this.state,
    required this.services,
  });

  final AppState state;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('questionnaires'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                QuestionnaireEditorScreen(state: state, services: services),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(strings.text('newQuestionnaire')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text(
            strings.text('questionnaireDescription'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: BriefAiDesign.muted),
          ),
          const SizedBox(height: 20),
          Text(
            strings.text('questionnaireDrafts'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (state.questionnaires.isEmpty)
            _EmptyState(
              icon: Icons.assignment_outlined,
              text: strings.text('emptyQuestionnaires'),
            )
          else
            ...state.questionnaires.map(
              (draft) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.assignment_outlined,
                    color: BriefAiDesign.blue,
                  ),
                  title: Text(draft.title),
                  subtitle: Text(
                    '${draft.fields.length} · '
                    '${draft.updatedAt.day.toString().padLeft(2, '0')}.'
                    '${draft.updatedAt.month.toString().padLeft(2, '0')}.'
                    '${draft.updatedAt.year}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuestionnaireEditorScreen(
                        state: state,
                        services: services,
                        draft: draft,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class QuestionnaireEditorScreen extends StatefulWidget {
  const QuestionnaireEditorScreen({
    super.key,
    required this.state,
    required this.services,
    this.draft,
  });

  final AppState state;
  final AppServices services;
  final QuestionnaireDraft? draft;

  @override
  State<QuestionnaireEditorScreen> createState() =>
      _QuestionnaireEditorScreenState();
}

class _QuestionnaireEditorScreenState extends State<QuestionnaireEditorScreen> {
  static const _maxPages = 20;
  final _title = TextEditingController();
  final _sourceText = TextEditingController();
  final List<(TextEditingController, TextEditingController)> _fields = [];
  final List<PickedDocument> _documents = [];
  bool _busy = false;
  int _ocrPage = 0;

  bool get _isExisting => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _title.text = draft?.title ?? '';
    _sourceText.text = draft?.sourceText ?? '';
    for (final field in draft?.fields ?? const <QuestionnaireField>[]) {
      _fields.add((
        TextEditingController(text: field.label),
        TextEditingController(text: field.value),
      ));
    }
    if (_fields.isEmpty) _addField();
  }

  @override
  void dispose() {
    _title.dispose();
    _sourceText.dispose();
    for (final controllers in _fields) {
      controllers.$1.dispose();
      controllers.$2.dispose();
    }
    super.dispose();
  }

  void _addField({String label = '', String value = ''}) {
    setState(() {
      _fields.add((
        TextEditingController(text: label),
        TextEditingController(text: value),
      ));
    });
  }

  void _removeField(int index) {
    if (_fields.length == 1) return;
    final removed = _fields.removeAt(index);
    removed.$1.dispose();
    removed.$2.dispose();
    setState(() {});
  }

  Future<void> _select(Future<List<PickedDocument>> Function() source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await source();
      if (!mounted || picked.isEmpty) return;
      setState(() {
        _documents
          ..clear()
          ..addAll(picked.take(_maxPages));
        _sourceText.clear();
      });
    } on Object {
      _show(context.strings.text('ocrFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _capture() => _select(() async {
    final document = await widget.services.documents.capture();
    return document == null ? const <PickedDocument>[] : [document];
  });

  Future<void> _recognizeAndSave() async {
    if (_busy) return;
    if (!_isExisting && !widget.state.canCreateQuestionnaire) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuestionnairePackagesScreen(
            state: widget.state,
            services: widget.services,
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      if (_sourceText.text.trim().isEmpty && _documents.isNotEmpty) {
        final text = await widget.services.documents.ocrAll(
          _documents,
          onProgress: (current, _) {
            if (mounted) setState(() => _ocrPage = current);
          },
        );
        if (!mounted) return;
        _sourceText.text = text;
        _suggestFields(text);
      }
      if (_sourceText.text.trim().isEmpty && !_isExisting) {
        throw StateError(context.strings.text('enterTextFirst'));
      }
      if (!_isExisting) {
        final uid = widget.services.auth.uid ?? 'local-device';
        final allowance = await widget.services.entitlements
            .consumeQuestionnaire(uid);
        widget.state
          ..setFreeQuestionnairesUsed(allowance.freeUsed)
          ..setQuestionnaireCredits(allowance.credits);
        if (!mounted) return;
      }
      final now = DateTime.now();
      final title = _title.text.trim().isEmpty
          ? _suggestTitle(
              _sourceText.text,
              context.strings.text('questionnaires'),
            )
          : _title.text.trim();
      final draft = QuestionnaireDraft(
        id: widget.draft?.id ?? newLetterId(),
        title: title,
        fields: _fields
            .map(
              (controllers) => QuestionnaireField(
                label: controllers.$1.text.trim(),
                value: controllers.$2.text.trim(),
              ),
            )
            .where((field) => field.label.isNotEmpty || field.value.isNotEmpty)
            .toList(growable: false),
        sourceText: _sourceText.text.trim(),
        createdAt: widget.draft?.createdAt ?? now,
        updatedAt: now,
      );
      await widget.services.questionnaires.save(
        widget.services.currentVaultKey,
        draft,
        documents: _documents.isEmpty ? null : List.unmodifiable(_documents),
      );
      widget.state.replaceQuestionnaires([
        draft,
        ...widget.state.questionnaires.where((value) => value.id != draft.id),
      ]);
      if (!mounted) return;
      _show(context.strings.text('questionnaireSaved'));
      Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) _show('${context.strings.text('analysisFailed')}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _suggestFields(String text) {
    final parsed = _questionnaireFieldsFromOcr(text);
    if (parsed.isEmpty) return;
    for (final controllers in _fields) {
      controllers.$1.dispose();
      controllers.$2.dispose();
    }
    setState(() {
      _fields
        ..clear()
        ..addAll(
          parsed.map(
            (field) => (
              TextEditingController(text: field.label),
              TextEditingController(text: field.value),
            ),
          ),
        );
    });
  }

  Future<void> _export(bool word) async {
    final title = _title.text.trim().isEmpty
        ? _suggestTitle(
            _sourceText.text,
            context.strings.text('questionnaires'),
          )
        : _title.text.trim();
    final body = _fields
        .where((controllers) => controllers.$1.text.trim().isNotEmpty)
        .map(
          (controllers) =>
              '${controllers.$1.text.trim()}\n${controllers.$2.text.trim()}',
        )
        .join('\n\n');
    try {
      if (word) {
        await widget.services.exports.saveWord(title: title, body: body);
      } else {
        await widget.services.exports.savePdf(title: title, body: body);
      }
      if (mounted) _show(context.strings.text('pdfReady'));
    } on Object {
      if (mounted) _show(context.strings.text('pdfSaveFailed'));
    }
  }

  void _show(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isExisting
              ? strings.text('editQuestionnaire')
              : strings.text('newQuestionnaire'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (!_isExisting) ...[
            Text(
              strings.text('scanQuestionnaire'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              strings.text('questionnaireDescription'),
              style: const TextStyle(color: BriefAiDesign.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(strings.text('camera')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () =>
                            _select(widget.services.documents.galleryMultiple),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(strings.text('gallery')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _select(widget.services.documents.files),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(strings.text('pdfImage')),
                ),
              ],
            ),
            if (_documents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(strings.pagesSelected(_documents.length)),
              ),
            const SizedBox(height: 24),
          ],
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: strings.text('questionnaireTitle'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.text('editQuestionnaire'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _fields.length; index++) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _fields[index].$1,
                      decoration: InputDecoration(
                        labelText: strings.text('fieldLabel'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _fields[index].$2,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: strings.text('fieldValue'),
                      ),
                    ),
                    if (_fields.length > 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => _removeField(index),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _addField,
            icon: const Icon(Icons.add),
            label: Text(strings.text('addField')),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _busy ? null : _recognizeAndSave,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _busy && _ocrPage > 0
                  ? strings.ocrProgress(_ocrPage, _documents.length)
                  : strings.text('saveQuestionnaire'),
            ),
          ),
          if (_isExisting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _export(true),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(strings.text('exportWord')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _export(false),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(strings.text('savePdf')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class QuestionnairePackagesScreen extends StatefulWidget {
  const QuestionnairePackagesScreen({
    super.key,
    required this.state,
    required this.services,
  });
  final AppState state;
  final AppServices services;
  @override
  State<QuestionnairePackagesScreen> createState() =>
      _QuestionnairePackagesScreenState();
}

class _QuestionnairePackagesScreenState
    extends State<QuestionnairePackagesScreen> {
  late final Future<(ProductDetailsResponse, Map<String, String>, bool)>
  _offers;
  @override
  void initState() {
    super.initState();
    _offers = () async {
      if (kIsWeb) {
        return (
          ProductDetailsResponse(
            productDetails: const [],
            notFoundIDs: const [],
          ),
          await widget.services.purchases.wrapperProductPrices(),
          await widget.services.purchases.isNativeStoreWrapper(),
        );
      }
      return (
        await widget.services.purchases.products(),
        const <String, String>{},
        false,
      );
    }();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.text('buyQuestionnaires'))),
    body: FutureBuilder<(ProductDetailsResponse, Map<String, String>, bool)>(
      future: _offers,
      builder: (context, snapshot) {
        final details = {
          for (final product
              in snapshot.data?.$1.productDetails ?? const <ProductDetails>[])
            product.id: product,
        };
        final prices = snapshot.data?.$2 ?? const <String, String>{};
        final native = snapshot.data?.$3 == true;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.strings.text('questionnaireLimit'),
              style: const TextStyle(color: BriefAiDesign.muted),
            ),
            const SizedBox(height: 18),
            for (final pack in kQuestionnaireCreditPacks) ...[
              _PlanCard(
                title: details[pack.productId]?.title ?? '${pack.credits}',
                price:
                    details[pack.productId]?.price ??
                    prices[pack.productId] ??
                    pack.fallbackPrice,
                features: [
                  context.strings.format('questionnaireCredits', {
                    'count': pack.credits,
                  }),
                ],
                action: kIsWeb
                    ? native
                          ? () => _buyNative(pack.productId)
                          : null
                    : () => _buy(details[pack.productId]),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    ),
  );

  Future<void> _buy(ProductDetails? product) async {
    if (product == null) {
      _show(context.strings.purchaseMessage('notConfigured'));
      return;
    }
    try {
      await widget.services.purchases.buy(product);
    } on Object {
      if (mounted) _show(context.strings.purchaseMessage('failed'));
    }
  }

  Future<void> _buyNative(String productId) async {
    try {
      final result = await widget.services.purchases.buyNativeStoreProduct(
        productId,
      );
      widget.state.setQuestionnaireCredits(result.questionnaireCredits);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) _show(context.strings.purchaseMessage('failed'));
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

List<QuestionnaireField> _questionnaireFieldsFromOcr(String source) {
  final fields = <QuestionnaireField>[];
  final linePattern = RegExp(r'^\s*([^\n:]{2,96}?)(?:\s*[:?])\s*(.*)$');
  for (final line in source.split(RegExp(r'\r?\n'))) {
    final match = linePattern.firstMatch(line);
    if (match == null) continue;
    final label = match.group(1)?.trim() ?? '';
    final value = match.group(2)?.trim() ?? '';
    if (label.isNotEmpty && !label.startsWith('[[')) {
      fields.add(QuestionnaireField(label: label, value: value));
    }
    if (fields.length == 24) break;
  }
  return fields;
}

String _suggestTitle(String source, String fallback) {
  for (final line in source.split(RegExp(r'\r?\n'))) {
    final candidate = line.trim();
    if (candidate.length >= 4 &&
        candidate.length <= 90 &&
        !candidate.startsWith('[[')) {
      return candidate;
    }
  }
  return fallback;
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
    final currentLanguage = Localizations.localeOf(context).languageCode;
    final analysisLanguage = letter.analysisLanguage
        ?.split(RegExp('[-_]'))
        .first;
    final analysisMatchesLanguage = analysisLanguage == currentLanguage;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('resultTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Badge(
            label: _urgencyLabel(context, letter.urgency),
            color: letter.urgency == Urgency.high
                ? Colors.red
                : letter.urgency == Urgency.medium
                ? Colors.orange
                : Colors.green,
          ),
          const SizedBox(height: 12),
          Text(
            _letterHeading(context, letter),
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
          if (analysisMatchesLanguage)
            _ResultSection(
              title: strings.text('simpleExplanation'),
              content: letter.plainExplanation,
            )
          else
            _ResultSection(
              title: strings.text('simpleExplanation'),
              content: strings.text('analysisLanguageMismatch'),
            ),
          _ResultSection(
            title: strings.text('category'),
            content: strings.category(letter.category.name),
          ),
          _ResultSection(
            title: strings.text('folder'),
            content: _folderLabel(context, letter.folder),
          ),
          if (letter.tags.isNotEmpty)
            _ResultSection(
              title: strings.text('tags'),
              content: letter.tags.join(', '),
            ),
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
          if (analysisMatchesLanguage)
            _ResultSection(
              title: strings.text('nextSteps'),
              content: letter.suggestedAction,
            ),
          if (!analysisMatchesLanguage && letter.sourceText.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (!await _ensureCloudAiAccess(context, services) ||
                      !context.mounted) {
                    return;
                  }
                  try {
                    final translated = await services.ai.analyse(
                      letterId: letter.id,
                      text: letter.sourceText,
                      language: state.aiLanguageCode,
                    );
                    final saved = await services.letters.replaceAnalysis(
                      services.currentVaultKey,
                      translated,
                    );
                    if (!saved || !context.mounted) return;
                    state.replaceAnalysis(translated);
                    await services.reminders.schedule(
                      translated,
                      language: state.aiLanguageCode,
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          state: state,
                          letter: translated,
                          services: services,
                        ),
                      ),
                    );
                  } on Object {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.strings.text('tryAgain')),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.translate_rounded),
                label: Text(strings.text('assistantExplainAgainButton')),
              ),
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
  final _letterDraft = TextEditingController();
  final _emailDraft = TextEditingController();
  late final String _vaultKey;
  Future<GeneratedReply>? _response;
  bool _emailVersion = false;
  bool _restoringReply = true;
  bool _savingDraft = false;

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
    _letterDraft.dispose();
    _emailDraft.dispose();
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
                    ? TextField(
                        controller: _emailVersion ? _emailDraft : _letterDraft,
                        minLines: 12,
                        maxLines: null,
                        maxLength: 30000,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          counterText: '',
                        ),
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
                onPressed: _savingDraft
                    ? null
                    : () => _saveEditedReply(strings),
                icon: const Icon(Icons.save_outlined),
                label: Text(strings.text('saveLocally')),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _savingDraft
                    ? null
                    : () async {
                        if (!await _saveEditedReply(strings, silent: true)) {
                          return;
                        }
                        await widget.services.exports.copy(_selectedDraft);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.text('replyCopied')),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy),
                label: Text(strings.text('copyReply')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _savingDraft ? null : () => _composeEmail(strings),
                icon: const Icon(Icons.email_outlined),
                label: Text(strings.text('sendEmail')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _savingDraft ? null : () => _savePdf(strings),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(strings.text('savePdf')),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _savingDraft ? null : () => _saveWord(strings),
                icon: const Icon(Icons.description_outlined),
                label: const Text('Word (.docx)'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _savingDraft
                    ? null
                    : () async {
                        await _saveEditedReply(strings, silent: true);
                        if (mounted) setState(() => _response = null);
                      },
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
        _setDrafts(saved.reply);
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
      _setDrafts(generated);
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

  String get _selectedDraft => _emailVersion
      ? _emailDraft.text.trimRight()
      : _letterDraft.text.trimRight();

  GeneratedReply get _editedReply => GeneratedReply(
    letter: _letterDraft.text.trimRight(),
    email: _emailDraft.text.trimRight(),
  );

  void _setDrafts(GeneratedReply reply) {
    _letterDraft.text = reply.letter;
    _emailDraft.text = reply.email;
  }

  Future<bool> _saveEditedReply(
    AppStrings strings, {
    bool silent = false,
  }) async {
    final edited = _editedReply;
    if (edited.letter.trim().isEmpty || edited.email.trim().isEmpty) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('responseUnavailable'))),
        );
      }
      return false;
    }
    setState(() => _savingDraft = true);
    try {
      await widget.services.letters.claimLegacyDeviceVault(_vaultKey);
      final saved = await widget.services.letters.saveGeneratedReply(
        _vaultKey,
        widget.letter.id,
        edited,
        userContext: _facts.text.trim(),
      );
      if (!saved) throw StateError('Local archive is unavailable.');
      await widget.services.letters.updateOrganisation(
        _vaultKey,
        widget.letter.id,
        status: LetterStatus.replyPrepared,
      );
      widget.state.updateStatus(widget.letter.id, LetterStatus.replyPrepared);
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('replySavedLocally'))),
        );
      }
      return true;
    } on Object {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.text('responseUnavailable'))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  Future<void> _savePdf(AppStrings strings) async {
    if (!await _saveEditedReply(strings, silent: true)) return;
    try {
      await widget.services.exports.savePdf(
        title: 'BriefAI Germany — ${widget.letter.title}',
        body: _selectedDraft,
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

  Future<void> _saveWord(AppStrings strings) async {
    if (!await _saveEditedReply(strings, silent: true)) return;
    try {
      await widget.services.exports.saveWord(
        title: 'BriefAI Germany — ${widget.letter.title}',
        body: _selectedDraft,
      );
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${strings.text('pdfSaveFailed')}: $error')),
        );
      }
    }
  }

  Future<void> _composeEmail(AppStrings strings) async {
    if (!await _saveEditedReply(strings, silent: true)) return;
    try {
      await widget.services.exports.composeEmail(
        subject: 'Antwort: ${widget.letter.title}',
        body: _emailDraft.text.trimRight(),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Row(
          children: [
            Text(
              'BRIEFAI',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BriefAiDesign.blue,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            _LanguageMenu(state: widget.state, services: widget.services),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: BriefAiDesign.navy,
            borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.folder_copy_outlined,
                    color: Color(0xFFD7E2FF),
                    size: 25,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('archive'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.text('archiveSubtitle'),
                      style: const TextStyle(
                        color: Color(0xFFD5DDF6),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          strings.text('folder'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(strings.text('allFolders')),
              selected: _folder == null,
              onSelected: (_) => setState(() => _folder = null),
            ),
            ...LetterFolder.values.map(
              (folder) => ChoiceChip(
                label: Text(_folderLabel(context, folder)),
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
                : strings.text('emptyFolder'),
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
    // These labels belong to the interface, not to the optional AI answer
    // language.  Keeping them tied to the app locale prevents a Serbian UI
    // from inheriting a previously chosen Russian/Turkish AI language.
    final archiveCopy = _AssistantArchiveCopy(
      label: strings.text('assistantArchiveLabel'),
      ready: strings.text('assistantArchiveReady'),
      explainButton: strings.text('assistantExplainAgainButton'),
      explainAgain: strings.text('assistantExplainAgainPrompt'),
    );
    final selectedHeading = selectedLetter == null
        ? null
        : _letterHeading(context, selectedLetter);
    final visibleMessages = _messages.isEmpty
        ? [
            _ChatMessage(
              text: selectedLetter == null
                  ? strings.text('assistantHello')
                  : '${archiveCopy.ready}\n$selectedHeading',
              fromUser: false,
            ),
          ]
        : _messages;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('assistantTitle')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _LanguageMenu(
              state: widget.state,
              services: widget.services,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (letters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: _AssistantLetterPanel(
                label: archiveCopy.label,
                selectedLetterId: selectedLetter?.id,
                letters: letters,
                disabled: _sending,
                explainButton: archiveCopy.explainButton,
                letterLabel: (letter) => _letterHeading(context, letter),
                categoryLabel: (letter) =>
                    context.strings.category(letter.category.name),
                onChanged: (id) => setState(() {
                  _selectedLetterId = id;
                  // Questions about one letter must never be used as context
                  // for another locally archived letter.
                  _messages.clear();
                }),
                onExplain: selectedLetter == null
                    ? null
                    : () {
                        _question.text = archiveCopy.explainAgain;
                        _ask();
                      },
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: visibleMessages
                  .map(
                    (message) => Align(
                      alignment: message.fromUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: message.fromUser
                              ? BriefAiDesign.blueSoft
                              : BriefAiDesign.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(
                              message.fromUser ? 16 : 5,
                            ),
                            bottomRight: Radius.circular(
                              message.fromUser ? 5 : 16,
                            ),
                          ),
                          border: Border.all(
                            color: message.fromUser
                                ? const Color(0xFFBED0FF)
                                : BriefAiDesign.border,
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.4),
                        ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BriefAiDesign.navy,
            borderRadius: BorderRadius.circular(BriefAiDesign.radius),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  strings.text('myProfile'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
                        // Keep the default explanation language aligned with
                        // an explicit interface-language choice. Users can
                        // still choose a different AI language in the next
                        // setting, but a Serbian UI must not silently keep a
                        // previous language such as Russian.
                        state.setAiLanguage(value);
                        try {
                          final preferences =
                              await SharedPreferences.getInstance();
                          await preferences.setString(
                            'briefai.interface-language',
                            value,
                          );
                          await preferences.setString(
                            'briefai.ai-language',
                            value,
                          );
                          await preferences.setBool(
                            'briefai.ai-language-explicit',
                            false,
                          );
                          await services.auth.setPreferredLanguage(value);
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
                          final preferences =
                              await SharedPreferences.getInstance();
                          await preferences.setBool(
                            'briefai.ai-language-explicit',
                            true,
                          );
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
          title: Text(strings.text('householdProfiles')),
          subtitle: Text(
            strings.format('activeProfileNamed', {
              'name': _householdProfileName(strings, services.household.active),
            }),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HouseholdProfilesScreen(services: services),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.enhanced_encryption_outlined),
          title: Text(strings.text('encryptedArchiveBackup')),
          subtitle: Text(strings.text('backupSubtitle')),
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
                      } on Object catch (_) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.text('accountDeletePartial'),
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
    final strings = context.strings;
    final name = TextEditingController();
    final pin = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(strings.text('newHouseholdProfile')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: strings.text('profileName'),
                ),
              ),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.text('optionalPin'),
                  helperText: strings.text('pinRecommended'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.text('create')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.services.household.add(
        name: name.text,
        pin: pin.text.isEmpty ? null : pin.text,
      );
      if (mounted) {
        setState(() {});
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('tryAgain'))));
      }
    } finally {
      name.dispose();
      pin.dispose();
    }
  }

  Future<void> _activate(HouseholdProfile profile) async {
    final strings = context.strings;
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
              child: Text(strings.text('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.text('open')),
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
      ).showSnackBar(SnackBar(content: Text(strings.text('invalidPin'))));
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.services.household.profiles;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('householdProfiles'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text(strings.text('addProfile')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.text('householdPrivacy')),
          const SizedBox(height: 16),
          ...profiles.map(
            (profile) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    profile.hasPin ? Icons.lock_outline : Icons.person_outline,
                  ),
                ),
                title: Text(_householdProfileName(strings, profile)),
                subtitle: Text(
                  profile.id == widget.services.household.activeId
                      ? strings.text('activeProfile')
                      : strings.text('separateLocalArchive'),
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

  Future<String> _buildEncryptedArchive() async {
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'profile': widget.services.household.active.name,
      'letters': await widget.services.letters.exportRecords(
        widget.services.currentVaultKey,
      ),
      'questionnaires': await widget.services.questionnaires.exportRecords(
        widget.services.currentVaultKey,
      ),
    };
    return widget.services.backups.encrypt(
      payload: payload,
      passphrase: _password.text,
    );
  }

  Future<void> _export() async {
    final strings = context.strings;
    if (_password.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('passwordMin10Error'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final encrypted = await _buildEncryptedArchive();
      await widget.services.exports.shareEncryptedBackup(encrypted);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('backupReady'))));
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('backupFailed'))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restore() async {
    final strings = context.strings;
    if (_password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('backupPasswordRequired'))),
      );
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
      if (rawLetters is! List) {
        throw const FormatException('Invalid backup archive.');
      }
      final records = rawLetters
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
      final count = await widget.services.letters.importRecords(
        widget.services.currentVaultKey,
        records,
      );
      final questionnaires = await _restoreQuestionnaires(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('restoreCount', {'count': count + questionnaires}),
            ),
          ),
        );
      }
    } on Object catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('restoreFailed'))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _uploadCloud() async {
    final strings = context.strings;
    final uid = widget.services.auth.uid;
    if (uid == null || _password.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('passwordMin10Error'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.services.cloudBackups.upload(
        uid: uid,
        encrypted: await _buildEncryptedArchive(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('backupReady'))));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('backupFailed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreCloud() async {
    final strings = context.strings;
    final uid = widget.services.auth.uid;
    if (uid == null || _password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('backupPasswordRequired'))),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final payload = await widget.services.backups.decrypt(
        encodedBackup: await widget.services.cloudBackups.download(uid: uid),
        passphrase: _password.text,
      );
      final rawLetters = payload['letters'];
      if (rawLetters is! List) {
        throw const FormatException('Invalid backup archive.');
      }
      final records = rawLetters
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false);
      final count = await widget.services.letters.importRecords(
        widget.services.currentVaultKey,
        records,
      );
      final questionnaires = await _restoreQuestionnaires(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('restoreCount', {'count': count + questionnaires}),
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(strings.text('restoreFailed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int> _restoreQuestionnaires(Map<String, dynamic> payload) async {
    final raw = payload['questionnaires'];
    if (raw is! List) return 0;
    return widget.services.questionnaires.importRecords(
      widget.services.currentVaultKey,
      raw
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('backupTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.enhanced_encryption_outlined, size: 48),
          const SizedBox(height: 16),
          Text(strings.text('backupDescription')),
          const SizedBox(height: 20),
          TextField(
            controller: _password,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: strings.text('backupPassword'),
              helperText: strings.text('min10Characters'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(strings.text('createEncryptedBackup')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore_page_outlined),
            label: Text(strings.text('restoreBackup')),
          ),
          if (widget.services.cloudEnabled &&
              widget.services.auth.isSignedIn) ...[
            const SizedBox(height: 28),
            Text(
              strings.text('cloudBackup'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(strings.text('cloudBackupPrivacy')),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _uploadCloud,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(strings.text('uploadCloudBackup')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreCloud,
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text(strings.text('restoreCloudBackup')),
            ),
          ],
        ],
      ),
    );
  }
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
      'questionnaires': await services.questionnaires.exportRecords(
        services.currentVaultKey,
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
    final sections = privacy
        ? [
            (strings.text('dataController'), strings.text('legalPrivacyData')),
            (
              strings.text('privacyPolicy'),
              strings.text('legalPrivacyProcessing'),
            ),
            (strings.text('exportData'), strings.text('legalPrivacyRights')),
          ]
        : [
            (strings.text('terms'), strings.text('legalTermsPurpose')),
            (
              strings.text('choosePlan'),
              strings.text('legalTermsSubscriptions'),
            ),
            (strings.text('privacyPolicy'), strings.text('legalTermsUse')),
          ];
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
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: BriefAiDesign.navy,
                      borderRadius: BorderRadius.circular(BriefAiDesign.radius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Icon(
                              Icons.workspace_premium_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.text('choosePlan'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            height: 1.08,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          strings.text('planTagline'),
                          style: const TextStyle(
                            color: Color(0xFFD5DDF6),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _PlanCard(
                    title: 'FREE',
                    price: '0 €',
                    features: [strings.text('freeFeature')],
                    selected: !widget.state.isPremium,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    strings.creditPackText('heading'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.creditPackText('detail'),
                    style: const TextStyle(color: BriefAiDesign.muted),
                  ),
                  const SizedBox(height: 12),
                  for (final pack in kAnalysisCreditPacks) ...[
                    _PlanCard(
                      title:
                          productById[pack.productId]?.title ??
                          strings.creditPackText('item', count: pack.credits),
                      price:
                          productById[pack.productId]?.price ??
                          wrapperPrices[pack.productId] ??
                          pack.fallbackPrice,
                      features: [
                        strings.creditPackText('item', count: pack.credits),
                        strings.creditPackText('detail'),
                      ],
                      action: kIsWeb
                          ? snapshot.data?.nativeWrapper == true
                                ? () => _buyNativePack(pack.productId)
                                : null
                          : () => _buy(productById[pack.productId]),
                    ),
                    const SizedBox(height: 12),
                  ],
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

  Future<void> _buyNativePack(String productId) async {
    try {
      final result = await widget.services.purchases.buyNativeStoreProduct(
        productId,
      );
      if (!mounted) return;
      if (result.creditsAdded > 0) {
        widget.state.setAnalysisCredits(result.analysisCredits);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.creditPackText(
                'added',
                count: result.creditsAdded,
              ),
            ),
          ),
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

enum _LetterCardAction {
  newLetter,
  inProgress,
  replyPrepared,
  sent,
  awaitingReply,
  done,
  organise,
  delete,
}

class _AssistantLetterPanel extends StatelessWidget {
  const _AssistantLetterPanel({
    required this.label,
    required this.selectedLetterId,
    required this.letters,
    required this.disabled,
    required this.explainButton,
    required this.letterLabel,
    required this.categoryLabel,
    required this.onChanged,
    required this.onExplain,
  });

  final String label;
  final String? selectedLetterId;
  final List<LetterAnalysis> letters;
  final bool disabled;
  final String explainButton;
  final String Function(LetterAnalysis letter) letterLabel;
  final String Function(LetterAnalysis letter) categoryLabel;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onExplain;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BriefAiDesign.surface,
        borderRadius: BorderRadius.circular(BriefAiDesign.radius),
        border: Border.all(color: BriefAiDesign.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: BriefAiDesign.blueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      Icons.description_outlined,
                      color: BriefAiDesign.blue,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedLetterId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: BriefAiDesign.surfaceMuted,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: BriefAiDesign.border),
                ),
              ),
              items: letters
                  .map(
                    (letter) => DropdownMenuItem(
                      value: letter.id,
                      child: Text(
                        '${letterLabel(letter)} · ${categoryLabel(letter)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: disabled ? null : onChanged,
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: disabled ? null : onExplain,
              icon: const Icon(Icons.auto_awesome_outlined, size: 19),
              label: Text(explainButton),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    final strings = context.strings;
    final due = letter.paymentDueDate ?? letter.deadline;
    final hasActions =
        onStatus != null || onDelete != null || onOrganize != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LetterThumbnail(highPriority: letter.urgency == Urgency.high),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _letterHeading(context, letter),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _LetterMetaPill(
                            icon: Icons.folder_outlined,
                            label: strings.category(letter.category.name),
                          ),
                          if (letter.isPaymentObligation)
                            _LetterMetaPill(
                              icon: letter.paymentPaid
                                  ? Icons.check_circle_outline
                                  : Icons.payments_outlined,
                              label: letter.paymentPaid
                                  ? strings.text('paymentPaid')
                                  : strings.text('paymentOpen'),
                            ),
                          if (due != null)
                            _LetterMetaPill(
                              icon: Icons.event_outlined,
                              label:
                                  '${due.day.toString().padLeft(2, '0')}.${due.month.toString().padLeft(2, '0')}.${due.year}',
                              warning: due.isBefore(DateTime.now()),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasActions)
                  PopupMenuButton<_LetterCardAction>(
                    tooltip: strings.text('progressStatus'),
                    onSelected: (action) {
                      switch (action) {
                        case _LetterCardAction.newLetter:
                          onStatus?.call(LetterStatus.newLetter);
                        case _LetterCardAction.inProgress:
                          onStatus?.call(LetterStatus.inProgress);
                        case _LetterCardAction.replyPrepared:
                          onStatus?.call(LetterStatus.replyPrepared);
                        case _LetterCardAction.sent:
                          onStatus?.call(LetterStatus.sent);
                        case _LetterCardAction.awaitingReply:
                          onStatus?.call(LetterStatus.awaitingReply);
                        case _LetterCardAction.done:
                          onStatus?.call(LetterStatus.done);
                        case _LetterCardAction.organise:
                          onOrganize?.call();
                        case _LetterCardAction.delete:
                          onDelete?.call();
                      }
                    },
                    itemBuilder: (_) => [
                      if (onStatus != null) ...[
                        PopupMenuItem(
                          value: _LetterCardAction.newLetter,
                          child: Text(strings.text('newStatus')),
                        ),
                        PopupMenuItem(
                          value: _LetterCardAction.inProgress,
                          child: Text(strings.text('progressStatus')),
                        ),
                        PopupMenuItem(
                          value: _LetterCardAction.replyPrepared,
                          child: Text(
                            _statusLabel(context, LetterStatus.replyPrepared),
                          ),
                        ),
                        PopupMenuItem(
                          value: _LetterCardAction.sent,
                          child: Text(_statusLabel(context, LetterStatus.sent)),
                        ),
                        PopupMenuItem(
                          value: _LetterCardAction.awaitingReply,
                          child: Text(
                            _statusLabel(context, LetterStatus.awaitingReply),
                          ),
                        ),
                        PopupMenuItem(
                          value: _LetterCardAction.done,
                          child: Text(strings.text('doneStatus')),
                        ),
                      ],
                      if (onStatus != null &&
                          (onOrganize != null || onDelete != null))
                        const PopupMenuDivider(),
                      if (onOrganize != null)
                        PopupMenuItem(
                          value: _LetterCardAction.organise,
                          child: Text(strings.text('organize')),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: _LetterCardAction.delete,
                          child: Text(strings.text('deleteDocument')),
                        ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LetterThumbnail extends StatelessWidget {
  const _LetterThumbnail({required this.highPriority});
  final bool highPriority;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 72,
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 9),
    decoration: BoxDecoration(
      color: BriefAiDesign.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: highPriority ? const Color(0xFFFFCCCC) : BriefAiDesign.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          highPriority
              ? Icons.priority_high_rounded
              : Icons.description_outlined,
          size: 16,
          color: highPriority ? BriefAiDesign.red : BriefAiDesign.blue,
        ),
        const SizedBox(height: 7),
        const _DocumentLine(width: 30),
        const SizedBox(height: 4),
        const _DocumentLine(width: 22),
        const SizedBox(height: 4),
        const _DocumentLine(width: 27),
      ],
    ),
  );
}

class _DocumentLine extends StatelessWidget {
  const _DocumentLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 3,
    decoration: BoxDecoration(
      color: const Color(0xFFB7C1D4),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _LetterMetaPill extends StatelessWidget {
  const _LetterMetaPill({
    required this.icon,
    required this.label,
    this.warning = false,
  });
  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: warning ? BriefAiDesign.redSoft : BriefAiDesign.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: warning ? BriefAiDesign.red : null),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    ),
  );
}

String _letterHeading(BuildContext context, LetterAnalysis letter) {
  final currentLanguage = Localizations.localeOf(context).languageCode;
  final sourceLanguage = letter.analysisLanguage?.split(RegExp('[-_]')).first;
  if (sourceLanguage == currentLanguage && letter.title.trim().isNotEmpty) {
    return letter.title.trim();
  }

  // Analyses created before language provenance was stored can contain a
  // previous user's language. A neutral sender/category heading is better
  // than presenting a Russian or unrelated title inside a Serbian interface.
  final sender = letter.senderName?.trim();
  final category = context.strings.category(letter.category.name);
  if (sender != null && sender.isNotEmpty) return '$sender — $category';
  return category;
}

String _householdProfileName(AppStrings strings, HouseholdProfile profile) {
  if (profile.id == HouseholdProfileService.personalId &&
      profile.name.trim().toLowerCase() == 'personal') {
    return strings.text('personalProfile');
  }
  return profile.name;
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
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('deadlineCalendar'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(strings.text('deadlineLocal')),
          const SizedBox(height: 20),
          _DeadlineGroup(
            title: strings.text('overdue'),
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            letters: groups.overdue,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: strings.text('today'),
            icon: Icons.today_outlined,
            color: Colors.orange,
            letters: groups.today,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: strings.text('thisWeek'),
            icon: Icons.date_range_outlined,
            color: Colors.blue,
            letters: groups.thisWeek,
            state: state,
            services: services,
          ),
          _DeadlineGroup(
            title: strings.text('later'),
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
              title: Text(_letterHeading(context, letter)),
              subtitle: Text(_dueText(context, letter)),
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
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(context.strings.text('noItems')),
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
  final strings = context.strings;
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
                  strings.text('organizeLetter'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<LetterFolder>(
                  initialValue: folder,
                  decoration: InputDecoration(
                    labelText: strings.text('folder'),
                  ),
                  items: LetterFolder.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_folderLabel(context, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setSheetState(() => folder = value ?? folder),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LetterStatus>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: strings.text('communicationStatus'),
                  ),
                  items: LetterStatus.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_statusLabel(context, value)),
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
                  decoration: InputDecoration(
                    labelText: strings.text('tags'),
                    hintText: strings.text('tagsHint'),
                    helperText: strings.text('tagsHelper'),
                  ),
                ),
                if (letter.isPaymentObligation) ...[
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(strings.text('invoicePaid')),
                    subtitle: Text(
                      letter.amount ?? strings.text('amountNotRecognized'),
                    ),
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
                  child: Text(strings.text('saveLocally')),
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

String _dueText(BuildContext context, LetterAnalysis letter) {
  final due = letter.paymentDueDate ?? letter.deadline;
  if (due == null) return context.strings.text('noDeadline');
  final prefix = letter.isPaymentObligation
      ? context.strings.text('paymentDuePrefix')
      : context.strings.text('deadlinePrefix');
  return '$prefix ${due.day.toString().padLeft(2, '0')}.${due.month.toString().padLeft(2, '0')}.${due.year}';
}

String _statusLabel(BuildContext context, LetterStatus status) =>
    switch (status) {
      LetterStatus.newLetter => context.strings.text('newStatus'),
      LetterStatus.inProgress => context.strings.text('progressStatus'),
      LetterStatus.replyPrepared => context.strings.text('replyPreparedStatus'),
      LetterStatus.sent => context.strings.text('sentStatus'),
      LetterStatus.awaitingReply => context.strings.text('awaitingReplyStatus'),
      LetterStatus.done => context.strings.text('doneStatus'),
    };

String _urgencyLabel(BuildContext context, Urgency urgency) =>
    switch (urgency) {
      Urgency.high => context.strings.text('urgencyHigh'),
      Urgency.medium => context.strings.text('urgencyMedium'),
      Urgency.low => context.strings.text('urgencyLow'),
    };

String _folderLabel(BuildContext context, LetterFolder folder) =>
    switch (folder) {
      LetterFolder.inbox => context.strings.text('folderInbox'),
      LetterFolder.housing => context.strings.text('folderHousing'),
      LetterFolder.work => context.strings.text('folderWork'),
      LetterFolder.family => context.strings.text('folderFamily'),
      LetterFolder.insurance => context.strings.text('folderInsurance'),
      LetterFolder.taxes => context.strings.text('folderTaxes'),
      LetterFolder.finance => context.strings.text('folderFinance'),
    };

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: BriefAiDesign.surface,
      borderRadius: BorderRadius.circular(BriefAiDesign.radius),
      border: Border.all(color: BriefAiDesign.border),
    ),
    child: Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: BriefAiDesign.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 28, color: BriefAiDesign.muted),
        ),
        const SizedBox(height: 14),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BriefAiDesign.muted),
        ),
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
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.content});
  final String title;
  final String content;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: BriefAiDesign.blue,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 8),
            Text(content, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
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
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: selected ? BriefAiDesign.blueSoft : BriefAiDesign.surface,
        borderRadius: BorderRadius.circular(BriefAiDesign.radius),
        border: Border.all(
          color: selected ? BriefAiDesign.blue : BriefAiDesign.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.check, size: 15, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: BriefAiDesign.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: FilledButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.strings.text('choosePlanButton')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
