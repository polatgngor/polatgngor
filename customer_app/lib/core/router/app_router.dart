import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/ride/presentation/location_selection_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../core/providers/onboarding_provider.dart';
import '../../features/profile/presentation/profile_screen.dart';

import '../../features/profile/presentation/edit_profile_screen.dart';

import '../../features/profile/presentation/change_phone_screen.dart';
import '../../features/auth/presentation/permissions/location_permission_screen.dart';
import '../../features/auth/presentation/permissions/notification_permission_screen.dart';
import '../../features/notifications/presentation/notification_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';

import '../../features/rides/presentation/ride_history_screen.dart';
import '../../features/settings/presentation/privacy_screen.dart';
import '../../features/settings/presentation/terms_screen.dart';
import '../../features/settings/presentation/legal_info_screen.dart'; // NEW
import '../../features/settings/presentation/clarification_text_screen.dart'; // NEW
import '../../features/home/presentation/screens/announcements_screen.dart';
import '../../features/support/presentation/screens/support_dashboard_screen.dart';
import '../../features/support/presentation/screens/create_ticket_screen.dart';
import '../../features/support/presentation/screens/support_chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/globals.dart';

final routerProvider = Provider<GoRouter>((ref) {

  // Use ValueNotifier to listen to auth changes without rebuilding the router itself
  final listenable = ValueNotifier<bool>(true);

  ref.listen(authProvider, (_, __) {
    listenable.value = !listenable.value;
  });

  ref.listen(onboardingProvider, (_, __) {
    listenable.value = !listenable.value;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: listenable,
    initialLocation: '/login',
    redirect: (context, state) {
      // Read latest state
      final authState = ref.read(authProvider);
      
      if (authState.isLoading) return null; // Stay on "loading"
      
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/login';
      final isRegistering = state.uri.toString() == '/register';
      final isVerifyingOtp = state.uri.toString() == '/otp-verify';

      // Allow login, register, otp-verify if not logged in
      if (!isLoggedIn) {
        if (isLoggingIn || isRegistering || isVerifyingOtp) return null;
        return '/login';
      }
      
      
      // If logged in, don't allow auth pages
      if (isLoggedIn && (isLoggingIn || isRegistering || isVerifyingOtp)) {
           final onboardingState = ref.read(onboardingProvider);
           
           if (onboardingState.isLoading) return null; // Wait for onboarding check
           
           final isCompleted = onboardingState.value ?? false;
           if (!isCompleted) return '/permission-location';
           return '/home';
      }

      // Check Permissions / Onboarding for logged-in users
      if (isLoggedIn) {
         final onboardingState = ref.read(onboardingProvider);
         
         if (onboardingState.isLoading) return null;
         
         final isCompleted = onboardingState.value ?? false;
         
         final isPermissionLoc = state.uri.toString() == '/permission-location';
         final isPermissionNotif = state.uri.toString() == '/permission-notification';
        
         if (!isCompleted) {
            if (isPermissionLoc || isPermissionNotif) return null; 
            return '/permission-location';
         }
         
         // If completed, prevent going back to permission screens
         if (isPermissionLoc || isPermissionNotif) return '/home';
      }

      return null;
    },


    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) {
           final phone = state.extra as String;
           return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/location-selection',
        builder: (context, state) => const LocationSelectionScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) => const EditProfileScreen(),
          ),

          GoRoute(
            path: 'change-phone',
            builder: (context, state) => const ChangePhoneScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/ride-history',
        builder: (context, state) => const RideHistoryScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/announcements',
        builder: (context, state) => AnnouncementsScreen(type: state.uri.queryParameters['type']),
      ),
      GoRoute(
        path: '/legal',
        builder: (context, state) => const LegalInfoScreen(),
      ),
      GoRoute(
        path: '/clarification',
        builder: (context, state) => const ClarificationTextScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportDashboardScreen(),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => const CreateTicketScreen(),
          ),
          GoRoute(
            path: 'chat/:id',
            builder: (context, state) => SupportChatScreen(ticketId: int.parse(state.pathParameters['id']!)),
          ),
        ],
      ),
      GoRoute(
        path: '/permission-location',
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        path: '/permission-notification',
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
    ],
  );
});

