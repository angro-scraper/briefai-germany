import 'package:briefai_germany/app/briefai_app.dart';
import 'package:briefai_germany/core/app_localizations.dart';
import 'package:briefai_germany/core/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('both privacy choices are visible on a narrow first visit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppStrings.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnalyticsConsentCard(
              analytics: PrivacyAnalyticsService(cloudEnabled: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final accept = find.text('Akzeptieren');
    final decline = find.text('Ablehnen');
    expect(accept, findsOneWidget);
    expect(decline, findsOneWidget);
    expect(
      tester.getTopLeft(accept).dy,
      lessThan(tester.getTopLeft(decline).dy),
    );
    expect(
      tester
          .getSize(
            find.ancestor(of: accept, matching: find.byType(FilledButton)),
          )
          .width,
      greaterThan(280),
    );
    expect(tester.takeException(), isNull);
  });
}
