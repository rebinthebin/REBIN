import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

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
          title: Text(
            'Aktivite Merkezi',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: const [
          ActivityCard(
            title: 'Görevler & Başarılar',
            subtitle: 'Yeni hedeflere ulaşın ve rozetler kazanın.',
            icon: Icons.checklist_rounded,
            color: Colors.orangeAccent,
            route: '/tasks',
          ),
          SizedBox(height: 16),
          ActivityCard(
            title: 'Bilgi Kartları',
            subtitle: 'Geri dönüşüm hakkında yeni şeyler öğrenin.',
            icon: Icons.lightbulb_rounded,
            color: Colors.blueAccent,
            route: '/info',
          ),
          SizedBox(height: 16),
          ActivityCard(
            title: 'Oyun Zamanı',
            subtitle: 'Eğlenceli oyunlarla bilginizi test edin.',
            icon: Icons.sports_esports_rounded,
            color: Colors.greenAccent,
            route: '/games',
          ),
        ],
      ),
    ),
    );
  }
}

class ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  const ActivityCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
