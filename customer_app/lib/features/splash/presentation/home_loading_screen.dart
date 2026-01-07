import 'package:flutter/material.dart';

class HomeLoadingScreen extends StatelessWidget {
  const HomeLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Used inside a Stack/Overlay, so Scaffold is not strictly needed and might cause layout issues during fade
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white, // Matches Native Splash Background
      child: Center(
        child: Image.asset(
          'assets/images/splash_logo_padded.png',
          width: 300, 
          height: 300,
          gaplessPlayback: true, // Prevents flickering
        ),
      ),
    );
  }
}
