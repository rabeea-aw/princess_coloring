import 'package:flutter/material.dart';
import 'gallery_screen.dart';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_texts.dart';

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
    SoundManager.instance.addListener(_onSoundChanged);
    _initSound();
  }

  @override
  void dispose() {
    SoundManager.instance.removeListener(_onSoundChanged);
    super.dispose();
  }

  void _onSoundChanged() {
    if (!mounted) return;
    setState(() {
      isSoundOn = SoundManager.instance.soundEnabled;
    });
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

  Future<void> _openSettingsSheet() async {
    if (isSoundOn) {
      await SoundManager.instance.playTapSound();
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final texts = AppTexts.of(context);

            Future<void> updateLanguage(AppLanguage language) async {
              await AppSettings.instance.setLanguage(language);
              setSheetState(() {});
              if (!mounted) return;
              setState(() {});
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDB2E6),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    texts.settingsTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFB5318E),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFC4E9), width: 2),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            texts.language,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          leading: const Icon(Icons.language_rounded),
                        ),
                        RadioListTile<AppLanguage>(
                          value: AppLanguage.device,
                          groupValue: AppSettings.instance.language,
                          title: Text(texts.followDeviceLanguage),
                          activeColor: const Color(0xFFE358B8),
                          onChanged: (v) => v == null ? null : updateLanguage(v),
                        ),
                        RadioListTile<AppLanguage>(
                          value: AppLanguage.english,
                          groupValue: AppSettings.instance.language,
                          title: Text(texts.english),
                          activeColor: const Color(0xFFE358B8),
                          onChanged: (v) => v == null ? null : updateLanguage(v),
                        ),
                        RadioListTile<AppLanguage>(
                          value: AppLanguage.arabic,
                          groupValue: AppSettings.instance.language,
                          title: Text(texts.arabic),
                          activeColor: const Color(0xFFE358B8),
                          onChanged: (v) => v == null ? null : updateLanguage(v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5AAD),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        texts.done,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
    final texts = AppTexts.of(context);

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
              onTap: _openSettingsSheet,
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
                  child: Center(
                    child: Text(
                      texts.startColoring,
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