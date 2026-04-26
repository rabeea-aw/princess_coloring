import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/coloring_item.dart';
import '../painters/drawing_painter.dart';
import '../painters/fill_particles_painter.dart';
import '../services/ads_manager.dart';

class DrawPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
  });
}

enum PaintMode {
  brush,
  fill,
  glitterFill,
  patternFill,
  sticker,
}

class StickerData {
  final Offset offset;
  final String imagePath;
  final double size;

  StickerData({
    required this.offset,
    required this.imagePath,
    required this.size,
  });
}

class _UndoSnapshot {
  final List<DrawPoint?> points;
  final List<StickerData> stickers;
  final img.Image? fillLayer;

  _UndoSnapshot({
    required this.points,
    required this.stickers,
    required this.fillLayer,
  });

  Map<String, dynamic> toJson(Size canvasSize) {
    final pointsData = <Map<String, dynamic>>[];
    for (final p in points) {
      if (p == null) {
        pointsData.add({'isBreak': true});
      } else {
        pointsData.add({
          'nx': p.offset.dx / canvasSize.width,
          'ny': p.offset.dy / canvasSize.height,
          'color': p.color.value,
          'strokeWidth': p.strokeWidth,
        });
      }
    }

    final stickersData = <Map<String, dynamic>>[];
    for (final s in stickers) {
      stickersData.add({
        'nx': s.offset.dx / canvasSize.width,
        'ny': s.offset.dy / canvasSize.height,
        'imagePath': s.imagePath,
        'size': s.size,
      });
    }

    return {
      'points': pointsData,
      'stickers': stickersData,
      'fill': fillLayer == null
          ? null
          : base64Encode(Uint8List.fromList(img.encodePng(fillLayer!))),
    };
  }

  static _UndoSnapshot fromJson(Map<String, dynamic> json, Size canvasSize) {
    final restoredPoints = <DrawPoint?>[];
    final pointsData = json['points'];

    if (pointsData is List) {
      for (final item in pointsData) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);
        if (map['isBreak'] == true) {
          restoredPoints.add(null);
          continue;
        }

        final nx = (map['nx'] as num?)?.toDouble() ?? 0;
        final ny = (map['ny'] as num?)?.toDouble() ?? 0;

        restoredPoints.add(
          DrawPoint(
            offset: Offset(nx * canvasSize.width, ny * canvasSize.height),
            color: Color((map['color'] as num?)?.toInt() ?? Colors.black.value),
            strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 8,
          ),
        );
      }
    }

    final restoredStickers = <StickerData>[];
    final stickersData = json['stickers'];

    if (stickersData is List) {
      for (final item in stickersData) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);

        final nx = (map['nx'] as num?)?.toDouble() ?? 0;
        final ny = (map['ny'] as num?)?.toDouble() ?? 0;

        restoredStickers.add(
          StickerData(
            offset: Offset(nx * canvasSize.width, ny * canvasSize.height),
            imagePath: map['imagePath']?.toString() ?? '',
            size: (map['size'] as num?)?.toDouble() ?? 72,
          ),
        );
      }
    }

    img.Image? fill;
    final fillRaw = json['fill'];
    if (fillRaw is String && fillRaw.isNotEmpty) {
      fill = img.decodeImage(base64Decode(fillRaw));
    }

    return _UndoSnapshot(points: restoredPoints, stickers: restoredStickers, fillLayer: fill);
  }
}

class ColoringScreen extends StatefulWidget {
  final ColoringItem item;

