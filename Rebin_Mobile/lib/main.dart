import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Proje içi dosyaları import et
import 'package:latlong2/latlong.dart';
import 'widgets/main_scaffold.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/qr_scan_screen.dart';
import 'screens/my_bins_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/rebin_detail_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/info_cards_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/games_screen.dart';
import 'services/bin_database_service.dart';

// Supabase Credentials
const String supabaseUrl = 'https://spmyeaixfdiohkmmfvgu.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwbXllYWl4ZmRpb2hrbW1mdmd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTY1NzEsImV4cCI6MjEwMTU5MjU3MX0.wcoZ8uYNZa_9Ugp2iZBdtNxCz9lBHR67_V5GK7kuPcA';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Supabase SDK Başlatma
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    print("Supabase başarıyla başlatıldı.");
  } catch (e) {
    print("Supabase başlatma hatası: $e");
  }

  // SQLite veritabanını başlat ve varsayılan kutuları ekle
  await BinDatabaseService.instance.initDefaultBins();
  
  runApp(const ProviderScope(child: RebinApp()));
}


// --- Rota Yönetimi (GoRouter) ---
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    // Ana iskelet (Bottom Nav Bar içeren sayfalar)
    ShellRoute(
      builder: (context, state, child) {
        return MainScaffold(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen(),),
        GoRoute(
          path: '/map', 
          builder: (context, state) {
            final LatLng? targetLoc = state.extra as LatLng?;
            return MapScreen(targetLocation: targetLoc);
          },
        ),
        GoRoute(path: '/activity', builder: (context, state) => const ActivityScreen(),),
        GoRoute(path: '/my-bins', builder: (context, state) => const MyBinsScreen(),),
      ],
    ),
    // Tam ekran sayfalar
    GoRoute(path: '/qr-scan', builder: (context, state) => const QRScanScreen(),),
    GoRoute(path: '/camera', builder: (context, state) => const CameraScreen(),),
    GoRoute(path: '/tasks', builder: (context, state) => const TasksScreen(),),
    GoRoute(path: '/info', builder: (context, state) => const InfoCardsScreen(),),
    GoRoute(path: '/stats', builder: (context, state) => const StatisticsScreen(),),
    GoRoute(path: '/games', builder: (context, state) => const GamesScreen(),),
    // Kutu detay ekranı — binId (String) ile açılır
    GoRoute(
      path: '/rebin-detail',
      builder: (context, state) {
        final binId = state.extra as String?;
        if (binId != null) {
          return RebinDetailScreen(binId: binId);
        } else {
          return const HomeScreen(); 
        }
      },
    ),
  ],
);

// --- Ana Uygulama Widget'ı ---
class RebinApp extends StatelessWidget {
  const RebinApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.robotoTextTheme(Theme.of(context).textTheme);

    return MaterialApp.router(
      title: 'REBIN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Ana Yeşil Renk
          brightness: Brightness.light,
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF81C784),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Açık Gri Arka Plan
        textTheme: textTheme.copyWith(
          displayLarge: GoogleFonts.montserrat(textStyle: textTheme.displayLarge, fontWeight: FontWeight.bold, color: Colors.black87),
          headlineMedium: GoogleFonts.montserrat(textStyle: textTheme.headlineMedium, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.roboto(textStyle: textTheme.bodyLarge, fontSize: 16),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
         appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent, // AppBar'ı saydam yap
          elevation: 0, // Gölgeyi kaldır
          iconTheme: const IconThemeData(color: Colors.black87), // Geri butonu gibi ikonların rengi
          titleTextStyle: textTheme.headlineMedium?.copyWith(color: Colors.black87, fontWeight: FontWeight.bold), // Başlık stili
        )
      ),
      routerConfig: _router,
    );
  }
}
