import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('drawer.legal_info'.tr()),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLegalItem(
            context,
            title: 'drawer.terms'.tr(),
            icon: Icons.description_outlined,
            onTap: () => context.push('/terms'),
          ),
          const SizedBox(height: 12),
          _buildLegalItem(
            context,
            title: 'drawer.privacy'.tr(),
            icon: Icons.privacy_tip_outlined,
            onTap: () => context.push('/privacy'),
          ),
          const SizedBox(height: 12),
          _buildLegalItem(
            context,
            title: 'settings.clarification_title'.tr(),
            icon: Icons.info_outline_rounded,
            onTap: () => context.push('/clarification'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalItem(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
         trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
      ),
    );
  }
}
