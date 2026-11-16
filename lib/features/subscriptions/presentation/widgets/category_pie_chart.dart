import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_container.dart';
import '../../../../core/utils/currency_formatter.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({
    required this.values,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.currency,
    super.key,
  });

  final Map<String, double> values;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<double>(0, (sum, e) => sum + e.value);
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spending by category',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Add a subscription to see your breakdown',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 190,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions) return;
                      final index =
                          response?.touchedSection?.touchedSectionIndex;
                      onCategorySelected(
                        index == null ? null : entries[index].key,
                      );
                    },
                  ),
                  sections: [
                    for (final entry in entries)
                      PieChartSectionData(
                        value: entry.value,
                        color:
                            AppColors.categories[entry.key] ?? AppColors.muted,
                        radius:
                            selectedCategory == null ||
                                selectedCategory == entry.key
                            ? 58
                            : 48,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final entry in entries)
                  ActionChip(
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor:
                          AppColors.categories[entry.key] ?? AppColors.muted,
                    ),
                    label: Text(
                      '${entry.key} · ${((entry.value / total) * 100).round()}% '
                      '(${CurrencyFormatter.format(entry.value, currency)})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: () => onCategorySelected(
                      selectedCategory == entry.key ? null : entry.key,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
