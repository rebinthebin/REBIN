import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/supabase_providers.dart';

class QRScanScreen extends ConsumerStatefulWidget {
  const QRScanScreen({super.key});

  @override
  ConsumerState<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends ConsumerState<QRScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 10.0,
      end: 236.0,
    ).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _isScanning = false;
        });

        _processQRCode(code.trim());
      }
    }
  }

  Future<void> _processQRCode(String rawCipher) async {
    // Karakter temizleme (Gizli karakterler, whitespace vb.)
    final cleanedToken = rawCipher.trim().replaceAll(
      RegExp(r'[\u200B-\u200D\uFEFF]'),
      '',
    );
    print("[QR] Temizlenmiş token: '$cleanedToken'");

    // 1. Yükleniyor durumu göster
    _showSnackBar('Kutu doğrulanıyor...', Colors.orange);

    try {
      // 2. Supabase'den kutuyu qr_token ile ara
      final supabaseService = ref.read(supabaseServiceProvider);
      final verifiedBin = await supabaseService.getBinByQrToken(cleanedToken);

      if (verifiedBin == null) {
        _showSnackBar('Geçersiz veya yetkisiz REBİN kodu', Colors.red);
        _resumeScanning();
        return;
      }

      // 3. SQLite'a Kaydet (İsim korunur, diğer veriler güncellenir)
      final binDb = ref.read(binDatabaseServiceProvider);
      await binDb.insertOrUpdateBin(verifiedBin);

      print("[QR] Kutu başarıyla senkronize edildi: ${verifiedBin.name}");

      // 6. Provider'ları güncelle
      ref.invalidate(privateBinsProvider);
      ref.invalidate(allBinsProvider);
      ref.invalidate(binByIdProvider(verifiedBin.binId));

      // Başarı mesajı
      _showSnackBar(
        'Kutu başarıyla eklendi: ${verifiedBin.name}',
        Colors.green,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.pop();
        }
      });
    } catch (e) {
      print("[QR] Beklenmeyen hata: $e");
      _showSnackBar('Bir hata oluştu: $e', Colors.red);
      _resumeScanning();
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resumeScanning() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
      }
    });
  }

  void _showManualAddDialog() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController tokenController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Kod İle Ekle',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Kutu ID (Örn: rebin_0001)',
                  hintStyle: const TextStyle(color: Colors.black54),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tokenController,
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'Güvenlik Kodu (QR Token)',
                  hintStyle: const TextStyle(color: Colors.black54),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final binId = idController.text.trim();
                final token = tokenController.text.trim();
                Navigator.pop(context);
                if (binId.isNotEmpty && token.isNotEmpty) {
                  _processManualCode(binId, token);
                } else {
                  _showSnackBar(
                    'Lütfen her iki alanı da doldurun.',
                    Colors.orange,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                'Onayla',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processManualCode(String binId, String token) async {
    _showSnackBar('Kutu doğrulanıyor...', Colors.orange);

    try {
      final supabaseService = ref.read(supabaseServiceProvider);
      // 1. Direkt bin_id ile sorgula
      final verifiedBin = await supabaseService.getBinById(binId);

      if (verifiedBin == null) {
        _showSnackBar('Geçersiz veya yetkisiz REBİN kodu', Colors.red);
        return;
      }

      // 2. Güvenlik Kontrolü: Token eşleşmeli (Manual girişte bile)
      if (verifiedBin.qrToken != token) {
        _showSnackBar('Güvenlik kodu eşleşmiyor!', Colors.red);
        return;
      }

      // 3. SQLite'a kaydet (İsim korunur, diğer veriler güncellenir)
      final binDb = ref.read(binDatabaseServiceProvider);
      await binDb.insertOrUpdateBin(verifiedBin);

      // 4. State güncelle
      ref.invalidate(privateBinsProvider);
      ref.invalidate(allBinsProvider);
      ref.invalidate(binByIdProvider(binId));

      _showSnackBar(
        'Kutu başarıyla eklendi: ${verifiedBin.name}',
        Colors.green,
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.pop();
      });
    } catch (e) {
      print("[Manual] Beklenmeyen hata: $e");
      _showSnackBar('Bir hata oluştu: $e', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _showManualAddDialog,
              child: Text(
                'Kod ile ekle',
                style: GoogleFonts.outfit(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Gerçek Kamera Görüntüsü
          MobileScanner(controller: _scannerController, onDetect: _onDetect),

          // Yarı Saydam Siyah Kaplama (Ortası Delik)
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Colors.green,
                borderRadius: 20,
                borderLength: 40,
                borderWidth: 8,
                cutOutSize: 250,
              ),
            ),
          ),

          // Hareketli Tarama Çizgisi (TAM ORTALANMIŞ)
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Positioned(
                          top: _animation.value,
                          left: 0,
                          child: Container(
                            width: 250,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.8),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Üst ve Alt Yazılar/İkonlar
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      "REBİN üzerindeki QR'ı taratın",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Ortası kare şeklinde delik olan yarı saydam kaplama için yardımcı sınıf
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 0.7),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10.0);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getCutOutPath() {
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
      );
    }

    return Path()
      ..addRect(rect)
      ..addPath(getCutOutPath(), Offset.zero);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: Offset(width / 2, height / 2),
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(
      Path()
        ..addRect(rect)
        ..addRect(cutOutRect)
        ..fillType = PathFillType.evenOdd,
      backgroundPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
