import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../../../core/presentation/screens/legal_viewer_screen.dart';
import '../../../notifications/presentation/notification_provider.dart';


// Update provider to return Map instead of String
final driverProfileSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final authService = ref.read(authServiceProvider);
  try {
    final profile = await authService.getProfile();
    final user = profile['user'];
    return user ?? {};
  } catch (e) {
    return {};
  }
});

class DriverDrawer extends ConsumerStatefulWidget {
  const DriverDrawer({super.key});

  @override
  ConsumerState<DriverDrawer> createState() => _DriverDrawerState();
}

class _DriverDrawerState extends ConsumerState<DriverDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) {
      return 'home.greeting.morning'.tr();
    } else if (hour >= 12 && hour < 18) {
      return 'home.greeting.afternoon'.tr();
    } else {
      return 'home.greeting.evening'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(driverProfileSummaryProvider);
    final user = profileAsync.asData?.value;
    final firstName = user?['first_name'] ?? 'Sürücü';
    final lastName = user?['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final photoUrl = user?['profile_photo'];

    final notifState = ref.watch(notificationNotifierProvider);

    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.75, // %75 Width
      child: SafeArea(
        top: false, 
        child: Column(
          children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A77F6), Color(0xFF4C94FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                   color: const Color(0xFF1A77F6).withOpacity(0.3),
                   blurRadius: 15,
                   offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(4), 
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 64, // Radius 32 * 2
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: (photoUrl != null && photoUrl.isNotEmpty) 
                          ? Image.network(
                              photoUrl.startsWith('http') ? photoUrl : '${AppConstants.baseUrl}/$photoUrl',
                              fit: BoxFit.cover,
                              width: 64,
                              height: 64,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Text(
                                    firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A77F6),
                                    ),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                              },
                            )
                          : Center(
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A77F6),
                                ),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  fullName.isNotEmpty ? fullName : 'Sürücü',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: 'drawer.profile'.tr(),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_rounded,
                  title: 'drawer.history'.tr(),
                  trailing: notifState.totalUnreadMessages > 0 
                      ? Badge.count(count: notifState.totalUnreadMessages, backgroundColor: Colors.red) 
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/ride-history');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'drawer.earnings'.tr(),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/earnings');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications_active_outlined,
                  title: 'drawer.announcements'.tr(),
                  trailing: notifState.unreadAnnouncementCount > 0 
                      ? Badge.count(count: notifState.unreadAnnouncementCount, backgroundColor: Colors.red) 
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    context.push(Uri(path: '/announcements', queryParameters: {'type': 'announcement'}).toString());
                  },
                ),

                _buildDrawerItem(
                  context,
                  icon: Icons.support_agent_rounded,
                  title: 'drawer.support'.tr(),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/support');
                  },
                ),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4), // Logic fix: Match ListTile padding
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Color(0xFF424242), size: 22),
                    ),
                    title: Text(
                      'drawer.legal_info'.tr(),
                      style: const TextStyle(
                        color: Color(0xFF424242),
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    childrenPadding: const EdgeInsets.only(left: 60),
                    children: [
                      ListTile(
                        title: Text('drawer.terms'.tr(), style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LegalViewerScreen(
                                title: 'drawer.terms'.tr(),
                                content: context.locale.languageCode == 'en' 
                                  ? LegalConstants.termsOfUseEn 
                                  : LegalConstants.termsOfUse,
                              ),
                            ),
                          );
                        },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                      ListTile(
                        title: Text('drawer.clarification'.tr(), style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LegalViewerScreen(
                                title: 'drawer.clarification'.tr(),
                                content: context.locale.languageCode == 'en' 
                                  ? LegalConstants.clarificationTextEn 
                                  : LegalConstants.clarificationText,
                              ),
                            ),
                          );
                        },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                      ListTile(
                        title: Text('drawer.privacy'.tr(), style: const TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LegalViewerScreen(
                                title: 'drawer.privacy'.tr(),
                                content: context.locale.languageCode == 'en' 
                                  ? LegalConstants.privacyPolicyEn 
                                  : LegalConstants.privacyPolicy,
                              ),
                            ),
                          );
                        },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // LANGUAGE SELECTOR (Diff: Aligned left, matching padding)
                 Align(
                   alignment: Alignment.centerLeft,
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                     child: GestureDetector(
                       onTap: () {
                         if (context.locale.languageCode == 'tr') {
                           context.setLocale(const Locale('en'));
                         } else {
                           context.setLocale(const Locale('tr'));
                         }
                       },
                       child: Container(
                         width: 120,
                         height: 36,
                         padding: const EdgeInsets.all(4),
                         decoration: BoxDecoration(
                           gradient: const LinearGradient(
                             colors: [Color(0xFF1A77F6), Color(0xFF4C94FA)],
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                           ),
                           borderRadius: BorderRadius.circular(12),
                           boxShadow: [
                             BoxShadow(
                               color: const Color(0xFF1A77F6).withOpacity(0.4),
                               blurRadius: 8,
                               offset: const Offset(0, 4),
                             ),
                           ],
                         ),
                         child: Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Expanded(
                               child: _LanguageOption(
                                 label: 'TR', 
                                 isSelected: context.locale.languageCode == 'tr',
                               ),
                             ),
                             const SizedBox(width: 4),
                             Expanded(
                               child: _LanguageOption(
                                 label: 'EN', 
                                 isSelected: context.locale.languageCode == 'en',
                               ),
                             ),
                           ],
                         ),
                       ),
                     ),
                   ),
                 ),

              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: _buildDrawerItem(
              context,
              icon: Icons.logout_rounded,
              title: 'drawer.logout'.tr(),
              isDestructive: true,
              onTap: () async {
                Navigator.pop(context);
                // Trigger state change in provider so router redirects automatically
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
     ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    Widget? trailing,
  }) {
    final color = isDestructive ? Colors.red : Colors.grey[800];
    
    return ListTile(
      trailing: trailing,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _LanguageOption({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10), // Matching the container radius style slightly
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1A77F6) : Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
