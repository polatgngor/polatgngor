import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pinput/pinput.dart';
import '../../../core/widgets/custom_toast.dart';
import 'auth_provider.dart';

import 'dart:async';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  Timer? _timer;
  int _start = 180; // 3 minutes

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_start == 0) {
          setState(() {
            timer.cancel();
          });
        } else {
          setState(() {
            _start--;
          });
        }
      },
    );
  }

  String get timerText {
    int minutes = _start ~/ 60;
    int seconds = _start % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pin = _pinController.text;
    if (pin.length != 6) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ref.read(authProvider.notifier).verifyOtp(
        widget.phone,
        pin,
      );

      if (mounted) {
        if (result != null) {
          if (result['is_new_user'] == true) {
            context.push('/register', extra: {
              'phone': widget.phone,
              'verification_token': result['verification_token'],
            });
          } else {
            // Check if driver status is approved? 
            // The provider already returns user data, simple redirect to home
            // The existing login logic in AuthProvider/Service handles some status checks?
            // Actually service.verifyOtp returns data directly. 
            // We can trust the user object presence means we can go home.
            context.go('/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService().show(
          context,
          e.toString().replaceAll('Exception: ', ''),
          ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 56,
      height: 56,
      textStyle: const TextStyle(fontSize: 20, color: Color.fromRGBO(30, 60, 87, 1), fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        border: Border.all(color: const Color.fromRGBO(234, 239, 243, 1)),
        borderRadius: BorderRadius.circular(20),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).primaryColor),
      borderRadius: BorderRadius.circular(8),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
         color: const Color.fromRGBO(234, 239, 243, 1),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60), // Space for icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A77F6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 64,
                    color: Color(0xFF1A77F6),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'auth.verify_title'.tr(),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'auth.enter_code_sent'.tr(),
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.phone,
                style: TextStyle(color: Colors.grey[800], fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              Pinput(
                length: 6,
                controller: _pinController,
                focusNode: _focusNode,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                submittedPinTheme: submittedPinTheme,
                onCompleted: (pin) => _verify(),
                pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                showCursor: true,
              ),

              const SizedBox(height: 40),

              if (_isLoading)
                 const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _verify,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('auth.verify'.tr(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text('auth.didnt_receive'.tr() + " "),
                   TextButton(
                     onPressed: _start == 0 ? () {
                       ref.read(authProvider.notifier).sendOtp(widget.phone);
                       CustomNotificationService().show(
                        context,
                        'auth.resend_code'.tr(),
                        ToastType.success,
                       );
                       setState(() {
                         _start = 180;
                         startTimer();
                       });
                     } : null,
                     child: Text(
                       _start == 0 ? 'auth.resend_code'.tr() : '$_start s',
                       style: TextStyle(
                         color: _start == 0 ? Theme.of(context).primaryColor : Colors.grey,
                         fontWeight: _start == 0 ? FontWeight.bold : FontWeight.normal
                       ),
                     ),
                   )
                ],
              ),
              if (_start > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    timerText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
