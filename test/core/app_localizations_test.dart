import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/domain.dart';
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
}