  const ColoringScreen({super.key, required this.item});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen>
    with SingleTickerProviderStateMixin {
  static const int _tapParticleCount = 8;

  final List<DrawPoint?> points = [];
  final List<StickerData> stickers = [];
  final List<_UndoSnapshot> _undoStack = [];
  Timer? _delayedFillTimer;
  bool _isFilling = false;

  final GlobalKey _previewKey = GlobalKey();

  Color selectedColor = const Color(0xFFFF5C1C);
  double strokeWidth = 8;
  PaintMode currentMode = PaintMode.fill;

  final List<double> brushSizes = [6, 12, 18];

  int? activeColorIndex;
  final Map<int, GlobalKey> _colorKeys = {};

  static const double _paletteBarHeight = 62;
  static const double _toolsBarHeight = 96;
  static const double _bannerReservedHeight = 72;
  static const double _topCanvasSpacing = 12;
  static const double _bottomControlsAreaHeight = 120;

  static const double _canvasAspectRatio = 3 / 4;

  img.Image? _outlineImage;
  img.Image? _fillLayer;
  Uint8List? _fillLayerBytes;

  img.Image? _patternImage;
  img.Image? _glitterImage;

  bool _loading = true;

  final List<Map<String, dynamic>> _pendingPointData = [];
  final List<Map<String, dynamic>> _pendingStickerData = [];
  final List<Map<String, dynamic>> _pendingUndoData = [];
  bool _restoredSavedData = false;
  Size? _lastCanvasSize;

  late final AnimationController _particlesController;
  final List<FillParticle> _particles = [];
  final math.Random _random = math.Random();

  BannerAd? _bannerAd;
  bool _isBannerReady = false;

  final List<Color> colorsList = [
    const Color(0xFFFF3D00),
    const Color(0xFFFF9800),
    const Color(0xFFFFE100),
    const Color(0xFF73E600),
    const Color(0xFF33B5FF),
    const Color(0xFF2E6CFF),
    const Color(0xFFA93CFF),
    const Color(0xFFFF66C4),
    const Color(0xFFB7682A),
  ];

  final List<String> stickerOptions = [
    'assets/images/stickers/stick_1.png',
    'assets/images/stickers/stick_2.png',
    'assets/images/stickers/stick_3.png',
    'assets/images/stickers/stick_4.png',
    'assets/images/stickers/stick_5.png',
    'assets/images/stickers/stick_6.png',
    'assets/images/stickers/stick_7.png',
    'assets/images/stickers/stick_8.png',
  ];
  String selectedSticker = 'assets/images/stickers/stick_1.png';

  final List<String> patternOptions = [
    'assets/images/patterns/pattern1.png',
    'assets/images/patterns/pattern2.png',
    'assets/images/patterns/pattern3.png',
    'assets/images/patterns/pattern4.png',
    'assets/images/patterns/pattern5.png',
    'assets/images/patterns/pattern6.png',
    'assets/images/patterns/pattern7.png',
    'assets/images/patterns/pattern8.png',
  ];
  String selectedPattern = 'assets/images/patterns/pattern1.png';

  final List<String> glitterOptions = [
    'assets/images/glitter/glitter1.png',
    'assets/images/glitter/glitter2.png',
    'assets/images/glitter/glitter3.png',
    'assets/images/glitter/glitter4.png',
    'assets/images/glitter/glitter5.png',
    'assets/images/glitter/glitter6.png',
    'assets/images/glitter/glitter7.png',
    'assets/images/glitter/glitter8.png',
  ];
  String selectedGlitter = 'assets/images/glitter/glitter1.png';

  String get _saveKey =>
      widget.item.imagePath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  
  String get _undoPrefsKey => 'undo_stack_$_saveKey';


  @override
  void initState() {
    super.initState();

    for (int i = 0; i < colorsList.length; i++) {
      _colorKeys[i] = GlobalKey();
    }

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _particles.clear(); // 🚫 NO setState here
        }
      });

    _loadBannerAd();
    _loadImageForFill();
  }

  void _pushUndoState() {
    _undoStack.add(
      _UndoSnapshot(
        points: List<DrawPoint?>.from(points),
        stickers: List<StickerData>.from(stickers),
        fillLayer: _fillLayer == null ? null : img.Image.from(_fillLayer!),
      ),
    );

    if (_undoStack.length > 10) {
      _undoStack.removeAt(0);
    }
  }

  void undoLastStep() {
    if (_undoStack.isEmpty) return;

    final last = _undoStack.removeLast();

    setState(() {
      points
        ..clear()
        ..addAll(last.points);

      stickers
        ..clear()
        ..addAll(last.stickers);

      if (last.fillLayer != null) {
        _fillLayer = img.Image.from(last.fillLayer!);
        _updateFillLayerBytes();
      } else if (_outlineImage != null) {
        _fillLayer = img.Image(
          width: _outlineImage!.width,
          height: _outlineImage!.height,
          numChannels: 4,
        );
        img.fill(_fillLayer!, color: img.ColorRgba8(0, 0, 0, 0));
        _updateFillLayerBytes();
      }

      _particles.clear();
      activeColorIndex = null;
    });

    _saveAfterFrame();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdsManager.bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _isBannerReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          _isBannerReady = false;
        },
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _delayedFillTimer?.cancel();
    _bannerAd?.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  Future<Directory> _getSaveDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/coloring_saves');
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }
    return saveDir;
  }

  Future<File> _getFillFile() async {
    final dir = await _getSaveDirectory();
    return File('${dir.path}/${_saveKey}_fill.png');
  }

  Future<File> _getDataFile() async {
    final dir = await _getSaveDirectory();
    return File('${dir.path}/${_saveKey}_data.json');
  }

  Future<File> _getPreviewFile() async {
    final dir = await _getSaveDirectory();
    return File('${dir.path}/${_saveKey}_preview.png');
  }

  Future<void> _loadImageForFill() async {
    try {
      final data = await rootBundle.load(widget.item.imagePath);
      final bytes = data.buffer.asUint8List();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      _outlineImage = decoded;
      _fillLayer = img.Image(
        width: decoded.width,
        height: decoded.height,
        numChannels: 4,
      );
      img.fill(_fillLayer!, color: img.ColorRgba8(0, 0, 0, 0));

      _updateFillLayerBytes();
      await _loadPatternImage();
      await _loadGlitterImage();
      await _loadSavedDrawing();
      await _loadUndoStackFromPrefs();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveUndoStackToPrefs(Size canvasSize) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final undoData = _undoStack
          .map((snapshot) => snapshot.toJson(canvasSize))
          .toList();
      await prefs.setString(_undoPrefsKey, jsonEncode(undoData));
    } catch (_) {}
  }

  Future<void> _loadUndoStackFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_undoPrefsKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _pendingUndoData.clear();
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          _pendingUndoData.add(item);
        } else if (item is Map) {
          _pendingUndoData.add(Map<String, dynamic>.from(item));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPatternImage() async {
    try {
      final data = await rootBundle.load(selectedPattern);
      _patternImage = img.decodeImage(data.buffer.asUint8List());
    } catch (_) {
      _patternImage = null;
    }
  }

  Future<void> _loadGlitterImage() async {
    try {
      final data = await rootBundle.load(selectedGlitter);
      _glitterImage = img.decodeImage(data.buffer.asUint8List());
    } catch (_) {
      _glitterImage = null;
    }
  }

  Future<void> _loadSavedDrawing() async {
    try {
      final fillFile = await _getFillFile();
      if (await fillFile.exists()) {
        final bytes = await fillFile.readAsBytes();
        final savedFill = img.decodeImage(bytes);

        if (savedFill != null &&
            _outlineImage != null &&
            savedFill.width == _outlineImage!.width &&
            savedFill.height == _outlineImage!.height) {
          _fillLayer = savedFill;
          _updateFillLayerBytes();
        }
      }

      final dataFile = await _getDataFile();
      if (await dataFile.exists()) {
        final raw = await dataFile.readAsString();
        final decodedJson = jsonDecode(raw);

        _pendingPointData.clear();
        _pendingStickerData.clear();
        _pendingUndoData.clear();

        if (decodedJson is Map<String, dynamic>) {
          final savedPoints = decodedJson['points'];
          final savedStickers = decodedJson['stickers'];

          if (savedPoints is List) {
            for (final item in savedPoints) {
              if (item is Map<String, dynamic>) {
                _pendingPointData.add(item);
              } else if (item is Map) {
                _pendingPointData.add(Map<String, dynamic>.from(item));
              }
            }
          }

          if (savedStickers is List) {
            for (final item in savedStickers) {
              if (item is Map<String, dynamic>) {
                _pendingStickerData.add(item);
              } else if (item is Map) {
                _pendingStickerData.add(Map<String, dynamic>.from(item));
              }
            }
          }

          final undoList = decodedJson['undoStack'];
          if (undoList is List) {
            for (final item in undoList) {
              if (item is Map<String, dynamic>) {
                _pendingUndoData.add(item);
              } else if (item is Map) {
                _pendingUndoData.add(Map<String, dynamic>.from(item));
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  void _restoreSavedDataIfNeeded(Size canvasSize) {
    if (_restoredSavedData) return;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    _restoredSavedData = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final restoredPoints = <DrawPoint?>[];
      final restoredStickers = <StickerData>[];

      for (final item in _pendingPointData) {
        if (item['isBreak'] == true) {
          restoredPoints.add(null);
          continue;
        }

        final double nx = (item['nx'] as num).toDouble();
        final double ny = (item['ny'] as num).toDouble();

        restoredPoints.add(
          DrawPoint(
            offset: Offset(nx * canvasSize.width, ny * canvasSize.height),
            color: Color((item['color'] as num).toInt()),
            strokeWidth: (item['strokeWidth'] as num).toDouble(),
          ),
        );
      }

      for (final item in _pendingStickerData) {
        final double nx = (item['nx'] as num).toDouble();
        final double ny = (item['ny'] as num).toDouble();

        restoredStickers.add(
          StickerData(
            offset: Offset(nx * canvasSize.width, ny * canvasSize.height),
            imagePath: item['imagePath']?.toString() ?? stickerOptions.first,
            size: (item['size'] as num?)?.toDouble() ?? 72,
          ),
        );
      }

      final restoredUndo = <_UndoSnapshot>[];
      for (final undo in _pendingUndoData) {
        restoredUndo.add(_UndoSnapshot.fromJson(undo, canvasSize));
      }

      setState(() {
        points
          ..clear()
          ..addAll(restoredPoints);
        stickers
          ..clear()
          ..addAll(restoredStickers);
        _undoStack
          ..clear()
          ..addAll(restoredUndo);
      });
    });
  }

  void _updateFillLayerBytes() {
    if (_fillLayer == null) return;
    _fillLayerBytes = Uint8List.fromList(img.encodePng(_fillLayer!));
  }

  bool _isWithinCanvas(Offset pos, Size size) {
    return pos.dx >= 0 &&
        pos.dy >= 0 &&
        pos.dx <= size.width &&
        pos.dy <= size.height;
  }

  bool _isBlackBoundary(img.Pixel pixel) {
    return pixel.a > 0 && pixel.r < 40 && pixel.g < 40 && pixel.b < 40;
  }

  bool _hasBrushDrawing() => points.any((p) => p != null);

  bool _hasStickerDrawing() => stickers.isNotEmpty;

  bool _hasFillDrawing() {
    if (_fillLayer == null) return false;

    for (int y = 0; y < _fillLayer!.height; y++) {
      for (int x = 0; x < _fillLayer!.width; x++) {
        if (_fillLayer!.getPixel(x, y).a > 0) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAnyDrawing() {
    return _hasBrushDrawing() || _hasFillDrawing() || _hasStickerDrawing();
  }

  Future<void> _savePreviewImage() async {
    try {
      if (!_hasAnyDrawing()) return;

      await Future.delayed(Duration.zero);
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          _previewKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return;

      final previewFile = await _getPreviewFile();
      await previewFile.writeAsBytes(
        byteData.buffer.asUint8List(),
        flush: true,
      );

      await FileImage(previewFile).evict();
    } catch (_) {}
  }

  Future<void> _saveDrawing() async {
    try {
      if (!_hasAnyDrawing()) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_undoPrefsKey);
        } catch (_) {}

        await _deleteSavedDrawing();
        return;
      }

      if (_fillLayer != null) {
        final fillFile = await _getFillFile();
        await fillFile.writeAsBytes(
          Uint8List.fromList(img.encodePng(_fillLayer!)),
          flush: true,
        );
      }

      final canvasSize = _lastCanvasSize;
      if (canvasSize != null &&
          canvasSize.width > 0 &&
          canvasSize.height > 0) {
        final dataFile = await _getDataFile();

        final pointsData = [];

        for (final p in points) {
          if (p == null) {
            pointsData.add({'isBreak': true});
          } else {
            pointsData.add({
              'nx': p.offset.dx / canvasSize.width,
              'ny': p.offset.dy / canvasSize.height,
              'color': p.color.value,
              'strokeWidth': p.strokeWidth,
            });
          }
        }

        final stickersData = [];

        for (final s in stickers) {
          stickersData.add({
            'nx': s.offset.dx / canvasSize.width,
            'ny': s.offset.dy / canvasSize.height,
            'imagePath': s.imagePath,
            'size': s.size,
          });
        }

        final undoData = _undoStack
            .map((snapshot) => snapshot.toJson(canvasSize))
            .toList();
        await _saveUndoStackToPrefs(canvasSize);

        await dataFile.writeAsString(
          jsonEncode({
            'points': pointsData,
            'stickers': stickersData,
            'undoStack': undoData,
          }),
          flush: true,
        );
      }

      await _savePreviewImage();
    } catch (_) {}
  }

  Future<void> _saveAfterFrame() async {
    await Future.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    await _saveDrawing();
  }

  Future<void> _deleteSavedDrawing() async {
    try {
      final files = [
        await _getFillFile(),
        await _getDataFile(),
        await _getPreviewFile(),
      ];

      for (final file in files) {
        if (await file.exists()) {
          if (file.path.endsWith('_preview.png')) {
            await FileImage(file).evict();
          }
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> clearCanvas() async {
    _pushUndoState();

    setState(() {
      points.clear();
      stickers.clear();
      _pendingPointData.clear();
      _pendingStickerData.clear();
      _pendingUndoData.clear();
      _undoStack.clear();
      _restoredSavedData = true;
      _particles.clear();
      activeColorIndex = null;

      if (_outlineImage != null) {
        _fillLayer = img.Image(
          width: _outlineImage!.width,
          height: _outlineImage!.height,
          numChannels: 4,
        );
        img.fill(_fillLayer!, color: img.ColorRgba8(0, 0, 0, 0));
        _updateFillLayerBytes();
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_undoPrefsKey);
    } catch (_) {}

    await _deleteSavedDrawing();
  }

  void _spawnParticles(Offset center) {
    final now = DateTime.now();

    final newParticles = List.generate(_tapParticleCount, (i) {
      final angle = (i / _tapParticleCount) * math.pi * 2;
      final distance = 16 + _random.nextDouble() * 20;

      return FillParticle(
        start: center,
        end: Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        ),
        size: 8 + _random.nextDouble() * 5,
        rotation: angle,
        duration: Duration(milliseconds: 320 + _random.nextInt(140)),
        createdAt: now,
      );
    });

    // 🚫 NO setState → this removes lag completely
    _particles
      ..clear()
      ..addAll(newParticles);

    _particlesController.forward(from: 0);
  }

  void _handleCanvasTap(TapDownDetails details, Size canvasSize) {
    final local = details.localPosition;
    if (!_isWithinCanvas(local, canvasSize)) return;

    if (currentMode == PaintMode.sticker) {
      _addSticker(local);
    } else {
      _handleFillTap(details, canvasSize);
    }
  }

  void _addSticker(Offset localPosition) {
    _pushUndoState();

    setState(() {
      stickers.add(
        StickerData(
          offset: localPosition,
          imagePath: selectedSticker,
          size: 82,
        ),
      );
    });

    _saveAfterFrame();
  }

  void _handleFillTap(TapDownDetails details, Size canvasSize) {
    if (_outlineImage == null || _fillLayer == null) return;
    if (_isFilling) return;

    final local = details.localPosition;
    if (!_isWithinCanvas(local, canvasSize)) return;

    final int imageX =
        (local.dx / canvasSize.width * _outlineImage!.width).floor();
    final int imageY =
        (local.dy / canvasSize.height * _outlineImage!.height).floor();

    // ✅ Start animation instantly
    _spawnParticles(local);

    // ❌ Cancel previous fill if exists
    _delayedFillTimer?.cancel();

    // ✅ Delay heavy work until animation almost finishes
    _delayedFillTimer = Timer(const Duration(milliseconds: 430), () async {
      if (!mounted) return;

      _isFilling = true;

      _pushUndoState();
      await _performFill(imageX, imageY);

      _isFilling = false;
    });
  }

  Future<void> _performFill(int imageX, int imageY) async {
    await _floodFill(imageX, imageY);
    await _saveAfterFrame();
  }

  img.ColorRgba8 _pixelColorForMode(int x, int y, Color baseColor) {
    switch (currentMode) {
      case PaintMode.glitterFill:
        if (_glitterImage != null) {
          final p = _glitterImage!
              .getPixel(x % _glitterImage!.width, y % _glitterImage!.height);
          return img.ColorRgba8(
            p.r.toInt(),
            p.g.toInt(),
            p.b.toInt(),
            p.a.toInt(),
          );
        }
        break;

      case PaintMode.patternFill:
        if (_patternImage != null) {
          final p = _patternImage!
              .getPixel(x % _patternImage!.width, y % _patternImage!.height);
          return img.ColorRgba8(
            p.r.toInt(),
            p.g.toInt(),
            p.b.toInt(),
            p.a.toInt(),
          );
        }
        break;

      case PaintMode.brush:
      case PaintMode.fill:
      case PaintMode.sticker:
        break;
    }

    return img.ColorRgba8(
      baseColor.red,
      baseColor.green,
      baseColor.blue,
      255,
    );
  }

  Future<void> _floodFill(int startX, int startY) async {
    if (_outlineImage == null || _fillLayer == null) return;

    final width = _outlineImage!.width;
    final height = _outlineImage!.height;

    if (startX < 0 || startX >= width || startY < 0 || startY >= height) {
      return;
    }

    if (_isBlackBoundary(_outlineImage!.getPixel(startX, startY))) return;

    final startFill = _fillLayer!.getPixel(startX, startY);

    if (currentMode == PaintMode.fill &&
        startFill.a == 255 &&
        startFill.r == selectedColor.red &&
        startFill.g == selectedColor.green &&
        startFill.b == selectedColor.blue) {
      return;
    }

    final visited = List.generate(
      height,
      (_) => List<bool>.filled(width, false),
    );

    final queue = Queue<Offset>();
    queue.add(Offset(startX.toDouble(), startY.toDouble()));
    var processed = 0;

    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      final x = cur.dx.toInt();
      final y = cur.dy.toInt();

      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      if (visited[y][x]) continue;

      visited[y][x] = true;

      if (_isBlackBoundary(_outlineImage!.getPixel(x, y))) continue;

      _fillLayer!.setPixel(x, y, _pixelColorForMode(x, y, selectedColor));

      queue.add(Offset((x + 1).toDouble(), y.toDouble()));
      queue.add(Offset((x - 1).toDouble(), y.toDouble()));
      queue.add(Offset(x.toDouble(), (y + 1).toDouble()));
      queue.add(Offset(x.toDouble(), (y - 1).toDouble()));

      processed++;
      if (processed % 2500 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    setState(() {
      _updateFillLayerBytes();
    });
  }

  Widget _buildTopRoundButton({
    required IconData icon,
    required VoidCallback onTap,
    required List<Color> colors,
    double size = 46,
    double iconSize = 23,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.95),
            width: 4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _buildToolButton({
    required String imagePath,
    required VoidCallback onTap,
    required bool selected,
    double size = 72,
    double imageSize = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: 84,
        child: Center(
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            scale: selected ? 1.18 : 1.0,
            child: SizedBox(
              width: imageSize,
              height: imageSize,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool(String path, PaintMode mode) {
    return _buildToolButton(
      imagePath: path,
      selected: currentMode == mode,
      onTap: () {
        setState(() {
          currentMode = mode;
          if (mode == PaintMode.brush) {
            final idx = colorsList.indexOf(selectedColor);
            activeColorIndex = idx >= 0 ? idx : 0;
          } else {
            activeColorIndex = null;
          }
        });
      },
    );
  }

  Widget _saveButton() {
    return _buildToolButton(
      imagePath: 'assets/images/tools/save.png',
      selected: false,
      onTap: () async {
        await _saveAfterFrame();
        if (!mounted) return;
        Navigator.pop(context);
      },
    );
  }

  Widget _buildColorDot(Color color, {int? colorIndex}) {
    final isSelected = selectedColor == color;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
          if (currentMode == PaintMode.brush && colorIndex != null) {
            activeColorIndex = colorIndex;
          }
        });
      },
      child: AnimatedContainer(
        key: colorIndex != null ? _colorKeys[colorIndex] : null,
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        transform:
            isSelected ? (Matrix4.identity()..scale(1.08)) : Matrix4.identity(),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.black26,
            width: isSelected ? 3.2 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? color.withOpacity(0.45) : Colors.black12,
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrushSizeDot(double sizeValue) {
    final isSelected = strokeWidth == sizeValue;
    final double previewSize = sizeValue <= 6
        ? 10
        : sizeValue <= 12
            ? 16
            : 22;

    return GestureDetector(
      onTap: () {
        setState(() {
          strokeWidth = sizeValue;
          activeColorIndex = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: isSelected ? Colors.black87 : Colors.black26,
            width: isSelected ? 2.4 : 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: previewSize,
            height: previewSize,
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrushSizeOverlay() {
    if (currentMode != PaintMode.brush || activeColorIndex == null) {
      return const SizedBox.shrink();
    }

    final key = _colorKeys[activeColorIndex!];
    final contextForColor = key?.currentContext;
    if (contextForColor == null) return const SizedBox.shrink();

    final renderBox = contextForColor.findRenderObject() as RenderBox?;
    final overlayBox = context.findRenderObject() as RenderBox?;

    if (renderBox == null || overlayBox == null || !renderBox.hasSize) {
      return const SizedBox.shrink();
    }

    final colorTopLeft =
        renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final colorSize = renderBox.size;

    const double overlayWidth = 168;
    const double overlayHeight = 56;
    const double minPadding = 8;

    double left =
        colorTopLeft.dx + (colorSize.width / 2) - (overlayWidth / 2);

    if (left < minPadding) left = minPadding;
    if (left + overlayWidth > overlayBox.size.width - minPadding) {
      left = overlayBox.size.width - overlayWidth - minPadding;
    }

    final double top = colorTopLeft.dy - overlayHeight - 8;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: overlayWidth,
          height: overlayHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final size in brushSizes) _buildBrushSizeDot(size),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomImageItem({
    required String imagePath,
    required bool selected,
    required VoidCallback onTap,
    bool circular = true,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFE86ED7) : Colors.black26,
            width: selected ? 3 : 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(circular ? 50 : 8),
          child: Image.asset(imagePath, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildColorBar() {
    int itemCount = colorsList.length;

    if (currentMode == PaintMode.glitterFill) {
      itemCount = glitterOptions.length;
    } else if (currentMode == PaintMode.patternFill) {
      itemCount = patternOptions.length;
    } else if (currentMode == PaintMode.sticker) {
      itemCount = stickerOptions.length;
    }

    return Container(
      height: _paletteBarHeight,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF7B2FD9).withOpacity(0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD073FF),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (currentMode == PaintMode.glitterFill) {
            final g = glitterOptions[index];
            return _buildBottomImageItem(
              imagePath: g,
              selected: selectedGlitter == g,
              circular: true,
              size: 38,
              onTap: () async {
                selectedGlitter = g;
                await _loadGlitterImage();
                if (!mounted) return;
                setState(() {});
              },
            );
          }

          if (currentMode == PaintMode.patternFill) {
            final p = patternOptions[index];
            return _buildBottomImageItem(
              imagePath: p,
              selected: selectedPattern == p,
              circular: true,
              size: 38,
              onTap: () async {
                selectedPattern = p;
                await _loadPatternImage();
                if (!mounted) return;
                setState(() {});
              },
            );
          }

          if (currentMode == PaintMode.sticker) {
            final s = stickerOptions[index];
            return _buildBottomImageItem(
              imagePath: s,
              selected: selectedSticker == s,
              circular: false,
              size: 52,
              onTap: () {
                setState(() => selectedSticker = s);
              },
            );
          }

          return _buildColorDot(colorsList[index], colorIndex: index);
        },
      ),
    );
  }

  Widget _buildToolsBar() {
    final tools = [
      ['assets/images/tools/brush.png', PaintMode.brush],
      ['assets/images/tools/fill.png', PaintMode.fill],
      ['assets/images/tools/glitter.png', PaintMode.glitterFill],
      ['assets/images/tools/pattern.png', PaintMode.patternFill],
      ['assets/images/tools/sticker.png', PaintMode.sticker],
    ];

    return Container(
      height: _toolsBarHeight,
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 4),
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB15DFF), Color(0xFF8E39F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF7B2FD9), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final tool in tools)
                _tool(tool[0] as String, tool[1] as PaintMode),
              _saveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSection() {
    return Container(
      height: _bannerReservedHeight,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
      alignment: Alignment.bottomCenter,
      color: const Color(0xFFB55BFF),
      child: (_isBannerReady && _bannerAd != null)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 16,
                height: _bannerReservedHeight - 14,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: _bannerAd!.size.width.toDouble(),
                    height: _bannerAd!.size.height.toDouble(),
                    child: AdWidget(ad: _bannerAd!),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildCanvas() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final double availableHeight =
                constraints.maxHeight - _topCanvasSpacing;

            double frameWidth = availableWidth * 0.992;
            double frameHeight = frameWidth / _canvasAspectRatio;

            if (frameHeight > availableHeight) {
              frameHeight = availableHeight;
              frameWidth = frameHeight * _canvasAspectRatio;
            }

            Widget frameChild;

            if (_loading || _outlineImage == null) {
              frameChild = const Center(
                child: CircularProgressIndicator(),
              );
            } else {
              frameChild = ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: const Color(0xFFE7E7E7),
                  padding: const EdgeInsets.all(6),
                  child: AspectRatio(
                    aspectRatio: _canvasAspectRatio,
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: LayoutBuilder(
                        builder: (context, innerConstraints) {
                          final canvasSize = Size(
                            innerConstraints.maxWidth,
                            innerConstraints.maxHeight,
                          );

                          _lastCanvasSize = canvasSize;
                          _restoreSavedDataIfNeeded(canvasSize);

                          final isTapMode =
                              currentMode == PaintMode.fill ||
                                  currentMode == PaintMode.glitterFill ||
                                  currentMode == PaintMode.patternFill ||
                                  currentMode == PaintMode.sticker;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: isTapMode
                                ? (d) => _handleCanvasTap(d, canvasSize)
                                : null,
                            onPanStart: currentMode == PaintMode.brush
                                ? (d) {
                                    final pos = d.localPosition;
                                    if (_isWithinCanvas(pos, canvasSize)) {
                                      _pushUndoState();

                                      setState(() {
                                        points.add(
                                          DrawPoint(
                                            offset: pos,
                                            color: selectedColor,
                                            strokeWidth: strokeWidth,
                                          ),
                                        );
                                      });
                                    }
                                  }
                                : null,
                            onPanUpdate: currentMode == PaintMode.brush
                                ? (d) {
                                    final pos = d.localPosition;
                                    if (_isWithinCanvas(pos, canvasSize)) {
                                      setState(() {
                                        points.add(
                                          DrawPoint(
                                            offset: pos,
                                            color: selectedColor,
                                            strokeWidth: strokeWidth,
                                          ),
                                        );
                                      });
                                    } else if (points.isNotEmpty &&
                                        points.last != null) {
                                      setState(() {
                                        points.add(null);
                                      });
                                    }
                                  }
                                : null,
                            onPanEnd: currentMode == PaintMode.brush
                                ? (_) {
                                    setState(() {
                                      points.add(null);
                                    });
                                    _saveAfterFrame();
                                  }
                                : null,
                            child: RepaintBoundary(
                              key: _previewKey,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: Colors.white),
                                  if (_fillLayerBytes != null)
                                    Positioned.fill(
                                      child: Image.memory(
                                        _fillLayerBytes!,
                                        fit: BoxFit.fill,
                                         gaplessPlayback: true,
                                      ),
                                    ),
                                  Positioned.fill(
                                    child: Image.asset(
                                      widget.item.imagePath,
                                      fit: BoxFit.fill,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                                  CustomPaint(
                                    size: canvasSize,
                                    painter: DrawingPainter(
                                      points: points,
                                    ),
                                  ),
                                  for (final s in stickers)
                                    Positioned(
                                      left: s.offset.dx - s.size / 2,
                                      top: s.offset.dy - s.size / 2,
                                      child: IgnorePointer(
                                        child: Image.asset(
                                          s.imagePath,
                                          width: s.size,
                                          height: s.size,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  IgnorePointer(
                                    child: AnimatedBuilder(
                                      animation: _particlesController,
                                      builder: (context, _) {
                                        return CustomPaint(
                                          size: canvasSize,
                                          painter: FillParticlesPainter(
                                            particles: _particles,
                                            now: DateTime.now(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                const SizedBox(height: _topCanvasSpacing),
                Expanded(
                  child: Center(
                    child: Container(
                      width: frameWidth,
                      height: frameHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7E7E7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFF59C93B),
                          width: 8,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(child: frameChild),
                          Positioned(
                            top: -8,
                            left: -6,
                            child: _buildTopRoundButton(
                              icon: Icons.arrow_back_rounded,
                              onTap: () async {
                                await _saveAfterFrame();
                                if (!mounted) return;
                                Navigator.pop(context);
                              },
                              colors: const [
                                Color(0xFFA855F7),
                                Color(0xFF7E22CE),
                              ],
                            ),
                          ),
                          Positioned(
                            top: -8,
                            right: -6,
                            child: Row(
                              children: [
                                _buildTopRoundButton(
                                  icon: Icons.undo_rounded,
                                  onTap: undoLastStep,
                                  colors: const [
                                    Color(0xFF4DB6FF),
                                    Color(0xFF1976D2),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                _buildTopRoundButton(
                                  icon: Icons.delete_rounded,
                                  onTap: clearCanvas,
                                  colors: const [
                                    Color(0xFFFF8A36),
                                    Color(0xFFFF4C1D),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveAfterFrame();
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFB55BFF),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: _bannerReservedHeight),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildCanvas(),
                        SizedBox(
                          height: _bottomControlsAreaHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: _buildToolsBar(),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: -30,
                                child: _buildColorBar(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildBrushSizeOverlay(),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBannerSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}