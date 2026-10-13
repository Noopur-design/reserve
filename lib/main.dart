import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/sign_in_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/web_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: AppColors.creamLight,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  // Restore saved accounts / session before the first frame so the right
  // start screen is shown.
  final state = await AppState.load();
  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const ReserveApp(),
    ),
  );
}

class ReserveApp extends StatelessWidget {
  const ReserveApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once: the start screen is decided at launch, later changes are
    // handled by navigation.
    final s = context.read<AppState>();
    final Widget home = !s.onboarded
        ? const OnboardingScreen()
        : s.isSignedIn
            ? const MainShell()
            : const SignInScreen();
    return MaterialApp(
      // On the web this is the browser tab title.
      title: kIsWeb ? 'Reserve — Spirits · Wine · Beyond' : 'Reserve',
      debugShowCheckedModeBanner: false,
      theme: kIsWeb ? AppTheme.web : AppTheme.light,
      scrollBehavior: kIsWeb ? const WebScrollBehavior() : null,
      builder: kIsWeb ? webAppBuilder : clampTextScale,
      home: home,
    );
  }
}

/// Web builder: the phone frame on wide screens (see [WebFrame]), with the
/// text-scale clamp applied inside it so it sees the framed MediaQuery.
/// [frame] overrides whether the frame may be shown (tests).
Widget webAppBuilder(BuildContext context, Widget? child, {bool? frame}) =>
    WebFrame(enabled: frame, child: Builder(builder: (context) => clampTextScale(context, child)));

/// MaterialApp builder that keeps text scaling within the range the layouts
/// are designed for (0.85–1.15). Also used by the widget tests.
Widget clampTextScale(BuildContext context, Widget? child) {
  final mq = MediaQuery.of(context);
  final scale = mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.15);
  return MediaQuery(data: mq.copyWith(textScaler: scale), child: child!);
}
