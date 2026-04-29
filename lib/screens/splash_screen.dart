import 'dart:async';
import 'package:flutter/material.dart';
import 'intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool showSecondImage = false;
  bool showLogo = false;

  @override
  void initState() {
    super.initState();

    // شغل انيميشن اللوجو مباشرة
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        showLogo = true;
      });
    });

    // بعد ثانية: أظهر الصورة الثانية
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        showSecondImage = true;
      });
    });

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const IntroScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // 🔥 اللوجو مع حركة
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: showLogo ? 1 : 0,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 800),
                scale: showLogo ? 1 : 0.6,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 180,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 الصورة الثانية من تحت
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: showSecondImage ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 800),
                offset: showSecondImage
                    ? const Offset(0, 0)
                    : const Offset(0, 0.5),
                child: Image.asset(
                  'assets/images/logo_1.png',
                  width: 240,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}