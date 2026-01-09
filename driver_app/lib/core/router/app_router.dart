import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/change_phone_screen.dart';
import '../../features/rides/presentation/ride_history_screen.dart';
import '../../features/earnings/presentation/earnings_screen.dart';
import '../../features/settings/presentation/privacy_screen.dart';
import '../../features/settings/presentation/terms_screen.dart';
import '../../features/settings/presentation/legal_info_screen.dart';
import '../../features/settings/presentation/clarification_text_screen.dart';
import '../../features/home/presentation/screens/announcements_screen.dart';
import '../../features/support/presentation/screens/support_dashboard_screen.dart';
import '../../features/support/presentation/screens/create_ticket_screen.dart';
import '../../features/support/presentation/screens/support_chat_screen.dart';
import '../../features/auth/presentation/pending_screen.dart';
import '../../features/auth/presentation/permissions/location_permission_screen.dart';
import '../../features/auth/presentation/permissions/notification_permission_screen.dart';
import '../../features/auth/presentation/permissions/background_permission_screen.dart';
import '../../core/providers/onboarding_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = ValueNotifier<bool>(true);

  // Re-evaluate routes when auth state changes
  ref.listen(authProvider, (_, __) => listenable.value = !listenable.value);
  // Re-evaluate routes when onboarding completes
  ref.listen(onboardingProvider, (_, __) => listenable.value = !listenable.value);

  return GoRouter(
    refreshListenable: listenable,
    initialLocation: '/login',
    redirect: (context, state) {
      // 1. Handle Deep Links
      if (state.uri.scheme == 'taksibudriver' || state.uri.toString().contains('taksibudriver://')) {
          return '/home';
      }

      final authState = ref.read(authProvider);

      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/login';
      final isRegistering = state.uri.toString() == '/register';
      final isVerifyingOtp = state.uri.toString() == '/otp-verify';
      final isPendingScreen = state.uri.toString() == '/pending';

      // 2. Not Logged In
      if (!isLoggedIn) {
        if (isLoggingIn || isRegistering || isVerifyingOtp) return null;
        return '/login';
      }

      // 3. Logged In - Check Status & Onboarding
      final driver = authState.value?['driver'];
      final user = authState.value?['user'];
      
      String? status;
      if (driver != null) {
          status = driver['status'];
      } else if (user != null && user['driver_status'] != null) {
          status = user['driver_status'];
      }

      final onboardingState = ref.read(onboardingProvider);
      if (onboardingState.isLoading) return null;
       
      final isCompleted = onboardingState.value ?? false;
      final isPermissionLoc = state.uri.toString() == '/permission-location';
      final isPermissionBack = state.uri.toString() == '/permission-background';
      final isPermissionNotif = state.uri.toString() == '/permission-notification';
      
      if (!isCompleted) {
         // Allow any of the permission screens to be viewed
         if (isPermissionLoc || isPermissionBack || isPermissionNotif) return null;
         // Default start
         return '/permission-location';
      }

      if (status == 'pending') {
          if (isPendingScreen) return null;
          return '/pending';
      }

      if (isLoggingIn || isRegistering || isVerifyingOtp || isPendingScreen) return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp-verify', builder: (context, state) => OtpScreen(phone: state.extra as String)),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/pending', builder: (context, state) => const PendingScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/ride-history', builder: (context, state) => const RideHistoryScreen()),
      GoRoute(path: '/earnings', builder: (context, state) => const EarningsScreen()),
      GoRoute(path: '/announcements', builder: (context, state) => AnnouncementsScreen(type: state.uri.queryParameters['type'])),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
      GoRoute(path: '/legal', builder: (context, state) => const LegalInfoScreen()),
      GoRoute(path: '/clarification', builder: (context, state) => const ClarificationTextScreen()),
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
      GoRoute(path: '/profile/edit', builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: '/profile/change-phone', builder: (context, state) => const ChangePhoneScreen()),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportDashboardScreen(),
        routes: [
          GoRoute(path: 'create', builder: (context, state) => const CreateTicketScreen()),
          GoRoute(path: 'chat/:id', builder: (context, state) => SupportChatScreen(ticketId: int.parse(state.pathParameters['id']!))),
        ],
      ),
      GoRoute(path: '/permission-location', builder: (context, state) => const LocationPermissionScreen()),
      GoRoute(path: '/permission-background', builder: (context, state) => const BackgroundPermissionScreen()), 
      GoRoute(path: '/permission-notification', builder: (context, state) => const NotificationPermissionScreen()),
    ],
  );
});
