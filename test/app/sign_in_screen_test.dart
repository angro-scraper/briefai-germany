import 'package:briefai_germany/app/briefai_app.dart';
import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Apple sign in does not show or require the email registration form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppStrings.supportedLocales,
          home: SignInScreen(services: AppServices.unavailable('widget test')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('apple-sign-in')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.textContaining('do not ask you'), findsOneWidget);
      expect(find.byKey(const ValueKey('email-auth-field')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('show-email-auth')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('email-auth-field')), findsOneWidget);
    },
  );
}
