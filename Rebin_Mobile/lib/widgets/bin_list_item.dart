import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/bin_model.dart';
import '../core/waste_theme.dart';

class BinListItem extends StatelessWidget {
  final RebinBin bin;

  const BinListItem({super.key, required this.bin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Genel doluluk oranı
    final double averageLevel = bin.general;

    // Doluluk rengini belirle
    Color levelColor;
    if (averageLevel < 0.3) {
      levelColor = Colors.green;
    } else if (averageLevel < 0.7) {
      levelColor = Colors.orange;
    } else {
      levelColor = Colors.red;
    }

    // Tür ve durum rengini belirle
    final bool isPrivate = bin.isPrivate;
    final bool isOutOfOrder = bin.isOutOfOrder;
    final Color typeColor = isPrivate ? Colors.green : Colors.blue;
    final String typeLabel = isPrivate ? 'Özel' : 'Topluma Açık';
    final IconData typeIcon = isPrivate ? Icons.lock : Icons.public;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isOutOfOrder
            ? const BorderSide(color: WasteTheme.outOfOrderBorderColor, width: 2)
            : (isPrivate
                ? BorderSide(color: Colors.green.shade400, width: 2)
                : BorderSide(color: Colors.blue.shade400, width: 2)),
      ),
      color: isOutOfOrder
          ? WasteTheme.outOfOrderBgColor.withValues(alpha: 0.3)
          : (isPrivate ? Colors.green.shade50 : Colors.white),
      child: InkWell(
        onTap: () {
          context.push('/rebin-detail', extra: bin.binId);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Doluluk göstergesi (Logo)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: levelColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.recycling,
                          color: levelColor,
                          size: 24,
                        ),
                      ),
                      if (isOutOfOrder)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.priority_high,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Kutu bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bin.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPrivate ? Colors.green.shade800 : Colors.black87,
                                ),
                              ),
                            ),
                            // Arızalı Rozeti veya Tür badge'i
                            if (isOutOfOrder) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: WasteTheme.outOfOrderBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: WasteTheme.outOfOrderBorderColor),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: WasteTheme.outOfOrderTextColor, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Arızalı',
                                      style: TextStyle(
                                        color: WasteTheme.outOfOrderTextColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(typeIcon, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    typeLabel,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Genel Doluluk: %${(averageLevel * 100).toInt()}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // İleri ok
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isPrivate ? Colors.green.shade400 : Colors.blue.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Alt taraftaki küçük yuvarlak göstergeler (Sıfır Atık Renkleri)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSmallWasteIndicator('Kağıt', bin.paper, WasteTheme.paperColor),
                  _buildSmallWasteIndicator('Plastik', bin.plastic, WasteTheme.plasticColor),
                  _buildSmallWasteIndicator('Cam', bin.glass, WasteTheme.glassColor),
                  _buildSmallWasteIndicator('Metal', bin.metal, WasteTheme.metalColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallWasteIndicator(String title, double percent, Color color) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 18.0,
          lineWidth: 4.0,
          percent: percent.clamp(0.0, 1.0),
          progressColor: color,
          backgroundColor: color.withValues(alpha: 0.2),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
