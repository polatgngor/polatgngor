import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../data/auth_service.dart' as auth_service;

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Trigger explicit approval for test accounts
    // We delay slightly to ensure frame is built, though request is background
    Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
           ref.read(auth_service.authServiceProvider).ackTestAccount();
        }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Primary color from theme or hardcoded specific blue
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background subtle decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.05),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Spacer(flex: 2),
                  
                  // Animated Icon Area
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing Circles
                      _buildPulseCircle(0),
                      _buildPulseCircle(0.5),
                      _buildPulseCircle(1.0),
                      
                      // Central Icon Container
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.hourglass_top_rounded,
                          size: 48,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Text(
                    'Onay Bekleniyor',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Sürücü başvurunuz başarıyla alınmıştır.\nEkibimiz belgelerinizi inceliyor. Onay sürecinden sonra uygulamayı kullanmaya başlayabilirsiniz.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // TEST ACCOUNT INSTRUCTION
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.06), // Very subtle background
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align top incase of multiline
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Test Hesabı / Test Account',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Onaylanmak için uygulamayı yeniden başlatın.\nRestart app for auto-approval.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor.withOpacity(0.8),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Actions
                  // Actions
                  // Logout removed as per request
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: OutlinedButton(
                  //     onPressed: () {
                  //        ref.read(authProvider.notifier).logout();
                  //     },
                  //     // ...
                  //   ),
                  // ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseCircle(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = (_controller.value + delay) % 1.0;
        // Scale 1.0 -> 2.0
        final double scale = 1.0 + t;
        // Opacity 0.5 -> 0.0
        final double opacity = (1.0 - t) * 0.3;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).primaryColor.withOpacity(opacity),
            ),
          ),
        );
      },
    );
  }
}
