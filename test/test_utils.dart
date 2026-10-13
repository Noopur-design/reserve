import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reserve_liquor/main.dart';
import 'package:reserve_liquor/state/app_state.dart';
import 'package:reserve_liquor/theme/app_theme.dart';

/// Shared helpers for the widget tests (not a test file itself).

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Loads the real Playfair / Manrope fonts so text is measured like on a
/// phone (the default test font is much narrower and hides overflows).
Future<void> loadAppFonts() async {
  await _loadFont('Playfair', ['assets/fonts/PlayfairDisplay.ttf', 'assets/fonts/PlayfairDisplay-Italic.ttf']);
  await _loadFont('Manrope', ['assets/fonts/Manrope.ttf']);
}

/// Sets the logical screen size and the system text scale for one test.
void setScreen(WidgetTester tester, Size size, {double textScale = 1.0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The app's MaterialApp setup (theme + text-scale clamp) around [home].
Widget appHarness(AppState state, Widget home) => ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: AppTheme.light, builder: clampTextScale, home: home),
    );

/// A signed-in store, as after "Create Account".
AppState signedInState({String name = 'Riya Kapoor'}) {
  final s = AppState();
  final err = s.createAccount(name: name, phone: '9876543210', email: 'riya@example.com', password: 'secret1');
  if (err != null) throw StateError(err);
  return s;
}

/// Fails if any text found by [finder] was cut off (ellipsis / maxLines) or
/// wrapped anywhere other than its own line breaks (e.g. mid-word). Overflow
/// checks miss both, since neither is an error.
void expectTextFits(WidgetTester tester, Finder finder) {
  final elements = finder.evaluate().toList();
  expect(elements, isNotEmpty, reason: 'no text found for $finder');
  for (final e in elements) {
    final p = e.renderObject! as RenderParagraph;
    final natural = TextPainter(
      text: p.text,
      textDirection: p.textDirection,
      textScaler: p.textScaler,
      strutStyle: p.strutStyle,
      textHeightBehavior: p.textHeightBehavior,
      locale: p.locale,
    )..layout();
    final label = p.text.toPlainText().replaceAll('\n', r'\n');
    expect(p.didExceedMaxLines, isFalse, reason: '"$label" is cut off');
    expect(p.size.height, lessThanOrEqualTo(natural.height + 0.5),
        reason: '"$label" wraps onto extra lines (${p.size.height} vs ${natural.height})');
    natural.dispose();
  }
}

/// For text that may wrap: fails if it was cut off, or if any word is wider
/// than the line (the only case where a line breaks mid-word).
void expectNoBrokenWords(WidgetTester tester, Finder finder) {
  final elements = finder.evaluate().toList();
  expect(elements, isNotEmpty, reason: 'no text found for $finder');
  for (final e in elements) {
    final p = e.renderObject! as RenderParagraph;
    final label = p.text.toPlainText();
    expect(p.didExceedMaxLines, isFalse, reason: '"$label" is cut off');
    final style = p.text.style;
    for (final word in label.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      final w = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: p.textDirection,
        textScaler: p.textScaler,
      )..layout();
      expect(w.width, lessThanOrEqualTo(p.size.width + 0.5), reason: '"$word" in "$label" is broken mid-word');
      w.dispose();
    }
  }
}

/// How much [finder]'s single text is scaled on screen (1.0 = full size),
/// e.g. by a FittedBox around it.
double shownScale(WidgetTester tester, Finder finder) {
  final p = tester.renderObject<RenderParagraph>(finder);
  return tester.getRect(finder).width / p.size.width;
}

bool _neverScrolls(ScrollPhysics? p) {
  for (var x = p; x != null; x = x.parent) {
    if (x is NeverScrollableScrollPhysics) return true;
  }
  return false;
}

/// Scrolls every scrollable on screen from start to end, a viewport at a
/// time, so lazily built rows are laid out too (and any overflow in them is
/// reported). Swipe-locked views such as the onboarding PageView are skipped.
Future<void> scrollThroughAll(WidgetTester tester) async {
  final done = <ScrollableState>{};
  for (var pass = 0; pass < 3; pass++) {
    final states = tester.stateList<ScrollableState>(find.byType(Scrollable)).toList();
    var any = false;
    for (final s in states) {
      if (done.contains(s) || !s.mounted) continue;
      done.add(s);
      if (_neverScrolls(s.widget.physics)) continue;
      final pos = s.position;
      if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) continue;
      any = true;
      final step = (pos.viewportDimension * 0.8).clamp(80.0, double.infinity);
      var offset = pos.pixels;
      while (s.mounted && offset < s.position.maxScrollExtent) {
        offset = (offset + step).clamp(0.0, s.position.maxScrollExtent);
        s.position.jumpTo(offset);
        await tester.pump(const Duration(milliseconds: 60));
      }
      if (s.mounted) {
        s.position.jumpTo(0);
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
    if (!any) break;
  }
}
