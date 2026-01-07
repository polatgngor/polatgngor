import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'core/services/background_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/ringtone_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  
  await EasyLocalization.ensureInitialized();
  
  // Fire and forget - don't block app startup
  NotificationService().initialize();
  BackgroundService.initializeService();
  
  // CHECK FOR PENDING CALL SOUND
  try {
    final prefs = await SharedPreferences.getInstance();
    final bool? pendingSound = prefs.getBool('pending_call_sound');
    final String? timestampStr = prefs.getString('pending_call_timestamp');

    if (pendingSound == true && timestampStr != null) {
      final DateTime timestamp = DateTime.parse(timestampStr);
      final DateTime now = DateTime.now();
      // Only play if the trigger was recent (e.g., within last 30 seconds)
      if (now.difference(timestamp).inSeconds < 30) {
        debugPrint("Main: Pending call sound detected within valid time window. Playing Ringtone.");
        // Play Ringtone Immediately
        await RingtoneService().playRingtone();
        
        // Clear flag
        await prefs.remove('pending_call_sound');
        await prefs.remove('pending_call_timestamp');
      } else {
         debugPrint("Main: Pending call sound detected but expired. Clearing.");
         await prefs.remove('pending_call_sound');
         await prefs.remove('pending_call_timestamp');
      }
    }
  } catch (e) {
    debugPrint("Main: Error checking pending sound: $e");
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      startLocale: const Locale('tr'),
      child: const ProviderScope(child: DriverApp()),
    ),
  );
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);
    
    // Splash removal is handled in specific screens (Login, Home, etc.)
    // to ensure smooth transition.

    
    return MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'taksibu sürücü',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A77F6),
          primary: const Color(0xFF1A77F6),
          surface: Colors.white,
        ),
        useMaterial3: true,
        // Modern Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF1F4F8),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.transparent, width: 0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
        ),

        // Modern Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A77F6),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
