// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'providers/pump_provider.dart';
import 'ui/screens/splash_screen.dart';

/// Global navigator key — used by PumpProvider to push HR scan
/// screen from anywhere in the app (even deep inside Kids Mode).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // Request permissions early
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
    Permission.notification,
    Permission.camera,
  ].request();

  runApp(
    ChangeNotifierProvider(
      create: (_) => PumpProvider(),
      child: const SmartPumpApp(),
    ),
  );
}

class SmartPumpApp extends StatelessWidget {
  const SmartPumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PumpProvider>();

    // Inject the global navigator key into the provider
    // so HR check timer can push routes from anywhere.
    provider.navigatorKey = navigatorKey;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'EleCare',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      ),
      scaffoldBackgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      cardColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      textTheme:
          GoogleFonts.outfitTextTheme(ThemeData(brightness: brightness).textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        foregroundColor:
            isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
      ),
    );
  }
}
