import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/supabase_providers.dart';
import '../widgets/bin_list_item.dart';
import '../models/bin_model.dart';

class MyBinsScreen extends ConsumerStatefulWidget {
  const MyBinsScreen({super.key});

  @override
  ConsumerState<MyBinsScreen> createState() => _MyBinsScreenState();
}

class _MyBinsScreenState extends ConsumerState<MyBinsScreen> {
  @override
  void initState() {
    super.initState();
    // Her ekran geçişinde verileri veritabanından yeniden oku
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(privateBinsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final binsAsyncValue = ref.watch(privateBinsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Kutularım',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      body: binsAsyncValue.when(
        data: (bins) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (bins.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: Text('Henüz hiç kutu eklemediniz.')),
                  )
                else
                  Builder(builder: (context) {
                    final sortedBins = List<RebinBin>.from(bins);
                    sortedBins.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedBins.length,
                      itemBuilder: (context, index) {
                        final bin = sortedBins[index];
                        return BinListItem(bin: bin);
                      },
                    );
                  }),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('QR ile Ekle'),
                  onPressed: () {
                    context.push('/qr-scan');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25), // Oval köşeler
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded),
                  label: const Text('İstatistikleri Görüntüle'),
                  onPressed: () {
                    context.push('/stats');
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 120), // Alttaki navigasyonla çakışmaması için boşluk
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Hata: $error')),
      ),
    ),
    );
  }
}
