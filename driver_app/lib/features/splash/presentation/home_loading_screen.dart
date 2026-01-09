import 'package:flutter/material.dart';

class HomeLoadingScreen extends StatelessWidget {
  const HomeLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Center(
        child: Image.asset(
          'assets/images/splash_logo_padded.png',
          width: 300,
          height: 300,
           gaplessPlayback: true,
        ),
      ),
    );
  }
}
