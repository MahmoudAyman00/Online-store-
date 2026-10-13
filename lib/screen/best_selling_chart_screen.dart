import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/theme.dart';
import '../core/ui.dart';

/// Best sellers as share-of-sales pie + ranked table.
/// Same data source as before (Transactions items), new presentation.
class BestSellingChartScreen extends StatefulWidget {
  const BestSellingChartScreen({super.key});

  @override
  State<BestSellingChartScreen> createState() =>
      _BestSellingChartScreenState();
}

class _BestSellingChartScreenState extends State<BestSellingChartScreen> {
  int _touchedIndex = -1;

  static const _palette = [
    AppColors.primary,
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFF59E0B),
    Color(0xFF16A34A),
    Color(0xFFEC4899),
    Color(0xFF6B7280),
  ];

  Future<Map<String, int>> _getBestSellingProducts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('Transactions').get();

    final Map<String, int> productSales = {};
    for (final doc in snapshot.docs) {
      final items = doc['items'] as List<dynamic>? ?? [];
      for (final item in items) {
        final name = (item['name'] ?? 'Unknown').toString();
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        productSales[name] = (productSales[name] ?? 0) + qty;
      }
    }
    return productSales;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Best Selling Products')),
      body: FutureBuilder<Map<String, int>>(
        future: _getBestSellingProducts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          } else if (snapshot.hasError) {
            return AppError(
              message: 'Error: ${snapshot.error}',
              onRetry: () => setState(() {}),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const AppEmpty(message: 'No data available.');
          }

          final sorted = snapshot.data!.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final total =
              sorted.fold<int>(0, (acc, e) => acc + e.value);

          // Top 6 + "Other" bucket so the pie stays readable
          const topN = 6;
          final top = sorted.take(topN).toList();
          final rest = sorted.skip(topN).toList();
          final List<MapEntry<String, int>> slices = [...top];
          if (rest.isNotEmpty) {
            slices.add(MapEntry(
                'Other (${rest.length} products)',
                rest.fold<int>(0, (s, e) => s + e.value)));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text('Sales share',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$total units sold',
                            style: TextStyle(
                                fontSize: 13,
                                color: context.muted)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              centerSpaceRadius: 52,
                              sectionsSpace: 2,
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  setState(() {
                                    final idx = response?.touchedSection
                                        ?.touchedSectionIndex;
                                    _touchedIndex = idx ?? -1;
                                  });
                                },
                              ),
                              sections: List.generate(slices.length,
                                  (i) {
                                final e = slices[i];
                                final share =
                                    total == 0 ? 0 : e.value / total * 100;
                                final touched = i == _touchedIndex;
                                return PieChartSectionData(
                                  value: e.value.toDouble(),
                                  color: _palette[i % _palette.length],
                                  radius: touched ? 62 : 50,
                                  title:
                                      share >= 6 ? '${share.toStringAsFixed(0)}%' : '',
                                  titleStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: List.generate(slices.length, (i) {
                            return _LegendDot(
                              color: _palette[i % _palette.length],
                              label: slices[i].key,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Top products',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...List.generate(sorted.length, (i) {
                          final e = sorted[i];
                          final share = total == 0
                              ? 0.0
                              : e.value / total;
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 26,
                                  child: Text('#${i + 1}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: i == 0
                                            ? AppColors.accent
                                            : context.muted,
                                      )),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(e.key,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    fontSize: 14)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                              '${e.value} • ${(share * 100).toStringAsFixed(1)}%',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      context.muted)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                        child:
                                            LinearProgressIndicator(
                                          value: share,
                                          minHeight: 6,
                                          backgroundColor:
                                              context.softFill,
                                          valueColor:
                                              AlwaysStoppedAnimation(
                                                  _palette[i %
                                                      _palette.length]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
