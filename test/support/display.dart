// Screen size, text size and language for widget tests (US5.1, US5.2).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets the test view to [width] by [height] logical pixels with system text
/// at [textScale] (2.0 is 200%), and restores everything after the test.
void useDisplay(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1,
}) {
  tester.view
    ..devicePixelRatio = 2
    ..physicalSize = Size(width * 2, height * 2);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Makes the phone's own language [locale] for this test, which the app
/// follows until the person picks a language.
void usePhoneLocale(WidgetTester tester, Locale locale) {
  tester.platformDispatcher.localesTestValue = [locale];
  tester.platformDispatcher.localeTestValue = locale;
  addTearDown(() {
    tester.platformDispatcher.clearLocalesTestValue();
    tester.platformDispatcher.clearLocaleTestValue();
  });
}

/// The smallest phone width the app supports, with text at 200%.
void useSmallPhoneWithLargeText(WidgetTester tester) =>
    useDisplay(tester, width: 320, height: 640, textScale: 2);
