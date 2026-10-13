import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Web only: shows the app inside a phone-sized device frame when the
/// browser viewport is wide (desktop, tablet), so the phone-first layouts are
/// not stretched across a monitor. Narrow viewports (real phones, or the app
/// embedded in a ~412 px wide iframe) get the app full-bleed, exactly as on a
/// device. On Android / iOS this widget just returns [child].
///
/// Use it in `MaterialApp.builder` around the Navigator, so every route,
/// dialog, bottom sheet, snack bar and tooltip (they all live in the
/// Navigator's overlay or a route's Scaffold) is laid out and clipped inside
/// the frame. The framed area gets its own [MediaQuery]: a phone-sized
/// [MediaQueryData.size], a status-bar / gesture-bar [MediaQueryData.padding]
/// and the part of an on-screen keyboard that overlaps the phone.
class WebFrame extends StatefulWidget {
  const WebFrame({super.key, required this.child, this.enabled});

  final Widget child;

  /// Whether the frame may be shown at all. Defaults to [kIsWeb]; tests pass
  /// `true`, since `kIsWeb` is false under `flutter test`.
  final bool? enabled;

  /// Viewports wider than this (logical px) get the device frame.
  static const double breakpoint = 600;

  /// Logical size of the framed "phone" screen.
  static const double screenWidth = 412;
  static const double maxScreenHeight = 900;

  /// Shorter windows keep this screen height and scale the phone down
  /// instead, so layouts never get squashed below a real phone's height.
  static const double minScreenHeight = 640;

  /// Simulated status bar and gesture-bar insets inside the frame.
  static const EdgeInsets screenPadding = EdgeInsets.only(top: 24, bottom: 16);

  static const double screenRadius = 40;
  static const double bezel = 10;

  /// Space kept free above and below the phone.
  static const double margin = 24;
  static const double _captionGap = 14;
  static const double _captionHeight = 18;
  static const double _captionSpace = _captionGap + _captionHeight;

  static const caption = 'Reserve · Flutter demo — best viewed on mobile';

  /// Whether a viewport of [size] shows the frame (when enabled).
  static bool framesAt(Size size) => size.width > breakpoint;

  @override
  State<WebFrame> createState() => _WebFrameState();
}

/// Where the phone sits in a wide viewport.
@immutable
class _FrameLayout {
  const _FrameLayout({required this.screenHeight, required this.scale, required this.gapBelowScreen});

  /// Logical height of the phone screen (width is [WebFrame.screenWidth]).
  final double screenHeight;

  /// < 1 when the window is too short and the whole phone is scaled down.
  final double scale;

  /// Viewport px between the bottom of the phone screen and the bottom of
  /// the viewport (used to work out how much of a keyboard overlaps it).
  final double gapBelowScreen;

  static const double outerWidth = WebFrame.screenWidth + 2 * WebFrame.bezel;

  double get outerHeight => screenHeight + 2 * WebFrame.bezel;

  /// Phone plus caption, unscaled.
  double get blockHeight => outerHeight + WebFrame._captionSpace;

  factory _FrameLayout.of(Size viewport) {
    final available = math.max(0.0, viewport.height - 2 * WebFrame.margin);
    final screenHeight = (available - WebFrame._captionSpace - 2 * WebFrame.bezel)
        .clamp(WebFrame.minScreenHeight, WebFrame.maxScreenHeight)
        .toDouble();
    final blockHeight = screenHeight + 2 * WebFrame.bezel + WebFrame._captionSpace;
    final scale = math.min(
      1.0,
      math.min(available / blockHeight, math.max(0.0, viewport.width - 2 * WebFrame.margin) / outerWidth),
    );
    final gapBelowScreen =
        (viewport.height - blockHeight * scale) / 2 + (WebFrame._captionSpace + WebFrame.bezel) * scale;
    return _FrameLayout(screenHeight: screenHeight, scale: scale, gapBelowScreen: gapBelowScreen);
  }
}

class _WebFrameState extends State<WebFrame> {
  // Keeps the app's state (navigation stack, form input) when the window is
  // resized across the breakpoint and the child moves in or out of the frame.
  final GlobalKey _appKey = GlobalKey(debugLabel: 'WebFrame app');

  @override
  Widget build(BuildContext context) {
    if (!(widget.enabled ?? kIsWeb)) return widget.child;

    final outer = MediaQuery.of(context);
    final app = KeyedSubtree(key: _appKey, child: widget.child);
    if (!WebFrame.framesAt(outer.size)) return app;

    final layout = _FrameLayout.of(outer.size);
    final keyboard = math.max(0.0, outer.viewInsets.bottom - layout.gapBelowScreen) / layout.scale;
    final screen = outer.copyWith(
      size: Size(WebFrame.screenWidth, layout.screenHeight),
      padding: WebFrame.screenPadding,
      viewPadding: WebFrame.screenPadding,
      viewInsets: EdgeInsets.only(bottom: keyboard),
      systemGestureInsets: EdgeInsets.zero,
      displayFeatures: const [],
    );

    return DecoratedBox(
      key: const Key('web-frame-backdrop'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8F3EC), AppColors.cream, Color(0xFFE8DCCB)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: _FrameLayout.outerWidth * layout.scale,
          height: layout.blockHeight * layout.scale,
          child: FittedBox(
            child: SizedBox(
              width: _FrameLayout.outerWidth,
              height: layout.blockHeight,
              child: Column(children: [
                _Phone(height: layout.outerHeight, data: screen, child: app),
                const SizedBox(height: WebFrame._captionGap),
                SizedBox(
                  height: WebFrame._captionHeight,
                  child: Text(
                    WebFrame.caption,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: T.sans(12.5, color: AppColors.grey, spacing: 0.3)
                        .copyWith(decoration: TextDecoration.none),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin dark bezel with a soft shadow, a rounded screen and a punch-hole
/// camera in the simulated status bar.
class _Phone extends StatelessWidget {
  const _Phone({required this.height, required this.data, required this.child});

  final double height;
  final MediaQueryData data;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const outerRadius = BorderRadius.all(Radius.circular(WebFrame.screenRadius + WebFrame.bezel));
    return SizedBox(
      key: const Key('web-frame-phone'),
      width: _FrameLayout.outerWidth,
      height: height,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        // Faint highlight along the bezel's outer edge.
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          border: Border.all(color: const Color(0x2EFFFFFF)),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1411),
            borderRadius: outerRadius,
            boxShadow: [
              BoxShadow(color: Color(0x2E2A1208), blurRadius: 64, spreadRadius: -4, offset: Offset(0, 30)),
              BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(WebFrame.bezel),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(WebFrame.screenRadius)),
              child: SizedBox(
                key: const Key('web-frame-screen'),
                width: data.size.width,
                height: data.size.height,
                child: MediaQuery(
                  data: data,
                  child: Stack(fit: StackFit.expand, children: [
                    child,
                    // Punch-hole camera, centred in the status bar.
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: IgnorePointer(
                          child: SizedBox.square(
                            dimension: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: Color(0xFF0E0B0A), shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Web scrolling that feels like the phone app: lists and carousels can also
/// be dragged with a mouse (horizontal carousels can't be reached with a
/// vertical mouse wheel otherwise).
class WebScrollBehavior extends MaterialScrollBehavior {
  const WebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {...super.dragDevices, PointerDeviceKind.mouse};
}
