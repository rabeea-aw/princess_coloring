import 'dart:io';
// import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsManager {
  static const bool isTest = true;

  static const String _testBanner =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  static const String _androidBanner =
      'ca-app-pub-8167739436024208/6955545335';
  static const String _iosBanner =
      'ca-app-pub-8167739436024208/7713169797';

  static const String _androidInterstitial =
    'ca-app-pub-8167739436024208/7876821329';
  static const String _iosInterstitial =
      'ca-app-pub-8167739436024208/9704908312';

  static String get bannerId {
    if (isTest) return _testBanner;
    if (Platform.isAndroid) return _androidBanner;
    if (Platform.isIOS) return _iosBanner;
    throw UnsupportedError('Unsupported platform');
  }

  static String get interstitialId {
    if (isTest) return _testInterstitial;
    if (Platform.isAndroid) return _androidInterstitial;
    if (Platform.isIOS) return _iosInterstitial;
    throw UnsupportedError('Unsupported platform');
  }
}