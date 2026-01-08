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
import 'dart:async';
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options_manual.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    
    try {
      if (Platform.isIOS) {
        await Firebase.initializeApp(
          options: ManualFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

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
          if (now.difference(timestamp).inSeconds < 30) {
            debugPrint("Main: Pending call sound detected within valid time window. Playing Ringtone.");
            await RingtoneService().playRingtone();
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
    } catch (e, s) {
      debugPrint("Startup Error: $e");
      FlutterNativeSplash.remove();
      runApp(ErrorApp(message: "Başlatma Hatası: $e"));
    }
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text("Uygulama Başlatılamadı", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SelectableText(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
