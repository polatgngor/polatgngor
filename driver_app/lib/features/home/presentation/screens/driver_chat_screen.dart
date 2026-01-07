import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:dio/dio.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../../../core/services/socket_service.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/auth_provider.dart';
import '../../../rides/data/ride_repository.dart';

// Simple provider for chat messages
class DriverChatMessagesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void add(Map<String, dynamic> msg) {
    state = [...state, msg];
  }

  void set(List<Map<String, dynamic>> messages) {
    state = messages;
  }
}

final driverChatMessagesProvider = NotifierProvider<DriverChatMessagesNotifier, List<Map<String, dynamic>>>(DriverChatMessagesNotifier.new);

class DriverChatScreen extends ConsumerStatefulWidget {
  final String rideId;

  const DriverChatScreen({super.key, required this.rideId});

  @override
  ConsumerState<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends ConsumerState<DriverChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  final List<String> _quickReplies = [
    'chat.quick_reply_1'.tr(),
    'chat.quick_reply_2'.tr(),
    'chat.quick_reply_3'.tr(),
    'chat.quick_reply_4'.tr(),
    'chat.quick_reply_5'.tr(),
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages(); // Removed duplicate call
    _initSocket();
  }

  Future<void> _initSocket() async {
    final socketService = ref.read(socketServiceProvider);
    if (!socketService.isSocketConnected) {
      await socketService.connect();
    }
    if (mounted) {
      _setupSocketListener();
      _joinChatRoom();
    }
  }

  @override
  void dispose() {
    _leaveChatRoom();
    final socketService = ref.read(socketServiceProvider);
    socketService.off('ride:message');
    socketService.off('join_failed');
    socketService.off('ride:joined');
    socketService.off('connect');
    
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _joinChatRoom() {
    final socket = ref.read(socketServiceProvider).socket;
    socket.emit('ride:join', {'ride_id': widget.rideId});
  }

  void _leaveChatRoom() {
    final socket = ref.read(socketServiceProvider).socket;
    socket.emit('ride:leave', {'ride_id': widget.rideId});
  }

  void _setupSocketListener() {
    final socketService = ref.read(socketServiceProvider);

    // Force re-join on reconnect
    socketService.on('connect', (_) {
      debugPrint('[DriverChatScreen] Socket connected/reconnected. Joining room...');
      if (mounted) _joinChatRoom();
    });

    socketService.on('ride:message', (data) {
      if (!mounted) return; // Early exit safety
      debugPrint('[DriverChatScreen] Received ride:message: $data');
      if (data['ride_id'].toString() == widget.rideId) {
        final messages = ref.read(driverChatMessagesProvider);
        final currentUserData = ref.read(authProvider).value;
        final currentUserId = currentUserData?['user']?['id'];

        // If it's my message, try to find the optimistic one and replace it
        if (currentUserId != null && data['sender_id'].toString() == currentUserId.toString()) {
           final index = messages.lastIndexWhere((m) => m['is_optimistic'] == true && m['text'] == data['text']);
           if (index != -1) {
             final updated = List<Map<String, dynamic>>.from(messages);
             updated[index] = data; 
             ref.read(driverChatMessagesProvider.notifier).set(updated);
             return; 
           }
        }
        
        ref.read(driverChatMessagesProvider.notifier).add(data);
        _scrollToBottom();
      }
    });

    socketService.on('join_failed', (data) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          data['message'] ?? 'Sohbet odasına katılınamadı: ${data['reason']}',
          ToastType.error,
        );
      }
    });

    socketService.on('ride:joined', (data) {
       debugPrint('[DriverChatScreen] Joined room: ${data['room']}');
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await ref.read(driverRideRepositoryProvider).getMessages(widget.rideId);
      if (mounted) {
        ref.read(driverChatMessagesProvider.notifier).set(messages);
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Silent fail or minimal correction
      }
    }
  }

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty) return;

    // Optimistic Update
    final currentUserData = ref.read(authProvider).value;
    final currentUserId = currentUserData?['user']?['id'];
    
    final optimisticMsg = {
      'text': text,
      'sender_id': currentUserId,
      'is_me': true,
      'is_optimistic': true,
      'created_at': DateTime.now().toIso8601String(),
    };
    ref.read(driverChatMessagesProvider.notifier).add(optimisticMsg);
    _scrollToBottom();

    final socket = ref.read(socketServiceProvider).socket;
    socket.emit('ride:message', {
      'ride_id': widget.rideId,
      'text': text,
    });
    
    if (quickText == null) {
      _controller.clear();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(driverChatMessagesProvider);
    final currentUserData = ref.watch(authProvider).value;
    final currentUserId = currentUserData?['user']?['id'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'chat.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[200],
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final senderId = msg['sender_id'];
                      
                      // Correct logic: If senderId matches my ID, it's me.
                      final isMe = (currentUserId != null && senderId.toString() == currentUserId.toString()) || (msg['is_me'] == true);

                      return _MessageBubble(
                        message: msg['text'] ?? msg['message'],
                        isMe: isMe,
                        time: msg['formatted_date'] ?? msg['created_at'] ?? msg['sent_at'],
                        senderName: isMe ? 'Ben' : 'Yolcu',
                      );
                    },
                  ),
          ),
          
          // Quick Replies
          Container(
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              scrollDirection: Axis.horizontal,
              itemCount: _quickReplies.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _sendMessage(_quickReplies[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      _quickReplies[index],
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Input Area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), 
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F4F8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'chat.placeholder'.tr(),
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    onPressed: () => _sendMessage(),
                    tooltip: 'chat.send'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final dynamic time;
  final String senderName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.time,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
          border: !isMe ? Border.all(color: Colors.grey[200]!) : null,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(time),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[500],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all, size: 14, color: Colors.white.withOpacity(0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(dynamic time) {
    if (time == null) return '';
    
    // Handle standard ISO string (contains T)
    if (time is String && time.contains('T')) {
      try {
        final date = DateTime.parse(time);
        return DateFormat('HH:mm').format(date);
      } catch (_) {}
    }

    // Handle "DD.MM.YYYY HH:mm" or "YYYY-MM-DD HH:mm:ss" (contains space)
    if (time is String && time.contains(' ')) {
      final parts = time.split(' ');
      if (parts.isNotEmpty) {
        final timePart = parts.last;
        final subParts = timePart.split(':');
        if (subParts.length >= 2) {
          return '${subParts[0]}:${subParts[1]}';
        }
        return timePart;
      }
    }

    try {
      final date = time is String ? DateTime.parse(time) : DateTime.fromMillisecondsSinceEpoch(time);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }
}
