import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../../../core/widgets/custom_toast.dart';

class OtpVerificationSheet extends ConsumerStatefulWidget {
  final String phone;
  final Function(String) onVerified;

  const OtpVerificationSheet({super.key, required this.phone, required this.onVerified});

  @override
  ConsumerState<OtpVerificationSheet> createState() => _OtpVerificationSheetState();
}

class _OtpVerificationSheetState extends ConsumerState<OtpVerificationSheet> {
  final _codeController = TextEditingController();
  bool _isSending = false;
  bool _codeSent = false;
  
  @override
  void initState() {
    super.initState();
    _sendOtp();
  }

  Future<void> _sendOtp() async {
    if (!mounted) return;
    setState(() => _isSending = true);
    try {
      final repo = ref.read(authRepositoryProvider); 
      await repo.sendOtp(widget.phone); 
      
      if (mounted) {
        setState(() {
          _isSending = false;
          _codeSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        CustomNotificationService().show(
          context,
          'Hata: $e',
          ToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Güvenlik Doğrulaması', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('İşlemi tamamlamak için ${widget.phone} numarasına gönderilen onay kodunu giriniz.', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 24),
        
        if (_isSending)
          const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ))
        else ...[
           TextField(
             controller: _codeController,
             keyboardType: TextInputType.number,
             maxLength: 6,
             textAlign: TextAlign.center,
             style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
             decoration: InputDecoration(
               hintText: '######',
               counterText: "",
               border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
               filled: true,
               fillColor: Colors.grey[50]
             ),
             autofocus: true,
           ),
           const SizedBox(height: 24),
           ElevatedButton(
             onPressed: () {
                final code = _codeController.text.trim();
                if (code.length < 4) return;
                widget.onVerified(code);
             },
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(vertical: 16),
               backgroundColor: const Color(0xFF1A77F6), // Check brand color? Usually Taksibu Taxi Yellow/Blue? Assuming Blue/Primary.
               foregroundColor: Colors.white,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
             ),
             child: const Text('Doğrula ve Devam Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           ),
           const SizedBox(height: 12),
           TextButton(
             onPressed: _sendOtp,
             child: const Text('Kodu Tekrar Gönder'),
           ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}
