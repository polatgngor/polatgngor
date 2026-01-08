import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'auth_provider.dart';
import 'package:flutter/gestures.dart';
import '../../../../core/constants/legal_constants.dart';
import '../../../../core/presentation/screens/legal_viewer_screen.dart';
import '../../../../core/widgets/custom_toast.dart';

import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isAgreed = false;
  String? _fullPhoneNumber;

  @override
  void initState() {
    super.initState();
    // Pre-cache splash logo for smooth transition to Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
       precacheImage(const AssetImage('assets/images/splash_logo_padded.png'), context);
       _checkAndRemoveSplash();
    });
  }

  void _checkAndRemoveSplash() {
      // Check current state
      final authState = ref.read(authProvider);
      
      if (!authState.isLoading && authState.value == null) {
         FlutterNativeSplash.remove();
      } else {
         // If still loading, we rely on the listener in build() or here?
         // Actually, let's use a one-shot listener logic here strictly for splash
         // But simplest is to just ensure we check in build/listener too if needed.
         // However, ref.listen in build is safer.
      }
  }


  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }


  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_fullPhoneNumber == null) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await ref.read(authProvider.notifier).sendOtp(_fullPhoneNumber!);
        
        if (mounted) {
           context.push('/otp-verify', extra: _fullPhoneNumber!);
        }
      } catch (e) {
        if (mounted) {
          CustomNotificationService().show(
            context,
            e.toString(),
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
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    // Listen for Auth Loading Completion to remove Splash
    ref.listen(authProvider, (previous, next) {
       if (!next.isLoading && next.value == null) {
          FlutterNativeSplash.remove();
       }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20), // Top spacing for Switcher
                // Custom Language Switcher
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      if (context.locale.languageCode == 'tr') {
                        context.setLocale(const Locale('en'));
                      } else {
                        context.setLocale(const Locale('tr'));
                      }
                    },
                    child: Container(
                      width: 100, 
                      height: 32,
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
                
                const SizedBox(height: 80), // Pushing logo down to "middle-ish"
                Center(
                  child: Text(
                    'taksibu',
                    style: GoogleFonts.montserrat(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                      color: const Color(0xFF0866ff),
                    ),
                  ),
                ),
                const SizedBox(height: 48), // Increased space between Logo and Welcome
                Text(
                  'auth.welcome_title'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'auth.enter_phone'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 48),

                IntlPhoneField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'auth.phone_label'.tr(),
                    border: OutlineInputBorder(
                      borderSide: BorderSide(),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  initialCountryCode: 'TR',
                  pickerDialogStyle: PickerDialogStyle(
                    backgroundColor: Colors.white,
                    searchFieldInputDecoration: InputDecoration(
                      labelText: 'Search Country',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    countryCodeStyle: const TextStyle(fontSize: 16),
                    countryNameStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    listTileDivider: const SizedBox(height: 0), // Clean list
                  ),
                  onChanged: (phone) {
                    _fullPhoneNumber = phone.completeNumber;
                  },
                  onCountryChanged: (country) {
                    // Update country if needed
                  },
                ),
                const SizedBox(height: 24),

                // Legal Agreements Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _isAgreed,
                        onChanged: (value) {
                          setState(() {
                            _isAgreed = value ?? false;
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                           // Toggle on text tap as well for better UX
                           setState(() {
                            _isAgreed = !_isAgreed;
                          });
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(
                                text: 'Kullanım Koşulları',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0866ff),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LegalViewerScreen(
                                          title: 'Kullanım Koşulları',
                                          content: LegalConstants.termsOfUse,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: 'Aydınlatma Metni',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0866ff),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LegalViewerScreen(
                                          title: 'Aydınlatma Metni',
                                          content: LegalConstants.clarificationText,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: ' ve '),
                              TextSpan(
                                text: 'Gizlilik Politikası',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0866ff),
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LegalViewerScreen(
                                          title: 'Gizlilik Politikası',
                                          content: LegalConstants.privacyPolicy,
                                        ),
                                      ),
                                    );
                                  },
                              ),
                              const TextSpan(text: "'nı okudum ve kabul ediyorum."),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _isAgreed ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                    ),
                    child: Text('auth.continue'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1A77F6) : Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
