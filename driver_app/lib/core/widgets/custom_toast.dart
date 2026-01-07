import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ToastType { success, error, info }

class CustomToast extends StatelessWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const CustomToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Haptic Feedback on Build (Sound/Vibration feel)
    HapticFeedback.lightImpact();

    Color backgroundColor;
    IconData icon;

    switch (type) {
      case ToastType.success:
        backgroundColor = const Color(0xFF1A77F6); // Unified Blue
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        backgroundColor = const Color(0xFF1A77F6); // Unified Blue
        icon = Icons.error_rounded;
        break;
      case ToastType.info:
        backgroundColor = const Color(0xFF1A77F6); // Unified Blue
        icon = Icons.info_rounded;
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16), // Modern Radius
                boxShadow: [
                  BoxShadow(
                    color: backgroundColor.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Hug content
                children: [
                   Icon(icon, color: Colors.white, size: 24),
                   const SizedBox(width: 12),
                   Flexible(
                     child: Text(
                       message,
                       style: const TextStyle(
                         color: Colors.white,
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         fontFamily: 'Inter',
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ),
                   const SizedBox(width: 8),
                   GestureDetector(
                     onTap: onDismiss,
                     child: const Icon(Icons.close, color: Colors.white70, size: 20),
                   ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Global Overlay Service
class CustomNotificationService {
  static final CustomNotificationService _instance = CustomNotificationService._internal();

  factory CustomNotificationService() => _instance;

  CustomNotificationService._internal();

  OverlayEntry? _overlayEntry;

  void show(BuildContext context, String message, ToastType type) {
    // Remove existing if any
    hide();

    final overlayState = Overlay.of(context);
    
    // Animation Controller Wrapper would be ideal, but for simplicity we use AnimatedWidget logic inside if needed
    // or just a simple entry with TweenAnimationBuilder
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _ToastAnimator(
        child: CustomToast(
          message: message, 
          type: type, 
          onDismiss: hide,
        ),
      ),
    );

    overlayState.insert(_overlayEntry!);

    // Auto dismiss
    Future.delayed(const Duration(seconds: 3), () {
      hide();
    });
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ToastAnimator extends StatefulWidget {
  final Widget child;
  const _ToastAnimator({required this.child});

  @override
  State<_ToastAnimator> createState() => _ToastAnimatorState();
}

class _ToastAnimatorState extends State<_ToastAnimator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Off screen top
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut, // "Fişek" effect (bounce)
      reverseCurve: Curves.easeInBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: widget.child,
    );
  }
}
