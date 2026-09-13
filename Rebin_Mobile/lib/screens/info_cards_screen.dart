import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../core/waste_theme.dart';

class InfoCardData {
  final String category;
  final String categoryNumber;
  final String fact;
  final Color color;

  InfoCardData({
    required this.category,
    required this.categoryNumber,
    required this.fact,
    required this.color,
  });
}

class InfoCardsScreen extends StatefulWidget {
  const InfoCardsScreen({super.key});

  @override
  State<InfoCardsScreen> createState() => _InfoCardsScreenState();
}

class _InfoCardsScreenState extends State<InfoCardsScreen> with SingleTickerProviderStateMixin {
  final List<InfoCardData> cards = [
    InfoCardData(
      category: "Plastik",
      categoryNumber: "#1",
      fact: "Plastik şişeleri atmadan önce kapağını çıkarın ve ezerek boyutunu küçültün; bu, taşıma kapasitesini ve lojistik verimi %40 artırarak karbon ayak izinizi azaltır!",
      color: WasteTheme.plasticColor,
    ),
    InfoCardData(
      category: "Kağıt",
      categoryNumber: "#1",
      fact: "Yağlı pizza kutuları veya soslu kağıtlar geri dönüştürülemez! Kirli kısımları genel atığa atın, sadece temiz ve kuru kısımları R.E.B.İ.N.'e bırakın. Unutmayın, bir adet yağlı kağıt tüm bir balya temiz kağıdı kirletebilir!",
      color: WasteTheme.paperColor,
    ),
    InfoCardData(
      category: "Cam",
      categoryNumber: "#1",
      fact: "Cam şişelerin içini boşaltın, metal kapakları ve plastik etiketleri ayırarak ilgili kutulara atın. Saf camın geri dönüşümü %100 verimlidir ve sonsuz kez kalitesini kaybetmeden dönüştürülebilir!",
      color: WasteTheme.glassColor,
    ),
    InfoCardData(
      category: "Metal",
      categoryNumber: "#1",
      fact: "Alüminyum kutuları geri dönüştürmek, hammaddeden yeni bir kutu üretmeye oranla %95 daha az enerji harcar. Sadece bir metal kutuyu geri dönüştürerek bir televizyonu 3 saat çalıştıracak enerjiyi kurtarabilirsiniz!",
      color: WasteTheme.metalColor,
    ),
    InfoCardData(
      category: "Plastik",
      categoryNumber: "#2",
      fact: "Şeffaf plastikler, renkli olanlara göre daha yüksek geri dönüşüm değerine sahiptir. Mümkünse alışverişlerinizde renksiz ve şeffaf ambalajları tercih ederek döngüsel ekonomiye destek olun!",
      color: WasteTheme.plasticColor,
    ),
    InfoCardData(
      category: "Kağıt",
      categoryNumber: "#2",
      fact: "Kağıtları küçük parçalara ayırmak veya parçalamak, lif boylarını kısalttığı için geri dönüşüm kalitesini düşürür. Kağıtları yırtmadan, bütün halde veya sadece katlayarak biriktirmek en verimli yoldur!",
      color: WasteTheme.paperColor,
    ),
    InfoCardData(
      category: "Cam",
      categoryNumber: "#2",
      fact: "Isıya dayanıklı camlar (borcamlar) veya ayna/pencere camları, ambalaj camlarından farklı bir erime noktasına sahiptir. Bu yüzden sadece cam şişe ve kavanozları geri dönüşüme gönderin!",
      color: WasteTheme.glassColor,
    ),
    InfoCardData(
      category: "Metal",
      categoryNumber: "#2",
      fact: "Alüminyum folyolar da geri dönüştürülebilir! Ancak folyonun geri dönüşüm tesisinde kaybolmaması için küçük parçalar yerine, folyoları biriktirip yumruk büyüklüğünde bir top haline getirerek kutuya atın.",
      color: WasteTheme.metalColor,
    ),
  ];

