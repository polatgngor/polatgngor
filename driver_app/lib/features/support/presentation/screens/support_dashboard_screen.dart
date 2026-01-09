import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../data/support_service.dart';

class SupportDashboardScreen extends ConsumerWidget {
  const SupportDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(myTicketsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'support.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home'); 
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/support/create'),
        label: Text('support.new_ticket'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1A77F6), // Brand Blue
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      body: ticketsAsync.when(
        data: (tickets) {
          if (tickets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8), // Light Grey
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.support_agent, size: 48, color: Color(0xFF1A77F6)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'support.no_tickets'.tr(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final isClosed = ticket['status'] == 'closed';
              
              final statusColor = isClosed ? Colors.grey[600] : const Color(0xFF1A77F6);
              final statusBg = isClosed ? Colors.grey[100] : const Color(0xFFE3F2FD);
              final statusBorder = isClosed ? Colors.grey[300] : const Color(0xFFBBDEFB);

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: CircleAvatar(
                    backgroundColor: statusBg,
                    child: Icon(
                      isClosed ? Icons.check : Icons.mark_chat_unread_rounded,
                      color: statusColor,
                    ),
                  ),
                  title: Text(
                    ticket['subject'] ?? 'Konusuz',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '#${ticket['id']} • ${DateFormat('dd MMM HH:mm').format(DateTime.parse(ticket['created_at']))}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusBorder!),
                    ),
                    child: Text(
                      ticket['status'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  onTap: () => context.push('/support/chat/${ticket['id']}'),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1A77F6))),
        error: (err, stack) => Center(child: Text('Hata: $err')),
      ),
    );
  }
}
