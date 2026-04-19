import 'package:flutter/material.dart';
import 'gallery_screen.dart';
import '../main.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  bool isSoundOn = true;

  @override
  void initState() {
    super.initState();
    _initSound();
  }

  Future<void> _initSound() async {
    isSoundOn = SoundManager.instance.soundEnabled;

    if (isSoundOn) {
      await SoundManager.instance.playBackgroundMusic();
    }

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleSound() async {
    final newValue = !isSoundOn;

    await SoundManager.instance.setSoundEnabled(newValue);

    if (newValue) {
      await SoundManager.instance.playBackgroundMusic();
    } else {
      await SoundManager.instance.stopBackgroundMusic();
    }

    if (!mounted) return;
    setState(() {
      isSoundOn = newValue;
    });
  }

  Future<void> _openGallery() async {
    if (isSoundOn) {
      await SoundManager.instance.playTapSound();
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GalleryScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg1.png',
              fit: BoxFit.cover,
            ),
          ),

          Positioned(
            top: 70,
            left: 20,
            right: 20,
            child: Center(
              child: Image.asset(
                'assets/images/title.png',
                height: 190,
                fit: BoxFit.contain,
              ),
            ),
          ),

          Positioned(
            top: 48,
            left: 20,
            child: _circleButton(
              icon: Icons.settings,
              onTap: () {},
            ),
          ),

          Positioned(
            top: 48,
            right: 20,
            child: _circleButton(
              icon: isSoundOn ? Icons.volume_up : Icons.volume_off,
              onTap: _toggleSound,
            ),
          ),

          Positioned(
            top: 300,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _openGallery,
                child: Container(
                  width: 250,
                  height: 78,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF7BC4),
                        Color(0xFFFF4FA3),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: const Color(0xFFFFD1EA),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "ابدأ التلوين",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 10,
            left: -20,
            child: Image.asset(
              'assets/images/princess.png',
              height: size.height * 0.5,
              fit: BoxFit.contain,
            ),
          ),

          Positioned(
            bottom: 100,
            right: -18,
            child: Image.asset(
              'assets/images/bord.png',
              height: 210,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFA7D8),
              Color(0xFFFF6DB8),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: const Color(0xFFFFD9EE),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}