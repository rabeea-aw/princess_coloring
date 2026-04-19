import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import '../models/coloring_item.dart';
import '../services/ads_manager.dart';
import 'coloring_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  static final List<ColoringItem> items = List.generate(
    12,
    (index) => ColoringItem(
      title: '${index + 1}',
      imagePath: 'assets/images/princess${index + 1}.png',
    ),
  );

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  static const Color primaryColor = Color(0xFFE784DE);
  // static const Color lightBackgroundColor = Color(0xFFFDF1FC);
  static const Color softPinkColor = Color(0xFFF6C3EF);
  static const Color iconColor = Color(0xFFC85BBC);

  final Map<String, File?> previewFiles = {};
  final Map<String, int> previewVersions = {};

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  InterstitialAd? _interstitialAd;
  bool _isShowingInterstitial = false;

  late final PageController _pageController;

  int _currentPage = 0;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();

    _pageController = PageController();
    _soundEnabled = SoundManager.instance.soundEnabled;

    _loadPreviewFiles();
    _loadBannerAd();
    _loadInterstitialAd();

    // SoundManager.instance.playBackgroundMusic();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleSound() async {
    final newValue = !_soundEnabled;
    await SoundManager.instance.setSoundEnabled(newValue);

    if (newValue) {
      await SoundManager.instance.playBackgroundMusic();
    }

    if (!mounted) return;
    setState(() => _soundEnabled = newValue);
  }

  void _loadBannerAd() {
    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: AdsManager.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          if (!mounted) return;
          setState(() => _isBannerLoaded = false);
        },
      ),
    );

    _bannerAd!.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: AdsManager.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd?.dispose();
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
        },
      ),
    );
  }

  String _getSaveKey(String imagePath) =>
      imagePath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

  Future<Directory> _getSaveDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/coloring_saves');

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    return saveDir;
  }

  Future<File?> _getPreviewFileIfExists(ColoringItem item) async {
    final dir = await _getSaveDirectory();
    final saveKey = _getSaveKey(item.imagePath);
    final file = File('${dir.path}/${saveKey}_preview.png');

    return await file.exists() ? file : null;
  }

  Future<void> _loadPreviewFiles() async {
    final Map<String, File?> newFiles = {};
    final Map<String, int> newVersions = {};

    for (final item in GalleryScreen.items) {
      final file = await _getPreviewFileIfExists(item);
      newFiles[item.imagePath] = file;

      if (file != null) {
        final modified = await file.lastModified();
        newVersions[item.imagePath] = modified.millisecondsSinceEpoch;
        await FileImage(file).evict();
      } else {
        newVersions[item.imagePath] = 0;
      }
    }

    if (!mounted) return;

    setState(() {
      previewFiles
        ..clear()
        ..addAll(newFiles);

      previewVersions
        ..clear()
        ..addAll(newVersions);
    });
  }

  Future<void> _goToColoringScreen(ColoringItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ColoringScreen(item: item),
      ),
    );

    await _loadPreviewFiles();

    if (_soundEnabled) {
      await SoundManager.instance.playBackgroundMusic();
    }
  }

  Future<void> _openColoringScreen(ColoringItem item) async {
    if (_soundEnabled) {
      await SoundManager.instance.playTapSound();
    }

    if (_interstitialAd != null && !_isShowingInterstitial) {
      _isShowingInterstitial = true;

      final ad = _interstitialAd!;
      _interstitialAd = null;

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) async {
          ad.dispose();
          _isShowingInterstitial = false;
          _loadInterstitialAd();
          await _goToColoringScreen(item);
        },
        onAdFailedToShowFullScreenContent: (ad, error) async {
          ad.dispose();
          _isShowingInterstitial = false;
          _loadInterstitialAd();
          await _goToColoringScreen(item);
        },
      );

      ad.show();
    } else {
      await _goToColoringScreen(item);
    }
  }

  Widget _buildGalleryCard(
    ColoringItem item,
    File? previewFile,
    int version,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openColoringScreen(item),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(
            color: primaryColor,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: previewFile != null
              ? Image(
                  key: ValueKey('${previewFile.path}_$version'),
                  image: FileImage(previewFile),
                  fit: BoxFit.contain,
                )
              : Image.asset(
                  item.imagePath,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int pageCount) {
    if (pageCount <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          pageCount,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _currentPage == index ? primaryColor : softPinkColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primaryColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const int itemsPerPage = 6;
    final int pageCount = (GalleryScreen.items.length / itemsPerPage).ceil();

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 181, 249),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 181, 249),
        elevation: 0,
        centerTitle: true,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: _buildCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () async {
              if (_soundEnabled) {
                await SoundManager.instance.playTapSound();
              }
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 6, bottom: 6),
            child: _buildCircleButton(
              icon: _soundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              onTap: () async {
                await SoundManager.instance.playTapSound();
                await _toggleSound();
              },
            ),
          ),
        ],
        title: const Text(
          'Coloring',
          style: TextStyle(
            color: iconColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: pageCount,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, pageIndex) {
                final int start = pageIndex * itemsPerPage;
                int end = start + itemsPerPage;

                if (end > GalleryScreen.items.length) {
                  end = GalleryScreen.items.length;
                }

                final pageItems = GalleryScreen.items.sublist(start, end);

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pageItems.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.92,
                    ),
                    itemBuilder: (context, index) {
                      final item = pageItems[index];
                      final previewFile = previewFiles[item.imagePath];
                      final version = previewVersions[item.imagePath] ?? 0;

                      return _buildGalleryCard(
                        item,
                        previewFile,
                        version,
                      );
                    },
                  ),
                );
              },
            ),
          ),
          _buildPageIndicator(pageCount),
          if (_isBannerLoaded && _bannerAd != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}