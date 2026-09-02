import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/domain.dart';
import 'package:briefai_germany/core/eu_major_language_translations.dart';
import 'package:briefai_germany/core/major_language_translations.dart';
import 'package:briefai_germany/core/workflow_translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'all supported app languages contain the primary user journey',
    () async {
      const keys = [
        'home',
        'archive',
        'assistant',
        'profile',
        'welcome',
        'appLanguage',
        'signIn',
        'createAccount',
        'continueEmail',
        'pricePerMonth',
        'appleNoExtraData',
        'optionalProfileName',
        'uploadDocument',
        'page',
        'pagesSelected',
        'ocrProgress',
        'removePage',
        'maxPages',
        'filesTooLarge',
        'ocrReading',
        'loadingImage',
        'ocrReady',
        'ocrNotReady',
        'photoReadyForAnalysis',
        'ocrFailed',
        'enterTextFirst',
        'analyzeLetter',
        'assistantTitle',
        'resultTitle',
        'simpleExplanation',
        'senderName',
        'recipientName',
        'paymentRecipient',
        'documentType',
        'invoiceNumber',
        'servicePeriod',
        'paymentReference',
        'paymentObligation',
        'paymentDueDate',
        'paymentOpen',
        'paymentPaid',
        'generateReply',
        'replyFactsTitle',
        'replyFactsHelp',
        'replyFactsHint',
        'replySavedLocally',
        'editReplyContext',
        'pdfReady',
        'pdfSaveFailed',
        'replyTitle',
        'archiveSubtitle',
        'privacyPolicy',
        'choosePlan',
        'freeFeature',
        'deleteAccount',
      ];

      for (final locale in AppStrings.supportedLocales) {
        final strings = await AppStrings.delegate.load(locale);
        for (final key in keys) {
          expect(
            strings.text(key),
            isNot(key),
            reason: '${locale.languageCode} is missing $key',
          );
        }
        for (final category in LetterCategory.values) {
          expect(
            strings.category(category.name),
            isNot(category.name),
            reason:
                '${locale.languageCode} is missing category ${category.name}',
          );
        }
      }
    },
  );

  test('interface and AI language choices are explicitly separated', () {
    expect(AppStrings.languageLabels, hasLength(53));
    expect(AppStrings.fullyLocalizedLanguageCodes, hasLength(16));
    expect(
      AppStrings.interfaceLanguageEntries.map((entry) => entry.key).toSet(),
      AppStrings.fullyLocalizedLanguageCodes,
    );
    expect(
      AppStrings.aiLanguageEntries.map((entry) => entry.key).toSet(),
      AppStrings.languageLabels.keys.toSet(),
    );
    for (final entry in AppStrings.aiLanguageEntries) {
      expect(AppStrings.languagePickerLabel(entry), entry.value);
    }
  });

  test(
    'every advertised interface language ships every static string',
    () async {
      for (final language in AppStrings.fullyLocalizedLanguageCodes) {
        final strings = await AppStrings.delegate.load(Locale(language));
        for (final key in AppStrings.interfaceTextKeys) {
          expect(
            strings.shipsStaticText(key),
            isTrue,
            reason: '$language falls back for interface key $key',
          );
        }
        for (final key in AppStrings.categoryKeys) {
          expect(
            strings.shipsCategory(key),
            isTrue,
            reason: '$language falls back for category $key',
          );
        }
        for (final key in AppStrings.purchaseMessageKeys) {
          expect(
            strings.shipsPurchaseMessage(key),
            isTrue,
            reason: '$language falls back for purchase message $key',
          );
        }
      }
    },
  );

  test('remaining analysis count is interpolated', () async {
    final strings = await AppStrings.delegate.load(
      AppStrings.supportedLocales.first,
    );
    expect(strings.remaining(1), contains('1'));
    expect(strings.remaining(1), isNot(contains('{count}')));
    expect(strings.pagesSelected(3), contains('3'));
    expect(strings.pagesSelected(3), isNot(contains('{count}')));
    expect(strings.ocrProgress(2, 5), allOf(contains('2'), contains('5')));
    expect(strings.maxPages(20), contains('20'));
  });

  test('Russian, Ukrainian and Arabic ship complete static interfaces', () {
    const majorLanguages = {'ru', 'uk', 'ar'};
    const referenceLanguage = 'ru';
    final referenceKeys = majorInterfaceTranslations[referenceLanguage]!.keys
        .toSet();
    final referenceCategoryKeys = majorCategoryTranslations[referenceLanguage]!
        .keys
        .toSet();

    expect(referenceKeys, hasLength(153));
    expect(referenceCategoryKeys, hasLength(LetterCategory.values.length));

    for (final language in majorLanguages) {
      expect(
        AppStrings.hasFullyLocalizedInterface(language),
        isTrue,
        reason: '$language must be presented as a complete app language',
      );
      expect(
        majorInterfaceTranslations[language]!.keys.toSet(),
        referenceKeys,
        reason: '$language is missing interface strings',
      );
      expect(
        majorCategoryTranslations[language]!.keys.toSet(),
        referenceCategoryKeys,
        reason: '$language is missing document categories',
      );
    }
  });

  test(
    'Romanian, Polish, Italian, Greek and Albanian ship complete interfaces',
    () {
      const additionalLanguages = {'ro', 'pl', 'it', 'el', 'sq'};
      final referenceKeys = majorInterfaceTranslations['ru']!.keys.toSet();
      final referenceCategoryKeys = majorCategoryTranslations['ru']!.keys
          .toSet();

      for (final language in additionalLanguages) {
        expect(
          AppStrings.hasFullyLocalizedInterface(language),
          isTrue,
          reason: '$language must be presented as a complete app language',
        );
        expect(
          euMajorInterfaceTranslations[language]!.keys.toSet(),
          referenceKeys,
          reason: '$language is missing interface strings',
        );
        expect(
          euMajorCategoryTranslations[language]!.keys.toSet(),
          referenceCategoryKeys,
          reason: '$language is missing document categories',
        );
      }
    },
  );

  test('additional language bundles preserve runtime placeholders', () {
    final english = const AppStrings(Locale('en'));
    final placeholderPattern = RegExp(r'\{[^}]+\}');

    for (final language in const ['ro', 'pl', 'it', 'el', 'sq']) {
      for (final entry in euMajorInterfaceTranslations[language]!.entries) {
        final expected = placeholderPattern
            .allMatches(english.text(entry.key))
            .map((match) => match.group(0))
            .toList();
        final actual = placeholderPattern
            .allMatches(entry.value)
            .map((match) => match.group(0))
            .toList();
        expect(
          actual,
          expected,
          reason: '$language changed placeholders for ${entry.key}',
        );
      }
      expect(
        euMajorInterfaceTranslations[language]!['premiumName'],
        'BriefAI Premium',
      );
    }
  });

  test('workflow translations are complete and preserve placeholders', () {
    final english = const AppStrings(Locale('en'));
    final placeholderPattern = RegExp(r'\{[^}]+\}');
    final referenceKeys = workflowInterfaceTranslations['en']!.keys.toSet();

    expect(
      workflowInterfaceTranslations.keys.toSet(),
      AppStrings.fullyLocalizedLanguageCodes,
    );
    for (final language in AppStrings.fullyLocalizedLanguageCodes) {
      final translations = workflowInterfaceTranslations[language]!;
      expect(
        translations.keys.toSet(),
        referenceKeys,
        reason: '$language is missing workflow interface strings',
      );
      for (final entry in translations.entries) {
        final expected = placeholderPattern
            .allMatches(english.text(entry.key))
            .map((match) => match.group(0))
            .toList();
        final actual = placeholderPattern
            .allMatches(entry.value)
            .map((match) => match.group(0))
            .toList();
        expect(
          actual,
          expected,
          reason: '$language changed placeholders for ${entry.key}',
        );
      }
    }
  });

  test('major-language user journeys do not fall back to English', () async {
    const englishValues = {
      'Welcome',
      'Analyze a new letter',
      'Upload document',
      'Analysis result',
      'Generate reply',
      'Save PDF',
      'Choose a plan',
    };
    const keys = {
      'welcome',
      'analyzeNew',
      'uploadDocument',
      'resultTitle',
      'generateReply',
      'savePdf',
      'choosePlan',
    };

    for (final language in const [
      'ru',
      'uk',
      'ar',
      'ro',
      'pl',
      'it',
      'el',
      'sq',
    ]) {
      final strings = await AppStrings.delegate.load(Locale(language));
      for (final key in keys) {
        expect(
          englishValues,
          isNot(contains(strings.text(key))),
          reason: '$language unexpectedly fell back to English for $key',
        );
      }
    }
  });

  testWidgets('Arabic interface uses right-to-left layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Text(
            Directionality.of(context) == TextDirection.rtl ? 'rtl' : 'ltr',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('rtl'), findsOneWidget);
  });
}
