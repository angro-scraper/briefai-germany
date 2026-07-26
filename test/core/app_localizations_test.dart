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
        'uploadDocument',
        'ocrReading',
        'loadingImage',
        'ocrReady',
        'ocrNotReady',
        'ocrFailed',
        'enterTextFirst',
        'analyzeLetter',
        'assistantTitle',
        'resultTitle',
        'simpleExplanation',
        'generateReply',
        'replyTitle',
        'archiveSubtitle',
        'privacyPolicy',
        'choosePlan',
        'freeBetaActive',
        'freeBetaTitle',
        'freeBetaBody',
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
  });
}