  int currentIndex = 0;
  double _dragOffset = 0.0;
  late AnimationController _animController;
  late Animation<double> _animOffset;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _animController.addListener(() {
      setState(() {
        _dragOffset = _animOffset.value;
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details, double screenWidth) {
    if (_dragOffset < -screenWidth * 0.25 || details.velocity.pixelsPerSecond.dx < -500) {
      if (currentIndex < cards.length - 1) {
        // Sonraki karta geç (Sola kaydır)
        _animOffset = Tween<double>(begin: _dragOffset, end: -screenWidth).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOut),
        );
        _animController.forward(from: 0).then((_) {
          setState(() {
            currentIndex++;
            _dragOffset = 0.0;
          });
          UserStaticsDatabase.instance.incrementStatic('info_cards');
        });
      } else {
        _resetDrag();
      }
    } else if (_dragOffset > screenWidth * 0.25 || details.velocity.pixelsPerSecond.dx > 500) {
      if (currentIndex > 0) {
        // Önceki karta dön (Sağa kaydır)
        _animOffset = Tween<double>(begin: _dragOffset, end: screenWidth).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOut),
        );
        _animController.forward(from: 0).then((_) {
          setState(() {
            currentIndex--;
            _dragOffset = 0.0;
          });
        });
      } else {
        _resetDrag();
      }
    } else {
      _resetDrag();
    }
  }

  void _resetDrag() {
    _animOffset = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward(from: 0);
  }

  double _getAngleForIndex(int index) {
    if (index == 0) return 0.0;
    return (index % 2 == 1) ? -0.05 : 0.05;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bilgi Kartları',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 100.0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: (details) => _onPanEnd(details, screenWidth),
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: _buildCards(screenWidth),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (currentIndex > 0) ...[
                    const Icon(Icons.arrow_back, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "Geri",
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Text(
                    "${currentIndex + 1} / ${cards.length}",
                    style: GoogleFonts.outfit(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                  if (currentIndex < cards.length - 1) ...[
                    const SizedBox(width: 16),
                    Text(
                      "İleri",
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCards(double screenWidth) {
    List<Widget> stackWidgets = [];

    // 1. Alttaki kartları çiz (Görsel derinlik için)
    if (currentIndex > 0 && _dragOffset >= 0) {
      // Sola kaydırırken altta önceki kart gözüksün
      stackWidgets.add(
        Transform.translate(
          offset: Offset(_dragOffset - screenWidth, 0),
          child: Transform.rotate(
            angle: _getAngleForIndex(currentIndex - 1),
            child: _buildSingleCardContent(cards[currentIndex - 1]),
          ),
        ),
      );
    }

    // 2. Mevcut kartı çiz
    stackWidgets.add(
      Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Transform.rotate(
          angle: _getAngleForIndex(currentIndex),
          child: _buildSingleCardContent(cards[currentIndex]),
        ),
      )
    );

    // 3. Gelecek/Geçmiş kartları çiz
    if (currentIndex < cards.length - 1 && _dragOffset <= 0) {
      // Sola kaydırırken sağdan gelen kart
      stackWidgets.insert(0, 
        Transform.translate(
          offset: Offset(_dragOffset + screenWidth, 0),
          child: Transform.rotate(
            angle: _getAngleForIndex(currentIndex + 1),
            child: _buildSingleCardContent(cards[currentIndex + 1]),
          ),
        )
      );
    }

    return stackWidgets;
  }

  Widget _buildSingleCardContent(InfoCardData data, {bool isBottomCard = false}) {
    return Container(
      width: 300,
      height: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: data.color, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isBottomCard ? 0.05 : 0.15),
            blurRadius: isBottomCard ? 8 : 20,
            offset: Offset(0, isBottomCard ? 4 : 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${data.category} ${data.categoryNumber}",
                  style: GoogleFonts.outfit(
                    color: data.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.fact,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.recycling,
              size: 56,
              color: data.color.withValues(alpha: 0.15),
            ),
          )
        ],
      ),
    );
  }
}
