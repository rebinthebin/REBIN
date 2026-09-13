import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pytorch_lite/pigeon.dart';
import '../services/database_service.dart';
import '../providers/daily_task_provider.dart';
import '../core/waste_theme.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final List<ResultObjectDetection> detections;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.detections,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isTaskCompleted = false;

  final Map<String, Color> _kClassColors = {
    'Plastik': WasteTheme.plasticColor,
    'Kağıt': WasteTheme.paperColor,
    'Cam': WasteTheme.glassColor,
    'Metal': WasteTheme.metalColor,
    'Çöp': WasteTheme.trashColor,
  };

  Color _colorOf(String label) => _kClassColors.entries
      .firstWhere(
        (e) => label.toLowerCase().contains(e.key.toLowerCase()),
        orElse: () => const MapEntry('', Colors.grey),
      )
      .value;

  String _mapLabelToTurkish(String label) {
    switch (label.toLowerCase()) {
      case 'plastic':
        return 'Plastik';
      case 'glass':
        return 'Cam';
      case 'metal':
        return 'Metal';
      case 'paper':
        return 'Kağıt';
      case 'cardboard':
        return 'Kağıt';
      case 'trash':
        return 'Çöp';
      default:
        return label;
    }
  }

  ResultObjectDetection? _getBestDetection() {
    if (widget.detections.isEmpty) return null;
    ResultObjectDetection best = widget.detections[0];
    for (var det in widget.detections) {
      if (det.score > best.score) {
        best = det;
      }
    }
    return best;
  }

  Future<void> _onConfirm(String label, double conf) async {
    if (_isTaskCompleted) return;
    if (label == 'Çöp') return;

    setState(() {
      _isTaskCompleted = true;
    });

    // Veritabanına kaydet
    await UserStaticsDatabase.instance.createWasteScan(label, conf);

    if (!mounted) return;

    // Malzemenin güncel sayısını alalım
    final counts = await UserStaticsDatabase.instance.getWasteCountByType();
    final lowerLabel = label.toLowerCase();
    String matKey = 'genel';
    if (lowerLabel.contains('plastik')) {
      matKey = 'plastik';
    } else if (lowerLabel.contains('cam')) {
      matKey = 'cam';
    } else if (lowerLabel.contains('kağıt') || lowerLabel.contains('kagit')) {
      matKey = 'kağıt';
    } else if (lowerLabel.contains('metal')) {
      matKey = 'metal';
    }

    int newCount = counts.entries
        .firstWhere(
          (e) => e.key.toLowerCase().contains(matKey),
          orElse: () => const MapEntry('', 0),
        )
        .value;
    int oldCount = newCount > 0 ? newCount - 1 : 0;
    int target = oldCount < 50 ? 50 : 100;

    // Başarı Pop-up'ı Göster (Arka planda kalacak)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('✅', style: TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Başarılı!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${label.toUpperCase()} malzemesi başarıyla taratıldı.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '%${(conf * 100).toStringAsFixed(1)} Doğruluk',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Görev Bildirimini Overlay Olarak Ekle
    OverlayEntry progressOverlay = OverlayEntry(
      builder: (context) => _TaskProgressNotification(
        material: matKey,
        initialCount: oldCount,
        target: target,
      ),
    );
    if (!mounted) return;
    Overlay.of(context).insert(progressOverlay);

    // Animasyonların bitmesini bekle (3.5 saniye toplam)
    await Future.delayed(const Duration(milliseconds: 3500));
    progressOverlay.remove();

    // Günlük Görev Sayacını Artır ve ilerlemeyi işle
    await ref.read(dailyTaskProvider.notifier).incrementCount(matKey);

    await Future.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Dialog'u kapat
      Navigator.pop(
        context,
      ); // Sonuç ekranından çık (kameraya veya ana sayfaya dön)
    }
  }

  @override
  Widget build(BuildContext context) {
    final bestDet = _getBestDetection();
    final String label = bestDet != null
        ? _mapLabelToTurkish(bestDet.className ?? 'Bilinmiyor')
        : 'Tanımlanamadı';
    final double confidence = bestDet != null ? bestDet.score : 0.0;
    final bool isTrash = label == 'Çöp';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Görüntü
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 2),
                image: DecorationImage(
                  image: FileImage(File(widget.imagePath)),
                  fit: BoxFit.cover,
                ),
              ),
              child: bestDet != null
                  ? CustomPaint(painter: _BBoxPainter(bestDet, _colorOf(label)))
                  : null,
            ),
          ),

          // 2. Üst Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Tarama Sonucu',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Dengelemek için
              ],
            ),
          ),

          // 3. Ana Bilgi Kutusu
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: (!_isTaskCompleted && !isTrash && confidence >= 0.50)
                  ? () => _onConfirm(label, confidence)
                  : null,
              child: DetectionInfoBox(
                label: label,
                confidence: confidence,
                color: bestDet != null ? _colorOf(label) : Colors.grey,
                isTrash: isTrash,
                isInteractive:
                    !_isTaskCompleted && !isTrash && confidence >= 0.50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  final ResultObjectDetection det;
  final Color color;

  _BBoxPainter(this.det, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rect = det.rect;
    double left, top, right, bottom;

    if (rect.left <= 1.0 && rect.right <= 1.0 && rect.bottom <= 1.0) {
      left = rect.left * size.width;
      top = rect.top * size.height;
      right = rect.right * size.width;
      bottom = rect.bottom * size.height;
    } else {
      // Coordinates are based on the 640x640 model input
      final double scaleX = size.width / 640.0;
      final double scaleY = size.height / 640.0;
      left = rect.left * scaleX;
      top = rect.top * scaleY;
      right = rect.right * scaleX;
      bottom = rect.bottom * scaleY;
    }

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DetectionInfoBox extends StatefulWidget {
  final String label;
  final double confidence;
  final Color color;
  final bool isTrash;
  final bool isInteractive;

  const DetectionInfoBox({
    super.key,
    required this.label,
    required this.confidence,
    required this.color,
    this.isTrash = false,
    this.isInteractive = true,
  });

  @override
  State<DetectionInfoBox> createState() => _DetectionInfoBoxState();
}

class _DetectionInfoBoxState extends State<DetectionInfoBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnimation = Tween<double>(begin: 0.55, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.isInteractive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(DetectionInfoBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isInteractive && !oldWidget.isInteractive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isInteractive && oldWidget.isInteractive) {
      _controller.stop();
      _controller.animateBack(0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isInteractive ? _scaleAnimation.value : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(widget.isInteractive ? _glowAnimation.value : 0.55),
                  blurRadius: widget.isInteractive ? 30 : 20,
                  spreadRadius: widget.isInteractive ? 5 : 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            widget.isTrash ? Icons.delete_outline : Icons.document_scanner,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.isTrash
                      ? 'Bu malzeme geri dönüştürülemez'
                      : widget.isInteractive
                          ? '%${(widget.confidence * 100).toStringAsFixed(1)} Doğruluk (Onaylamak için dokunun)'
                          : '%${(widget.confidence * 100).toStringAsFixed(1)} Doğruluk',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Task Progress Notification Overlay (From camera_screen)
// ─────────────────────────────────────────────────────────
class _TaskProgressNotification extends StatefulWidget {
  final String material;
  final int initialCount;
  final int target;

  const _TaskProgressNotification({
    required this.material,
    required this.initialCount,
    required this.target,
  });

  @override
  State<_TaskProgressNotification> createState() =>
      _TaskProgressNotificationState();
}

class _TaskProgressNotificationState extends State<_TaskProgressNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late int _displayCount;

  @override
  void initState() {
    super.initState();
    _displayCount = widget.initialCount;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _playAnimationSequence();
  }

  Future<void> _playAnimationSequence() async {
    await _controller.forward();
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _displayCount++;
      });
    }
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color = WasteTheme.getColor(widget.material);
    IconData iconData = WasteTheme.getIcon(widget.material);

    double progress = (_displayCount / widget.target).clamp(0.0, 1.0);

    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: SafeArea(
        child: SlideTransition(
          position: _slideAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Görev İlerlemesi",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              height: 8,
                              width:
                                  (MediaQuery.of(context).size.width - 120) *
                                  progress,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, -0.5),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                                );
                              },
                          child: Text(
                            "$_displayCount / ${widget.target}",
                            key: ValueKey<int>(_displayCount),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
