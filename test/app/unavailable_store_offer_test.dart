import 'package:briefai_germany/app/briefai_app.dart';
import 'package:briefai_germany/core/app_config.dart';
import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/app_services.dart';
import 'package:briefai_germany/core/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'paywall does not advertise fallback prices without store offers',
    (tester) async {
      await showScreen(
        tester,
        SubscriptionScreen(
          state: AppState(),
          services: AppServices.unavailable('store test'),
        ),
      );

      expect(find.text('Purchases are currently unavailable.'), findsWidgets);
      for (final pack in kAnalysisCreditPacks) {
        expect(find.textContaining(pack.fallbackPrice), findsNothing);
      }
      for (final plan in kSubscriptionPlans) {
        await tester.scrollUntilVisible(
          find.text('${plan.key.toUpperCase()} · ${plan.monthlyAnalysisLimit}'),
          250,
        );
        expect(find.textContaining(plan.fallbackPrice), findsNothing);
        expect(find.text('Purchases are currently unavailable.'), findsWidgets);
      }
    },
  );

  testWidgets('questionnaire packages do not advertise unavailable prices', (
    tester,
  ) async {
    await showScreen(
      tester,
      QuestionnairePackagesScreen(
        state: AppState(),
        services: AppServices.unavailable('store test'),
      ),
    );

    expect(find.text('Purchases are currently unavailable.'), findsWidgets);
    for (final pack in kAnalysisCreditPacks) {
      expect(find.textContaining(pack.fallbackPrice), findsNothing);
    }
  });
}
