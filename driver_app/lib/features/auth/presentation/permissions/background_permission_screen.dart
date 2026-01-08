import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackgroundPermissionScreen extends ConsumerStatefulWidget {
  const BackgroundPermissionScreen({super.key});

  @override
  ConsumerState<BackgroundPermissionScreen> createState() => _BackgroundPermissionScreenState();
}

class _BackgroundPermissionScreenState extends ConsumerState<BackgroundPermissionScreen> with WidgetsBindingObserver {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Valid entry point, remove splash
    FlutterNativeSplash.remove();

    WidgetsBinding.instance.addObserver(this);
    _checkPermissions(); // Check immediately on enter
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    final overlayStatus = await Permission.systemAlertWindow.status;

    if (batteryStatus.isGranted && overlayStatus.isGranted) {
      if (mounted) {
        context.go('/permission-notification');
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoading = true);

    // 1. Overlay (System Alert Window)
    if (!await Permission.systemAlertWindow.isGranted) {
       await Permission.systemAlertWindow.request();
    }
    
    // 2. Battery Optimization
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
       await Permission.ignoreBatteryOptimizations.request();
    }

    setState(() => _isLoading = false);
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A77F6).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_system_daydream_rounded, // Combined icon concept
                  size: 64,
                  color: Color(0xFF1A77F6),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Arkaplan İzinleri',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Uygulamanın sorunsuz çalışması için "Diğer Uygulamaların Üzerinde Göster" ve "Pil Optimizasyonu" izinlerini vermelisiniz.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Bullet points
              _buildBullet('Diğer Uygulamaların Üzerinde Göster'),
              _buildBullet('Pil Kısıtlamasını Kaldır'),
              
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _requestPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A77F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('İzinleri Ver'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
