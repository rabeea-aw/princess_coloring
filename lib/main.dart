import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:audioplayers/audioplayers.dart';

import 'screens/splash_screen.dart';
import 'services/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await MobileAds.instance.initialize();
  await SoundManager.instance.init();
  await AppSettings.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final appLocale = AppSettings.instance.resolveLocale(deviceLocale);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Princess Coloring',
      locale: appLocale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SoundManager {
  SoundManager._();
  static final SoundManager instance = SoundManager._();

  final AudioPlayer _bgPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  bool _soundEnabled = true;

  bool get soundEnabled => _soundEnabled;

  Future<void> init() async {
    await _bgPlayer.setReleaseMode(ReleaseMode.loop);
    await _effectPlayer.setReleaseMode(ReleaseMode.stop);

    // 🎵 موسيقى الخلفية أوطى
    await _bgPlayer.setVolume(0.25);

    // 🔊 أصوات التأثيرات أعلى
    await _effectPlayer.setVolume(1.0);
  }

  Future<void> playBackgroundMusic() async {
    if (!_soundEnabled) return;

    await _bgPlayer.stop();
    await _bgPlayer.setVolume(0.25);
    await _bgPlayer.play(AssetSource('sounds/bg_music.mp3'));
  }

  Future<void> stopBackgroundMusic() async {
    await _bgPlayer.stop();
  }

  Future<void> playTapSound() async {
    if (!_soundEnabled) return;

    await _effectPlayer.stop();
    await _effectPlayer.setVolume(1.0);
    await _effectPlayer.play(AssetSource('sounds/click.mp3'));
  }

  Future<void> playFillSound() async {
    if (!_soundEnabled) return;

    await _effectPlayer.stop();
    await _effectPlayer.setVolume(0.9);
    await _effectPlayer.play(AssetSource('sounds/fill.mp3'));
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;

    if (!_soundEnabled) {
      await _bgPlayer.stop();
      await _effectPlayer.stop();
    } else {
      await _bgPlayer.setVolume(0.25);
      await _effectPlayer.setVolume(1.0);
    }
  }

  Future<void> dispose() async {
    await _bgPlayer.dispose();
    await _effectPlayer.dispose();
  }
}