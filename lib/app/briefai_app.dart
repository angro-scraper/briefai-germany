import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/domain.dart';
import '../core/app_services.dart';

class BriefAiApp extends StatefulWidget {
  const BriefAiApp({super.key, required this.services});
  final AppServices services;

  @override
  State<BriefAiApp> createState() => _BriefAiAppState();
}

class _BriefAiAppState extends State<BriefAiApp> {
  final AppState _state = AppState();
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _purchaseSubscription = widget.services.purchases.updates.listen(
        _handlePurchaseUpdates,
        onError: (_) {},
      );
    }
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
      theme: _theme(),
      home: _state.onboardingComplete
          ? AppShell(state: _state, services: widget.services)
          : OnboardingScreen(onComplete: _state.completeOnboarding),
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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;
  static const _pages = [
    (
      'Fotografiši nemačko pismo',
      'Snimite dokument ili učitajte PDF i sliku.',
      Icons.document_scanner_outlined,
    ),
    (
      'AI objašnjava šta znači',
      'Jasno objašnjenje na vašem jeziku, bez administrativnog žargona.',
      Icons.auto_awesome,
    ),
    (
      'Ne propusti rokove',
      'Sačuvajte dokument i dobićete podsetnike za važne datume.',
      Icons.notifications_active_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _pages[_page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'BriefAI',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                child: Text(_page == 2 ? 'Počni bezbedno' : 'Nastavi'),
              ),
              TextButton(
                onPressed: widget.onComplete,
                child: const Text('Preskoči'),
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

  @override
  void initState() {
    super.initState();
    if (widget.services.cloudEnabled) {
      _authSubscription = widget.services.auth.authChanges.listen((user) {
        _lettersSubscription?.cancel();
        _entitlementSubscription?.cancel();
        if (user != null) {
          _lettersSubscription = widget.services.letters
              .watch(user.uid)
              .listen(widget.state.replaceLetters);
          _entitlementSubscription = widget.services.entitlements
              .watch(user.uid)
              .listen(widget.state.setPremium);
        } else {
          widget.state.setPremium(false);
        }
      });
    }
  }

  @override
  void dispose() {
    _lettersSubscription?.cancel();
    _entitlementSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Početna',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Arhiva',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Asistent',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
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
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Dobro došli',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text('Razumite nemačka pisma, na jeziku koji vam odgovara.'),
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
            const Text(
              'Analiziraj novo pismo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.isPremium
                  ? 'Neograničene analize su aktivne.'
                  : 'Preostalo: ${2 - state.freeAnalysesUsed} od 2 besplatne analize.',
              style: const TextStyle(color: Color(0xFFD7E0FF)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: state.canAnalyse
                  ? () => !services.cloudEnabled || services.auth.isSignedIn
                        ? Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnalysisScreen(
                                state: state,
                                services: services,
                              ),
                            ),
                          )
                        : Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SignInScreen(services: services),
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
                state.canAnalyse ? 'Dodaj dokument' : 'Aktiviraj Premium',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      Text(
        'Poslednja pisma',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      if (state.letters.isEmpty)
        const _EmptyState(
          icon: Icons.inbox_outlined,
          text: 'Još nemate sačuvanih pisama.',
        )
      else
        ...state.letters.take(3).map((letter) => LetterCard(letter: letter)),
    ],
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_create ? 'Kreiraj nalog' : 'Prijava')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Sačuvajte pisma na bezbedan način.',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Lozinka (najmanje 6 znakova)',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _emailSignIn,
          child: Text(_create ? 'Kreiraj nalog' : 'Prijavi se'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _google,
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Nastavi sa Google'),
        ),
        if (Theme.of(context).platform == TargetPlatform.iOS)
          OutlinedButton.icon(
            onPressed: _loading ? null : _apple,
            icon: const Icon(Icons.apple),
            label: const Text('Nastavi sa Apple'),
          ),
        TextButton(
          onPressed: () => setState(() => _create = !_create),
          child: Text(
            _create
                ? 'Već imate nalog? Prijavite se'
                : 'Nemate nalog? Registrujte se',
          ),
        ),
      ],
    ),
  );

  Future<void> _emailSignIn() => _run(
    () => widget.services.auth.signInWithEmail(
      _email.text.trim(),
      _password.text,
      create: _create,
    ),
  );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Prijava nije uspela: $error')));
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
  final _text = TextEditingController(
    text:
        'Finanzamt\nBitte reichen Sie die Unterlagen bis zum 05.08.2026 ein. Betrag: 120,00 EUR.',
  );
  bool _loading = false;
  PickedDocument? _document;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nova analiza')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Učitajte dokument',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kamera, PDF i galerija se u produkciji povezuju kroz ML Kit OCR. Za lokalnu proveru unesite ili nalepite tekst dokumenta.',
          ),
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
                label: const Text('Kamera'),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _select(widget.services.documents.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galerija'),
              ),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _select(widget.services.documents.file),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('PDF ili slika'),
              ),
            ],
          ),
          if (_document != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Izabrano: ${_document!.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(hintText: 'Tekst sa pisma'),
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
            label: Text(_loading ? 'AI obrađuje…' : 'Analiziraj pismo'),
          ),
        ],
      ),
    ),
  );

  Future<void> _analyse() async {
    setState(() => _loading = true);
    try {
      final id = newLetterId();
      final userId = widget.services.auth.uid ?? 'local-user';
      final language = await widget.services.auth.preferredLanguage();
      String? storagePath;
      if (_document != null) {
        storagePath = await widget.services.documents.upload(
          uid: userId,
          letterId: id,
          document: _document!,
        );
        if (!_document!.isPdf && _document!.ocrPath != null) {
          _text.text = await widget.services.documents.ocr(_document!);
        } else if (storagePath != null) {
          _text.text = await widget.services.documents.extractUploadedText(
            storagePath: storagePath,
            mimeType: _document!.mimeType,
          );
        } else {
          throw StateError(
            'PDF analiza zahteva prijavljen nalog i Firebase Storage.',
          );
        }
      }
      final analysis = await widget.services.ai.analyse(
        letterId: id,
        text: _text.text,
        language: language,
        storagePath: storagePath,
      );
      widget.state.addAnalysis(analysis);
      await widget.services.reminders.schedule(analysis);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analiza nije uspela: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _select(Future<PickedDocument?> Function() source) async {
    final selected = await source();
    if (selected == null) return;
    setState(() => _document = selected);
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rezultat analize')),
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
          title: 'Jednostavno objašnjenje',
          content: letter.plainExplanation,
        ),
        _ResultSection(title: 'Kategorija', content: letter.category.label),
        if (letter.deadline != null)
          _ResultSection(
            title: 'Rok',
            content:
                '${letter.deadline!.day.toString().padLeft(2, '0')}.${letter.deadline!.month.toString().padLeft(2, '0')}.${letter.deadline!.year}',
          ),
        if (letter.amount != null)
          _ResultSection(title: 'Pronađen iznos', content: letter.amount!),
        _ResultSection(
          title: 'Šta sada da uradite',
          content: letter.suggestedAction,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ResponseScreen(letter: letter, services: services),
            ),
          ),
          icon: const Icon(Icons.edit_note),
          label: const Text('Generiši odgovor'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Završi i idi na početnu'),
        ),
      ],
    ),
  );
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
  late final Future<String> _response = () async {
    final language = await widget.services.auth.preferredLanguage();
    return widget.services.ai.generateReply(
      letterId: widget.letter.id,
      facts: widget.letter.sourceText,
      language: language,
    );
  }();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Predlog odgovora')),
    body: FutureBuilder<String>(
      future: _response,
      builder: (context, snapshot) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Formalni nemački odgovor',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: snapshot.hasError
                    ? Text('Odgovor nije dostupan: ${snapshot.error}')
                    : snapshot.hasData
                    ? SelectableText(snapshot.data!)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: snapshot.hasData
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Odgovor je spreman za kopiranje.'),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.copy),
              label: const Text('Kopiraj odgovor'),
            ),
          ],
        ),
      ),
    ),
  );
}

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Arhiva',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text('Vaša pisma su organizovana po statusu i kategoriji.'),
      const SizedBox(height: 20),
      if (state.letters.isEmpty)
        const _EmptyState(
          icon: Icons.folder_off_outlined,
          text: 'Arhiva je prazna.',
        )
      else
        ...state.letters.map(
          (letter) => LetterCard(
            letter: letter,
            onStatus: (status) async {
              state.updateStatus(letter.id, status);
              final uid = services.auth.uid;
              if (uid != null) {
                await services.letters.updateStatus(uid, letter.id, status);
              }
            },
          ),
        ),
    ],
  );
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key, required this.state, required this.services});
  final AppState state;
  final AppServices services;
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _question = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Zdravo! Pitajte me o pismu koje ste upravo analizirali.',
      fromUser: false,
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI asistent')),
    body: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: _messages
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
                  decoration: const InputDecoration(
                    hintText: 'Npr. Koji je rok?',
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
        letterId: letter?.id,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(text: answer, fromUser: false)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Odgovor nije dostupan: $error',
          fromUser: false,
        ));
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
  Widget build(BuildContext context) => ListView(
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
          'Moj profil',
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
                  title: const Text('Ime'),
                  subtitle: Text(name.isEmpty ? 'Dodajte ime' : name),
                  onTap: () => _editTextProfile(
                    context,
                    services,
                    'Ime',
                    name,
                    (value) => services.auth.updateProfile(displayName: value),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Preferirani jezik'),
                  subtitle: Text(_languageLabels[language] ?? language),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        services.auth.updateProfile(preferredLanguage: value),
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
                  title: const Text('Zemlja porekla'),
                  subtitle: Text(
                    country.isEmpty ? 'Dodajte zemlju porekla' : country,
                  ),
                  onTap: () => _editTextProfile(
                    context,
                    services,
                    'Zemlja porekla',
                    country,
                    (value) =>
                        services.auth.updateProfile(countryOfOrigin: value),
                  ),
                ),
              ],
            );
          },
        )
      else ...const [
        ListTile(
          leading: Icon(Icons.language),
          title: Text('Preferirani jezik'),
          subtitle: Text('Srpski'),
        ),
        ListTile(
          leading: Icon(Icons.public),
          title: Text('Zemlja porekla'),
          subtitle: Text('Prijavite se da biste sačuvali profil'),
        ),
      ],
      const Divider(),
      ListTile(
        leading: const Icon(Icons.workspace_premium),
        title: Text(state.isPremium ? 'Premium je aktivan' : 'BriefAI Premium'),
        subtitle: const Text('Neograničene analize, odgovori i podsetnici'),
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
          title: const Text('Prijavite se ili kreirajte nalog'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => SignInScreen(services: services)),
          ),
        ),
      if (services.cloudEnabled && services.auth.isSignedIn)
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Odjavi se'),
          onTap: services.auth.signOut,
        ),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privatnost i brisanje naloga'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => const AlertDialog(
            title: Text('Vaša privatnost'),
            content: Text(
              'U produkciji se podaci čuvaju šifrovano, a nalog i dokumenti mogu se trajno obrisati iz profila.',
            ),
          ),
        ),
      ),
      if (services.cloudEnabled && services.auth.isSignedIn)
        ListTile(
          leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
          title: const Text('Trajno obriši nalog'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Obrisati nalog?'),
              content: const Text(
                'Ova radnja trajno briše dokumente, analize i korisnički nalog.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: () async {
                    await services.auth.deleteAccount();
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Obriši'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
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
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () async {
            await save(controller.text.trim());
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: const Text('Sačuvaj'),
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
  late final Future<ProductDetailsResponse> _products;

  @override
  void initState() {
    super.initState();
    _products = kIsWeb
        ? Future.value(
            ProductDetailsResponse(productDetails: const [], notFoundIDs: const []),
          )
        : widget.services.purchases.products();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Izaberite plan')),
    body: FutureBuilder<ProductDetailsResponse>(
      future: _products,
      builder: (context, snapshot) {
        final productById = {
          for (final product
              in snapshot.data?.productDetails ?? <ProductDetails>[])
            product.id: product,
        };
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Više sigurnosti, manje stresa.',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _PlanCard(
              title: 'FREE',
              price: '0 €',
              features: const ['2 analize mesečno'],
              selected: !widget.state.isPremium,
            ),
            _PlanCard(
              title: 'PREMIUM',
              price:
                  productById[PurchaseService.premiumId]?.price ??
                  '4,99 € / mesečno',
              features: const [
                'Neograničene analize',
                'AI odgovori i prevodi',
                'Arhiva i podsetnici',
              ],
              action: kIsWeb
                  ? () => _webCheckout('premium')
                  : () => _buy(productById[PurchaseService.premiumId]),
            ),
            _PlanCard(
              title: 'PRO',
              price:
                  productById[PurchaseService.proId]?.price ??
                  '9,99 € / mesečno',
              features: const [
                'Za porodice i male firme',
                'Sve iz Premium paketa',
              ],
              action: kIsWeb
                  ? () => _webCheckout('pro')
                  : () => _buy(productById[PurchaseService.proId]),
            ),
            const SizedBox(height: 12),
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: _restorePurchases,
                icon: const Icon(Icons.restore),
                label: const Text('Vrati kupovine'),
              ),
            if (!kIsWeb) const SizedBox(height: 12),
            Text(
              snapshot.hasError
                  ? 'Kupovine trenutno nisu dostupne: ${snapshot.error}'
                  : 'Plaćanje se obrađuje preko Google Play Billing / Apple In-App Purchase. Entitlement se aktivira tek nakon serverske verifikacije.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );

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
}

class LetterCard extends StatelessWidget {
  const LetterCard({super.key, required this.letter, this.onStatus});
  final LetterAnalysis letter;
  final ValueChanged<LetterStatus>? onStatus;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        child: Icon(
          letter.urgency == Urgency.high
              ? Icons.priority_high
              : Icons.description_outlined,
        ),
      ),
      title: Text(letter.title),
      subtitle: Text(
        '${letter.category.label}${letter.deadline == null ? '' : ' • Rok ${letter.deadline!.day}.${letter.deadline!.month}.'}',
      ),
      trailing: onStatus == null
          ? null
          : PopupMenuButton<LetterStatus>(
              onSelected: onStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: LetterStatus.newLetter,
                  child: Text('Novo'),
                ),
                PopupMenuItem(
                  value: LetterStatus.inProgress,
                  child: Text('Rešavam'),
                ),
                PopupMenuItem(
                  value: LetterStatus.done,
                  child: Text('Završeno'),
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
                child: const Text('Izaberi plan'),
              ),
            ),
        ],
      ),
    ),
  );
}
