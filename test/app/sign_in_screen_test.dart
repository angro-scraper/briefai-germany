import 'package:briefai_germany/app/briefai_app.dart';
import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/link.dart';

void main() {
  testWidgets(
    'Apple sign in is a direct primary action and email stays optional',
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

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('apple-sign-in')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.byKey(const ValueKey('email-auth-field')), findsNothing);
      final privacyLink = tester.widget<Link>(
        find.ancestor(
          of: find.byKey(const ValueKey('sign-in-privacy-link')),
          matching: find.byType(Link),
        ),
      );
      final termsLink = tester.widget<Link>(
        find.ancestor(
          of: find.byKey(const ValueKey('sign-in-terms-link')),
          matching: find.byType(Link),
        ),
      );
      expect(
        privacyLink.uri.toString(),
        'https://briefai.salvesca.com/privacy.html',
      );
      expect(
        termsLink.uri.toString(),
        'https://briefai.salvesca.com/terms.html',
      );

      await tester.tap(find.byKey(const ValueKey('show-email-auth')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('email-auth-field')), findsOneWidget);
    },
  );
}
