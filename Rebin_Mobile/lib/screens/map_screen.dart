import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/bin_database_service.dart';
import '../models/bin_model.dart';
import '../providers/supabase_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  final LatLng? targetLocation;

  const MapScreen({super.key, this.targetLocation});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  LatLng _userLocation = const LatLng(40.9933292, 28.7004161);
  List<RebinBin> _privateBins = [];
  List<RebinBin> _publicBins = [];
  bool _isLoadingBins = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _pulseAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _getUserLocation();
    _loadBinsFromDB();
  }

  Future<void> _getUserLocation() async {
    final location = loc.Location();
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
      }

      if (serviceEnabled) {
        loc.PermissionStatus permissionGranted = await location.hasPermission();
        if (permissionGranted == loc.PermissionStatus.denied) {
          permissionGranted = await location.requestPermission();
        }

        if (permissionGranted == loc.PermissionStatus.granted || permissionGranted == loc.PermissionStatus.grantedLimited) {
          final locationData = await location.getLocation();
          if (mounted && locationData.latitude != null && locationData.longitude != null) {
            setState(() {
              _userLocation = LatLng(locationData.latitude!, locationData.longitude!);
            });
            // Eğer hedef konum yoksa, haritayı kullanıcının gerçek konumuna taşı
            if (widget.targetLocation == null) {
              _mapController.move(_userLocation, 14.0);
            }
          }
        }
      }
    } catch (e) {
      print("GPS alınamadı, varsayılan konum kullanılacak: $e");
      // Konum alınamazsa varsayılan konuma (40.9933292, 28.7004161) odaklan (Zaten _userLocation varsayılanı o)
      if (widget.targetLocation == null) {
        _mapController.move(_userLocation, 14.0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBinsFromDB() async {
    setState(() => _isLoadingBins = true);
    try {
      final dbService = BinDatabaseService.instance;
      final supabaseService = ref.read(supabaseServiceProvider);

      // 1. Yerel verileri hemen al
      var privateBins = await dbService.getPrivateBins();
      var publicBins = await dbService.getPublicBins();

      if (mounted) {
        setState(() {
          _privateBins = privateBins;
          _publicBins = publicBins;
        });
      }

      // 2. Supabase'den güncel verileri çek (Public bins için)
      final freshPublic = await supabaseService.getPublicBins();
      if (freshPublic.isNotEmpty && mounted) {
        setState(() {
          _publicBins = freshPublic;
        });
        // İsteğe bağlı: SQLite'ı da güncelle
        for (var b in freshPublic) {
          await dbService.insertOrUpdateBin(b);
        }
      }
    } catch (e) {
      print("Kutu yükleme hatası: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBins = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Text('Harita', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Konumunuz',
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87)),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.targetLocation ?? _userLocation,
                initialZoom: widget.targetLocation != null ? 17.0 : 14.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.project.rebin',
                ),
                MarkerLayer(
                  markers: [
                    // Kullanıcı Konumu (Kırmızı Pulse)
                    Marker(
                      point: _userLocation,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 20 + _pulseAnimation.value,
                                height: 20 + _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withValues(alpha: 0.3),
                                ),
                              ),
                              const Icon(Icons.my_location,
                                  color: Colors.red, size: 24),
                            ],
                          );
                        },
                      ),
                    ),

                    // Özel Kutular (Yeşil İkon)
                    ..._privateBins.map((bin) => _buildBinMarker(bin, Colors.green.shade600)),

                    // Topluma Açık Kutular (Mavi Yuvarlak İkon)
                    ..._publicBins.map((bin) => _buildBinMarker(bin, Colors.blue.shade600)),
                  ],
                ),
              ],
            ),

            if (_isLoadingBins)
              const Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: 8),
                          Text('Kutular güncelleniyor...'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Harita Lejantı (Sol Alt)
            Positioned(
              bottom: 24,
              left: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(Colors.green.shade600, 'Özel Kutum'),
                      const SizedBox(height: 8),
                      _buildLegendItem(
                          Colors.blue.shade600, 'Topluma Açık Kutu'),
                      const SizedBox(height: 8),
                      _buildLegendWarningItem('Arızalı Kutu'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _mapController.move(_userLocation, 15.0);
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: Colors.black87),
        ),
      ),
    );
  }

  Marker _buildBinMarker(RebinBin bin, Color baseColor) {
    final bool isOutOfOrder = bin.isOutOfOrder;
    const Color outOfOrderBorder = Color(0xFFD97706); // Koyu Sarı / Amber 600

    return Marker(
      point: LatLng(bin.latitude, bin.longitude),
      width: 46,
      height: 46,
      child: GestureDetector(
        onTap: () {
          context.push('/rebin-detail', extra: bin.binId);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
                border: isOutOfOrder
                    ? Border.all(color: outOfOrderBorder, width: 3.0)
                    : Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: isOutOfOrder
                        ? outOfOrderBorder.withValues(alpha: 0.5)
                        : baseColor.withValues(alpha: 0.4),
                    blurRadius: isOutOfOrder ? 10 : 8,
                    spreadRadius: isOutOfOrder ? 2 : 1,
                  ),
                ],
              ),
              child: const Icon(Icons.recycling, color: Colors.white, size: 24),
            ),
            // Arızalı kutu için sağ üst köşede kırmızı ünlem işareti
            if (isOutOfOrder)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendWarningItem(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD97706), width: 2),
              ),
            ),
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
